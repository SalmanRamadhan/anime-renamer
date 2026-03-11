# 🎬 Anime Renamer

> A Python tool that automatically renames your messy anime files and folders into a clean, consistent, media-server-friendly naming convention.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.6%2B-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20|%20macOS%20|%20Linux-0078d4.svg)]()

---

## ✨ Features

- 🔍 **Smart parsing** — handles fansub, scene, and streaming release formats
- 📁 **File & folder renaming** — consistent, pretty naming in one command
- 👀 **Dry-run mode** — preview every change before committing
- ↩️ **Undo mode** — instantly revert renames using an auto-generated log
- 📂 **Recursive mode** — process entire anime libraries in one go
- 🧹 **Auto-cleanup** — removes underscores, dots, illegal characters, and stray brackets
- 📝 **Change log** — every rename is logged to `rename-log.txt` for auditing
- 🖱️ **Interactive mode** — run with no arguments for a guided, no-typing experience
- 🌐 **Unicode support** — handles Japanese titles and special characters
- 🔧 **Zero dependencies** — pure Python stdlib, nothing extra to install
- 🖥️ **Cross-platform** — works on Windows, macOS, and Linux

---

## 📐 Naming Conventions

### Folder

```
[Anime Title] ([Year]) [Type] [Resolution]
```

| Example |
|---------|
| `Demon Slayer (2019) [TV] [1080p]` |
| `Your Name (2016) [Movie] [BD 1080p]` |
| `Sword Art Online (2012) [TV] [720p]` |

### File

```
[Anime Title] - [Episode] [Resolution] [Group].extension
```

| Example |
|---------|
| `Shingeki no Kyojin - 01 [1080p] [HorribleSubs].mkv` |
| `Jujutsu Kaisen - 01 [1080p] [SubsPlease].mkv` |
| `One Piece - 1015 [1080p] [CR].mkv` |

---

## 🚀 Quick Start

### Option A — Double-click (Windows, easiest)

1. Download or clone this repo.
2. Double-click **`anime-renamer-py.bat`**.
3. Follow the on-screen prompts — enter your folder path, choose options, done!

### Option B — Command line

```bash
# Interactive mode (no arguments = guided prompts)
python anime_renamer.py

# Basic usage
python anime_renamer.py --path "C:\Anime\Demon Slayer"

# With year and type tags on the folder
python anime_renamer.py --path "C:\Anime\Demon Slayer" --year 2019 --type TV

# Dry-run first (no changes made)
python anime_renamer.py --path "C:\Anime\Demon Slayer" --dry-run

# Process an entire library recursively
python anime_renamer.py --path "C:\Anime" --recurse --dry-run

# Undo all renames (reads rename-log.txt)
python anime_renamer.py --path "C:\Anime\Demon Slayer" --undo

# Override the group tag for all files
python anime_renamer.py --path "C:\Anime\One Piece" --group CR
```

---

## 📋 Parameters

| Parameter | Short | Type | Default | Description |
|-----------|-------|------|---------|-------------|
| `--path` | `-p` | String | *(required)* | Target directory to process |
| `--dry-run` | `-d` | Flag | off | Preview changes without renaming |
| `--recurse` | `-r` | Flag | off | Process all subdirectories |
| `--undo` | `-u` | Flag | off | Revert renames using `rename-log.txt` |
| `--type` | `-t` | String | `TV` | Folder type tag: `TV`, `Movie`, `OVA`, `ONA`, `Special` |
| `--year` | `-y` | String | *(empty)* | Release year added to folder name |
| `--group` | `-g` | String | *(auto-detect)* | Override release group tag for all files |

---

## 🔄 Before & After Examples

### Files

| Before (messy) | After (pretty) |
|----------------|----------------|
| `[HorribleSubs] Shingeki no Kyojin - 01 [1080p].mkv` | `Shingeki no Kyojin - 01 [1080p] [HorribleSubs].mkv` |
| `[Erai-raws] Kimetsu no Yaiba - 01 [1080p][Multiple Subtitle].mkv` | `Kimetsu no Yaiba - 01 [1080p] [Erai-raws].mkv` |
| `One.Piece.E1015.1080p.WEB.x264-CR.mkv` | `One Piece - 1015 [1080p] [CR].mkv` |
| `[SubsPlease] Jujutsu Kaisen - 01 (1080p) [A1B2C3D4].mkv` | `Jujutsu Kaisen - 01 [1080p] [SubsPlease].mkv` |
| `[SubsPlease]_Boku_No_Hero_-_01_[720p][ABCD1234].mkv` | `Boku no Hero - 01 [720p] [SubsPlease].mkv` |
| `Attack.on.Titan.S04E28.1080p.BluRay.x264-GROUP.mkv` | `Attack on Titan - 28 [1080p] [GROUP].mkv` |
| `Naruto Episode 01.mkv` | `Naruto - 01.mkv` |

### Folders

| Before | After |
|--------|-------|
| `[HorribleSubs] Demon Slayer` | `Demon Slayer (2019) [TV] [1080p]` |
| `Jujutsu.Kaisen.S01` | `Jujutsu Kaisen S01 (2020) [TV] [1080p]` |

---

## 📦 Supported Input Formats

```
[SubGroup] Anime Title - 01 (1080p) [HASH].mkv
[SubGroup] Anime Title - 01v2 (720p) [HASH].mkv
[SubGroup]_Anime_Title_-_01_[1080p][HASH].mkv
Anime.Title.S01E01.1080p.BluRay.x264-GROUP.mkv
Anime.Title.E1015.1080p.WEB.x264-CR.mkv
Anime Title Episode 01.mkv
Anime Title - 01 [1080p].mkv
```

---

## 📁 Files in This Repo

| File | Description |
|------|-------------|
| `anime_renamer.py` | Main Python script |
| `anime-renamer-py.bat` | Double-click Windows launcher |
| `anime-renamer.ps1` | Legacy PowerShell script |
| `anime-renamer.bat` | Legacy PowerShell batch wrapper |
| `README.md` | This documentation |
| `LICENSE` | MIT License |
| `.gitignore` | Ignores logs & OS junk |

---

## ⚙️ Requirements

- **Python:** 3.6 or later
- **OS:** Windows 10/11, macOS, or Linux
- No external packages required — uses only the Python standard library.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).  
© 2026 SalmanRamadhan
