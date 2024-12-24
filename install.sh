#!/bin/bash

# Step 1: Update and upgrade OS
sudo apt update && sudo apt upgrade -y

# Step 3: Install FIM (after reboot)
echo "Installing FIM..."
sudo apt-get install fim -y

# Step 4: Install Node.js and npm
echo "Installing Node.js and npm..."
sudo apt-get install npm -y

# Step 5: Add JSON tool
echo "Installing JSON tool..."
sudo npm install -g json

# Step 6: Configure firmware for screen rotation
CONFIG_FILE="/boot/firmware/config.txt"

if [ -f "$CONFIG_FILE" ]; then
    echo "Setting up screen rotation in $CONFIG_FILE..."
    
    # Add or update the display_rotate=1 line
    if grep -q "^display_rotate=" "$CONFIG_FILE"; then
        sudo sed -i 's/^display_rotate=.*/display_rotate=1/' "$CONFIG_FILE"
    else
        echo "display_rotate=1" | sudo tee -a "$CONFIG_FILE"
    fi

    # Comment out the dtoverlay=vc4-kms-v3d line
    sudo sed -i 's/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/' "$CONFIG_FILE"

    echo "Screen rotation setup complete. Please reboot for changes to take effect."
else
    echo "Configuration file $CONFIG_FILE not found. Please check your setup."
fi

# Step 7: Download and place script in /home/pi/scripts
echo "Downloading script.sh to /home/pi/scripts..."
mkdir -p /home/pi/scripts
wget -O /home/pi/scripts/script.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/script.sh
chmod +x /home/pi/scripts/script.sh

# Step 8: Add crontab entries
echo "Adding crontab entries..."
(crontab -l 2>/dev/null; echo "@reboot /usr/bin/bash /home/pi/scripts/script.sh >> /home/pi/scripts/cron_output.log 2>&1") | crontab - 
(crontab -l 2>/dev/null; echo "5 * * * * /home/pi/scripts/script.sh") | crontab - 

# Step 9: Disable unwanted services

# Disable Bluetooth
echo "Disabling Bluetooth..."
sudo systemctl disable bluetooth.service
sudo systemctl stop bluetooth.service

# Disable Camera
echo "Disabling Camera..."
sudo raspi-config nonint do_camera 0

# Disable GUI (LightDM or other display manager)
echo "Disabling GUI..."
sudo systemctl set-default multi-user.target
sudo systemctl disable lightdm.service
sudo systemctl stop lightdm.service

# Disable alsa-restore.service
echo "Disabling alsa-restore.service..."
sudo systemctl disable alsa-restore.service
sudo systemctl stop alsa-restore.service

# Disable modemmanager.service
echo "Disabling modemmanager.service..."
sudo systemctl disable modemmanager.service
sudo systemctl stop modemmanager.service

# Disable rpc-statd-notify.service
echo "Disabling rpc-statd-notify.service..."
sudo systemctl disable rpc-statd-notify.service
sudo systemctl stop rpc-statd-notify.service

# Step 10: Reboot the system
echo "Rebooting the system..."
sudo reboot now
