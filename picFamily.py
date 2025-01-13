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

def get_valid_ip():
    log_message("Waiting for a valid IP address...")
    while True:
        assigned_ip = subprocess.getoutput("hostname -I | awk '{print $1}'").strip()
        if assigned_ip and assigned_ip != "127.0.0.1":
            log_message(f"Valid IP address assigned: {assigned_ip}")
            return assigned_ip
        log_message("No valid IP address assigned yet. Retrying...")
        time.sleep(15)

def check_internet():
    log_message("Checking internet connectivity for up to 5 minutes...")
    timeout = time.time() + 300
    while time.time() < timeout:
        if subprocess.call(["ping", "-c", "1", "8.8.8.8"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) == 0:
            log_message("Internet is available!")
            return True
        log_message("Internet not available. Retrying...")
        time.sleep(5)
    log_message("Failed to establish internet connectivity after 5 minutes. Continuing script...")
    return False

def sync_time():
    log_message("Syncing time with systemd-timesyncd...")
    retry_command(lambda: subprocess.run(["sudo", "timedatectl", "set-ntp", "true"], check=True))

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
        with open("/sys/class/graphics/fbcon/cursor_blink", "w") as f:
            f.write("0")
    except Exception as e:
        log_message(f"Failed to hide cursor: {e}")

def display_image(local_image_path):
    log_message(f"Attempting to display image: {local_image_path}")
    max_attempts = 5
    attempt = 1
    try:
        # Open the image using Pillow
        img = Image.open(local_image_path)

        # Example: Resize the image to fit your screen resolution (adjust the size as needed)
        screen_width, screen_height = 800, 600  # Set to your screen resolution
        img = img.resize((screen_width, screen_height))

        # Convert image to RGB format
        img = img.convert('RGB')

        # Save the modified image as a temporary file in a format supported by framebuffer
        temp_image_path = "/tmp/modified_image.bmp"
        img.save(temp_image_path, format="BMP")
        
        while attempt <= max_attempts:
            try:
                # Display the image using Pillow
                subprocess.run(["sudo", "fbi", "-T", "1", "-d", "/dev/fb0", temp_image_path], check=True)
                log_message(f"Image {local_image_path} displayed successfully.")
                return True
            except subprocess.CalledProcessError as e:
                log_message(f"Error displaying image on attempt {attempt}: {e}")
                attempt += 1
                time.sleep(2)
        log_message(f"Failed to display image after {max_attempts} attempts.")
        return False
    except Exception as e:
        log_message(f"Error processing image {local_image_path}: {e}")
        return False

def main():
    get_valid_ip()
    check_internet()
    sync_time()

    # Determine the server URI
    internal_uri = "http://192.168.86.167:3000"
    external_uri = "http://184.92.108.105:3000"

    settings = None
    for uri in (internal_uri, external_uri):
        settings = fetch_settings(uri)
        if settings:
            break

    if not settings:
        log_message("Failed to fetch settings from both internal and external servers. Exiting.")
        return

    current_pic = settings.get("currentPic")
    if not current_pic:
        log_message("Error: 'currentPic' not found in server response.")
        return

    log_message(f"Received 'currentPic': {current_pic}")
    full_path = f"{uri}/images/{current_pic}"
    local_image_path = Path(f"/home/pi/{current_pic}")

    # Check if the image already exists locally
    if local_image_path.exists():
        log_message(f"Image already exists locally: {local_image_path}. Skipping download.")
    else:
        log_message("Image not found locally. Downloading...")
        try:
            response = requests.get(full_path, stream=True)
            response.raise_for_status()
            with open(local_image_path, "wb") as f:
                f.write(response.content)
            log_message(f"Image downloaded successfully: {local_image_path}")
        except requests.RequestException as e:
            log_message(f"Failed to download image: {e}")
            return

    hide_cursor()
    display_image(str(local_image_path))

if __name__ == "__main__":
    main()
