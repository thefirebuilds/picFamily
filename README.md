# picFamily Client

picFamily is a Raspberry Pi digital picture frame client. On boot, the device downloads the current client script from GitHub, asks the picFamily service which image should be displayed, downloads that image if needed, and renders it directly to the framebuffer with `fim`.

## Files

- `picFamily.py` is the runtime client that fetches settings, downloads the selected image, and displays it.
- `install.sh` performs first-time device setup, installs packages, writes the startup script, updates the root crontab, and reboots.
- `update_crontab.sh` is a remote-friendly repair script for updating the managed crontab and startup script without rerunning the full installer.
- `diagnose_picfamily.sh` prints network, crontab, current image, framebuffer, FIM, and recent log diagnostics from a frame.
- `remote_update_picfamily.ps1` runs the repair flow from a workstation over SSH, so the operator does not need to manually log in to the Pi.
- `run_remote_update_picfamily.cmd` is the recommended Windows double-click updater. It uses SSH directly and keeps the window open so the operator can read the result.
- `cleanup.sh` removes local logs and downloaded image files.

## Service Endpoints

The client uses the public DNS name for both internal and external network access:

```text
https://picfamily.blaketex.com
```

Known endpoints:

- `GET /settings` returns the active display settings JSON, including `currentPic` and `setDate`.
- `GET /` returns the JSON feed of available images.
- `GET /images/{fileName}` returns an image file for local download and display.

## Boot Flow

The managed root crontab runs:

```cron
# BEGIN picFamily managed cron
@reboot /home/pi/scripts/start_picfamily.sh >> /home/pi/cron_output.log 2>&1
0 2 * * 0 /sbin/reboot
# END picFamily managed cron
```

`start_picfamily.sh` does the boot work in order:

1. Waits 30 seconds for boot networking to settle.
2. Downloads the current `install.sh` to `/home/pi/scripts/install.sh`, retrying for up to 3 minutes.
3. Downloads the current `update_crontab.sh` to `/home/pi/scripts/update_crontab.sh`, retrying for up to 3 minutes.
4. Downloads the current `picFamily.py` to `/home/pi/scripts/picFamily.py`, retrying for up to 3 minutes.
5. Logs the installed file details to `/home/pi/cron_output.log`.
6. Starts the client with `/usr/bin/python3 /home/pi/scripts/picFamily.py`.

This keeps devices current when `picFamily.py` changes on GitHub and avoids racing separate `@reboot` cron entries.

## Updating Cron Remotely

After `update_crontab.sh` is pushed to GitHub, a helper can run this on a device:

```bash
wget -O /tmp/update_crontab.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh && sudo bash /tmp/update_crontab.sh
```

The script preserves unrelated root crontab entries, removes older picFamily boot entries, writes the managed picFamily cron block, and logs to `/home/pi/update_crontab.log`.

## Updating From a Workstation

Use `remote_update_picfamily.ps1` when you know the frame IP address or hostname and want to repair it from your own computer without opening an interactive SSH session.

On Windows, the easiest path is to double-click:

```text
run_remote_update_picfamily.cmd
```

That launcher asks for the frame IP address or hostname, connects over SSH, runs the update, and keeps the window open so you can read the result. Use the `.cmd` launcher instead of right-clicking the `.ps1` file with `Open with PowerShell`, because Windows may close that PowerShell window before you can see the output.

From this repository folder on a Windows workstation, run:

```powershell
.\remote_update_picfamily.ps1 -HostName DEVICE_IP
```

If this repository is not already on the workstation, download the helper first:

```powershell
Invoke-WebRequest -Uri https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/remote_update_picfamily.ps1 -OutFile remote_update_picfamily.ps1
Invoke-WebRequest -Uri https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/run_remote_update_picfamily.cmd -OutFile run_remote_update_picfamily.cmd
```

For a non-technical helper on Windows, only `run_remote_update_picfamily.cmd` is required.

Example:

```powershell
.\remote_update_picfamily.ps1 -HostName 192.168.86.42
```

The script connects as the `pi` user by default. To use a different user:

```powershell
.\remote_update_picfamily.ps1 -HostName 192.168.86.42 -User blake
```

To update the scripts and restart the picture frame client without rebooting:

```powershell
.\remote_update_picfamily.ps1 -HostName 192.168.86.42 -RestartClient
```

To update the scripts and reboot the device:

```powershell
.\remote_update_picfamily.ps1 -HostName 192.168.86.42 -Reboot
```

For automation, add `-NoPause` so the PowerShell window does not wait for Enter:

```powershell
.\remote_update_picfamily.ps1 -HostName 192.168.86.42 -NoPause
```

The workstation must have SSH installed. On Windows, check with:

```powershell
ssh -V
```

If SSH is missing, install OpenSSH Client:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

