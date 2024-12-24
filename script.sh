#!/bin/bash
echo  "Preparing PicFamily"
sleep 90

until [ -e /dev/fb0 ]; do
    echo "Waiting for framebuffer device..." >> /home/pi/fbi_debug.log
    sleep 1
done
echo "/dev/fb0 ready" >> /home/pi/fbi_debug.log

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm

URI="http://192.168.86.167:3000"

echo "fetching data from $URI"

currentPic=$(curl -s "$URI/settings" | json currentPic)
echo "$currentPic"

fullPath="$URI/images/$currentPic"

echo "$fullPath"

wget -q -O "/home/pi/$currentPic" "$fullPath"
sleep 5

echo "loading:  /home/pi/$currentPic"

#clear fim buffers
pkill fim
clear > /dev/fb0

# Hide the cursor
echo -e '\033[?25l' > /dev/tty0

# Display the image
sudo fim -A -q -T 1 -d /dev/fb0 "/home/pi/$currentPic" > fim_log.txt 2>&1

# Restore the cursor
echo -e '\033[?25h' > /dev/tty0
