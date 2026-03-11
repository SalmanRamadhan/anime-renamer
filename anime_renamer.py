#!/usr/bin/env python3
"""
Anime Renamer - Prettifies anime media libraries.

Parses common anime file naming patterns (fansub, scene, streaming rips) and
renames them into clean, consistent naming conventions.

File output:   [Anime Title] - [Episode] [Resolution] [Group].ext
Folder output: [Anime Title] ([Year]) [Type] [Resolution]
"""

import argparse
import os
import re
import sys
from datetime import datetime

# ── Constants ────────────────────────────────────────────────────────────────

LOG_FILE_NAME = "rename-log.txt"
VIDEO_EXTS = {
    ".mkv", ".mp4", ".avi", ".m4v", ".mov",
    ".wmv", ".flv", ".webm", ".ts", ".m2ts",
}
ILLEGAL_CHARS_RE = re.compile(r'[/\\:*?"<>|]')


# ── ANSI colour helpers (Windows 10+ supports VT sequences) ──────────────────

def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m"

def cyan(t: str) -> str:    return _c("36", t)
def yellow(t: str) -> str:  return _c("33", t)
def green(t: str) -> str:   return _c("32", t)
def magenta(t: str) -> str: return _c("35", t)
def gray(t: str) -> str:    return _c("90", t)
def red(t: str) -> str:     return _c("31", t)


# ── Title Case ───────────────────────────────────────────────────────────────

LOWER_WORDS = {
    "a", "an", "the", "and", "but", "or", "nor", "for", "so", "yet",
    "at", "by", "in", "of", "on", "to", "up", "as", "is", "it",
    "no", "de", "da", "di", "van", "von", "el", "la", "le", "les",
}


def title_case(text: str) -> str:
    if not text or not text.strip():
        return ""
    words = text.split()
    result = []
    count = len(words)
    for i, word in enumerate(words):
        # Preserve all-uppercase abbreviations (e.g. CR, WEB, BD)
        if len(word) > 1 and word == word.upper():
            result.append(word)
        elif 0 < i < count - 1 and word.lower() in LOWER_WORDS:
            result.append(word.lower())
        else:
            result.append(word.capitalize())
    return " ".join(result)


# ── Clean text ───────────────────────────────────────────────────────────────

def clean_title(text: str) -> str:
    if not text or not text.strip():
        return ""
    text = text.replace("_", " ")
    text = re.sub(r"\.(?=[A-Za-z])", " ", text)   # dot before letter -> space
    text = re.sub(r"\.(?=\d{4})", " ", text)       # dot before 4-digit year
    text = ILLEGAL_CHARS_RE.sub("", text)
    text = re.sub(r"\s{2,}", " ", text)
    return text.strip()


# ── Parse anime filename ────────────────────────────────────────────────────

