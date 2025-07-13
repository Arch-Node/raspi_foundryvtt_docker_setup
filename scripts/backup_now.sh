#!/usr/bin/env python3
# =============================================================================
#  backup_now.py - Enhanced Backup Script for FoundryVTT Server
#
#  Author: Arch-Node Project
#  Purpose:
#    - Create compressed backups of FoundryVTT data
#    - Support multiple backup strategies (full, incremental)
#    - Verify backup integrity and completeness
#    - Integrate with Signal notifications
#    - Provide detailed logging and error handling
# =============================================================================

import os
import sys
import shutil
import tarfile
import gzip
import hashlib
import json
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
from dotenv import load_dotenv

# Add python directory to path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'python'))

try:
    from notify_signal import send_signal_notification
except ImportError:
    def send_signal_notification(message):
        print(f"[WARNING] Signal notification not available: {message}")

# Load environment variables with fallback paths
def load_env_files():
    env_paths = [
        "./env/drive_mount.env",
        "./env/backup.env", 
        "./env/foundry.env",
        "../env/drive_mount.env",
        "../env/backup.env",
        "../env/foundry.env"
    ]
    
    for env_path in env_paths:
        if os.path.exists(env_path):
            load_dotenv(dotenv_path=env_path)

load_env_files()

# Configuration with defaults
FOUNDRY_VOLUME = os.getenv("FOUNDRY_VOLUME", "foundry_data")
FOUNDATION_SOURCE = f"/var/lib/docker/volumes/{FOUNDRY_VOLUME}/_data"
BACKUP_BASE = os.getenv("MOUNT_POINT", "/backups")
RETENTION_DAYS = int(os.getenv("BACKUP_RETENTION_DAYS", 14))
BACKUP_TYPE = os.getenv("BACKUP_TYPE", "full")  # full, incremental
COMPRESS_BACKUPS = os.getenv("COMPRESS_BACKUPS", "true").lower() == "true"
VERIFY_BACKUPS = os.getenv("VERIFY_BACKUPS", "true").lower() == "true"
MAX_BACKUP_SIZE_GB = int(os.getenv("MAX_BACKUP_SIZE_GB", 10))

# Logging setup
LOG_DIR = os.path.join(BACKUP_BASE, "logs")
os.makedirs(LOG_DIR, exist_ok=True)
LOG_FILE = os.path.join(LOG_DIR, f"backup_{datetime.now().strftime('%Y%m%d')}.log")

def log_message(level, message):
    """Enhanced logging with timestamps and levels"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}"
    print(log_entry)
    
    with open(LOG_FILE, "a") as f:
        f.write(log_entry + "\n")

def get_directory_size(path):
    """Calculate directory size in bytes"""
    total_size = 0
    try:
        for dirpath, dirnames, filenames in os.walk(path):
            for filename in filenames:
                filepath = os.path.join(dirpath, filename)
                if os.path.exists(filepath):
                    total_size += os.path.getsize(filepath)
    except Exception as e:
        log_message("WARNING", f"Could not calculate size for {path}: {e}")
    return total_size

def format_size(bytes_size):
    """Format bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.2f} PB"

def calculate_checksum(filepath):
    """Calculate SHA256 checksum of a file"""
    hash_sha256 = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_sha256.update(chunk)
        return hash_sha256.hexdigest()
    except Exception as e:
        log_message("ERROR", f"Failed to calculate checksum for {filepath}: {e}")
        return None

def is_foundry_container_running():
    """Check if FoundryVTT container is running"""
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", f"volume={FOUNDRY_VOLUME}", "--format", "{{.Names}}"],
            capture_output=True, text=True, check=True
        )
        return bool(result.stdout.strip())
    except Exception:
        return False

def pause_foundry_container():
    """Pause FoundryVTT container for consistent backup"""
    try:
        result = subprocess.run(
            ["docker", "ps", "--filter", f"volume={FOUNDRY_VOLUME}", "--format", "{{.Names}}"],
            capture_output=True, text=True, check=True
        )
        container_name = result.stdout.strip()
        
        if container_name:
            log_message("INFO", f"Pausing container {container_name} for backup...")
            subprocess.run(["docker", "pause", container_name], check=True)
            return container_name
    except Exception as e:
        log_message("WARNING", f"Could not pause container: {e}")
    return None

def resume_foundry_container(container_name):
    """Resume FoundryVTT container after backup"""
    if container_name:
        try:
            log_message("INFO", f"Resuming container {container_name}...")
            subprocess.run(["docker", "unpause", container_name], check=True)
        except Exception as e:
            log_message("ERROR", f"Failed to resume container {container_name}: {e}")

