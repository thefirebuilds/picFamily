import os
import time
import json
import requests
import subprocess
import logging
from datetime import datetime

# Configuration
BASE_URL = "http://192.168.86.167:3000/images"
SETTINGS_URL = "http://192.168.86.167:3000/settings"
IMAGE_PATH = "/home/pi"
CHECK_INTERVAL = 300  # 5 minutes
IMAGE_REFRESH_INTERVAL = 3600  # 1 hour

# Logging setup
LOG_FILE = "/home/pi/image_display.log"
logging.basicConfig(filename=LOG_FILE, level=logging.INFO, format="%(asctime)s - %(message)s")

def log_message(message):
    """Log a message to the console and log file."""
    print(message)
    logging.info(message)

def get_current_pic_metadata():
    """Fetch the metadata for the current image."""
    try:
        log_message(f"Fetching metadata from: {SETTINGS_URL}")
        response = requests.get(SETTINGS_URL, timeout=10)
        log_message(f"Received HTTP status: {response.status_code}")
        response.raise_for_status()
        log_message(f"Raw response: {response.text}")

        data = response.json()
        log_message(f"Parsed metadata: {data}")

        current_pic = data.get("currentPic")
        set_date = data.get("setDate")

        if current_pic and set_date:
            try:
                set_date = int(set_date)
            except ValueError:
                log_message(f"Invalid setDate value: {set_date}")
                return None, None
            return current_pic, set_date
        else:
            log_message("Missing 'currentPic' or 'setDate' in response.")
            return None, None
    except requests.RequestException as e:
        log_message(f"Error fetching metadata: {e}")
        return None, None

def download_image(image_name, timestamp):
    """Download the image from the server."""
    url = f"{BASE_URL}/{image_name}?nocache={timestamp}"
    file_path = os.path.join(IMAGE_PATH, image_name)

    log_message(f"Downloading from {url}...")
    try:
        response = requests.get(url, stream=True, timeout=15)
        response.raise_for_status()
        with open(file_path, "wb") as file:
            for chunk in response.iter_content(1024):
                file.write(chunk)
        log_message(f"File {image_name} downloaded successfully to {file_path}.")
        return file_path
    except requests.RequestException as e:
        log_message(f"Failed to download {image_name}: {e}")
        return None

def display_image(image_path):
    """Display the image using fim in a subprocess."""
    log_message(f"Displaying image: {image_path}")
    try:
        subprocess.run(["fim", "-a", image_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        log_message(f"Failed to display image: {e}")

def main():
    """Main script loop to check and refresh the image."""
    log_message("Script started.")
    last_displayed_time = 0
    last_checked_log_time = 0

    # Fetch and display the image immediately on startup
    current_pic, set_date = get_current_pic_metadata()
    if current_pic and set_date:
        log_message(f"Displaying initial image with setDate: {set_date}.")
        image_path = download_image(current_pic, set_date) or os.path.join(IMAGE_PATH, current_pic)
        display_image(image_path)
        last_displayed_time = int(time.time())  # Mark this time as the last displayed time
    else:
        log_message("Initial metadata fetch failed. Waiting for next check.")

    while True:
        current_time = int(time.time())

        # Debug logging every 5 minutes
        if current_time - last_checked_log_time >= CHECK_INTERVAL:
            log_message("Checking if it's time to refresh the image...")
            last_checked_log_time = current_time

        current_pic, set_date = get_current_pic_metadata()
        if current_pic and set_date:
            if current_time - last_displayed_time >= IMAGE_REFRESH_INTERVAL:
                log_message(f"New image detected with setDate: {set_date}. Refreshing display...")

                image_path = download_image(current_pic, set_date) or os.path.join(IMAGE_PATH, current_pic)
                display_image(image_path)
                last_displayed_time = current_time  # Update last displayed time
            else:
                log_message(f"Not yet time to refresh. Next refresh in {IMAGE_REFRESH_INTERVAL - (current_time - last_displayed_time)} seconds.")
        else:
            log_message("Invalid or missing metadata. Retrying...")

        time.sleep(CHECK_INTERVAL)

if __name__ == "__main__":
    main()
