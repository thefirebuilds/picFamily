import os
import time
import json
import subprocess
import requests
from pathlib import Path
import logging
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

def retry_command(command, max_retries=5, delay=2):
    attempt = 1
    while attempt <= max_retries:
        try:
            if callable(command):
                command()
            else:
                subprocess.run(command, check=True, shell=True)
            return True
        except Exception as e:
            log_message(f"Attempt {attempt} failed: {e}")
            attempt += 1
            time.sleep(delay)
    log_message(f"Command failed after {max_retries} attempts: {command}")
    return False

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
        # Use sudo to write to /sys/class/graphics/fbcon/cursor_blink
        subprocess.run(
            ["sudo", "sh", "-c", "echo 0 > /sys/class/graphics/fbcon/cursor_blink"],
            check=True
        )
        log_message("Cursor successfully hidden.")
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to hide cursor: {e}")
    except Exception as e:
        log_message(f"Unexpected error while hiding cursor: {e}")
        
def display_image(image_path):
    log_message(f"Displaying image: {image_path}")
    try:
        subprocess.run(["fim", "-a", "-q", image_path], check=True)
        log_message(f"Image displayed successfully: {image_path}")
    except subprocess.CalledProcessError as e:
        log_message(f"Error displaying image: {e}")

def download_image(image_url, local_path):
    log_message(f"Downloading image from {image_url}...")
    try:
        response = requests.get(image_url, stream=True)
        response.raise_for_status()
        with open(local_path, "wb") as f:
            f.write(response.content)
        log_message(f"Image downloaded successfully: {local_path}")
        return True
    except requests.RequestException as e:
        log_message(f"Failed to download image: {e}")
        return False

def main():
    internal_uri = "http://192.168.86.167:3000"
    external_uri = "http://184.92.108.105:3000"

    hide_cursor()

    while True:
        # Wait until 1 minute after the hour
        current_time = time.localtime()
        if current_time.tm_min == 1:
            settings = None
            for uri in (internal_uri, external_uri):
                settings = fetch_settings(uri)
                if settings:
                    break

            if not settings:
                log_message("Failed to fetch settings from both internal and external servers.")
                time.sleep(60)  # Wait a minute before retrying
                continue

            current_pic = settings.get("currentPic")
            if not current_pic:
                log_message("Error: 'currentPic' not found in server response.")
                time.sleep(60)
                continue

            log_message(f"Received 'currentPic': {current_pic}")
            full_path = f"{uri}/images/{current_pic}"
            local_image_path = Path(f"/home/pi/{current_pic}")

            # Download the image if it doesn't exist locally or force update
            if not local_image_path.exists() or settings.get("forceUpdate", False):
                if not download_image(full_path, local_image_path):
                    log_message("Failed to fetch the new image. Retrying next hour.")
                    time.sleep(60)
                    continue

            # Display the image
            display_image(str(local_image_path))

        # Sleep until the next check
        time.sleep(30)

if __name__ == "__main__":
    main()
