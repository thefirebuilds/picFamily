#!/bin/bash
#cleanup log files and images.

# Remove specific files
rm -f /home/pi/fbi_debug.log
rm -f /home/pi/fim_log.txt
rm -f /home/pi/install.sh
rm -f /home/pi/picfamily_debug.log

# Remove image files with specified extensions
find /home/pi -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.gif" \) -exec rm -f {} \;

# Remove the cron_output.log file
rm -f /home/pi/cron_output.log

# Download and replace this script with the latest version from the repository
wget -q -O /home/pi/scripts/cleanup.sh https://raw.githubusercontent.com/thefirebuilds/picFamily/refs/heads/main/cleanup.sh
sudo chmod +x /home/pi/scripts/cleanup.sh
