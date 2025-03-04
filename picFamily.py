import os
import time
import subprocess
import requests
from datetime import datetime

# Global constants for paths and URLs
BASE_PATH = "/home/pi"
LOG_FILE = "/home/pi/picfamily_debug.log"
BASE_URL = "http://192.168.86.167:3000/images"

def log_message(message):
    """Log messages to the log file."""
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")

def get_device_ip():
    """Check if the device has an IP address."""
    try:
        result = subprocess.check_output("hostname -I", shell=True).decode().strip()
        return result if result else None
    except subprocess.CalledProcessError:
        return None

def check_internet_access():
    """Check if the device has internet access by pinging Google DNS."""
    try:
        subprocess.check_call(["ping", "-c", "1", "8.8.8.8"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def sync_device_time():
    """Synchronize the device's time using systemd's timedatectl."""
    try:
        subprocess.check_call(["sudo", "timedatectl", "set-ntp", "true"])
        log_message("Time synchronized successfully.")
        return True
    except subprocess.CalledProcessError:
        log_message("Failed to synchronize time.")
        return False

def is_inside_local_network():
    """Check if the device is inside the local network."""
    try:
        gateway = subprocess.check_output(["ip", "route", "show", "default"]).decode().split()[2]
        if gateway.startswith("192.168"):
            log_message(f"Device is inside the local network (Gateway: {gateway}).")
            return True
        else:
            log_message(f"Device is outside the local network (Gateway: {gateway}).")
            return False
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to check network gateway: {e}")
        return False

def wait_for_framebuffer():
    """Wait for framebuffer device to be available."""
    while not os.path.exists('/dev/fb0'):
        log_message("Waiting for framebuffer device...")
        time.sleep(1)
    log_message("Framebuffer device is ready.")

def get_current_pic():
    """Fetch the current image file name from the server."""
    url = "http://192.168.86.167:3000/settings"
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        current_pic = data.get("currentPic")
        if current_pic:
            return current_pic
        else:
            raise ValueError("Key 'currentPic' not found in the response.")
    except (requests.RequestException, ValueError) as e:
        log_message(f"Error fetching 'currentPic': {e}")
        return None

def check_metadata(file_path):
    """Check the metadata of the file (size, last modified time)."""
    try:
        if os.path.exists(file_path):
            file_stat = os.stat(file_path)
            file_size = file_stat.st_size
            last_modified = datetime.fromtimestamp(file_stat.st_mtime)
            log_message(f"File {file_path} metadata: Size={file_size} bytes, Last Modified={last_modified}")
            return file_size, last_modified
        else:
            log_message(f"File {file_path} does not exist.")
            return None, None
    except Exception as e:
        log_message(f"Error checking metadata for {file_path}: {e}")
        return None, None

def check_and_download_image(file_name):
    """Check if the image exists locally, otherwise download it."""
    file_path = os.path.join(BASE_PATH, file_name)
    
    # Check metadata before downloading
    existing_size, existing_mod_time = check_metadata(file_path)
    if existing_size:
        # If file is already downloaded, check if it has been modified
        url = f"{BASE_URL}/{file_name}"
        try:
            response = requests.head(url, timeout=10)  # Use HEAD to fetch headers only
            response.raise_for_status()
            remote_size = int(response.headers.get('Content-Length', 0))
            remote_mod_time = response.headers.get('Last-Modified')
            
            if remote_mod_time:
                remote_mod_time = datetime.strptime(remote_mod_time, '%a, %d %b %Y %H:%M:%S GMT')

            if existing_size == remote_size and existing_mod_time == remote_mod_time:
                log_message(f"File {file_name} is already up-to-date. Skipping download.")
                return file_path
            else:
                log_message(f"File {file_name} is outdated or different. Re-downloading...")
        except requests.RequestException as e:
            log_message(f"Error checking remote file metadata: {e}")
    
    # If no valid local file or outdated, download it
    try:
        log_message(f"File {file_name} not found locally or outdated. Downloading from {BASE_URL}/{file_name}...")
        response = requests.get(f"{BASE_URL}/{file_name}", stream=True)
        if response.status_code == 200:
            with open(file_path, "wb") as file:
                for chunk in response.iter_content(chunk_size=1024):
                    file.write(chunk)
            log_message(f"File {file_name} downloaded successfully to {file_path}.")
            return file_path
        else:
            log_message(f"Failed to download the file. HTTP Status Code: {response.status_code}")
            return None
    except requests.RequestException as e:
        log_message(f"An error occurred while downloading the file: {e}")
        return None

def terminate_fim_processes():
    """Terminate any existing fim processes."""
    try:
        fim_pids = subprocess.check_output(["pgrep", "fim"]).decode().split()
        for pid in fim_pids:
            log_message(f"Terminating FIM process: {pid}")
            subprocess.run(["sudo", "kill", pid])
            time.sleep(2)
    except subprocess.CalledProcessError:
        log_message("No active FIM processes detected.")

def hide_cursor():
    """Hide the cursor on the framebuffer device."""
    try:
        log_message("Attempting to hide cursor...")
        with open("/sys/class/graphics/fbcon/cursor_blink", "w") as cursor_file:
            cursor_file.write("0")
        log_message("Cursor hidden successfully.")
    except Exception as e:
        log_message(f"Failed to hide cursor: {e}")

def verify_cursor_hidden():
    """Verify if the cursor is hidden."""
    try:
        with open("/sys/class/graphics/fbcon/cursor_blink", "r") as cursor_file:
            status = cursor_file.read().strip()
            log_message(f"Cursor blink status: {status}")
    except Exception as e:
        log_message(f"Failed to verify cursor blink status: {e}")

def display_image(local_image_path):
    """Display the image using the FIM command."""
    log_message("Checking for running FIM processes.")
    terminate_fim_processes()

    try:
        subprocess.run(["sudo", "setterm", "-term", "linux", "-foreground", "black", "-clear", "all", ">", "/dev/tty1"])
        subprocess.run(["sudo", "dmesg", "-n", "1"])

        log_message(f"Attempting to display image: {local_image_path}")
        # Use subprocess.Popen with timeout to avoid blocking
        process = subprocess.Popen(
            ["sudo", "fim", "-a", "-q", "-T", "1", "-d", "/dev/fb0", local_image_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        log_message(f"Image displayed successfully: {local_image_path}")

        hide_cursor()

        # Optionally, wait for a short time to ensure the process is started, then return
        process.wait(timeout=5)  # Wait for 5 seconds max
        log_message("fim process completed or timed out.")

    except subprocess.TimeoutExpired:
        log_message(f"FIM process timed out while displaying: {local_image_path}")
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to display image: {e}")

def main():
    log_message("Script started.")
    os.environ['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    os.environ['TERM'] = 'xterm'

    # Ensure text stays black permanently
    log_message("Setting Text to Black.")
    subprocess.run(["sudo", "setterm", "-term", "linux", "-foreground", "black"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    while not get_device_ip():
        log_message("No IP address assigned. Retrying...")
        time.sleep(5)
    
    log_message(f"Device IP address: {get_device_ip()}")
    while not check_internet_access():
        log_message("No internet access. Retrying...")
        time.sleep(5)
    
    while not sync_device_time():
        log_message("Failed to sync time. Retrying...")
        time.sleep(5)

    global BASE_URL
    if is_inside_local_network():
        BASE_URL = "http://192.168.86.167:3000/images"
    else:
        BASE_URL = "http://184.92.108.105:3000/images"
    log_message(f"Using BASE_URL: {BASE_URL}")

    wait_for_framebuffer()
    
    # Clear the framebuffer before displaying anything
    log_message("Clearing framebuffer...")
    subprocess.run(["sudo", "dd", "if=/dev/zero", "of=/dev/fb0", "bs=1228800", "count=1"])
    log_message("Framebuffer cleared.")

    hide_cursor()
    verify_cursor_hidden()

    current_pic = get_current_pic()
    if current_pic:
        local_image_path = check_and_download_image(current_pic)
        if local_image_path:
            display_image(local_image_path)

    while True:
        # Calculate time to wait until the next full hour
        now = datetime.now()
        seconds_to_next_hour = (60 - now.minute) * 60 - now.second  # Wait until the next full hour
        log_message(f"Waiting for {seconds_to_next_hour} seconds until the top of the next hour...")

        # Wait for the calculated time
        time.sleep(seconds_to_next_hour)

        # Fetch and display the new image right after the hour
        new_pic = get_current_pic()
        if new_pic:
            local_image_path = check_and_download_image(new_pic)
            if local_image_path:
                display_image(local_image_path)

if __name__ == "__main__":
    main()