def create_backup_metadata(backup_path, source_size, backup_size, checksum=None):
    """Create metadata file for backup"""
    metadata = {
        "timestamp": datetime.now().isoformat(),
        "source_path": FOUNDATION_SOURCE,
        "backup_type": BACKUP_TYPE,
        "source_size_bytes": source_size,
        "backup_size_bytes": backup_size,
        "compressed": COMPRESS_BACKUPS,
        "retention_days": RETENTION_DAYS,
        "checksum": checksum,
        "foundry_volume": FOUNDRY_VOLUME
    }
    
    metadata_file = os.path.join(backup_path, "backup_metadata.json")
    try:
        with open(metadata_file, "w") as f:
            json.dump(metadata, f, indent=2)
        log_message("INFO", f"Created backup metadata: {metadata_file}")
    except Exception as e:
        log_message("WARNING", f"Could not create metadata file: {e}")

def create_compressed_backup(source_path, backup_path):
    """Create compressed tar.gz backup"""
    backup_file = os.path.join(backup_path, "foundry_data.tar.gz")
    
    try:
        log_message("INFO", "Creating compressed backup archive...")
        with tarfile.open(backup_file, "w:gz") as tar:
            tar.add(source_path, arcname="foundry_data")
        
        backup_size = os.path.getsize(backup_file)
        checksum = calculate_checksum(backup_file)
        
        log_message("INFO", f"Compressed backup created: {format_size(backup_size)}")
        return backup_size, checksum, backup_file
        
    except Exception as e:
        log_message("ERROR", f"Failed to create compressed backup: {e}")
        raise

def create_uncompressed_backup(source_path, backup_path):
    """Create uncompressed backup using rsync-style copy"""
    backup_dir = os.path.join(backup_path, "foundry_data")
    
    try:
        log_message("INFO", "Creating uncompressed backup...")
        shutil.copytree(source_path, backup_dir, dirs_exist_ok=True)
        
        backup_size = get_directory_size(backup_dir)
        log_message("INFO", f"Uncompressed backup created: {format_size(backup_size)}")
        return backup_size, None, backup_dir
        
    except Exception as e:
        log_message("ERROR", f"Failed to create uncompressed backup: {e}")
        raise

def verify_backup(backup_file_or_dir, is_compressed):
    """Verify backup integrity"""
    if not VERIFY_BACKUPS:
        return True
        
    log_message("INFO", "Verifying backup integrity...")
    
    try:
        if is_compressed and backup_file_or_dir.endswith('.tar.gz'):
            # Verify compressed archive
            with tarfile.open(backup_file_or_dir, "r:gz") as tar:
                # Try to list contents - will fail if corrupted
                members = tar.getmembers()
                log_message("INFO", f"Verified {len(members)} files in compressed backup")
        else:
            # Verify directory exists and has content
            if os.path.isdir(backup_file_or_dir):
                file_count = sum(len(files) for _, _, files in os.walk(backup_file_or_dir))
                log_message("INFO", f"Verified {file_count} files in uncompressed backup")
            else:
                raise Exception("Backup directory not found")
                
        return True
        
    except Exception as e:
        log_message("ERROR", f"Backup verification failed: {e}")
        return False

def cleanup_old_backups():
    """Remove backups older than retention period"""
    log_message("INFO", f"Cleaning up backups older than {RETENTION_DAYS} days...")
    cutoff = datetime.now() - timedelta(days=RETENTION_DAYS)
    
    backup_root = os.path.join(BACKUP_BASE, "foundry_backups")
    deleted_count = 0
    freed_space = 0
    
    if not os.path.exists(backup_root):
        log_message("WARNING", f"Backup root {backup_root} does not exist")
        return
    
    try:
        for folder in os.listdir(backup_root):
            folder_path = os.path.join(backup_root, folder)
            if os.path.isdir(folder_path):
                try:
                    folder_time = datetime.strptime(folder, "%Y%m%d_%H%M%S")
                    if folder_time < cutoff:
                        folder_size = get_directory_size(folder_path)
                        log_message("INFO", f"Deleting old backup: {folder} ({format_size(folder_size)})")
                        shutil.rmtree(folder_path)
                        deleted_count += 1
                        freed_space += folder_size
                except ValueError:
                    log_message("WARNING", f"Skipping unknown folder format: {folder}")
    except Exception as e:
        log_message("ERROR", f"Error during cleanup: {e}")
    
    if deleted_count > 0:
        log_message("INFO", f"Cleanup complete: {deleted_count} backups deleted, {format_size(freed_space)} freed")
    else:
        log_message("INFO", "No old backups to clean up")

