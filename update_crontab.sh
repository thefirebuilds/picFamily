#!/bin/bash

set -u

LOGFILE="/home/pi/update_crontab.log"
SCRIPTS_DIR="/home/pi/scripts"
STARTUP_SCRIPT="$SCRIPTS_DIR/start_picfamily.sh"
CRON_TMP="$(mktemp)"
CRON_NEW="$(mktemp)"
MANAGED_BEGIN="# BEGIN picFamily managed cron"
MANAGED_END="# END picFamily managed cron"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

cleanup() {
    rm -f "$CRON_TMP" "$CRON_NEW"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Please run this script with sudo:"
        echo "  sudo bash update_crontab.sh"
        exit 1
    fi
}

create_startup_script() {
    log "Creating $STARTUP_SCRIPT..."
    mkdir -p "$SCRIPTS_DIR"

    cat > "$STARTUP_SCRIPT" <<'EOF'
#!/bin/bash

LOGFILE="/home/pi/cron.log"
INSTALL_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh"
UPDATE_CRONTAB_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh"
PICFAMILY_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py"
SETTINGS_URL="https://picfamily.blaketex.com/settings"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

download_latest() {
    url="$1"
    destination="$2"
    temp_file="$(mktemp)"

    if /usr/bin/wget -q -O "$temp_file" "$url"; then
        mv "$temp_file" "$destination"
        chmod +x "$destination"
        log "Updated $destination"
        return 0
    fi

    rm -f "$temp_file"
    log "Failed to update $destination from $url"
    return 1
}

log "Startup script began."

log "Waiting 30 seconds for boot networking to settle."
sleep 30

until /usr/bin/wget -q --spider "$SETTINGS_URL"; do
    log "Network or settings endpoint unavailable. Retrying in 10 seconds..."
    sleep 10
done

download_latest "$INSTALL_URL" "/home/pi/scripts/install.sh"
download_latest "$UPDATE_CRONTAB_URL" "/home/pi/scripts/update_crontab.sh"
download_latest "$PICFAMILY_URL" "/home/pi/scripts/picFamily.py"

if [ ! -f /home/pi/scripts/picFamily.py ]; then
    log "picFamily.py is missing; cannot start."
    exit 1
fi

log "Starting picFamily.py."
exec /usr/bin/python3 /home/pi/scripts/picFamily.py
EOF

    chmod +x "$STARTUP_SCRIPT"
}

update_root_crontab() {
    log "Updating root crontab..."

    crontab -l > "$CRON_TMP" 2>/dev/null || true

    awk -v begin="$MANAGED_BEGIN" -v end="$MANAGED_END" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        skip { next }
        /raw\.githubusercontent\.com\/thefirebuilds\/picFamily\/refs\/heads\/main\/install\.sh/ { next }
        /\/home\/pi\/scripts\/start_picfamily\.sh/ { next }
        /\/home\/pi\/scripts\/picFamily\.py/ { next }
        /^0 2 \* \* 0 \/sbin\/reboot$/ { next }
        { print }
    ' "$CRON_TMP" > "$CRON_NEW"

    {
        echo "$MANAGED_BEGIN"
        echo "@reboot /bin/bash -lc 'sleep 30; until /usr/bin/wget -q --spider https://picfamily.blaketex.com/settings; do sleep 10; done; /usr/bin/wget -O /home/pi/scripts/install.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh && /usr/bin/wget -O /home/pi/scripts/update_crontab.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh && /usr/bin/wget -O /home/pi/scripts/picFamily.py https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py && /bin/chmod +x /home/pi/scripts/install.sh /home/pi/scripts/update_crontab.sh /home/pi/scripts/picFamily.py && exec /usr/bin/python3 /home/pi/scripts/picFamily.py' >> /home/pi/cron_output.log 2>&1"
        echo "0 2 * * 0 /sbin/reboot"
        echo "$MANAGED_END"
    } >> "$CRON_NEW"

    crontab "$CRON_NEW"
}

main() {
    trap cleanup EXIT
    require_root

    touch "$LOGFILE" /home/pi/cron.log /home/pi/cron_output.log
    chmod 666 "$LOGFILE" /home/pi/cron.log /home/pi/cron_output.log

    create_startup_script
    update_root_crontab

    log "Cron update complete. Current root crontab:"
    crontab -l | tee -a "$LOGFILE"
}

main "$@"
