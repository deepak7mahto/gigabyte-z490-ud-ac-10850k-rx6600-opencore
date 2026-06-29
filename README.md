# Gigabyte Z490 UD AC Hackintosh EFI (OpenCore)

[![OpenCore v1.0.1+](https://img.shields.io/badge/OpenCore-1.0.1%2B-blue.svg)](https://github.com/acidanthera/OpenCorePkg)
[![macOS Compatibility](https://img.shields.io/badge/macOS-Tahoe%2026.x%20%7C%20Sonoma%20%7C%20Ventura-success.svg)](#macos-compatibility)
[![Platform](https://img.shields.io/badge/Platform-Intel%20Comet%20Lake-lightgrey.svg)](#hardware-specifications)

This repository contains the OpenCore EFI configuration files for running macOS on a Gigabyte Z490 UD AC system powered by an Intel Core i9-10850K processor and an AMD Radeon RX 6600 graphics card.

---

## Hardware Specifications

| Component | Details |
| :--- | :--- |
| **Motherboard** | Gigabyte Z490 UD AC (Intel Z490 Chipset) |
| **CPU** | Intel Core i9-10850K (10 Cores, 20 Threads, Comet Lake) |
| **GPU** | AMD Radeon RX 6600 (8GB GDDR6, Navi 23) |
| **RAM** | 32GB DDR4 3600MHz (G.Skill Ripjaws V, 2×16GB) |
| **Storage (macOS)**| WD Green SN350 1TB NVMe SSD |
| **Storage (Windows)**| Samsung SSD 980 500GB NVMe SSD |
| **Ethernet** | Realtek RTL8168H/8111H PCIe Gigabit Ethernet |
| **Wi-Fi / BT** | Intel AX200/201 (CNVi, onboard) |
| **Audio** | Realtek ALC887 (VoodooHDA) |
| **SMBIOS** | iMac20,2 |

---

## macOS Compatibility

* macOS Tahoe 26.x: ✅ Tested & Fully Working
* macOS Sonoma 14.x: ✅ Compatible
* macOS Ventura 13.x: ✅ Compatible

---

## Working / Not Working Status

### Working
* **macOS Boot:** Native boot via OpenCore bootloader.
* **Graphics Acceleration (QE/CI):** Native AMD Radeon RX 6600 support with full Metal 3 acceleration. (iGPU UHD 630 runs headless for background compute task assistance).
* **Wi-Fi:** Intel Wireless connection via `itlwm.kext`.
* **Bluetooth:** Onboard Intel Bluetooth working flawlessly with `IntelBluetoothFirmware.kext` + `BlueToolFixup.kext` + `IntelBTPatcher.kext`.
* **Ethernet:** Realtek Gigabit Ethernet port runs at full speed via `RealtekRTL8111.kext`.
* **Audio:** Rear green Line-Out and HDMI/DP audio working.
* **USB Port Mapping:** Custom 12-port map (`UTBMap.kext`) configured under the 15-port limit. Internal Bluetooth USB port (Port 14 and Port 9 fallback) mapped to Type 255 to ensure proper power state management.
* **iMessage & FaceTime:** Fully working (requires generating your own unique serials).
* **Sleep & Wake:** Working.

### Not Working / Limitations
* **Apple AirDrop / Handoff:** Native AirDrop/Handoff is not supported due to Intel Wi-Fi limitations (requires Broadcom card for full Apple ecosystem features).
* **DRM (Apple TV / Netflix on Safari):** DRM might be limited depending on the iMac SMBIOS model. Using a third-party browser like Chrome resolves Netflix/Prime streaming.

---

## Kexts & Drivers Used

### Kernel Extensions (Kexts)
* **Lilu.kext** (v1.7.2): Arbitrary kernel patching.
* **VirtualSMC.kext** (v1.3.7): Advanced SMC emulation.
* **WhateverGreen.kext** (v1.7.0): Graphics patches for RX 6600.
* **itlwm.kext** (v2.3.0): Intel Wi-Fi client driver.
* **IntelBluetoothFirmware.kext** (v2.4.0): Intel Bluetooth firmware uploader.
* **IntelBTPatcher.kext** (v2.4.0): Bluetooth stack kernel patching.
* **BlueToolFixup.kext** (v2.7.2): Userspace Bluetooth compatibility for macOS Monterey+.
* **USBToolBox.kext** (v1.2.0) + **UTBMap.kext** (v1.1): Custom USB port mapping.
* **RealtekRTL8111.kext** (v3.0.4): Realtek Ethernet driver.
* **VoodooHDA.kext** (v3.0.3): Legacy audio driver fallback.
* **NVMeFix.kext** (v1.1.3): NVMe drive power management compatibility.
* **RestrictEvents.kext** (v1.1.6): Restricts unwanted processes/memory warnings on custom hardware.
* **RTCMemoryFixup.kext** (v1.0.7): Prevents CMOS checksum resets.
* **RadeonSensor.kext** + **SMCRadeonGPU.kext** (v0.3.3): GPU temperature reporting.
* **SMCProcessor.kext** + **SMCSuperIO.kext** (v1.3.7): CPU temp & fan speed metrics.

### ACPI SSDTs
* **SSDT-AWAC.aml**: Disables AWAC system clock and enables RTC for macOS compat.
* **SSDT-PLUG-DRTNIA.aml**: Configures native CPU power management (XCPM).
* **SSDT-EC-USBX-DESKTOP.aml**: Provides fake Embedded Controller (EC) and USB power injection.

---

## USB Port Mapping Table

To prevent sleep wake issues and ensure high-speed USB performance, all ports are mapped via `USBToolBox`:

| Port | Number (Hex) | Connector Type | Assigned Device |
| :--- | :--- | :--- | :--- |
| **HS01** | `05` | USB 3.0 Type-A | Rear Panel USB 2.0 / 3.0 |
| **HS02** | `09` | Internal (255) | Onboard Intel Bluetooth USB port |
| **HS03** | `0A` | USB 3.0 Type-A | Rear Panel Port |
| **HS04** | `0B` | USB 2.0 Type-A | Rear Panel USB 2.0 |
| **HS05** | `0C` | USB 2.0 Type-A | Rear Panel USB 2.0 |
| **HS06** | `0D` | Internal (255) | Onboard RGB/Motherboard Controller |
| **HS07** | `0E` | Internal (255) | Onboard Intel Bluetooth alternate header |
| **HS09** | `06` | Internal (255) | ITE Motherboard Controller |
| **HS10** | `08` | Internal (255) | ITE Controller Port 8 |
| **SS01** | `21` | USB 3.0 Type-A | Rear Panel USB 3.0 SuperSpeed |
| **SS02** | `25` | USB 3.0 Type-A | Rear Panel USB 3.0 SuperSpeed |
| **SS03** | `26` | USB 3.0 Type-A | Rear Panel USB 3.0 SuperSpeed |

Total enabled ports: **12** (remains below the macOS 15-port limit).

---

## Recommended BIOS Settings

Ensure your Gigabyte Z490 Motherboard BIOS is configured with these settings:

| Setting | Target State | Notes |
| :--- | :--- | :--- |
| **VT-d** | **Enabled** / **Disabled** | If Enabled, ensure `DisableIoMapper = True` in config.plist |
| **CFG Lock** | **Disabled** | Essential for native CPU power management |
| **Above 4G Decoding** | **Enabled** | Required for modern AMD GPUs |
| **Fast Boot** | **Disabled** | |
| **Secure Boot** | **Disabled** | |
| **CSM Support** | **Disabled** | Ensures UEFI-only boot mode |
| **SATA Mode** | **AHCI** | Required for macOS drive detection |
| **XHCI Hand-off** | **Enabled** | Required for USB controller handoff to OS |

---

## Installation & Setup

1. **Clone this repository:**
   ```bash
   git clone https://github.com/deepak7mahto/gigabyte-z490-ud-ac-10850k-rx6600-opencore.git
   ```
2. **Generate your own SMBIOS serials:**
   Do **NOT** attempt to boot with the serial numbers left as `REDACTED` or `00000000...` in this repository.
   - Download [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS).
   - Generate SMBIOS credentials for the model **`iMac20,2`**.
   - Open `EFI/OC/config.plist` and inject your newly generated values into `PlatformInfo -> Generic`:
     - `SystemSerialNumber`
     - `MLB` (Board Serial)
     - `SystemUUID`
     - `ROM` (Input your system's network card MAC address or keep the generic one)
3. Copy the sanitized `EFI` folder to the root of your FAT32 EFI boot partition.
4. Reboot, configure BIOS, and select the OpenCore boot device.

---

## Credits & Resources
* [Dortania OpenCore Install Guide](https://dortania.github.io/OpenCore-Install-Guide/)
* [Acidanthera](https://github.com/acidanthera) for OpenCore and core drivers.
* [USBToolBox](https://github.com/USBToolBox) project.
