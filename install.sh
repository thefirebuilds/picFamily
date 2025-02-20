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

def configure_screen_rotation() {
    config_file = "/boot/firmware/config.txt"
    if os.path.isfile(config_file):
        log("Setting up screen rotation in config.txt...")
        subprocess.run(["sudo", "sed", "-i", "s/^display_rotate=.*/display_rotate=1/", config_file], check=True)
        with open(config_file, "a") as f:
            f.write("display_rotate=1\n")
        subprocess.run(["sudo", "sed", "-i", "s/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/", config_file], check=True)
        log("Screen rotation setup complete. Please reboot for changes to take effect.")
    else:
        log("Configuration file not found. Please check your setup.")
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
    configure_screen_rotation()
    log "Setup complete!"
}

main
