## Englisch and German Description below

# Tactical RMM Scripts Collection

A collection of monitoring and maintenance scripts for Tactical RMM to manage Windows and Linux systems.

## 📋 Overview

This repository contains production-ready scripts for:
- **System Monitoring** (Updates, Reboots, Hardware)
- **Automated Maintenance** (Updates, Store Apps)
- **Security Checks** (UEFI, Secure Boot, Defender)
- **Infrastructure Monitoring** (ZFS, SMB, Scheduled Tasks)

---

## 🐧 Linux Scripts

### System Monitoring

#### `required_reboot_check.sh`
Checks if a system reboot is pending.

**Platform:** Debian/Ubuntu  
**Exit Codes:**
- `0` = No reboot required
- `1` = Reboot pending

**Usage:**
```bash
./required_reboot_check.sh
```

---

#### `system_update_check.sh`
Checks for available system updates (language-independent).

**Platform:** Debian/Ubuntu  
**Version:** 1.1  
**Exit Codes:**
- `0` = No updates available
- `1` = Updates available

**Usage:**
```bash
./system_update_check.sh
```

---

### Hardware & Storage

#### `smart_disk_health_check.sh`
Checks S.M.A.R.T. status of all physical disks.

**Platform:** Debian/Ubuntu  
**Requirements:** `smartmontools`  
**Exit Codes:**
- `0` = All disks OK
- `1` = Error detected

**Usage:**
```bash
./smart_disk_health_check.sh
```

---

#### `zfs_health_check.sh`
Checks the status of all ZFS storage pools.

**Platform:** Debian/Ubuntu  
**Requirements:** ZFS installed  
**Exit Codes:**
- `0` = All pools ONLINE
- `1` = Pool error detected

**Usage:**
```bash
./zfs_health_check.sh
```

---

### Virtualization

#### `EFI_disk_without_ms-cert-2023.sh`
Checks Proxmox VE logs for EFI certificate issues.

**Platform:** Proxmox VE  
**Checks for:** `"EFI disk without 'ms-cert=2023'"`  
**Exit Codes:**
- `0` = OK / not Proxmox
- `1` = Warning found

**Usage:**
```bash
./EFI_disk_without_ms-cert-2023.sh
```

---

### Maintenance & Configuration

#### `unattended_upgrades_check.sh`
Checks installation, configuration, and functionality of Unattended-Upgrades.

**Platform:** Debian/Ubuntu  
**Version:** 1.0  
**Exit Codes:**
- `0` = Everything OK
- `1` = Error found

**Usage:**
```bash
./unattended_upgrades_check.sh
```

---

## 🪟 Windows Scripts

### System Updates

#### `fast_windows_updates.ps1`
Installs Windows and Microsoft Updates with optimized timeout.

**Version:** 1.0 TRMM  
**Timeout:** ~15-30 Min  
**Requires:** Administrator privileges

**Parameters:**
- `-NoReboot` - Prevents automatic restart

**Exit Codes:**
- `0` = Successful
- `1` = Error or missing admin rights

**Usage:**
```powershell
.\fast_windows_updates.ps1
.\fast_windows_updates.ps1 -NoReboot
```

---

#### `Full_Windows_System_Update.ps1`
Comprehensive update script for Windows, software, and Store apps.

**Version:** 2.2 TRMM  
**Requires:** PowerShell 5.1+, Administrator privileges

**Updates:**
- Windows Updates (including Microsoft Updates)
- Software via winget/Chocolatey
- Microsoft Store Apps

**Excluded:** Wazuh Agent (Security Monitoring)

**Parameters:**
- `-SkipWindowsUpdates` - Skips Windows Updates
- `-SkipSoftwareUpdates` - Skips software updates
- `-SkipStoreApps` - Skips Store Apps
- `-NoReboot` - Prevents automatic restart

**Exit Codes:**
- `0` = All updates successful
- `1` = Error or missing admin rights

**Usage:**
```powershell
.\Full_Windows_System_Update.ps1
.\Full_Windows_System_Update.ps1 -SkipStoreApps -NoReboot
```

