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

LOGFILE="/home/pi/cron_output.log"
INSTALL_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh"
UPDATE_CRONTAB_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh"
PICFAMILY_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py"
DIAGNOSE_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/diagnose_picfamily.sh"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

download_latest() {
    url="$1"
    destination="$2"
    attempts=0

    while [ "$attempts" -lt 18 ]; do
        attempts=$((attempts + 1))
        temp_file="$(mktemp)"

        log "Downloading $destination from $url (attempt $attempts)..."
        if /usr/bin/wget -O "$temp_file" "$url"; then
            install -m 755 "$temp_file" "$destination"
            rm -f "$temp_file"
            log "Updated $destination"
            return 0
        fi

        rm -f "$temp_file"
        log "Failed to update $destination. Retrying in 10 seconds..."
        sleep 10
    done

    log "Giving up on $destination after $attempts attempts."
    return 1
}

log "picFamily boot update started."

log "Waiting 30 seconds for boot networking to settle."
sleep 30

download_latest "$INSTALL_URL" "/home/pi/scripts/install.sh" || true
download_latest "$UPDATE_CRONTAB_URL" "/home/pi/scripts/update_crontab.sh" || true
download_latest "$PICFAMILY_URL" "/home/pi/scripts/picFamily.py" || true
download_latest "$DIAGNOSE_URL" "/home/pi/scripts/diagnose_picfamily.sh" || true

ls -l /home/pi/scripts/install.sh /home/pi/scripts/update_crontab.sh /home/pi/scripts/picFamily.py /home/pi/scripts/diagnose_picfamily.sh 2>/dev/null | while read -r line; do
    log "$line"
done

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
        echo "@reboot $STARTUP_SCRIPT >> /home/pi/cron_output.log 2>&1"
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