def parse_anime_info(filename: str) -> dict:
    info = {
        "title": "",
        "episode": "",
        "version": "",
        "resolution": "",
        "release_group": "",
        "hash": "",
    }
    base = os.path.splitext(filename)[0]

    # Pattern 1-3: [SubGroup] Anime Title - 01 (1080p) [HASH]
    fansub = re.match(
        r"^\[(?P<group>[^\]]+)\]\s*(?P<title>.+?)\s*(?:-|_-_)\s*"
        r"(?P<ep>\d{1,4})(?P<ver>v\d)?[\s_]*"
        r"(?:\[(?P<res>\d{3,4}p|4[Kk]|2160p)\]|\((?P<res2>\d{3,4}p|4[Kk]|2160p)\))?"
        r"(?:[\s_]*\[(?P<hash>[0-9A-Fa-f]{8})\])?.*$",
        base,
    )
    if fansub:
        info["release_group"] = fansub.group("group").strip()
        info["title"] = clean_title(fansub.group("title"))
        info["episode"] = fansub.group("ep").lstrip("0").zfill(2)
        info["version"] = fansub.group("ver") or ""
        res = fansub.group("res") or fansub.group("res2") or ""
        info["resolution"] = res.lower()
        info["hash"] = fansub.group("hash") or ""
        return info

    # Pattern 4: Scene — Anime.Title.S01E01.1080p.BluRay.x264-GROUP
    scene = re.match(
        r"^(?P<title>.+?)\.S\d{1,2}E(?P<ep>\d{1,4})\.(?P<res>\d{3,4}p)?.*?(?:-(?P<group>[A-Za-z0-9]+))?$",
        base,
        re.IGNORECASE,
    )
    if scene:
        info["title"] = clean_title(scene.group("title"))
        info["episode"] = scene.group("ep").lstrip("0").zfill(2)
        info["resolution"] = (scene.group("res") or "").lower()
        info["release_group"] = scene.group("group") or ""
        return info

    # Pattern 5: Scene without season — Anime.Title.E1015.1080p.WEB.x264-GROUP
    scene_e = re.match(
        r"^(?P<title>.+?)\.E(?P<ep>\d{1,4})\.(?P<res>\d{3,4}p)?.*?(?:-(?P<group>[A-Za-z0-9]+))?$",
        base,
        re.IGNORECASE,
    )
    if scene_e:
        info["title"] = clean_title(scene_e.group("title"))
        info["episode"] = scene_e.group("ep").lstrip("0").zfill(2)
        info["resolution"] = (scene_e.group("res") or "").lower()
        info["release_group"] = scene_e.group("group") or ""
        return info

    # Pattern 6: Anime Title Episode 01
    ep_word = re.match(
        r"^(?P<title>.+?)\s+[Ee]pisode\s+(?P<ep>\d{1,4})",
        base,
        re.IGNORECASE,
    )
    if ep_word:
        info["title"] = clean_title(ep_word.group("title"))
        info["episode"] = ep_word.group("ep").lstrip("0").zfill(2)
        return info

    # Pattern 7: Generic — Anime Title - 01 [1080p]
    generic = re.match(
        r"^(?P<title>.+?)\s*-\s*(?P<ep>\d{1,4})(?P<ver>v\d)?"
        r"(?:\s*[\[\(](?P<res>\d{3,4}p|4[Kk]|2160p)[\]\)])?",
        base,
    )
    if generic:
        info["title"] = clean_title(generic.group("title"))
        info["episode"] = generic.group("ep").lstrip("0").zfill(2)
        info["version"] = generic.group("ver") or ""
        info["resolution"] = (generic.group("res") or "").lower()
        return info

    # Fallback: use entire base as title
    info["title"] = clean_title(base)
    return info


# ── Extract resolution from any bracket in filename ──────────────────────────

def get_resolution(name: str) -> str:
    m = re.search(r"(4[Kk]|2160p|\d{3,4}p)", name, re.IGNORECASE)
    return m.group(0).lower() if m else ""


# ── Build pretty file name ──────────────────────────────────────────────────

def build_pretty_filename(info: dict, ext: str, group_override: str = "") -> str:
    title = title_case(info["title"])
    ep = info["episode"]
    res = info["resolution"]
    grp = group_override or info["release_group"]

    parts = [title]
    if ep:
        parts.append(f"- {ep}")
    if res:
        parts.append(f"[{res}]")
    if grp:
        parts.append(f"[{grp}]")

    name = " ".join(parts).strip()
    name = ILLEGAL_CHARS_RE.sub("", name)
    name = re.sub(r"\s{2,}", " ", name)
    return f"{name}{ext}"


# ── Build pretty folder name ────────────────────────────────────────────────

def build_pretty_folder_name(folder_name: str, type_tag: str, year_tag: str, resolution_tag: str) -> str:
    clean = re.sub(r"\[.*?\]", "", folder_name)
    clean = re.sub(r"\(?\d{3,4}p\)?", "", clean)
    clean = clean_title(clean)
    title = title_case(clean)

    parts = [title]
    if year_tag:
        parts.append(f"({year_tag})")
    if type_tag:
        parts.append(f"[{type_tag}]")
    if resolution_tag:
        parts.append(f"[{resolution_tag}]")

    name = " ".join(parts).strip()
    name = ILLEGAL_CHARS_RE.sub("", name)
    name = re.sub(r"\s{2,}", " ", name)
    return name


# ── Logging ──────────────────────────────────────────────────────────────────

def write_log(log_path: str, old_name: str, new_name: str, directory: str):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"{timestamp} | {old_name} | {new_name} | {directory}\n"
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(line)


# ── Undo mode ────────────────────────────────────────────────────────────────

