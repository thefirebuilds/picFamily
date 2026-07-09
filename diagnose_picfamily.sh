#!/bin/bash

set -u

BASE_URL="https://picfamily.blaketex.com"
CURRENT_FILE=""

section() {
    echo
    echo "==== $1 ===="
}

section "System"
date
hostname
hostname -I 2>/dev/null || true

section "Installed Files"
ls -l /home/pi/scripts/install.sh /home/pi/scripts/update_crontab.sh /home/pi/scripts/picFamily.py /home/pi/scripts/start_picfamily.sh 2>/dev/null || true

section "Crontab"
sudo crontab -l 2>/dev/null || true

section "Network"
getent hosts picfamily.blaketex.com || true
getent hosts raw.githubusercontent.com || true
wget --spider "$BASE_URL/settings" || true

section "Settings"
SETTINGS_JSON="$(wget -q -O - "$BASE_URL/settings" || true)"
echo "$SETTINGS_JSON"

if command -v python3 >/dev/null 2>&1; then
    CURRENT_FILE="$(printf '%s' "$SETTINGS_JSON" | python3 -c 'import json,sys; data=json.load(sys.stdin); print(data.get("currentPic", ""))' 2>/dev/null || true)"
fi

if [ -n "$CURRENT_FILE" ]; then
    section "Current Image"
    echo "currentPic=$CURRENT_FILE"
    wget --spider "$BASE_URL/images/$CURRENT_FILE" || true
    ls -l "/home/pi/$CURRENT_FILE" 2>/dev/null || true
else
    echo "Could not determine currentPic from settings."
fi

section "Python Requests"
python3 -c "import requests; print(requests.get('$BASE_URL/settings', timeout=10).text)" || true

section "Framebuffer And FIM"
ls -l /dev/fb0 2>/dev/null || true
command -v fim || true
pgrep -a fim || true

section "Recent Logs: cron_output"
tail -n 120 /home/pi/cron_output.log 2>/dev/null || true

section "Recent Logs: cron"
tail -n 120 /home/pi/cron.log 2>/dev/null || true

section "Recent Logs: picfamily_debug"
tail -n 160 /home/pi/picfamily_debug.log 2>/dev/null || true