---

#### `winget_choco_updates.ps1`
Updates software via winget and Chocolatey.

**Version:** 1.1 TRMM  
**Timeout:** ~10-20 Min

**Parameters:**
- `-ExcludePackages` - Comma-separated list of packages to exclude

**Exit Codes:**
- `0` = Successful
- `1` = Error or missing admin rights

**Usage:**
```powershell
.\winget_choco_updates.ps1
.\winget_choco_updates.ps1 -ExcludePackages "package1,package2"
```

---

#### `windows_Store_App_Updates.ps1`
Updates Microsoft Store Apps.

**Version:** 1.0 TRMM  
**Timeout:** ~5-10 Min

**Exit Codes:**
- `0` = Successful
- `1` = Error

**Usage:**
```powershell
.\windows_Store_App_Updates.ps1
```

---

### Security & Compliance

#### `UEFI_Cert2023_Check.ps1`
Checks UEFI, Secure Boot, and Microsoft certificates.

**Checks:**
- UEFI mode active
- Secure Boot enabled
- Microsoft certificates current

**Security:** Read-only access, no system modifications

**Exit Codes:**
- `0` = All checks OK
- `1` = Error or warning

**Usage:**
```powershell
.\UEFI_Cert2023_Check.ps1
```

---

#### `AV_Add_Update_Exclusion.ps1`
Adds Windows Defender exclusions for Tactical RMM.

**Usage:**
```powershell
.\AV_Add_Update_Exclusion.ps1
```

---

### System Monitoring

#### `reboot_required.ps1`
Checks various Windows indicators for pending reboots.

**Version:** 1.1  
**Checks:**
- Windows Update
- Pending File Rename Operations
- Component Based Servicing
- Computer Rename

**Exit Codes:**
- `0` = No reboot needed
- `1` = Reboot required (WARNING)

**Usage:**
```powershell
.\reboot_required.ps1
```

---

#### `scheduled_task_check.ps1`
Checks scheduled tasks for errors.

**Version:** 1.4  
**Excluded:** System tasks, Microsoft folder

**Exit Codes:**
- `0` = All tasks OK
- `1` = At least one task with error

**Usage:**
```powershell
.\scheduled_task_check.ps1
```

---

### Network & Infrastructure

#### `smb_connect_check.ps1`
Checks accessibility of network drives/UNC paths.

**Version:** 2.2  
**Compatible:** Windows Server 2012+, Windows 10+, Windows 11

**Checks:**
- Ping to server
- UNC path existence (Test-Path)
- No read/write operations

**Parameters:**
- `-UNCPath` (required) - UNC path (e.g., `\\server\share`)
- `-Timeout` - Timeout in seconds (default: 5)

**Exit Codes:**
- `0` = Network drive accessible
- `1` = Not accessible (ALERT)
- `2` = Script error or invalid parameters

**Usage:**
```powershell
.\smb_connect_check.ps1 -UNCPath "\\server\share"
.\smb_connect_check.ps1 -UNCPath "\\192.168.1.100\backup" -Timeout 10
```

---

### Windows Update Management

#### `upgrade_block.ps1`
Blocks future Windows feature updates.

**Function:**
- Detects current Windows version
- Sets registry lock for feature updates
- Checks if lock already exists

**Usage:**
```powershell
.\upgrade_block.ps1
```

---

#### `upgrade_unlock.ps1`
Removes blocking of Windows feature updates.

**Function:**
- Checks if lock exists
- Removes registry entries

**Usage:**
```powershell
.\upgrade_unlock.ps1
```

---

## 🚀 Installation in Tactical RMM

### Linux Scripts
1. Upload script to Tactical RMM
2. Shell Type: **Bash**
3. Platform: **Linux**
4. Execute permissions are set automatically

### Windows Scripts
1. Upload script to Tactical RMM
2. Shell Type: **PowerShell**
3. Platform: **Windows**
4. If needed: Enable "Run as Administrator"

---

## 📊 Exit Code Convention