def undo(directory_path: str):
    log_path = os.path.join(directory_path, LOG_FILE_NAME)
    if not os.path.isfile(log_path):
        print(yellow(f"  WARNING: No rename log found at: {log_path}"))
        return

    with open(log_path, encoding="utf-8") as f:
        lines = [l.rstrip("\n") for l in f if "|" in l]

    reverted = 0
    errors = 0

    for line in lines:
        if re.match(r"^(TIMESTAMP|[-=]+)", line):
            continue
        parts = line.split("|")
        if len(parts) < 3:
            continue

        old_name = parts[1].strip()
        new_name = parts[2].strip()
        dir_part = parts[3].strip() if len(parts) > 3 else ""
        d = dir_part or directory_path

        new_path = os.path.join(d, new_name)
        old_path = os.path.join(d, old_name)

        if not os.path.exists(new_path):
            print(yellow(f"  WARNING: Not found (skipping): {new_path}"))
            continue
        if os.path.exists(old_path):
            print(yellow(f"  WARNING: Target already exists (skipping): {old_path}"))
            continue

        try:
            os.rename(new_path, old_path)
            print(cyan(f"  Reverted: {new_name} -> {old_name}"))
            reverted += 1
        except OSError as e:
            print(yellow(f"  WARNING: Failed to revert '{new_name}': {e}"))
            errors += 1

    print()
    print(green(f"Undo complete. Reverted: {reverted}  Errors: {errors}"))


# ── Rename files in a directory ──────────────────────────────────────────────

def rename_files(directory_path: str, log_path: str, group_override: str, dry_run: bool):
    renamed = 0
    skipped = 0

    files = sorted(
        [
            f for f in os.listdir(directory_path)
            if os.path.isfile(os.path.join(directory_path, f))
            and os.path.splitext(f)[1].lower() in VIDEO_EXTS
        ]
    )

    for fname in files:
        info = parse_anime_info(fname)
        ext = os.path.splitext(fname)[1]

        if not info["resolution"]:
            info["resolution"] = get_resolution(fname)

        pretty = build_pretty_filename(info, ext, group_override)

        if pretty == fname:
            skipped += 1
            continue

        dest = os.path.join(directory_path, pretty)

        print(yellow(f"  {fname}"))
        print(green(f"    -> {pretty}"))

        if not dry_run:
            if os.path.exists(dest):
                print(yellow(f"    Skipped (destination exists): {pretty}"))
                skipped += 1
                continue
            try:
                os.rename(os.path.join(directory_path, fname), dest)
                write_log(log_path, fname, pretty, directory_path)
                renamed += 1
            except OSError as e:
                print(yellow(f"    Error renaming '{fname}': {e}"))
                skipped += 1
        else:
            renamed += 1

    return renamed, skipped


# ── Rename folder ────────────────────────────────────────────────────────────

def rename_folder(directory_path: str, log_path: str, type_tag: str,
                  year_tag: str, resolution_tag: str, dry_run: bool) -> str:
    dir_name = os.path.basename(directory_path)

    # Determine dominant resolution from files inside
    if not resolution_tag:
        files = sorted(
            f for f in os.listdir(directory_path)
            if os.path.isfile(os.path.join(directory_path, f))
            and os.path.splitext(f)[1].lower() in VIDEO_EXTS
        )
        for f in files[:5]:
            res = get_resolution(f)
            if res:
                resolution_tag = res
                break

    pretty = build_pretty_folder_name(dir_name, type_tag, year_tag, resolution_tag)

    if pretty == dir_name:
        print(cyan(f"Folder already pretty: {dir_name}"))
        return directory_path

    parent = os.path.dirname(directory_path)
    new_path = os.path.join(parent, pretty)

    print()
    print(magenta("Folder:"))
    print(yellow(f"  {dir_name}"))
    print(green(f"  -> {pretty}"))

    if not dry_run:
        if os.path.exists(new_path):
            print(yellow(f"  Skipped folder rename (destination exists): {pretty}"))
            return directory_path
        try:
            os.rename(directory_path, new_path)
            write_log(log_path, dir_name, pretty, parent)
            return new_path
        except OSError as e:
            print(yellow(f"  Error renaming folder '{dir_name}': {e}"))
            return directory_path

    return directory_path


# ── Interactive mode (replaces the old .bat wrapper) ─────────────────────────

