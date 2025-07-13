#!/bin/bash
# =============================================================================
#  mount_drive.sh - Mount External Backup Storage (Local USB or Network)
#
#  Author: Arch-Node Project
#  Purpose:
#    - Mount USB drive for local backups
#    - Support for future NFS/SMB network mounts
#    - Robust error handling and validation
# =============================================================================

set -e

# Load environment variables
if [ -f ./env/drive_mount.env ]; then
    export $(grep -v '^#' ./env/drive_mount.env | xargs)
elif [ -f ../env/drive_mount.env ]; then
    export $(grep -v '^#' ../env/drive_mount.env | xargs)
else
    echo "[ERROR] Missing env/drive_mount.env. Cannot proceed with mounting."
    exit 1
fi

if [ "$MOUNT_DRIVE_ENABLED" != "true" ]; then
    echo "[INFO] External drive mounting is disabled. Skipping mount."
    exit 0
fi

# Set defaults
MOUNT_TYPE=${MOUNT_TYPE:-"usb"}  # usb, nfs, or smb
FILESYSTEM=${FILESYSTEM:-"ext4"}
MOUNT_OPTIONS=${MOUNT_OPTIONS:-"defaults,nofail"}

echo "[INFO] =============================================="
echo "[INFO] Storage Mount Configuration"
echo "[INFO] =============================================="
echo "[INFO] Mount Type: $MOUNT_TYPE"
echo "[INFO] Mount Point: $MOUNT_POINT"
if [ "$MOUNT_TYPE" = "usb" ]; then
    echo "[INFO] Device UUID: $DEVICE_UUID"
    echo "[INFO] Filesystem: $FILESYSTEM"
else
    echo "[INFO] Network Path: ${NETWORK_PATH:-"Not specified"}"
fi
echo "[INFO] =============================================="

# Function to detect USB drives
detect_usb_drives() {
    echo "[INFO] Detecting available USB drives..."
    lsblk -f -o NAME,FSTYPE,UUID,MOUNTPOINT | grep -E "(sd[a-z][0-9]|nvme[0-9]n[0-9]p[0-9])" || true
}

# Function to validate UUID exists
validate_uuid() {
    local uuid=$1
    if ! blkid | grep -q "$uuid"; then
        echo "[ERROR] UUID $uuid not found on system!"
        echo "[INFO] Available drives:"
        detect_usb_drives
        return 1
    fi
    return 0
}

# Function to check if already mounted
is_mounted() {
    mount | grep -q "$MOUNT_POINT"
}

# Function to mount USB drive
mount_usb_drive() {
    echo "[INFO] Mounting USB drive with UUID: $DEVICE_UUID"
    
    # Validate UUID exists
    if ! validate_uuid "$DEVICE_UUID"; then
        exit 1
    fi
    
    # Get device path from UUID
    DEVICE_PATH=$(blkid -U "$DEVICE_UUID")
    if [ -z "$DEVICE_PATH" ]; then
        echo "[ERROR] Could not find device path for UUID: $DEVICE_UUID"
        exit 1
    fi
    
    echo "[INFO] Device path: $DEVICE_PATH"
    
    # Check filesystem
    ACTUAL_FS=$(blkid -s TYPE -o value "$DEVICE_PATH")
    echo "[INFO] Detected filesystem: $ACTUAL_FS"
    
    if [ "$ACTUAL_FS" != "$FILESYSTEM" ]; then
        echo "[WARNING] Expected $FILESYSTEM but found $ACTUAL_FS"
        echo "[INFO] Using detected filesystem: $ACTUAL_FS"
        FILESYSTEM="$ACTUAL_FS"
    fi
    
    # Ensure mount point exists
    sudo mkdir -p "$MOUNT_POINT"
    
    # Check if already mounted
    if is_mounted; then
        echo "[INFO] Drive is already mounted at $MOUNT_POINT"
        return 0
    fi
    
    # Backup fstab first
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)
    
    # Remove any existing entries for this UUID or mount point
    sudo sed -i "/UUID=$DEVICE_UUID/d" /etc/fstab
    sudo sed -i "\|$MOUNT_POINT|d" /etc/fstab
    
    # Add new fstab entry
    echo "UUID=$DEVICE_UUID $MOUNT_POINT $FILESYSTEM $MOUNT_OPTIONS 0 2" | sudo tee -a /etc/fstab
    
    # Test mount
    if sudo mount "$MOUNT_POINT"; then
        echo "[INFO] USB drive mounted successfully at $MOUNT_POINT"
    else
        echo "[ERROR] Failed to mount USB drive!"
        # Remove the fstab entry we just added
        sudo sed -i "/UUID=$DEVICE_UUID/d" /etc/fstab
        exit 1
    fi
}

