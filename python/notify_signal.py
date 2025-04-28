#!/usr/bin/env python3

import os
import subprocess
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path='../env/signal.env')

SIGNAL_CLI_USER = os.getenv('SIGNAL_CLI_USER')
SIGNAL_GROUP_ID = os.getenv('SIGNAL_GROUP_ID')
SIGNAL_CLI_PATH = "/usr/bin/signal-cli"

def send_signal_message(message):
    """Send a simple message to the configured Signal group."""
    try:
        subprocess.run(
            f"{SIGNAL_CLI_PATH} -u {SIGNAL_CLI_USER} send --message \"{message}\" --receiver-group {SIGNAL_GROUP_ID}",
            shell=True,
            check=True
        )
        print("Signal message sent successfully.")
    except subprocess.CalledProcessError as e:
        print(f"Failed to send Signal message. Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: notify_signal.py \"Your message here\"")
        sys.exit(1)

    message = sys.argv[1]
    send_signal_message(message)
