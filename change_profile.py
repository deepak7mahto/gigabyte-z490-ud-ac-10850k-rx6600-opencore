#!/usr/bin/env python3
import sys
import os
import plistlib

PROFILES = {
    '1': ('Performance', 0x00),
    '2': ('Balanced', 0x80),
    '3': ('Power Saver', 0xC0)
}

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
                # Locate EPP marker: "epp" + zeros
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
        print("  1: Performance (EPP 0x00)")
        print("  2: Balanced (EPP 0x80)")
        print("  3: Power Saver (EPP 0xC0)")
        sys.exit(1)
        
    choice = sys.argv[1]
    name, val = PROFILES[choice]
    print(f"Switching profile to: {name} (EPP: 0x{val:02x})")
    
    # 1. Modify repository file
    repo_path = "/Users/homemac/Work/gigabyte-z490-ud-ac-10850k-rx6600-opencore/EFI/OC/Kexts/CPUFriendDataProvider.kext/Contents/Info.plist"
    if modify_plist(repo_path, val):
        print(f"✅ Updated repository configuration.")
    else:
        print(f"⚠️ Repository configuration file not found at {repo_path}")
        
    # 2. Modify active EFI file
    efi_path = "/Volumes/EFI/EFI/OC/Kexts/CPUFriendDataProvider.kext/Contents/Info.plist"
    if modify_plist(efi_path, val):
        print(f"✅ Updated active EFI configuration.")
    else:
        print(f"⚠️ Active EFI configuration not updated (make sure EFI is mounted).")

if __name__ == '__main__':
    main()
