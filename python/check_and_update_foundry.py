#!/usr/bin/env python3
# Script to check and update FoundryVTT container if needed.

import os
import subprocess
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path='../env/signal.env')

SIGNAL_CLI_USER = os.getenv('SIGNAL_CLI_USER')
SIGNAL_GROUP_ID = os.getenv('SIGNAL_GROUP_ID')
SIGNAL_CLI_PATH = "/usr/bin/signal-cli"

def timestamp():
    return time.strftime("[%Y-%m-%d %H:%M:%S]")

def send_signal_message(message):
    try:
        subprocess.run(
            f"{SIGNAL_CLI_PATH} -u {SIGNAL_CLI_USER} send --message \"{message}\" --receiver-group {SIGNAL_GROUP_ID}",
            shell=True,
            check=True
        )
        print(f"{timestamp()} Notification sent.")
    except subprocess.CalledProcessError as e:
        print(f"{timestamp()} Failed to send Signal message: {e}")

def get_current_foundry_version():
    result = subprocess.run(
        "docker inspect foundryvtt --format '{{ .Config.Image }}'",
        shell=True,
        capture_output=True,
        text=True
    )
    if result.returncode == 0:
        return result.stdout.strip()
    else:
        return None

def check_for_new_foundry_version():
    # Placeholder - Real FoundryVTT official version checking API would go here
    # For now, we simulate always "no new version" so we don't auto-update inappropriately
    return None

def backup_foundry_data():
    timestamp_str = time.strftime("%Y%m%d_%H%M%S")
    backup_filename = f"/backups/foundry_backup_{timestamp_str}.tar.gz"
    result = subprocess.run(f"tar czf {backup_filename} /home/foundryuser/foundrydata", shell=True)
    return result.returncode == 0

def update_foundry_container():
    # This needs to match your real docker run or docker-compose logic
    subprocess.run("docker pull felddy/foundryvtt:release", shell=True)
    subprocess.run("docker stop foundryvtt", shell=True)
    subprocess.run("docker rm foundryvtt", shell=True)
    subprocess.run("docker run -d --name foundryvtt -p 29000:30000 felddy/foundryvtt:release", shell=True)

def main():
    current_version = get_current_foundry_version()
    print(f"{timestamp()} Current Foundry container: {current_version}")

    available_version = check_for_new_foundry_version()

    if available_version and available_version != current_version:
        send_signal_message(f"🔔 New FoundryVTT version available: {available_version}. Backing up and updating...")

        backup_ok = backup_foundry_data()
        if backup_ok:
            send_signal_message("✅ Backup successful. Updating container...")
            update_foundry_container()
            send_signal_message("🚀 FoundryVTT container updated and restarted.")
        else:
            send_signal_message("⚠️ Backup failed! Aborting update.")
    else:
        print(f"{timestamp()} No new FoundryVTT version detected. Nothing to do.")

if __name__ == "__main__":
    main()
