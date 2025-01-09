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