All scripts follow the Tactical RMM convention:

| Exit Code | Meaning | Tactical RMM Status |
|-----------|---------|---------------------|
| `0` | Success / OK | ✅ Informational |
| `1` | Error / Warning | ⚠️ Warning/Error |
| `2` | Critical Error | 🔴 Critical (only some scripts) |

---

## 🔧 Requirements

### Linux
- Bash Shell
- Additional packages if needed:
  - `smartmontools` (for SMART Check)
  - `zfsutils-linux` (for ZFS Check)
  - `unattended-upgrades` (for Unattended-Upgrades Check)

### Windows
- PowerShell 5.1 or higher
- Administrator privileges (for most scripts)
- Optional:
  - `winget` (for software updates)
  - `Chocolatey` (for software updates)

---

## 📝 License

These scripts are provided "as-is".

---

## 🤝 Contributing

Contributions are welcome! Please create a pull request or open an issue.

---

## ⚠️ Disclaimer

These scripts have been developed for production use, but: **Always test in a test environment first!**

Especially for:
- Update scripts
- Registry changes (upgrade_block/unlock)
- Storage checks on production systems

# Tactical RMM Scripts Collection

Eine Sammlung von Monitoring- und Wartungsskripten für Tactical RMM zur Verwaltung von Windows- und Linux-Systemen.
I am not liable for damages.

## 📋 Übersicht

Diese Repository enthält produktionsreife Scripts für:
- **System-Monitoring** (Updates, Reboots, Hardware)
- **Automatisierte Wartung** (Updates, Store Apps)
- **Sicherheitschecks** (UEFI, Secure Boot, Defender)
- **Infrastruktur-Monitoring** (ZFS, SMB, Scheduled Tasks)

---

## 🐧 Linux Scripts

### System-Monitoring

#### `required_reboot_check.sh`
Prüft ob ein System-Neustart aussteht.

**Platform:** Debian/Ubuntu  
**Exit Codes:**
- `0` = Kein Reboot erforderlich
- `1` = Reboot ausstehend

**Verwendung:**
```bash
./required_reboot_check.sh
```

---

#### `system_update_check.sh`
Überprüft verfügbare System-Updates (sprachunabhängig).

**Platform:** Debian/Ubuntu  
**Version:** 1.1  
**Exit Codes:**
- `0` = Keine Updates verfügbar
- `1` = Updates verfügbar

**Verwendung:**
```bash
./system_update_check.sh
```

---

### Hardware & Storage

#### `smart_disk_health_check.sh`
Prüft S.M.A.R.T. Status aller physischen Festplatten.

**Platform:** Debian/Ubuntu  
**Voraussetzungen:** `smartmontools`  
**Exit Codes:**
- `0` = Alle Disks OK
- `1` = Fehler erkannt

**Verwendung:**
```bash
./smart_disk_health_check.sh
```

---

#### `zfs_health_check.sh`
Überprüft den Status aller ZFS Storage Pools.

**Platform:** Debian/Ubuntu  
**Voraussetzungen:** ZFS installiert  
**Exit Codes:**
- `0` = Alle Pools ONLINE
- `1` = Pool-Fehler erkannt

**Verwendung:**
```bash
./zfs_health_check.sh
```

---

### Virtualisierung

#### `EFI_disk_without_ms-cert-2023.sh`
Prüft Proxmox VE Logs auf EFI-Zertifikatsprobleme.

**Platform:** Proxmox VE  
**Prüft:** `"EFI disk without 'ms-cert=2023'"`  
**Exit Codes:**
- `0` = OK / nicht Proxmox
- `1` = Warning gefunden

**Verwendung:**
```bash
./EFI_disk_without_ms-cert-2023.sh
```

---

### Wartung & Konfiguration

#### `unattended_upgrades_check.sh`
Prüft Installation, Konfiguration und Funktionalität von Unattended-Upgrades.

**Platform:** Debian/Ubuntu  
**Version:** 1.0  
**Exit Codes:**
- `0` = Alles OK
- `1` = Fehler gefunden

