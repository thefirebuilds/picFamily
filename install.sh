#!/bin/bash

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

update_system() {
    log "Updating and upgrading the system..."
    sudo apt update && sudo apt upgrade -y
}

install_packages() {
    log "Installing required packages..."
    sudo apt install -y python3 fim
}

setup_scripts_directory() {
    log "Ensuring scripts directory exists..."
    mkdir -p /home/pi/scripts
}

download_script() {
    log "Downloading picFamily.py..."
    wget -O /home/pi/scripts/picFamily.py https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py
    chmod +x /home/pi/scripts/picFamily.py
}

update_crontab() {
    log "Updating crontab..."
    (crontab -l 2>/dev/null; echo "@reboot wget -O /home/pi/scripts/picFamily.py https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py") | crontab -
    (crontab -l 2>/dev/null; echo "@reboot python3 /home/pi/scripts/picFamily.py") | crontab -
    (crontab -l 2>/dev/null; echo "0 2 * * 0 /sbin/reboot") | crontab -
}

main() {
    update_system
    install_packages
    setup_scripts_directory
    download_script
    update_crontab
    log "Setup complete!"
}

main
