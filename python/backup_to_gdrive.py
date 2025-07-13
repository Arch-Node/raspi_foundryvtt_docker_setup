"""
backup_to_gdrive.py - Upload FoundryVTT backups to Google Drive

Usage:
    python backup_to_gdrive.py /path/to/backup_file_or_dir [drive_folder_name]

Setup:
    1. Enable Google Drive API for your Google account.
    2. Download credentials.json from Google Cloud Console and place in the path specified in your .env file.
    3. On first run, follow the browser prompt to authenticate.
    4. Create a .env file in this directory with the following variables:

    # .env example
    GDRIVE_CREDENTIALS=credentials.json
    GDRIVE_TOKEN=token.pickle
    GDRIVE_DEFAULT_FOLDER=FoundryVTT-Backups

Dependencies:
    pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib python-dotenv
"""
import os
import sys
import mimetypes
import pickle
import logging
from pathlib import Path
from dotenv import load_dotenv
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request

# Load environment variables from .env
load_dotenv()

SCOPES = ['https://www.googleapis.com/auth/drive.file']
CREDENTIALS_FILE = os.getenv('GDRIVE_CREDENTIALS', 'credentials.json')
TOKEN_FILE = os.getenv('GDRIVE_TOKEN', 'token.pickle')
DEFAULT_DRIVE_FOLDER = os.getenv('GDRIVE_DEFAULT_FOLDER', 'FoundryVTT-Backups')

logging.basicConfig(level=logging.INFO, format='[%(levelname)s] %(message)s')

def authenticate():
    creds = None
    if os.path.exists(TOKEN_FILE):
        with open(TOKEN_FILE, 'rb') as token:
            creds = pickle.load(token)
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        with open(TOKEN_FILE, 'wb') as token:
            pickle.dump(creds, token)
    return creds

def get_drive_service():
    creds = authenticate()
    return build('drive', 'v3', credentials=creds)

def get_folder_id(service, folder_name, parent_id=None):
    query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
    if parent_id:
        query += f" and '{parent_id}' in parents"
    results = service.files().list(q=query, spaces='drive', fields='files(id, name)').execute()
    files = results.get('files', [])
    if files:
        return files[0]['id']
    # Create folder if not found
    file_metadata = {
        'name': folder_name,
        'mimeType': 'application/vnd.google-apps.folder',
    }
    if parent_id:
        file_metadata['parents'] = [parent_id]
    folder = service.files().create(body=file_metadata, fields='id').execute()
    return folder.get('id')

def upload_file(service, file_path, parent_folder_id):
    file_name = os.path.basename(file_path)
    mime_type, _ = mimetypes.guess_type(file_path)
    file_metadata = {'name': file_name, 'parents': [parent_folder_id]}
    media = MediaFileUpload(file_path, mimetype=mime_type, resumable=True)
    logging.info(f"Uploading {file_name} to Google Drive...")
    file = service.files().create(body=file_metadata, media_body=media, fields='id').execute()
    logging.info(f"Upload complete: {file_name} (ID: {file.get('id')})")

def upload_directory(service, dir_path, parent_folder_id):
    for root, _, files in os.walk(dir_path):
        rel_path = os.path.relpath(root, dir_path)
        folder_id = parent_folder_id
        if rel_path != '.':
            # Create subfolders as needed
            for part in rel_path.split(os.sep):
                folder_id = get_folder_id(service, part, folder_id)
        for file in files:
            upload_file(service, os.path.join(root, file), folder_id)

def main():
    if len(sys.argv) < 2:
        print("Usage: python backup_to_gdrive.py /path/to/backup_file_or_dir [drive_folder_name]")
        sys.exit(1)
    backup_path = sys.argv[1]
    drive_folder = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_DRIVE_FOLDER
    if not os.path.exists(backup_path):
        logging.error(f"Backup path does not exist: {backup_path}")
        sys.exit(1)
    service = get_drive_service()
    folder_id = get_folder_id(service, drive_folder)
    if os.path.isfile(backup_path):
        upload_file(service, backup_path, folder_id)
    else:
        upload_directory(service, backup_path, folder_id)
    logging.info("All uploads complete.")

if __name__ == '__main__':
    main()
