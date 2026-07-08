param(
    [string]$HostName,

    [string]$User = "pi",

    [switch]$RestartClient,

    [switch]$Reboot,

    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$script:ExitCode = 0

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found. Install OpenSSH Client, then reopen PowerShell."
    }
}

function Pause-BeforeExit {
    if (-not $NoPause.IsPresent) {
        Write-Host ""
        Read-Host "Press Enter to close this window"
    }
}

try {
    if ([string]::IsNullOrWhiteSpace($HostName)) {
        $HostName = Read-Host "Enter the frame IP address or hostname"
    }

    if ([string]::IsNullOrWhiteSpace($HostName)) {
        throw "No host was provided."
    }

    Require-Command ssh

    $target = "$User@$HostName"
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
sudo mkdir -p "`$SCRIPTS_DIR"

download_and_install() {
    url="`$1"
    destination="`$2"
    temp_file="`$(mktemp)"

    echo "[picFamily] Downloading `$destination..."
    wget -O "`$temp_file" "`$url"
    sudo install -m 755 "`$temp_file" "`$destination"
    rm -f "`$temp_file"
}

echo "[picFamily] Downloading current scripts..."
download_and_install "`$INSTALL_URL" "`$SCRIPTS_DIR/install.sh"
download_and_install "`$UPDATE_CRONTAB_URL" "`$SCRIPTS_DIR/update_crontab.sh"
download_and_install "`$PICFAMILY_URL" "`$SCRIPTS_DIR/picFamily.py"

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
    $sshSucceeded = $?
    $sshExitCode = $LASTEXITCODE

    if ((-not $sshSucceeded) -or ($sshExitCode -ne 0)) {
        throw "SSH command failed with exit code $sshExitCode."
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $script:ExitCode = 1
}
finally {
    Pause-BeforeExit
}

exit $script:ExitCode
