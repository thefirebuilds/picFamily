# picFamily Client

picFamily is a Raspberry Pi digital picture frame client. On boot, the device downloads the current client script from GitHub, asks the picFamily service which image should be displayed, downloads that image if needed, and renders it directly to the framebuffer with `fim`.

## Files

- `picFamily.py` is the runtime client that fetches settings, downloads the selected image, and displays it.
- `install.sh` performs first-time device setup, installs packages, writes the startup script, updates the root crontab, and reboots.
- `update_crontab.sh` is a remote-friendly repair script for updating the managed crontab and startup script without rerunning the full installer.
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
@reboot /home/pi/scripts/start_picfamily.sh >> /home/pi/cron_output.log 2>&1
0 2 * * 0 /sbin/reboot
```

`start_picfamily.sh` does the boot work in order:

1. Waits 30 seconds for boot networking to settle.
2. Waits until `https://picfamily.blaketex.com/settings` is reachable.
3. Downloads the current `install.sh` to `/home/pi/scripts/install.sh`.
4. Downloads the current `picFamily.py` to `/home/pi/scripts/picFamily.py`.
5. Starts the client with `/usr/bin/python3 /home/pi/scripts/picFamily.py`.

This keeps devices current when `picFamily.py` changes on GitHub and avoids racing separate `@reboot` cron entries.

## Updating Cron Remotely

After `update_crontab.sh` is pushed to GitHub, a helper can run this on a device:

```bash
wget -O /tmp/update_crontab.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh && sudo bash /tmp/update_crontab.sh
```

The script preserves unrelated root crontab entries, removes older picFamily boot entries, writes the managed picFamily cron block, and logs to `/home/pi/update_crontab.log`.

## Logs

- `/home/pi/setup_log.txt` records full installer activity.
- `/home/pi/update_crontab.log` records remote cron repair activity.
- `/home/pi/cron_output.log` records cron startup output.
- `/home/pi/cron.log` records `start_picfamily.sh` and `picFamily.py` runtime output.
- `/home/pi/picfamily_debug.log` records client debug messages from `picFamily.py`.