**Verwendung:**
```bash
./unattended_upgrades_check.sh
```

---

## 🪟 Windows Scripts

### System-Updates

#### `fast_windows_updates.ps1`
Installiert Windows und Microsoft Updates mit optimiertem Timeout.

**Version:** 1.0 TRMM  
**Timeout:** ~15-30 Min  
**Erfordert:** Administrator-Rechte

**Parameter:**
- `-NoReboot` - Verhindert automatischen Neustart

**Exit Codes:**
- `0` = Erfolgreich
- `1` = Fehler oder keine Admin-Rechte

**Verwendung:**
```powershell
.\fast_windows_updates.ps1
.\fast_windows_updates.ps1 -NoReboot
```

---

#### `Full_Windows_System_Update.ps1`
Umfassendes Update-Skript für Windows, Software und Store Apps.

**Version:** 2.2 TRMM  
**Erfordert:** PowerShell 5.1+, Administrator-Rechte

**Aktualisiert:**
- Windows Updates (inkl. Microsoft Updates)
- Software via winget/Chocolatey
- Microsoft Store Apps

**Ausgeschlossen:** Wazuh Agent (Security Monitoring)

**Parameter:**
- `-SkipWindowsUpdates` - Überspringt Windows Updates
- `-SkipSoftwareUpdates` - Überspringt Software-Updates
- `-SkipStoreApps` - Überspringt Store Apps
- `-NoReboot` - Verhindert automatischen Neustart

**Exit Codes:**
- `0` = Alle Updates erfolgreich
- `1` = Fehler oder keine Admin-Rechte

**Verwendung:**
```powershell
.\Full_Windows_System_Update.ps1
.\Full_Windows_System_Update.ps1 -SkipStoreApps -NoReboot
```

---

#### `winget_choco_updates.ps1`
Aktualisiert Software via winget und Chocolatey.

**Version:** 1.1 TRMM  
**Timeout:** ~10-20 Min

**Parameter:**
- `-ExcludePackages` - Komma-getrennte Liste auszuschließender Pakete

**Exit Codes:**
- `0` = Erfolgreich
- `1` = Fehler oder keine Admin-Rechte

**Verwendung:**
```powershell
.\winget_choco_updates.ps1
.\winget_choco_updates.ps1 -ExcludePackages "package1,package2"
```

---

#### `windows_Store_App_Updates.ps1`
Aktualisiert Microsoft Store Apps.

**Version:** 1.0 TRMM  
**Timeout:** ~5-10 Min

**Exit Codes:**
- `0` = Erfolgreich
- `1` = Fehler

**Verwendung:**
```powershell
.\windows_Store_App_Updates.ps1
```

---

### Sicherheit & Compliance

#### `UEFI_Cert2023_Check.ps1`
Prüft UEFI, Secure Boot und Microsoft-Zertifikate.

**Prüfungen:**
- UEFI-Modus aktiv
- Secure Boot aktiviert
- Microsoft-Zertifikate aktuell

**Sicherheit:** Nur Lesezugriff, keine Systemänderungen

**Exit Codes:**
- `0` = Alle Checks OK
- `1` = Fehler oder Warnung

**Verwendung:**
```powershell
.\UEFI_Cert2023_Check.ps1
```

---

#### `AV_Add_Update_Exclusion.ps1`
Fügt Windows Defender Exclusions für Tactical RMM hinzu.

**Verwendung:**
```powershell
.\AV_Add_Update_Exclusion.ps1
```

---

### System-Monitoring

#### `reboot_required.ps1`
Prüft verschiedene Windows-Indikatoren für ausstehende Neustarts.

**Version:** 1.1  
**Prüft:**
- Windows Update
- Pending File Rename Operations
- Component Based Servicing
- Computer Rename

**Exit Codes:**
- `0` = Kein Neustart nötig
- `1` = Neustart erforderlich (WARNUNG)

**Verwendung:**
```powershell
.\reboot_required.ps1
```

---

#### `scheduled_task_check.ps1`
Überprüft geplante Aufgaben auf Fehler.