def interactive():
    print()
    print("  =============================================")
    print("      Anime Renamer - Interactive Mode")
    print("  =============================================")
    print()

    path = input("Enter the full path to your anime folder: ").strip()
    if not os.path.isdir(path):
        print(red(f"\n  ERROR: Path does not exist: {path}\n"))
        return

    print()
    do_dry = input("Do a dry-run first (preview changes without renaming)? [Y/n]: ").strip()
    dry_run = do_dry.lower() != "n"

    print()
    do_recurse = input("Process subdirectories recursively? [y/N]: ").strip()
    recurse = do_recurse.lower() == "y"

    print()
    print("  Anime type options: TV, Movie, OVA, ONA, Special")
    type_tag = input("Anime type [default: TV]: ").strip() or "TV"

    print()
    year = input("Release year (leave blank to skip): ").strip()

    print()
    group = input("Override group tag (leave blank to auto-detect): ").strip()

    # Build argv and run
    argv = ["--path", path, "--type", type_tag]
    if dry_run:
        argv.append("--dry-run")
    if recurse:
        argv.append("--recurse")
    if year:
        argv.extend(["--year", year])
    if group:
        argv.extend(["--group", group])

    args = build_parser().parse_args(argv)
    run(args)

    # Offer to apply for real after dry-run
    if dry_run:
        print()
        apply = input("Dry-run complete. Apply the renames now? [y/N]: ").strip()
        if apply.lower() == "y":
            print()
            print("  Applying renames ...")
            print()
            argv2 = ["--path", path, "--type", type_tag]
            if recurse:
                argv2.append("--recurse")
            if year:
                argv2.extend(["--year", year])
            if group:
                argv2.extend(["--group", group])
            args2 = build_parser().parse_args(argv2)
            run(args2)


# ── Main logic ───────────────────────────────────────────────────────────────

def run(args):
    path = os.path.abspath(args.path)
    if not os.path.isdir(path):
        print(red(f"ERROR: Path not found or not a directory: {path}"))
        sys.exit(1)

    dry_run = args.dry_run
    recurse = args.recurse
    do_undo = args.undo
    type_tag = args.type
    year = args.year
    group = args.group

    # Banner
    print()
    print(cyan("  =========================================="))
    print(cyan("            Anime Renamer"))
    print(cyan("  =========================================="))
    print()

    if dry_run:
        print(yellow("[DRY RUN] No files will be changed."))
        print()

    # Undo mode
    if do_undo:
        print(magenta("Mode: Undo"))
        undo(path)
        return

    # Log file
    log_path = os.path.join(path, LOG_FILE_NAME)
    if not dry_run and not os.path.isfile(log_path):
        with open(log_path, "w", encoding="utf-8") as f:
            f.write("TIMESTAMP                | OLD NAME | NEW NAME | DIRECTORY\n")
            f.write("-" * 80 + "\n")

    total_renamed = 0
    total_skipped = 0

    if recurse:
        # Process subdirectories leaf-first
        sub_dirs = []
        for root, dirs, _files in os.walk(path):
            for d in dirs:
                sub_dirs.append(os.path.join(root, d))
        sub_dirs.sort(reverse=True)

        for sub in sub_dirs:
            if not os.path.isdir(sub):
                continue
            print(cyan(f"Processing: {sub}"))
            r, s = rename_files(sub, log_path, group, dry_run)
            total_renamed += r
            total_skipped += s

    # Process target directory
    print(cyan(f"Processing: {path}"))
    r, s = rename_files(path, log_path, group, dry_run)
    total_renamed += r
    total_skipped += s

    # Rename folder
    path = rename_folder(path, log_path, type_tag, year,
                         get_resolution(path), dry_run)

    # Summary
    print()
    print(cyan("---------------------------------------------"))
    if dry_run:
        print(yellow(f"DRY RUN complete. Would rename: {total_renamed}  Unchanged: {total_skipped}"))
    else:
        print(green(f"Done! Renamed: {total_renamed}  Skipped: {total_skipped}"))
        if total_renamed > 0:
            print(gray(f"Log saved to: {log_path}"))
    print()


# ── CLI ──────────────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(
        description="Anime file and folder renamer - prettifies anime media libraries.",
    )
    p.add_argument("--path", "-p", required=True, help="Target directory path to process.")
    p.add_argument("--dry-run", "-d", action="store_true", help="Preview changes without renaming.")
    p.add_argument("--recurse", "-r", action="store_true", help="Process subdirectories recursively.")
    p.add_argument("--undo", "-u", action="store_true", help="Revert renames using rename-log.txt.")
    p.add_argument("--type", "-t", default="TV",
                   choices=["TV", "Movie", "OVA", "ONA", "Special"],
                   help="Anime type tag (default: TV).")
    p.add_argument("--year", "-y", default="", help="Release year to add to folder names.")
    p.add_argument("--group", "-g", default="", help="Override release group tag for all files.")
    return p


def main():
    # If no arguments provided, enter interactive mode
    if len(sys.argv) == 1:
        interactive()
    else:
        args = build_parser().parse_args()
        run(args)


if __name__ == "__main__":
    # Enable ANSI escape sequences on Windows
    if sys.platform == "win32":
        os.system("")  # noqa: S605 – triggers VT100 mode on Windows 10+
    main()
