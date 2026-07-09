@echo off
setlocal EnableExtensions

title picFamily remote updater
cd /d "%~dp0"

echo picFamily remote updater
echo.
echo This window will stay open when the update finishes.
echo.

where ssh >nul 2>nul
if errorlevel 1 (
    echo ERROR: ssh was not found on this computer.
    echo.
    echo Install OpenSSH Client from Windows Optional Features, then try again.
    echo.
    pause
    exit /b 1
)

set "PI_USER=pi"
set /p "PI_HOST=Enter the frame IP address or hostname: "

if "%PI_HOST%"=="" (
    echo.
    echo ERROR: No host was entered.
    echo.
    pause
    exit /b 1
)

echo.
echo Connecting to %PI_USER%@%PI_HOST%...
echo If prompted, enter the Raspberry Pi password. The password will not show while typing.
echo.

ssh -t %PI_USER%@%PI_HOST% "bash -lc 'set -e; SCRIPTS_DIR=/home/pi/scripts; INSTALL_URL=https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh; UPDATE_CRONTAB_URL=https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh; PICFAMILY_URL=https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py; echo [picFamily] Connected to $(hostname) as $(whoami); echo [picFamily] Ensuring runtime packages are installed...; if ! dpkg -s python3-requests ca-certificates wget >/dev/null 2>&1; then sudo apt-get update; sudo apt-get install -y python3-requests ca-certificates wget; fi; echo [picFamily] Ensuring scripts directory exists...; sudo mkdir -p $SCRIPTS_DIR; download_and_install() { url=$1; destination=$2; temp_file=$(mktemp); echo [picFamily] Downloading $destination...; wget -O $temp_file $url; sudo install -m 755 $temp_file $destination; rm -f $temp_file; }; echo [picFamily] Downloading current scripts...; download_and_install $INSTALL_URL $SCRIPTS_DIR/install.sh; download_and_install $UPDATE_CRONTAB_URL $SCRIPTS_DIR/update_crontab.sh; download_and_install $PICFAMILY_URL $SCRIPTS_DIR/picFamily.py; echo [picFamily] Updating root crontab...; sudo bash $SCRIPTS_DIR/update_crontab.sh; echo [picFamily] Current managed crontab:; sudo crontab -l; echo [picFamily] Remote update complete.'"

set "EXIT_CODE=%ERRORLEVEL%"

echo.
echo SSH exited with code %EXIT_CODE%.
echo.

if not "%EXIT_CODE%"=="0" (
    echo The update did not complete successfully. Review the messages above.
    echo.
)

pause
exit /b %EXIT_CODE%
