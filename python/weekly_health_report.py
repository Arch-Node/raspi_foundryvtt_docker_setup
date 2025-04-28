#!/usr/bin/env python3
# Send weekly server status report via Signal.

import os
import subprocess
import shutil
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path='../env/signal.env')
load_dotenv(dotenv_path='../env/backup.env')

SIGNAL_CLI_USER = os.getenv('SIGNAL_CLI_USER')
SIGNAL_GROUP_ID = os.getenv('SIGNAL_GROUP_ID')
SIGNAL_CLI_PATH = "/usr/bin/signal-cli"
BACKUP_FOLDER = os.getenv('BACKUP_FOLDER', '/backups')

def timestamp():
    return time.strftime("[%Y-%m-%d %H:%M:%S]")

def send_signal_message(message):
    try:
        subprocess.run(
            f"{SIGNAL_CLI_PATH} -u {SIGNAL_CLI_USER} send --message \"{message}\" --receiver-group {SIGNAL_GROUP_ID}",
            shell=True,
            check=True
        )
        print(f"{timestamp()} Weekly report sent.")
    except subprocess.CalledProcessError as e:
        print(f"{timestamp()} Failed to send Signal message: {e}")

def get_uptime():
    result = subprocess.run("uptime -p", shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_disk_space():
    total, used, free = shutil.disk_usage(BACKUP_FOLDER)
    return f"Backup Drive Free Space: {free // (2**30)} GiB / {total // (2**30)} GiB"

def get_latest_backup_info():
    try:
        backups = [f for f in os.listdir(BACKUP_FOLDER) if f.startswith("foundry_backup_") and f.endswith(".tar.gz")]
        backups.sort(reverse=True)
        if backups:
            latest = backups[0]
            path = os.path.join(BACKUP_FOLDER, latest)
            backup_time = os.path.getmtime(path)
            age_days = (time.time() - backup_time) / (60*60*24)
            return f"Latest Backup: {latest} ({age_days:.1f} days old)"
        else:
            return "No backups found!"
    except Exception as e:
        return f"Error checking backups: {e}"

def get_foundry_version():
    result = subprocess.run("docker inspect foundryvtt --format '{{ .Config.Image }}'", shell=True, capture_output=True, text=True)
    if result.returncode == 0:
        return f"Foundry Container Image: {result.stdout.strip()}"
    else:
        return "Unable to get FoundryVTT container info."

def build_weekly_report():
    parts = [
        f"📋 **Weekly Server Health Report**",
        f"Uptime: {get_uptime()}",
        f"{get_disk_space()}",
        f"{get_latest_backup_info()}",
        f"{get_foundry_version()}",
        f"Report Time: {timestamp()}"
    ]
    return "\n".join(parts)

if __name__ == "__main__":
    report = build_weekly_report()
    send_signal_message(report)
