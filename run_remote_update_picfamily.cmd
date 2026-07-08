@echo off
setlocal

cd /d "%~dp0"

echo picFamily remote updater
echo.
echo This window will stay open when the update finishes.
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0remote_update_picfamily.ps1"

echo.
echo PowerShell exited with code %ERRORLEVEL%.
echo.
pause
