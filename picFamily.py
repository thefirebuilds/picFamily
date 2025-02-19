import os
import time
import json
import subprocess
import logging
from urllib.request import urlopen, urlretrieve
from datetime import datetime

# Setup logging
LOG_FILE = "/home/pi/picfamily_debug.log"
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format="%(asctime)s - %(message)s")

def log_message(message):
    print(message)  # Also print to stdout for debugging
    logging.info(message)

# Wait for a valid IP address
def get_valid_ip():
    while True:
        ip = subprocess.getoutput("hostname -I | awk '{print $1}'").strip()
        if ip and ip != "127.0.0.1":
            log_message(f"Valid IP address assigned: {ip}")
            return ip
        log_message("No valid IP address assigned yet. Retrying...")
        time.sleep(15)

# Check internet connectivity
def wait_for_internet(timeout=300):
    start_time = time.time()
    while time.time() - start_time < timeout:
        if os.system("ping -c 1 8.8.8.8 > /dev/null 2>&1") == 0:
            log_message("Internet is available!")
            return True
        log_message("Internet not available. Retrying...")
        time.sleep(5)
    log_message("Failed to establish internet connectivity after 5 minutes.")
    return False

# Sync system time
def sync_time():
    for _ in range(5):
        if os.system("sudo timedatectl set-ntp true") == 0:
            log_message("Time synced successfully.")
            return
        log_message("Failed to enable NTP synchronization. Retrying...")
        time.sleep(2)
    log_message("Failed to sync time after multiple attempts.")

# Wait for framebuffer device
def wait_for_framebuffer():
    while not os.path.exists("/dev/fb0"):
        log_message("Waiting for framebuffer device...")
        time.sleep(1)
    log_message("/dev/fb0 ready")
    time.sleep(5)

# Determine server URI
def get_server_uri():
    internal_url = "http://192.168.86.167:3000/settings"
    external_url = "http://184.92.108.105:3000/settings"

    for url in [internal_url, external_url]:
        try:
            response = urlopen(url)
            if response.getcode() == 200:
                log_message(f"Using server at {url}")
                return url.replace("/settings", "")
        except:
            log_message(f"Failed to connect to {url}")
    
    log_message("Failed to connect to both internal and external servers. Exiting.")
    exit(1)

# Fetch settings from server
def fetch_settings(uri):
    settings_url = f"{uri}/settings"
    try:
        urlretrieve(settings_url, "/tmp/settings.json")
        with open("/tmp/settings.json") as f:
            data = json.load(f)
            return data.get("currentPic")
    except:
        log_message("Failed to fetch settings from server.")
        return None

# Display the image
def display_image(image_path):
    log_message(f"Attempting to display image: {image_path}")
    os.system("clear > /dev/fb0")
    time.sleep(1)
    
    for attempt in range(1, 6):
        log_message(f"Displaying image attempt {attempt}/5")
        os.system("sudo killall fim > /dev/null 2>&1")
        time.sleep(1)

        result = os.system(f"sudo fim -A -q -T 1 -d /dev/fb0 {image_path}")
        if result == 0:
            log_message("Image displayed successfully.")
            return
        log_message("Error displaying image. Retrying...")
        time.sleep(2)

    log_message("Failed to display image after multiple attempts.")

# Calculate time until the next full hour
def time_until_next_hour():
    now = datetime.now()
    next_hour = now.replace(minute=0, second=0, microsecond=0)  # Start of current hour
    next_hour = next_hour.timestamp() + 3600  # Add one hour
    sleep_time = int(next_hour - time.time())

    next_update_time = datetime.fromtimestamp(next_hour).strftime("%Y-%m-%d %H:%M:%S")
    log_message("Next image check scheduled for: {} ({} min {} sec from now)".format(next_update_time, sleep_time // 60, sleep_time % 60))

    return sleep_time

# Main execution flow
if __name__ == "__main__":
    log_message("Starting picFamily.py...")

    get_valid_ip()
    wait_for_internet()
    sync_time()
    wait_for_framebuffer()

    URI = get_server_uri()

    while True:
        current_pic = fetch_settings(URI)

        if not current_pic:
            log_message("Error: Failed to parse 'currentPic' from settings.")
        else:
            log_message(f"Received 'currentPic': {current_pic}")
            
            image_url = f"{URI}/images/{current_pic}"
            local_image_path = f"/home/pi/{current_pic}"

            if not os.path.exists(local_image_path):
                log_message("Downloading new image...")
                urlretrieve(image_url, local_image_path)
                log_message("Image downloaded successfully.")

            os.system("echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink > /dev/null")
            display_image(local_image_path)

        # Sleep until the next full hour
        sleep_time = time_until_next_hour()
        log_message(f"Sleeping for {sleep_time // 60} minutes until the next full hour.")
        time.sleep(sleep_time)
