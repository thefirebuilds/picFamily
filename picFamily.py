import os
import time
import json
import requests
import subprocess
from datetime import datetime

# Configuration
BASE_URL = "http://192.168.86.167:3000"
METADATA_URL = f"{BASE_URL}/settings"
IMAGE_PATH = "/home/pi"
CHECK_INTERVAL = 300  # 5 minutes
LOG_FILE = "/home/pi/image_display.log"

# Logging function
def log_message(message):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LOG_FILE, "a") as log:
        log.write(f"{timestamp} - {message}\n")
    print(f"{timestamp} - {message}")

# Function to fetch metadata
def fetch_metadata():
    try:
        response = requests.get(METADATA_URL, timeout=5)
        if response.status_code == 200:
            return response.json()
        else:
            log_message(f"Failed to fetch metadata. HTTP Status: {response.status_code}")
            return None
    except requests.RequestException as e:
        log_message(f"Error fetching metadata: {e}")
        return None

# Function to download image
def download_image(filename, set_date):
    url = f"{BASE_URL}/images/{filename}?nocache={set_date}"
    save_path = os.path.join(IMAGE_PATH, filename)
    
    try:
        log_message(f"Downloading from {url}...")
        response = requests.get(url, stream=True, timeout=10)
        if response.status_code == 200:
            with open(save_path, "wb") as file:
                for chunk in response.iter_content(1024):
                    file.write(chunk)
            log_message(f"File {filename} downloaded successfully.")
            return save_path
        else:
            log_message(f"Failed to download image. HTTP Status: {response.status_code}")
            return None
    except requests.RequestException as e:
        log_message(f"Error downloading image: {e}")
        return None

# Function to display image
def display_image(image_path):
    log_message("Ensuring cursor is hidden before displaying image...")
    subprocess.run("echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink", shell=True)
    log_message("Cursor blinking disabled.")

    log_message(f"Displaying image: {image_path}")
    subprocess.run(["fim", "-a", image_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# Hide cursor on startup
log_message("Script started.")
log_message("Attempting to hide cursor...")
subprocess.run("echo 0 | sudo tee /sys/class/graphics/fbcon/cursor_blink", shell=True)
log_message("Cursor hidden successfully.")

# Main loop
last_checked_log_time = time.time()
last_displayed_time = 0

while True:
    current_time = time.time()
    
    # Debug logging every 5 minutes
    if current_time - last_checked_log_time >= CHECK_INTERVAL:
        log_message("Checking if it's time to refresh the image...")
        last_checked_log_time = current_time

    # Fetch metadata
    metadata = fetch_metadata()
    if metadata and "currentPic" in metadata and "setDate" in metadata:
        current_pic = metadata["currentPic"]
        set_date = int(metadata["setDate"])
        
        # Calculate next refresh time (1 min after the hour)
        next_refresh_time = (current_time // 3600) * 3600 + 60  

        if current_time >= next_refresh_time:
            log_message(f"Time to refresh the image! Current time: {datetime.now().strftime('%H:%M:%S')}")
            image_path = download_image(current_pic, set_date) or os.path.join(IMAGE_PATH, current_pic)
            display_image(image_path)
            last_displayed_time = current_time  # Update last display time
        else:
            remaining = next_refresh_time - current_time
            log_message(f"Not yet time to refresh. Next refresh in {remaining} seconds.")
    else:
        log_message("Invalid or missing metadata. Retrying...")

    time.sleep(10)  # Small delay to prevent excessive polling
