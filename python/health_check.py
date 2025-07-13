# Health check script: check container and web, retry, Signal alert.

import os
import subprocess
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path='../env/signal.env')

SIGNAL_CLI_USER = os.getenv('SIGNAL_CLI_USER')
SIGNAL_GROUP_ID = os.getenv('SIGNAL_GROUP_ID')
AUTHORIZED_SENDERS = os.getenv('AUTHORIZED_SENDERS', '').split(',')
SIGNAL_CLI_PATH = "/usr/bin/signal-cli"

LOG_FILE = "../logs/health_check.log"

def timestamp():
    return time.strftime("[%Y-%m-%d %H:%M:%S]")

def log(message):
    with open(LOG_FILE, "a") as f:
        f.write(f"{timestamp()} {message}\n")
    print(f"{timestamp()} {message}")

def send_signal_alert(message):
    try:
        subprocess.run(
            f"{SIGNAL_CLI_PATH} -u {SIGNAL_CLI_USER} send --message \"{message}\" --receiver-group {SIGNAL_GROUP_ID}",
            shell=True,
            check=True
        )
        log("Signal alert sent successfully.")
    except subprocess.CalledProcessError:
        log("Failed to send Signal alert.")

def check_foundry_container():
    result = subprocess.run("podman ps --filter 'name=foundryvtt' --filter 'status=running' -q", shell=True, capture_output=True, text=True)
    return bool(result.stdout.strip())

def check_web_server(port=29000):
    result = subprocess.run(f"curl --connect-timeout 5 -s http://localhost:{port}", shell=True, capture_output=True, text=True)
    return result.returncode == 0

def health_check():
    retries = 3
    for attempt in range(1, retries + 1):
        log(f"Health check attempt {attempt}...")

        container_ok = check_foundry_container()
        web_ok = check_web_server()

        if container_ok and web_ok:
            log("FoundryVTT container and web server are healthy.")
            return True

        log(f"Attempt {attempt}: Foundry container healthy: {container_ok}, Web server healthy: {web_ok}")
        time.sleep(5)  # Wait before retrying

    # After retries failed
    send_signal_alert("🚨 FoundryVTT Health Check FAILED after retries! Immediate attention needed!")
    return False

if __name__ == "__main__":
    health_check()
