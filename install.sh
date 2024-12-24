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

# Step 7: Download and place script and cleanup script in /home/pi/scripts
echo "Downloading script.sh and cleanup.sh to /home/pi/scripts..."
mkdir -p /home/pi/scripts
wget -O /home/pi/scripts/script.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/script.sh
wget -O /home/pi/scripts/cleanup.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/cleanup.sh
chmod +x /home/pi/scripts/script.sh /home/pi/scripts/cleanup.sh

# Step 8: Add crontab entries
echo "Adding crontab entries..."
(crontab -l 2>/dev/null; echo "@reboot /usr/bin/bash /home/pi/scripts/script.sh >> /home/pi/scripts/cron_output.log 2>&1") | crontab - 
(crontab -l 2>/dev/null; echo "0 3 * * 0 /home/pi/scripts/cleanup.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 4 * * 0 sudo reboot") | crontab -

# Step 9: Download script.sh on first boot
echo "Creating script to download script.sh on first boot..."
echo -e "#!/bin/bash\nwget -O /home/pi/scripts/script.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/script.sh" | sudo tee /etc/init.d/download_script.sh > /dev/null
sudo chmod +x /etc/init.d/download_script.sh
sudo update-rc.d download_script.sh defaults

# Step 10: Reboot the system
echo "Rebooting the system..."
sudo reboot now