The remote helper performs these actions on the Pi:

1. Creates `/home/pi/scripts` if needed.
2. Installs required runtime packages if missing: `python3-requests`, `ca-certificates`, and `wget`.
3. Downloads the current `install.sh`, `update_crontab.sh`, `picFamily.py`, and `diagnose_picfamily.sh`.
4. Marks those files executable.
5. Runs `sudo bash /home/pi/scripts/update_crontab.sh`.
6. Prints the resulting root crontab.
7. Optionally restarts the client or reboots the device.

## Manual Recovery When Cron Fails

Use this when a frame is online but did not update itself at boot. These steps are meant for someone who is not comfortable editing crontab by hand.

### 1. Install or Open an SSH Client

On Windows 10 or Windows 11:

1. Open PowerShell.
2. Check whether SSH is already installed:

```powershell
ssh -V
```

3. If PowerShell says `ssh` is not recognized, install OpenSSH Client:

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

If that install command fails, open Windows Settings, search for `Optional Features`, choose `Add an optional feature`, install `OpenSSH Client`, then reopen PowerShell.

On macOS or Linux, open Terminal. SSH is normally already installed.

### 2. Get the Device IP Address

Use the local IP address shown on the picture frame screen if the device is displaying one. It will usually look like one of these:

```text
192.168.1.25
192.168.86.42
10.0.0.18
```

If the IP is not visible on the screen, check the Wi-Fi router or mesh app for a connected Raspberry Pi device. Common hostnames may include `raspberrypi` or a name you assigned during setup.

You can also try the hostname from your computer:

```bash
ssh pi@raspberrypi.local
```

If that works, you do not need the numeric IP.

### 3. Log In to the Device

From PowerShell or Terminal, connect with the IP address:

```bash
ssh pi@DEVICE_IP
```

Example:

```bash
ssh pi@192.168.86.42
```

If this is the first time connecting, SSH may ask whether to trust the device. Type:

```text
yes
```

Then enter the Raspberry Pi password. The password will not show while typing.

### 4. Move to the Scripts Directory

After logging in:

```bash
cd /home/pi/scripts
pwd
ls -la
```

`pwd` should print:

```text
/home/pi/scripts
```

### 5. Manually Download the Current Files

Run these commands on the Raspberry Pi:

```bash
wget -O /home/pi/scripts/install.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh
wget -O /home/pi/scripts/update_crontab.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh
wget -O /home/pi/scripts/picFamily.py https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py
chmod +x /home/pi/scripts/install.sh /home/pi/scripts/update_crontab.sh /home/pi/scripts/picFamily.py
```

### 6. Repair the Crontab

Run:

```bash
sudo bash /home/pi/scripts/update_crontab.sh
```

Confirm the output includes this managed block:

```cron
# BEGIN picFamily managed cron
@reboot /home/pi/scripts/start_picfamily.sh >> /home/pi/cron_output.log 2>&1
0 2 * * 0 /sbin/reboot
# END picFamily managed cron
```

You can check it again with:

```bash
sudo crontab -l
```

### 7. Restart the Client Without Rebooting

If you want the new code to run immediately:

```bash
sudo pkill -f picFamily.py || true
sudo pkill fim || true
sudo /home/pi/scripts/start_picfamily.sh
```

That command stays attached to the SSH session because it starts the picture frame client. To leave it running after you disconnect, use:

```bash
sudo nohup /home/pi/scripts/start_picfamily.sh >> /home/pi/cron_output.log 2>&1 &
```

Or simply reboot:

```bash
sudo reboot
```

### 8. Check Logs

Useful commands:

```bash
tail -n 80 /home/pi/update_crontab.log
tail -n 80 /home/pi/cron_output.log
tail -n 80 /home/pi/cron.log
tail -n 80 /home/pi/picfamily_debug.log
```

To confirm the endpoint works from the Pi:

```bash
wget -q -O - https://picfamily.blaketex.com/settings
```

To confirm the downloaded client uses the current public URL:

```bash
grep BASE_URL /home/pi/scripts/picFamily.py
```

### 9. Run the Diagnostic Script

After running the remote updater once, this script should exist on the frame:

```bash
sudo bash /home/pi/scripts/diagnose_picfamily.sh
```

It prints the current settings JSON, checks the current image URL, lists installed scripts, shows the managed crontab, checks `/dev/fb0` and `fim`, and tails the relevant logs.

## Logs

- `/home/pi/setup_log.txt` records full installer activity.
- `/home/pi/update_crontab.log` records remote cron repair activity.
- `/home/pi/cron_output.log` records cron startup output.
- `/home/pi/cron.log` records `start_picfamily.sh` and `picFamily.py` runtime output.
- `/home/pi/picfamily_debug.log` records client debug messages from `picFamily.py`.