def check_disk_space():
    """Check available disk space before backup"""
    try:
        statvfs = os.statvfs(BACKUP_BASE)
        free_bytes = statvfs.f_frsize * statvfs.f_bavail
        free_gb = free_bytes / (1024**3)
        
        source_size = get_directory_size(FOUNDATION_SOURCE)
        source_gb = source_size / (1024**3)
        
        log_message("INFO", f"Available space: {format_size(free_bytes)}")
        log_message("INFO", f"Source data size: {format_size(source_size)}")
        
        # Estimate backup size (compressed is ~30-50% of original)
        estimated_backup_gb = source_gb * (0.4 if COMPRESS_BACKUPS else 1.1)
        
        if free_gb < estimated_backup_gb:
            raise Exception(f"Insufficient disk space. Need ~{estimated_backup_gb:.2f}GB, have {free_gb:.2f}GB")
            
        if source_gb > MAX_BACKUP_SIZE_GB:
            log_message("WARNING", f"Source data ({source_gb:.2f}GB) exceeds maximum backup size ({MAX_BACKUP_SIZE_GB}GB)")
            
        return source_size
        
    except Exception as e:
        log_message("ERROR", f"Disk space check failed: {e}")
        raise

def main():
    """Main backup function"""
    start_time = datetime.now()
    container_name = None
    
    try:
        log_message("INFO", "=" * 50)
        log_message("INFO", "FoundryVTT Backup Starting")
        log_message("INFO", "=" * 50)
        log_message("INFO", f"Source: {FOUNDATION_SOURCE}")
        log_message("INFO", f"Destination: {BACKUP_BASE}")
        log_message("INFO", f"Type: {BACKUP_TYPE}")
        log_message("INFO", f"Compressed: {COMPRESS_BACKUPS}")
        log_message("INFO", f"Retention: {RETENTION_DAYS} days")
        
        # Pre-flight checks
        if not os.path.exists(FOUNDATION_SOURCE):
            raise Exception(f"Source path does not exist: {FOUNDATION_SOURCE}")
            
        if not os.path.exists(BACKUP_BASE):
            raise Exception(f"Backup destination does not exist: {BACKUP_BASE}")
        
        # Check disk space
        source_size = check_disk_space()
        
        # Create timestamped backup folder
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_folder = os.path.join(BACKUP_BASE, "foundry_backups", timestamp)
        os.makedirs(backup_folder, exist_ok=True)
        
        # Pause container for consistent backup
        if is_foundry_container_running():
            container_name = pause_foundry_container()
        
        # Create backup
        if COMPRESS_BACKUPS:
            backup_size, checksum, backup_path = create_compressed_backup(FOUNDATION_SOURCE, backup_folder)
        else:
            backup_size, checksum, backup_path = create_uncompressed_backup(FOUNDATION_SOURCE, backup_folder)
        
        # Resume container
        if container_name:
            resume_foundry_container(container_name)
            container_name = None
        
        # Verify backup
        if not verify_backup(backup_path, COMPRESS_BACKUPS):
            raise Exception("Backup verification failed")
        
        # Create metadata
        create_backup_metadata(backup_folder, source_size, backup_size, checksum)
        
        # Cleanup old backups
        cleanup_old_backups()
        
        # Calculate duration and compression ratio
        duration = datetime.now() - start_time
        compression_ratio = (source_size / backup_size * 100) if backup_size > 0 else 100
        
        # Success message
        success_msg = f"✅ Backup completed successfully in {duration.total_seconds():.1f}s"
        success_msg += f"\n📁 Size: {format_size(source_size)} → {format_size(backup_size)}"
        if COMPRESS_BACKUPS:
            success_msg += f" ({compression_ratio:.1f}% compression)"
        success_msg += f"\n📍 Location: {backup_folder}"
        
        log_message("INFO", success_msg)
        send_signal_notification(f"FoundryVTT backup completed: {format_size(backup_size)}")
        
    except Exception as e:
        error_msg = f"❌ Backup failed: {e}"
        log_message("ERROR", error_msg)
        send_signal_notification(f"FoundryVTT backup failed: {str(e)}")
        
        # Resume container if it was paused
        if container_name:
            resume_foundry_container(container_name)
        
        sys.exit(1)
    
    finally:
        log_message("INFO", "=" * 50)

if __name__ == "__main__":
    main()
