#!/usr/bin/env python3
import sys
import os
import plistlib
import subprocess

PROFILES = {
    '1': ('Performance', 0x00),
    '2': ('Balanced', 0x80),
    '3': ('Power Saver', 0xC0)
}

def find_efi_partition():
    try:
        res = subprocess.run(["diskutil", "list"], capture_output=True, text=True, check=True)
        for line in res.stdout.splitlines():
            if "EFI EFI" in line:
                parts = line.split()
                if parts:
                    return parts[-1] # E.g., "disk1s1" or "disk0s1"
    except Exception as e:
        print(f"Error finding EFI: {e}")
    return None

def modify_plist(path, epp_val):
    if not os.path.exists(path):
        return False
        
    with open(path, 'rb') as f:
        plist = plistlib.load(f)
        
    try:
        personalities = plist['IOKitPersonalities']
        for k in personalities:
            data_dict = personalities[k]
            if 'cf-frequency-data' in data_dict:
                freq_data = bytearray(data_dict['cf-frequency-data'])
                epp_marker = bytes.fromhex("6570700000000000000000000000000000000000")
                epp_offset = freq_data.find(epp_marker)
                if epp_offset >= 0:
                    val_offset = epp_offset + 20 + 8
                    freq_data[val_offset] = epp_val
                    data_dict['cf-frequency-data'] = bytes(freq_data)
                    plist['IOKitPersonalities'][k] = data_dict
                    
        with open(path, 'wb') as f:
            plistlib.dump(plist, f)
        return True
    except Exception as e:
        print(f"Error modifying {path}: {e}")
        return False

def main():
    if len(sys.argv) < 2 or sys.argv[1] not in PROFILES:
        print("Usage: change_profile.py [1|2|3]")
        sys.exit(1)
        
    choice = sys.argv[1]
    name, val = PROFILES[choice]
    print(f"Switching profile to: {name} (EPP: 0x{val:02x})")
    
    # 1. Modify repository file (always available, no mount needed)
    repo_path = "/Users/homemac/Work/gigabyte-z490-ud-ac-10850k-rx6600-opencore/EFI/OC/Kexts/CPUFriendDataProvider.kext/Contents/Info.plist"
    if modify_plist(repo_path, val):
        print(f"✅ Updated repository configuration.")
    else:
        print(f"⚠️ Repository configuration file not found at {repo_path}")
        
    # 2. Find and mount active EFI partition
    efi_dev = find_efi_partition()
    if not efi_dev:
        print("❌ Could not find EFI partition to update.")
        sys.exit(1)
        
    print(f"Mounting EFI partition (/dev/{efi_dev})...")
    try:
        subprocess.run(["diskutil", "mount", efi_dev], check=True, capture_output=True)
    except Exception as e:
        print(f"❌ Failed to mount EFI: {e}")
        sys.exit(1)
        
    # 3. Modify active EFI file
    efi_path = "/Volumes/EFI/EFI/OC/Kexts/CPUFriendDataProvider.kext/Contents/Info.plist"
    updated_efi = False
    if modify_plist(efi_path, val):
        print(f"✅ Updated active EFI configuration.")
        updated_efi = True
    else:
        print(f"❌ Active EFI configuration file not found at {efi_path}")
        
    # 4. Unmount active EFI partition
    print("Unmounting EFI...")
    try:
        subprocess.run(["diskutil", "unmount", "/Volumes/EFI"], check=True, capture_output=True)
        print("✅ EFI unmounted.")
    except Exception as e:
        print(f"⚠️ Failed to unmount EFI: {e}")
        
    if not updated_efi:
        sys.exit(1)

if __name__ == '__main__':
    main()