# Function to mount network drive (NFS)
mount_nfs_drive() {
    echo "[INFO] Mounting NFS share: $NETWORK_PATH"
    
    # Install NFS client if not present
    if ! command -v mount.nfs >/dev/null 2>&1; then
        echo "[INFO] Installing NFS client..."
        sudo apt-get update
        sudo apt-get install -y nfs-common
    fi
    
    # Ensure mount point exists
    sudo mkdir -p "$MOUNT_POINT"
    
    # Check if already mounted
    if is_mounted; then
        echo "[INFO] NFS share is already mounted at $MOUNT_POINT"
        return 0
    fi
    
    # Backup fstab
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)
    
    # Remove existing entries
    sudo sed -i "\|$MOUNT_POINT|d" /etc/fstab
    
    # Add NFS entry
    NFS_OPTIONS="${MOUNT_OPTIONS},_netdev"
    echo "$NETWORK_PATH $MOUNT_POINT nfs $NFS_OPTIONS 0 0" | sudo tee -a /etc/fstab
    
    # Test mount
    if sudo mount "$MOUNT_POINT"; then
        echo "[INFO] NFS share mounted successfully at $MOUNT_POINT"
    else
        echo "[ERROR] Failed to mount NFS share!"
        sudo sed -i "\|$MOUNT_POINT|d" /etc/fstab
        exit 1
    fi
}

# Function to mount SMB/CIFS drive
mount_smb_drive() {
    echo "[INFO] Mounting SMB/CIFS share: $NETWORK_PATH"
    
    # Install CIFS client if not present
    if ! command -v mount.cifs >/dev/null 2>&1; then
        echo "[INFO] Installing CIFS client..."
        sudo apt-get update
        sudo apt-get install -y cifs-utils
    fi
    
    # Ensure mount point exists
    sudo mkdir -p "$MOUNT_POINT"
    
    # Check if already mounted
    if is_mounted; then
        echo "[INFO] SMB share is already mounted at $MOUNT_POINT"
        return 0
    fi
    
    # Create credentials file if username/password provided
    if [ -n "$SMB_USERNAME" ] && [ -n "$SMB_PASSWORD" ]; then
        CREDS_FILE="/etc/foundry-smb-creds"
        sudo tee "$CREDS_FILE" > /dev/null <<EOF
username=$SMB_USERNAME
password=$SMB_PASSWORD
domain=${SMB_DOMAIN:-WORKGROUP}
EOF
        sudo chmod 600 "$CREDS_FILE"
        SMB_OPTIONS="credentials=$CREDS_FILE,${MOUNT_OPTIONS},_netdev"
    else
        SMB_OPTIONS="guest,${MOUNT_OPTIONS},_netdev"
    fi
    
    # Backup fstab
    sudo cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d-%H%M%S)
    
    # Remove existing entries
    sudo sed -i "\|$MOUNT_POINT|d" /etc/fstab
    
    # Add SMB entry
    echo "$NETWORK_PATH $MOUNT_POINT cifs $SMB_OPTIONS 0 0" | sudo tee -a /etc/fstab
    
    # Test mount
    if sudo mount "$MOUNT_POINT"; then
        echo "[INFO] SMB share mounted successfully at $MOUNT_POINT"
    else
        echo "[ERROR] Failed to mount SMB share!"
        sudo sed -i "\|$MOUNT_POINT|d" /etc/fstab
        exit 1
    fi
}

# Main mounting logic
case "$MOUNT_TYPE" in
    "usb")
        if [ -z "$DEVICE_UUID" ]; then
            echo "[ERROR] DEVICE_UUID is required for USB mounting!"
            echo "[INFO] Run 'blkid' to find your drive's UUID"
            detect_usb_drives
            exit 1
        fi
        mount_usb_drive
        ;;
    "nfs")
        if [ -z "$NETWORK_PATH" ]; then
            echo "[ERROR] NETWORK_PATH is required for NFS mounting!"
            echo "[INFO] Example: NETWORK_PATH=192.168.1.100:/path/to/share"
            exit 1
        fi
        mount_nfs_drive
        ;;
    "smb"|"cifs")
        if [ -z "$NETWORK_PATH" ]; then
            echo "[ERROR] NETWORK_PATH is required for SMB mounting!"
            echo "[INFO] Example: NETWORK_PATH=//192.168.1.100/share"
            exit 1
        fi
        mount_smb_drive
        ;;
    *)
        echo "[ERROR] Unknown MOUNT_TYPE: $MOUNT_TYPE"
        echo "[INFO] Supported types: usb, nfs, smb"
        exit 1
        ;;
esac

# Verify mount was successful
if is_mounted; then
    echo "[INFO] Verifying mount permissions and accessibility..."
    
    # Test write permissions
    TEST_FILE="$MOUNT_POINT/.foundry-mount-test"
    if echo "test" | sudo tee "$TEST_FILE" >/dev/null 2>&1; then
        sudo rm -f "$TEST_FILE"
        echo "[INFO] Mount has write permissions - OK"
    else
        echo "[WARNING] Mount may be read-only or have permission issues"
    fi
    
    # Show mount info
    echo "[INFO] Mount information:"
    df -h "$MOUNT_POINT" | tail -1
    
    # Set proper ownership if it's a backup directory
    if [[ "$MOUNT_POINT" == *backup* ]]; then
        echo "[INFO] Setting backup directory ownership..."
        sudo chown -R $(id -u):$(id -g) "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    echo "[INFO] =============================================="
    echo "[INFO] 🎉 Storage Mount Complete! 🎉"
    echo "[INFO] =============================================="
    echo "[INFO] Type: $MOUNT_TYPE"
    echo "[INFO] Location: $MOUNT_POINT"
    echo "[INFO] Status: $(mount | grep "$MOUNT_POINT" | cut -d' ' -f1,3,5)"
    echo "[INFO] =============================================="
else
    echo "[ERROR] Mount verification failed!"
    exit 1
fi
