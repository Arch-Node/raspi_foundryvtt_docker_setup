#!/usr/bin/env python3

# Listen and process authorized Signal commands.

import os
import subprocess
import json
import time
from dotenv import load_dotenv

# Load environment variables
load_dotenv(dotenv_path='../env/signal.env')

SIGNAL_CLI_USER = os.getenv('SIGNAL_CLI_USER')
SIGNAL_GROUP_ID = os.getenv('SIGNAL_GROUP_ID')
AUTHORIZED_SENDERS = os.getenv('AUTHORIZED_SENDERS', '').split(',')
SIGNAL_CLI_PATH = "/usr/bin/signal-cli"

COMMAND_PREFIX = "!"
ALLOWED_COMMANDS = [
    "foundry status",
    "foundry restart",
    "foundry health",
    "foundry backup",
    "foundry uptime",
    "foundry space",
    "foundry reboot",
    "foundry help"
]

def timestamp():
    return time.strftime("[%Y-%m-%d %H:%M:%S]")

def send_signal_message(message):
    try:
        subprocess.run(
            f"{SIGNAL_CLI_PATH} -u {SIGNAL_CLI_USER} send --message \"{message}\" --receiver-group {SIGNAL_GROUP_ID}",
            shell=True,
            check=True
        )
    except subprocess.CalledProcessError as e:
        print(f"Failed to send Signal message. Error: {e}")

def parse_command(body):
    if not body.startswith(COMMAND_PREFIX):
        return None
    return body[len(COMMAND_PREFIX):].strip()

def handle_command(command, sender):
    if sender not in AUTHORIZED_SENDERS:
        send_signal_message("Unauthorized sender. Access denied.")
        return

    if command not in ALLOWED_COMMANDS:
        send_signal_message(f"Invalid command '{command}'. Send '!foundry help' for options.")
        return

    if command == "foundry status":
        subprocess.run("./foundry.sh status", shell=True)
    elif command == "foundry restart":
        subprocess.run("./foundry.sh restart", shell=True)
    elif command == "foundry health":
        subprocess.run("python3 ../python/health_check.py", shell=True)
    elif command == "foundry backup":
        subprocess.run("./foundry.sh backup", shell=True)
    elif command == "foundry uptime":
        subprocess.run("uptime", shell=True)
    elif command == "foundry space":
        subprocess.run("df -h /backups", shell=True)
    elif command == "foundry reboot":
        # Future improvement: add confirmation flow
        subprocess.run("sudo reboot", shell=True)
    elif command == "foundry help":
        help_message = (
            "Available commands:\n"
            "!foundry status\n"
            "!foundry restart\n"
            "!foundry health\n"
            "!foundry backup\n"
            "!foundry uptime\n"
            "!foundry space\n"
            "!foundry reboot\n"
            "!foundry help"
        )
        send_signal_message(help_message)

def listen_for_signal_messages():
    while True:
        try:
            result = subprocess.run(
                f"{SIGNAL_CLI_PATH} -u {SIGNAL_CLI_USER} receive -t",
                shell=True,
                capture_output=True,
                text=True
            )

            if result.stdout:
                messages = result.stdout.strip().split("\n")
                for raw_message in messages:
                    try:
                        data = json.loads(raw_message)
                        envelope = data.get('envelope', {})
                        source = envelope.get('source', '')
                        body = envelope.get('dataMessage', {}).get('message', '')

                        if body:
                            command = parse_command(body)
                            if command:
                                handle_command(command, source)

                    except json.JSONDecodeError:
                        print(f"{timestamp()} Failed to decode message: {raw_message}")

        except Exception as e:
            print(f"{timestamp()} Error receiving messages: {e}")

        time.sleep(5)  # Small sleep to avoid hammering CPU

if __name__ == "__main__":
    print(f"{timestamp()} Signal listener starting...")
    listen_for_signal_messages()
