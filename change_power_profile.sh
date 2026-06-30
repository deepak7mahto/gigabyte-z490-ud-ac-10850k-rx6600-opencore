#!/bin/bash

# Simple interactive wrapper script to switch CPUFriend power profiles on Gigabyte Z490 Hackintosh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="${SCRIPT_DIR}/change_profile.py"

echo "============================================="
echo "   Hackintosh CPU Power Profile Selector     "
echo "============================================="
echo "1) Performance (EPP 0x00) - CPU stays locked at high turbo clocks"
echo "2) Balanced (EPP 0x80) - macOS default, scales up/down dynamically"
echo "3) Power Saver (EPP 0xC0) - Aggressively keeps CPU at lower clocks"
echo "============================================="
read -p "Select profile (1-3): " choice

if [[ ! "$choice" =~ ^[1-3]$ ]]; then
    echo "Invalid choice. Exiting."
    exit 1
fi

# Find and mount EFI partition
echo "Mounting EFI..."
# Detect disk structure
EFI_DEV=$(diskutil list | grep "EFI EFI" | awk '{print $NF}' | head -1)
if [ -z "$EFI_DEV" ]; then
    echo "Could not find EFI partition."
    exit 1
fi

echo "Found EFI partition at: /dev/${EFI_DEV}"
sudo diskutil mount "/dev/${EFI_DEV}"

if [ ! -d "/Volumes/EFI/EFI/OC" ]; then
    echo "EFI partition failed to mount or not valid OpenCore partition."
    exit 1
fi

# Run the python modification script
python3 "$PYTHON_SCRIPT" "$choice"

# Unmount EFI
echo "Unmounting EFI..."
sudo diskutil unmount "/Volumes/EFI"

echo "============================================="
echo "✅ Finished! Please restart your computer to apply the profile."
echo "============================================="