**Version:** 1.4  
**Ausgeschlossen:** System-Tasks, Microsoft-Ordner

**Exit Codes:**
- `0` = Alle Tasks OK
- `1` = Mindestens ein Task mit Fehler

**Verwendung:**
```powershell
.\scheduled_task_check.ps1
```

---

### Netzwerk & Infrastruktur

#### `smb_connect_check.ps1`
Prüft die Erreichbarkeit von Netzlaufwerken/UNC-Pfaden.

**Version:** 2.2  
**Kompatibel:** Windows Server 2012+, Windows 10+, Windows 11

**Prüfungen:**
- Ping zum Server
- UNC-Pfad Existenz (Test-Path)
- Keine Lese-/Schreiboperationen

**Parameter:**
- `-UNCPath` (erforderlich) - UNC-Pfad (z.B. `\\server\share`)
- `-Timeout` - Timeout in Sekunden (default: 5)

**Exit Codes:**
- `0` = Netzlaufwerk erreichbar
- `1` = Nicht erreichbar (ALERT)
- `2` = Script-Fehler oder ungültige Parameter

**Verwendung:**
```powershell
.\smb_connect_check.ps1 -UNCPath "\\server\share"
.\smb_connect_check.ps1 -UNCPath "\\192.168.1.100\backup" -Timeout 10
```

---

### Windows Update Verwaltung

#### `upgrade_block.ps1`
Blockiert zukünftige Windows-Feature-Updates.

**Funktion:**
- Ermittelt aktuelle Windows-Version
- Setzt Registry-Sperre für Feature-Updates
- Prüft ob Sperre bereits existiert

**Verwendung:**
```powershell
.\upgrade_block.ps1
```

---

#### `upgrade_unlock.ps1`
Entfernt Blockierung von Windows-Feature-Updates.

**Funktion:**
- Prüft ob Sperre existiert
- Entfernt Registry-Einträge

**Verwendung:**
```powershell
.\upgrade_unlock.ps1
```

---

## 🚀 Installation in Tactical RMM

### Linux Scripts
1. Script in Tactical RMM hochladen
2. Shell Type: **Bash**
3. Platform: **Linux**
4. Ausführungsrechte werden automatisch gesetzt

### Windows Scripts
1. Script in Tactical RMM hochladen
2. Shell Type: **PowerShell**
3. Platform: **Windows**
4. Bei Bedarf: "Run as Administrator" aktivieren

---

## 📊 Exit Code Konvention

Alle Scripts folgen der Tactical RMM Konvention:

| Exit Code | Bedeutung | Tactical RMM Status |
|-----------|-----------|---------------------|
| `0` | Erfolg / OK | ✅ Informational |
| `1` | Fehler / Warnung | ⚠️ Warning/Error |
| `2` | Kritischer Fehler | 🔴 Critical (nur bei einigen Scripts) |

---

## 🔧 Voraussetzungen

### Linux
- Bash Shell
- Ggf. zusätzliche Pakete:
  - `smartmontools` (für SMART Check)
  - `zfsutils-linux` (für ZFS Check)
  - `unattended-upgrades` (für Unattended-Upgrades Check)

### Windows
- PowerShell 5.1 oder höher
- Administrator-Rechte (bei den meisten Scripts)
- Optional:
  - `winget` (für Software-Updates)
  - `Chocolatey` (für Software-Updates)

---

## 📝 Lizenz

Diese Scripts werden "as-is" zur Verfügung gestellt.

---

## 🤝 Beiträge

Contributions sind willkommen! Bitte erstellen Sie einen Pull Request oder öffnen Sie ein Issue.

---

## ⚠️ Haftungsausschluss

Diese Scripts wurden für den produktiven Einsatz entwickelt, aber: **Testen Sie immer zuerst in einer Testumgebung!**
Kein Haftung auf Schäden!

Besonders bei:
- Update-Scripts
- Registry-Änderungen (upgrade_block/unlock)
- Storage-Checks auf Produktivsystemen
