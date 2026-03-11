@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

echo.
echo  =============================================
echo      Anime Renamer — Windows Batch Wrapper
echo  =============================================
echo.

:: ── Ask for path ─────────────────────────────────────────────────────────────
set /p "ANIME_PATH=Enter the full path to your anime folder: "

if not exist "!ANIME_PATH!" (
    echo.
    echo  ERROR: Path does not exist: !ANIME_PATH!
    echo.
    pause
    exit /b 1
)

:: ── Dry run? ──────────────────────────────────────────────────────────────────
echo.
set /p "DO_DRYRUN=Do a dry-run first (preview changes without renaming)? [Y/n]: "
if /i "!DO_DRYRUN!"=="" set DO_DRYRUN=Y
if /i "!DO_DRYRUN!"=="y" (
    set DRYRUN_FLAG=-DryRun
) else (
    set DRYRUN_FLAG=
)

:: ── Recurse? ──────────────────────────────────────────────────────────────────
echo.
set /p "DO_RECURSE=Process subdirectories recursively? [y/N]: "
if /i "!DO_RECURSE!"=="" set DO_RECURSE=N
if /i "!DO_RECURSE!"=="y" (
    set RECURSE_FLAG=-Recurse
) else (
    set RECURSE_FLAG=
)

:: ── Type ──────────────────────────────────────────────────────────────────────
echo.
echo  Anime type options: TV, Movie, OVA, ONA, Special
set /p "ANIME_TYPE=Anime type [default: TV]: "
if "!ANIME_TYPE!"=="" set ANIME_TYPE=TV

:: ── Year ──────────────────────────────────────────────────────────────────────
echo.
set /p "ANIME_YEAR=Release year (leave blank to skip): "
if "!ANIME_YEAR!"=="" (
    set YEAR_FLAG=
) else (
    set YEAR_FLAG=-Year "!ANIME_YEAR!"
)

:: ── Group override ────────────────────────────────────────────────────────────
echo.
set /p "ANIME_GROUP=Override group tag (leave blank to auto-detect): "
if "!ANIME_GROUP!"=="" (
    set GROUP_FLAG=
) else (
    set GROUP_FLAG=-Group "!ANIME_GROUP!"
)

:: ── Run the PowerShell script ─────────────────────────────────────────────────
echo.
echo  Running anime-renamer.ps1 ...
echo.

:: Determine directory of this batch file so we can find the .ps1 next to it
set "SCRIPT_DIR=%~dp0"
set "PS1_PATH=%SCRIPT_DIR%anime-renamer.ps1"

if not exist "!PS1_PATH!" (
    echo  ERROR: Could not find anime-renamer.ps1 next to this batch file.
    echo  Expected: !PS1_PATH!
    echo.
    pause
    exit /b 1
)

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "!PS1_PATH!" ^
    -Path "!ANIME_PATH!" ^
    !DRYRUN_FLAG! ^
    !RECURSE_FLAG! ^
    -Type "!ANIME_TYPE!" ^
    !YEAR_FLAG! ^
    !GROUP_FLAG!

echo.

:: ── If dry-run was done, offer to run for real ────────────────────────────────
if /i "!DRYRUN_FLAG!"=="-DryRun" (
    echo.
    set /p "RUN_REAL=Dry-run complete. Apply the renames now? [y/N]: "
    if /i "!RUN_REAL!"=="y" (
        echo.
        echo  Applying renames ...
        echo.
        powershell.exe -ExecutionPolicy Bypass -NoProfile -File "!PS1_PATH!" ^
            -Path "!ANIME_PATH!" ^
            !RECURSE_FLAG! ^
            -Type "!ANIME_TYPE!" ^
            !YEAR_FLAG! ^
            !GROUP_FLAG!
    )
)

echo.
pause
endlocal
