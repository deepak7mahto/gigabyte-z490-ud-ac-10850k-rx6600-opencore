# Changelog

All notable changes to this Hackintosh EFI project will be documented in this file.

## [1.0.0] - 2026-06-30
### Added
- Initial release of OpenCore EFI repository for Gigabyte Z490 UD AC.
- Added custom USB port map mapping `HS02` (Port 9) and `HS07` (Port 14) as Internal (255) to resolve Intel Bluetooth hardware power delivery.
- Enabled `IntelBluetoothFirmware.kext`, `IntelBTPatcher.kext`, and `BlueToolFixup.kext` for full Bluetooth support on macOS Monterey through Tahoe.
- Fully working Graphics acceleration (RX 6600), Ethernet (RTL8111), Wi-Fi (itlwm), Audio (VoodooHDA), and power monitoring.
