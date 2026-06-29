#!/bin/bash

# Script to sync active boot EFI with this repository, auto-sanitizing serial numbers.

REPO_DIR="/Users/homemac/Work/gigabyte-z490-ud-ac-10850k-rx6600-opencore"
EFI_DEV="disk0s1"
MOUNT_POINT="/Volumes/EFI"

echo "=================================================="
echo "          HACKINTOSH EFI UPDATE UTILITY           "
echo "=================================================="

# 1. Mount EFI partition if not already mounted
if ! mount | grep -q "$MOUNT_POINT"; then
    echo "Mounting EFI partition ($EFI_DEV)..."
    sudo diskutil mount "$EFI_DEV"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mount $EFI_DEV"
        exit 1
    fi
fi

# 2. Check source path
if [ ! -d "$MOUNT_POINT/EFI" ]; then
    echo "Error: Source EFI folder not found at $MOUNT_POINT/EFI"
    exit 1
fi

echo "Copying EFI folder..."
# Back up the repository plist first just in case
cp "$REPO_DIR/EFI/OC/config.plist" "/tmp/config.plist.tmp" 2>/dev/null

# Copy EFI
rm -rf "$REPO_DIR/EFI"
cp -R "$MOUNT_POINT/EFI" "$REPO_DIR/"

# Clean junk files
find "$REPO_DIR/EFI" -name "*.bak" -delete 2>/dev/null
find "$REPO_DIR/EFI" -name "*.backup_*" -delete 2>/dev/null
find "$REPO_DIR/EFI" -name "*before_ai" -delete 2>/dev/null
find "$REPO_DIR/EFI" -name "._*" -delete 2>/dev/null
find "$REPO_DIR/EFI" -name "oldConfig.plist" -delete 2>/dev/null
find "$REPO_DIR/EFI" -name ".contentVisibility" -delete 2>/dev/null

# 3. Sanitize config.plist using python
echo "Sanitizing config.plist..."
python3 -c "
import plistlib
plist_path = '$REPO_DIR/EFI/OC/config.plist'
try:
    with open(plist_path, 'rb') as f:
        plist = plistlib.load(f)
    
    # Sanitize SMBIOS
    generic = plist['PlatformInfo']['Generic']
    generic['MLB'] = 'C02XXXXXXXXXXXXXXXXXX'
    generic['SystemSerialNumber'] = 'REDACTED'
    generic['SystemUUID'] = '00000000-0000-0000-0000-000000000000'
    
    with open(plist_path, 'wb') as f:
        plistlib.dump(plist, f)
    print('  Sanitization completed successfully.')
except Exception as e:
    print('  Error sanitizing plist:', e)
"

# 4. Unmount EFI
echo "Unmounting EFI..."
diskutil unmount "$MOUNT_POINT"

echo "Sync complete! Git changes status:"
cd "$REPO_DIR"
git diff --name-status
echo "=================================================="
