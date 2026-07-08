param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [string]$User = "pi",

    [switch]$RestartClient,

    [switch]$Reboot
)

$ErrorActionPreference = "Stop"

$target = "$User@$HostName"

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install OpenSSH Client, then reopen PowerShell."
    }
}

Require-Command ssh

$restartClientValue = if ($RestartClient.IsPresent) { "1" } else { "0" }
$rebootValue = if ($Reboot.IsPresent) { "1" } else { "0" }

$remoteScript = @"
set -e

RESTART_CLIENT="$restartClientValue"
REBOOT_DEVICE="$rebootValue"
SCRIPTS_DIR="/home/pi/scripts"
INSTALL_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh"
UPDATE_CRONTAB_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh"
PICFAMILY_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py"

echo "[picFamily] Connected to `$(hostname) as `$(whoami)"
echo "[picFamily] Ensuring scripts directory exists..."
mkdir -p "`$SCRIPTS_DIR"

echo "[picFamily] Downloading current scripts..."
wget -O "`$SCRIPTS_DIR/install.sh" "`$INSTALL_URL"
wget -O "`$SCRIPTS_DIR/update_crontab.sh" "`$UPDATE_CRONTAB_URL"
wget -O "`$SCRIPTS_DIR/picFamily.py" "`$PICFAMILY_URL"
chmod +x "`$SCRIPTS_DIR/install.sh" "`$SCRIPTS_DIR/update_crontab.sh" "`$SCRIPTS_DIR/picFamily.py"

echo "[picFamily] Updating root crontab..."
sudo bash "`$SCRIPTS_DIR/update_crontab.sh"

echo "[picFamily] Current managed crontab:"
sudo crontab -l

if [ "`$RESTART_CLIENT" = "1" ]; then
    echo "[picFamily] Restarting client without reboot..."
    sudo pkill -f picFamily.py 2>/dev/null || true
    sudo pkill fim 2>/dev/null || true
    sudo nohup /bin/bash -lc 'sleep 2; /home/pi/scripts/start_picfamily.sh' >> /home/pi/cron_output.log 2>&1 &
fi

if [ "`$REBOOT_DEVICE" = "1" ]; then
    echo "[picFamily] Rebooting device..."
    sudo reboot
fi

echo "[picFamily] Remote update complete."
"@

Write-Host "Connecting to $target..."
Write-Host "If prompted, enter the Raspberry Pi password. The password will not show while typing."

$remoteScript | ssh $target "bash -s"
