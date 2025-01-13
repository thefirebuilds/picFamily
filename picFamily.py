import os
import time
import json
import subprocess
import requests
from pathlib import Path
import logging
from datetime import datetime
from PIL import Image

# Configure logging
LOG_FILE = "/home/pi/picfamily_debug.log"
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s - %(message)s"
)

def log_message(message):
    logging.info(message)
    print(message)

def fetch_settings(uri):
    log_message(f"Fetching settings from {uri}/settings...")
    try:
        response = requests.get(f"{uri}/settings", timeout=10)
        response.raise_for_status()
        settings = response.json()
        log_message("Successfully fetched settings.")
        return settings
    except requests.RequestException as e:
        log_message(f"Failed to fetch settings: {e}")
        return None

def hide_cursor():
    log_message("Hiding cursor...")
    try:
        subprocess.run(["sudo", "sh", "-c", "echo 0 > /sys/class/graphics/fbcon/cursor_blink"], check=True)
        log_message("Cursor successfully hidden.")
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to hide cursor: {e}")

def display_image(local_image_path):
    log_message(f"Displaying image: {local_image_path}")
    try:
        subprocess.run(["fim", "-a", "-q", local_image_path], check=True)
        log_message("Image displayed successfully.")
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to display image: {e}")

def download_image(uri, image_name):
    full_path = f"{uri}/images/{image_name}"
    local_image_path = Path(f"/home/pi/{image_name}")
    if local_image_path.exists():
        log_message(f"Image already exists locally: {local_image_path}. Skipping download.")
    else:
        log_message("Downloading image...")
        try:
            response = requests.get(full_path, stream=True)
            response.raise_for_status()
            with open(local_image_path, "wb") as f:
                f.write(response.content)
            log_message(f"Image downloaded successfully: {local_image_path}")
        except requests.RequestException as e:
            log_message(f"Failed to download image: {e}")
            return None
    return local_image_path

def main():
    internal_uri = "http://192.168.86.167:3000"
    external_uri = "http://184.92.108.105:3000"

    # Hide the cursor
    hide_cursor()

    # Fetch settings immediately
    settings = None
    for uri in (internal_uri, external_uri):
        settings = fetch_settings(uri)
        if settings:
            break

    if not settings:
        log_message("Failed to fetch settings. Exiting.")
        return

    current_pic = settings.get("currentPic")
    if not current_pic:
        log_message("No 'currentPic' found in settings. Exiting.")
        return

    # Display the image immediately
    local_image_path = download_image(uri, current_pic)
    if local_image_path:
        display_image(str(local_image_path))
    else:
        log_message("Could not display the initial image. Exiting.")
        return

    # Refresh the image every hour at 1 minute past the hour
    while True:
        now = datetime.now()
        next_refresh = (now.replace(minute=1, second=0, microsecond=0) + timedelta(hours=1))
        wait_time = (next_refresh - now).total_seconds()
        log_message(f"Next refresh scheduled at {next_refresh}. Waiting {wait_time} seconds...")
        time.sleep(wait_time)

        # Fetch settings and update the image
        for uri in (internal_uri, external_uri):
            settings = fetch_settings(uri)
            if settings:
                break

        if not settings:
            log_message("Failed to fetch settings during refresh. Skipping.")
            continue

        current_pic = settings.get("currentPic")
        if not current_pic:
            log_message("No 'currentPic' found during refresh. Skipping.")
            continue

        local_image_path = download_image(uri, current_pic)
        if local_image_path:
            display_image(str(local_image_path))

if __name__ == "__main__":
    main()
