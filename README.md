# 🎬 Anime Renamer

> A Windows PowerShell toolkit that automatically renames your messy anime files and folders into a clean, consistent, media-server-friendly naming convention.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078d4.svg)](https://www.microsoft.com/windows)

---

## ✨ Features

- 🔍 **Smart parsing** — handles fansub, scene, and streaming release formats
- 📁 **File & folder renaming** — consistent, pretty naming in one command
- 👀 **Dry-run mode** — preview every change before committing
- ↩️ **Undo mode** — instantly revert renames using an auto-generated log
- 📂 **Recursive mode** — process entire anime libraries in one go
- 🧹 **Auto-cleanup** — removes underscores, dots, illegal characters, and stray brackets
- 📝 **Change log** — every rename is logged to `rename-log.txt` for auditing
- 🖱️ **Batch wrapper** — double-click `anime-renamer.bat` for a guided, no-typing experience
- 🌐 **Unicode support** — handles Japanese titles and special characters
- 🔧 **Zero dependencies** — pure PowerShell, nothing to install

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

### Option A — Double-click (easiest)

1. Download or clone this repo.
2. Double-click **`anime-renamer.bat`**.
3. Follow the on-screen prompts — enter your folder path, choose options, done!

### Option B — PowerShell

```powershell
# Basic usage
.\anime-renamer.ps1 -Path "C:\Anime\Demon Slayer"

# With year and type tags on the folder
.\anime-renamer.ps1 -Path "C:\Anime\Demon Slayer" -Year 2019 -Type TV

# Dry-run first (no changes made)
.\anime-renamer.ps1 -Path "C:\Anime\Demon Slayer" -DryRun

# Process an entire library recursively
.\anime-renamer.ps1 -Path "C:\Anime" -Recurse -DryRun

# Undo all renames (reads rename-log.txt)
.\anime-renamer.ps1 -Path "C:\Anime\Demon Slayer" -Undo

# Override the group tag for all files
.\anime-renamer.ps1 -Path "C:\Anime\One Piece" -Group CR
```

---

## 📋 Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Path` | String | *(required)* | Target directory to process |
| `-DryRun` | Switch | off | Preview changes without renaming |
| `-Recurse` | Switch | off | Process all subdirectories |
| `-Undo` | Switch | off | Revert renames using `rename-log.txt` |
| `-Type` | String | `TV` | Folder type tag: `TV`, `Movie`, `OVA`, `ONA`, `Special` |
| `-Year` | String | *(empty)* | Release year added to folder name |
| `-Group` | String | *(auto-detect)* | Override release group tag for all files |

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
| `anime-renamer.ps1` | Main PowerShell script |
| `anime-renamer.bat` | Double-click batch wrapper |
| `README.md` | This documentation |
| `LICENSE` | MIT License |
| `.gitignore` | Ignores logs & OS junk |

---

## ⚙️ Requirements

- **OS:** Windows 10 or Windows 11
- **PowerShell:** 5.1 or later *(pre-installed on Windows 10+)*
- **Execution Policy:** The `.bat` wrapper sets `-ExecutionPolicy Bypass` automatically. If running the `.ps1` directly, you may need to allow script execution:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).  
© 2026 SalmanRamadhan
