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

# Wait for a valid IP address (not 127.0.0.1)
log_message "Waiting for a valid IP address..."
while true; do
    assigned_ip=$(hostname -I | awk '{print $1}')
    if [[ "$assigned_ip" != "127.0.0.1" && -n "$assigned_ip" ]]; then
        log_message "Valid IP address assigned: $assigned_ip"
        break
    fi
    log_message "No valid IP address assigned yet. Retrying..."
    sleep 5
done

# Wait until internet is available by pinging an external server
retry_command 5 ping -c 1 8.8.8.8 &>/dev/null || {
    log_message "Internet connection not available. Exiting."
    exit 1
}
log_message "Internet is available!"

# Sync time with an NTP server
log_message "Syncing time with systemd-timesyncd..."
retry_command 5 sudo timedatectl set-ntp true || log_message "Failed to enable NTP synchronization."

# Wait for framebuffer device
until [ -e /dev/fb0 ]; do
    log_message "Waiting for framebuffer device..."
    sleep 1
done
log_message "/dev/fb0 ready"
sleep 5

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export TERM=xterm

# Determine the server URI
log_message "Checking connectivity to internal server..."
if retry_command 5 curl -s -o /dev/null -w "%{http_code}" http://192.168.86.167:3000/settings | grep -q "200"; then
    URI="http://192.168.86.167:3000"
    log_message "Using internal server at $URI."
else
    log_message "Internal server not reachable. Checking external server..."
    if retry_command 5 curl -s -o /dev/null -w "%{http_code}" http://184.92.108.105:3000/settings | grep -q "200"; then
        URI="http://184.92.108.105:3000"
        log_message "Using external server at $URI."
    else
        log_message "Failed to connect to both internal and external servers. Exiting."
        exit 1
    fi
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

# Hide the cursor
echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink &>/dev/null

# Attempt to display the image
max_attempts=5
attempt=1

while (( attempt <= max_attempts )); do
    log_message "Attempting to display image: $localImagePath (Attempt $attempt/$max_attempts)"
    pkill fim 2>/dev/null
    clear > /dev/fb0
    sleep 1
    if sudo fim -A -q -T 1 -d /dev/fb0 "$localImagePath" > fim_log.txt 2>&1; then
        log_message "Image $localImagePath displayed successfully."
        exit 0
    else
        log_message "Error: Failed to display image with FIM on attempt $attempt."
        ((attempt++))
        sleep 2
    fi
done

# If all attempts fail, re-execute the script after 5 minutes
log_message "Error: Failed to display image after $max_attempts attempts. Restarting script in 5 minutes..."
sleep 300
exec "$0"
