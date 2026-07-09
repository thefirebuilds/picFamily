#!/bin/bash

LOGFILE="/home/pi/setup_log.txt"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

update_system() {
    log "Updating and upgrading the system..."
    sudo apt update && sudo apt upgrade -y >> "$LOGFILE" 2>&1
    if [ $? -eq 0 ]; then
        log "System updated and upgraded successfully."
    else
        log "Error occurred while updating/upgrading the system. Check the log above."
    fi
}

install_packages() {
    log "Installing required packages..."
    sudo apt install -y python3 python3-requests ca-certificates fim wget >> "$LOGFILE" 2>&1
    if [ $? -eq 0 ]; then
        log "Packages installed successfully."
    else
        log "Error occurred while installing packages. Check the log above."
    fi
}

configure_screen_rotation() {
    config_file="/boot/firmware/config.txt"
    
    if [ -f "$config_file" ]; then
        log "Setting up screen rotation in $config_file..."
        
        sudo sed -i 's/^display_rotate=.*/display_rotate=1/' "$config_file" >> "$LOGFILE" 2>&1
        if ! grep -q "^display_rotate=" "$config_file"; then
            echo "display_rotate=1" | sudo tee -a "$config_file" >> "$LOGFILE" 2>&1
        fi
        
        sudo sed -i 's/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/' "$config_file" >> "$LOGFILE" 2>&1
        if [ $? -eq 0 ]; then
            log "Screen rotation setup complete."
        else
            log "Error occurred while setting up screen rotation. Check the log above."
        fi
    else
        log "Configuration file not found. Please check your setup."
    fi
}

setup_scripts_directory() {
    log "Ensuring scripts directory exists..."
    mkdir -p /home/pi/scripts
    if [ $? -eq 0 ]; then
        log "Scripts directory created successfully."
    else
        log "Error creating scripts directory."
    fi
}

download_script() {
    log "Downloading picFamily.py..."
    wget -O /home/pi/scripts/picFamily.py https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py >> "$LOGFILE" 2>&1
    chmod +x /home/pi/scripts/picFamily.py
    if [ $? -eq 0 ]; then
        log "picFamily.py downloaded and made executable."
    else
        log "Error downloading or making picFamily.py executable."
    fi
}

create_startup_script() {
    log "Creating startup script..."

    cat > /home/pi/scripts/start_picfamily.sh <<'EOF'
#!/bin/bash

LOGFILE="/home/pi/cron_output.log"
INSTALL_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/install.sh"
UPDATE_CRONTAB_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/update_crontab.sh"
PICFAMILY_URL="https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py"

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

ls -l /home/pi/scripts/install.sh /home/pi/scripts/update_crontab.sh /home/pi/scripts/picFamily.py 2>/dev/null | while read -r line; do
    log "$line"
done

if [ ! -f /home/pi/scripts/picFamily.py ]; then
    log "picFamily.py is missing; cannot start."
    exit 1
fi

log "Starting picFamily.py."
exec /usr/bin/python3 /home/pi/scripts/picFamily.py
EOF

    chmod +x /home/pi/scripts/start_picfamily.sh
    if [ $? -eq 0 ]; then
        log "Startup script created successfully."
    else
        log "Error creating startup script."
    fi
}

update_crontab() {
    log "Updating sudo crontab..."

    # Backup and clear current sudo crontab
    sudo crontab -l 2>/dev/null > /tmp/mycron.log
    sudo crontab -r

    # Ensure the log file exists and has correct permissions
    sudo touch /home/pi/cron_output.log
    sudo chmod 666 /home/pi/cron_output.log

    # Create a new sudo crontab file
    cat > /tmp/new_cron <<'EOF'
# BEGIN picFamily managed cron
@reboot /home/pi/scripts/start_picfamily.sh >> /home/pi/cron_output.log 2>&1
0 2 * * 0 /sbin/reboot
# END picFamily managed cron
EOF

    # Load the new crontab file into sudo crontab
    sudo crontab /tmp/new_cron

    # Verify sudo crontab setup
    sudo crontab -l > /tmp/verify_crontab.log
    if [ $? -eq 0 ]; then
        log "Sudo crontab updated successfully."
    else
        log "Error updating sudo crontab. Check /tmp/verify_crontab.log for details."
    fi
    
    rm /tmp/mycron.log /tmp/new_cron
}

main() {
    log "Setup started..."
    update_system
    install_packages
    setup_scripts_directory
    download_script
    create_startup_script
    update_crontab
    configure_screen_rotation
    log "Setup complete! Rebooting now..."
    sudo reboot
}

main
