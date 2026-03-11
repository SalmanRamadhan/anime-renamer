@echo off
:: Anime Renamer - Python launcher
:: Double-click this file to start in interactive mode.

:: Try python, then py (Windows launcher)
where python >nul 2>&1
if %errorlevel%==0 (
    python "%~dp0anime_renamer.py" %*
    goto :done
)

where py >nul 2>&1
if %errorlevel%==0 (
    py "%~dp0anime_renamer.py" %*
    goto :done
)

echo.
echo  ERROR: Python is not installed or not in PATH.
echo  Please install Python 3.6+ from https://www.python.org/downloads/
echo.

:done
pause
