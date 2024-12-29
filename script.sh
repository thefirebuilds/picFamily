#!/bin/bash
LOG_FILE="/home/pi/picfamily_debug.log"

log_message() {
    echo "$(date) - $1" >> "$LOG_FILE"
}

retry_command() {
    local max_retries=$1
    shift
    local cmd="$@"
    local attempt=1
    until $cmd; do
        log_message "Attempt $attempt failed. Retrying..."
        attempt=$((attempt + 1))
        if [[ $attempt -gt $max_retries ]]; then
            log_message "Command failed after $max_retries attempts: $cmd"
            return 1
        fi
        sleep 2
    done
    return 0
}

echo "Preparing PicFamily"
log_message "Script started."

# Wait for a valid IP address (not 127.0.0.1)
log_message "Waiting for a valid IP address..."
until [[ "$(hostname -I)" != "127.0.0.1" ]]; do
    sleep 1
done
log_message "Valid IP address assigned: $(hostname -I)"

# Wait until internet is available by pinging an external server
retry_command 5 ping -c 1 8.8.8.8 &>/dev/null || {
    log_message "Internet connection not available. Exiting."
    exit 1
}
log_message "Internet is available!"

# Sync time with an NTP server
log_message "Syncing time with an NTP server..."
retry_command 5 sudo ntpdate -s time.google.com || log_message "Failed to sync time."

# Wait for framebuffer device
until [ -e /dev/fb0 ]; do
    log_message "Waiting for framebuffer device..."
    sleep 1
done
log_message "/dev/fb0 ready"
sleep 5

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm

# Check if the external IP is reachable
if retry_command 5 ping -c 1 184.92.108.105 &>/dev/null; then
    URI="http://184.92.108.105:3000"
    log_message "Using external server at $URI."
else
    URI="http://192.168.86.167:3000"
    log_message "Using internal server at $URI."
fi

# Fetch data from server
log_message "Fetching settings from $URI/settings..."
retry_command 5 curl -s "$URI/settings" -o /tmp/settings.json || {
    log_message "Failed to fetch settings from server. Exiting."
    exit 1
}

currentPic=$(cat /tmp/settings.json | json currentPic)
if [[ -z "$currentPic" ]]; then
    log_message "Error: Failed to parse 'currentPic' from server response."
    exit 1
fi
log_message "Received 'currentPic': $currentPic"

fullPath="$URI/images/$currentPic"
localImagePath="/home/pi/$currentPic"

# Check if the image already exists locally
if [[ -f "$localImagePath" ]]; then
    log_message "Image already exists locally: $localImagePath. Skipping download."
else
    log_message "Image not found locally. Downloading image..."
    retry_command 5 wget -q -O "$localImagePath" "$fullPath" || {
        log_message "Failed to download image. Exiting."
        exit 1
    }
    log_message "Image downloaded successfully: $localImagePath"
fi

# Display the image
log_message "Displaying image: $localImagePath"
pkill fim
clear > /dev/fb0

# Hide the cursor
echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink &>/dev/null

if sudo fim -A -q -T 1 -d /dev/fb0 "$localImagePath" > fim_log.txt 2>&1; then
    log_message "Image displayed successfully."
else
    log_message "Error: Failed to display image with FIM."
    exit 1
fi

# Restore the cursor
echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink &>/dev/null

log_message "Script completed successfully."
