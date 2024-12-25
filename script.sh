#!/bin/bash
echo  "Preparing PicFamily"

# Sync time with an NTP server
echo "Syncing time with an NTP server..."
sudo ntpdate -s time.google.com

# Wait for a valid IP address (not 127.0.0.1)
until [[ "$(hostname -I)" != "127.0.0.1" ]]; do
    sleep 1
done

# Wait until internet is available by pinging an external server (e.g., Google's DNS)
until ping -c 1 8.8.8.8 &>/dev/null; do
    sleep 1
done

echo "IP assigned and internet is available!"

until [ -e /dev/fb0 ]; do
    echo "Waiting for framebuffer device..." >> /home/pi/fbi_debug.log
    sleep 1
done
echo "/dev/fb0 ready" >> /home/pi/fbi_debug.log
sleep 5

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm

URI="http://192.168.86.167:3000"

echo "Fetching data from $URI"

currentPic=$(curl -s "$URI/settings" | json currentPic)
echo "$currentPic"

fullPath="$URI/images/$currentPic"

echo "$fullPath"

wget -q -O "/home/pi/$currentPic" "$fullPath"
sleep 5

echo "Loading:  /home/pi/$currentPic"

# Clear FIM buffers
pkill fim
clear > /dev/fb0

# Hide the cursor
echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink

# Display the image
sudo fim -A -q -T 1 -d /dev/fb0 "/home/pi/$currentPic" > fim_log.txt 2>&1

# Restore the cursor
echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink
