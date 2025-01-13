import os
import time
import subprocess

def log_message(message):
    with open("/home/pi/picfamily_debug.log", "a") as log_file:
        log_file.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")

def wait_for_framebuffer():
    while not os.path.exists('/dev/fb0'):
        log_message("Waiting for framebuffer device...")
        time.sleep(1)
    log_message("Framebuffer device is ready.")

def terminate_fim_processes():
    try:
        fim_pids = subprocess.check_output(["pgrep", "fim"]).decode().split()
        for pid in fim_pids:
            log_message(f"Terminating FIM process: {pid}")
            subprocess.run(["kill", pid])
            time.sleep(2)
    except subprocess.CalledProcessError:
        log_message("No active FIM processes detected.")

def display_image(local_image_path):
    log_message(f"Displaying image: {local_image_path}")
    terminate_fim_processes()
    os.system("clear > /dev/fb0")
    time.sleep(1)
    try:
        subprocess.run(["sudo", "fim", "-a", "-q", "-T", "1", "-d", "/dev/fb0", local_image_path], check=True)
        log_message("Image displayed successfully.")
    except subprocess.CalledProcessError as e:
        log_message(f"Failed to display image: {e}")

if __name__ == "__main__":
    log_message("Script started.")
    os.environ['PATH'] = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
    os.environ['TERM'] = 'xterm'

    wait_for_framebuffer()
    log_message("Hiding cursor...")
    subprocess.run(["echo", "0", "|", "sudo", "tee", "/sys/class/graphics/fbcon/cursor_blink"], shell=True)
    display_image("/home/pi/IMG_0658.JPG")
