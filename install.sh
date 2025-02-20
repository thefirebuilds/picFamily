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
    sudo apt install -y python3 fim >> "$LOGFILE" 2>&1
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

update_crontab() {
    log "Updating crontab..."
    
    crontab -l 2>/dev/null > /tmp/mycron.log
    
    # Clear the current crontab
    crontab -r

    # Ensure the log file exists and has correct permissions
    touch /home/pi/cron_output.log
    chmod 666 /home/pi/cron_output.log

    # Add new crontab entries
    echo "@reboot /bin/bash -c 'until ping -c 1 google.com; do sleep 1; done; echo \"Ping successful\" >> /home/pi/cron_output.log 2>&1; wget -O /home/pi/scripts/picFamily.py https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/picFamily.py >> /home/pi/cron_output.log 2>&1'" | crontab -
    echo "@reboot sudo python3 /home/pi/scripts/picFamily.py >> /home/pi/cron_output.log 2>&1" | crontab -

    # Verify cron job setup by appending current time to the log
    echo "@reboot echo \"Cron job started at $(date)\" >> /home/pi/cron_output.log" | crontab -
    
    crontab /tmp/mycron.log 2>/tmp/crontab_error.log
    if [ $? -eq 0 ]; then
        log "Crontab updated successfully."
    else
        log "Error updating crontab. Check /tmp/crontab_error.log for details."
    fi
    
    rm /tmp/mycron.log
}

main() {
    log "Setup started..."
    update_system
    install_packages
    setup_scripts_directory
    download_script
    update_crontab
    configure_screen_rotation
    log "Setup complete! Rebooting now..."
    sudo reboot
}

main
