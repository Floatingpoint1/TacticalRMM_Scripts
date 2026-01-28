#!/bin/bash

#######################################################
# Rainer IT Services - Disk Health Check Script
# Prueft S.M.A.R.T. Status aller physischen Festplatten
# Platform: Linux (Debian/Ubuntu)
# Shell Type: Bash
#######################################################

echo "=== DISK HEALTH CHECK ==="
echo "Start: $(date '+%d.%m.%Y %H:%M:%S')"
echo ""

# Zaehler fuer Probleme
CRITICAL_COUNT=0
WARNING_COUNT=0
TOTAL_DISKS=0
CHECKED_DISKS=0

#######################################################
# PROXMOX VIRTUALISIERUNGS-ERKENNUNG
#######################################################

echo "--- UMGEBUNGS-PRUEFUNG ---"
echo ""

IS_VIRTUAL=0
VIRT_TYPE=""

# Methode 1: systemd-detect-virt
if command -v systemd-detect-virt &> /dev/null; then
    VIRT_DETECT=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_DETECT" != "none" ] && [ -n "$VIRT_DETECT" ]; then
        IS_VIRTUAL=1
        VIRT_TYPE="$VIRT_DETECT"
    fi
fi

# Methode 2: Pruefe auf LXC Container
if [ -f /proc/1/environ ]; then
    if grep -qa "container=lxc" /proc/1/environ 2>/dev/null; then
        IS_VIRTUAL=1
        VIRT_TYPE="lxc"
    fi
fi

# Methode 3: Pruefe auf Proxmox-spezifische Dateien
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    IS_VIRTUAL=1
    [ -z "$VIRT_TYPE" ] && VIRT_TYPE="container"
fi

# Methode 4: Pruefe /proc/cpuinfo auf Hypervisor
if grep -q "hypervisor" /proc/cpuinfo 2>/dev/null; then
    IS_VIRTUAL=1
    [ -z "$VIRT_TYPE" ] && VIRT_TYPE="vm"
fi

# Methode 5: Pruefe dmesg auf Hypervisor
if dmesg 2>/dev/null | grep -qi "hypervisor\|vmware\|virtualbox\|kvm\|qemu\|xen" 2>/dev/null; then
    IS_VIRTUAL=1
    [ -z "$VIRT_TYPE" ] && VIRT_TYPE="vm"
fi

# Methode 6: Pruefe DMI/SMBIOS
if [ -r /sys/class/dmi/id/product_name ]; then
    PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
    if echo "$PRODUCT_NAME" | grep -qi "kvm\|qemu\|virtual\|vmware\|virtualbox\|proxmox"; then
        IS_VIRTUAL=1
        [ -z "$VIRT_TYPE" ] && VIRT_TYPE="vm"
    fi
fi

# Auswertung
if [ $IS_VIRTUAL -eq 1 ]; then
    echo "Umgebung: VIRTUALISIERT ($VIRT_TYPE)"
    echo ""
    echo "HINWEIS: System laeuft in einem Proxmox Container oder VM."
    echo "S.M.A.R.T. Daten sind in virtualisierten Umgebungen nicht verfuegbar."
    echo "Festplatten-Gesundheit muss auf dem Proxmox-Host geprueft werden."
    echo ""
    echo "=== ERGEBNIS: OK (VIRTUALISIERT) ==="
    echo "Check wird uebersprungen - keine Aktion erforderlich."
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
else
    echo "Umgebung: PHYSISCH"
    echo "Fahre mit Festplatten-Check fort..."
    echo ""
fi

#######################################################
# FESTPLATTEN-CHECK (nur bei physischen Systemen)
#######################################################

# Pruefe ob smartmontools installiert ist
if ! command -v smartctl &> /dev/null; then
    echo "FEHLER: smartctl ist nicht installiert!"
    echo "Installation mit: sudo apt-get install smartmontools"
    echo ""
    echo "=== ERGEBNIS: FEHLER ==="
    exit 1
fi

echo "--- FESTPLATTEN SCANNEN ---"
echo ""

# Finde alle PHYSISCHEN Festplatten
# Excludiere: loop, zd (ZFS zvols), dm (device mapper), sr (CD-ROM)
DISKS=$(lsblk -d -n -o NAME,TYPE 2>/dev/null | grep -E "disk" | awk '{print $1}' | grep -v -E "^loop|^zd|^dm|^sr")

if [ -z "$DISKS" ]; then
    echo "WARNUNG: Keine physischen Festplatten gefunden!"
    echo ""
    echo "=== ERGEBNIS: OK (KEINE FESTPLATTEN) ==="
    exit 0
fi

echo "Gefundene physische Festplatten:"
for disk in $DISKS; do
    echo "  - /dev/$disk"
    TOTAL_DISKS=$((TOTAL_DISKS + 1))
done
echo ""
echo "Gesamtanzahl: $TOTAL_DISKS"
echo ""

# Funktion: Pruefe S.M.A.R.T. fuer eine Festplatte
check_disk() {
    local disk=$1
    local disk_path="/dev/$disk"
    
    echo "=========================================="
    echo "Festplatte: $disk_path"
    echo "=========================================="
    
    # Pruefe ob S.M.A.R.T. unterstuetzt wird
    if ! smartctl -i "$disk_path" &> /dev/null; then
        echo "  Status: KEINE S.M.A.R.T. UNTERSTUETZUNG"
        echo ""
        return 0
    fi
    
    CHECKED_DISKS=$((CHECKED_DISKS + 1))
    
    # Hole S.M.A.R.T. Informationen
    SMART_INFO=$(smartctl -a "$disk_path" 2>/dev/null)
    
    # 1. Modell und Seriennummer
    MODEL=$(echo "$SMART_INFO" | grep -E "Device Model|Model Number|Product" | head -n1 | sed 's/.*: *//' | xargs)
    SERIAL=$(echo "$SMART_INFO" | grep -i "Serial Number" | head -n1 | sed 's/.*: *//' | xargs)
    
    echo "  Modell: ${MODEL:-Unbekannt}"
    echo "  Seriennummer: ${SERIAL:-Unbekannt}"
    echo ""
    
    # 2. S.M.A.R.T. Gesamtstatus
    SMART_HEALTH=$(smartctl -H "$disk_path" 2>/dev/null)
    SMART_STATUS=$(echo "$SMART_HEALTH" | grep -i "SMART overall-health" | sed 's/.*: *//' | xargs)
    
    # Fallback fuer andere Formate
    if [ -z "$SMART_STATUS" ]; then
        SMART_STATUS=$(echo "$SMART_HEALTH" | grep -i "SMART Health Status" | sed 's/.*: *//' | xargs)
    fi
    
    echo "  S.M.A.R.T. Gesamtstatus: ${SMART_STATUS:-Nicht verfuegbar}"
    
    # Nur als KRITISCH werten wenn explizit FAILED/FAILING
    if echo "$SMART_STATUS" | grep -qi "PASSED\|OK"; then
        echo "    >> OK"
    elif echo "$SMART_STATUS" | grep -qi "FAIL"; then
        echo "    >> KRITISCH - Festplatte meldet Probleme!"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    elif [ -z "$SMART_STATUS" ]; then
        # Wenn Status nicht verfuegbar, pruefen wir die Attribute
        echo "    >> Status nicht verfuegbar (pruefen Attribute)"
    else
        echo "    >> Unbekannter Status: $SMART_STATUS"
    fi
    echo ""
    
    # 3. Wichtige S.M.A.R.T. Attribute pruefen
    echo "  Wichtige Attribute:"
    
    # Reallocated Sectors (ID 5)
    REALLOCATED=$(echo "$SMART_INFO" | grep -E "Reallocated_Sector_Ct|Reallocated_Event_Count" | head -n1 | awk '{print $10}')
    if [ -n "$REALLOCATED" ] && [ "$REALLOCATED" != "0" ] && [ "$REALLOCATED" != "-" ]; then
        echo "    - Reallocated Sectors: $REALLOCATED (WARNUNG!)"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        echo "    - Reallocated Sectors: ${REALLOCATED:-0} (OK)"
    fi
    
    # Current Pending Sectors (ID 197)
    PENDING=$(echo "$SMART_INFO" | grep "Current_Pending_Sector" | awk '{print $10}')
    if [ -n "$PENDING" ] && [ "$PENDING" != "0" ] && [ "$PENDING" != "-" ]; then
        echo "    - Pending Sectors: $PENDING (WARNUNG!)"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    else
        echo "    - Pending Sectors: ${PENDING:-0} (OK)"
    fi
    
    # Offline Uncorrectable (ID 198)
    UNCORRECTABLE=$(echo "$SMART_INFO" | grep "Offline_Uncorrectable" | awk '{print $10}')
    if [ -n "$UNCORRECTABLE" ] && [ "$UNCORRECTABLE" != "0" ] && [ "$UNCORRECTABLE" != "-" ]; then
        echo "    - Offline Uncorrectable: $UNCORRECTABLE (KRITISCH!)"
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
    else
        echo "    - Offline Uncorrectable: ${UNCORRECTABLE:-0} (OK)"
    fi
    
    # Temperatur
    TEMP=$(echo "$SMART_INFO" | grep -E "Temperature_Celsius|Temperature:|Current Drive Temperature" | head -n1 | awk '{print $10}')
    # Fallback falls nicht in Spalte 10
    if [ -z "$TEMP" ] || [ "$TEMP" = "-" ]; then
        TEMP=$(echo "$SMART_INFO" | grep -E "Temperature" | head -n1 | grep -o '[0-9]\+' | head -n1)
    fi
    
    if [ -n "$TEMP" ] && [ "$TEMP" != "-" ] && [ "$TEMP" -gt 0 ] 2>/dev/null; then
        echo "    - Temperatur: ${TEMP}°C"
        if [ "$TEMP" -gt 60 ]; then
            echo "      (WARNUNG: Ueber 60°C!)"
            WARNING_COUNT=$((WARNING_COUNT + 1))
        elif [ "$TEMP" -gt 50 ]; then
            echo "      (Info: Etwas warm)"
        fi
    fi
    
    # Power On Hours
    HOURS=$(echo "$SMART_INFO" | grep "Power_On_Hours" | awk '{print $10}')
    if [ -z "$HOURS" ] || [ "$HOURS" = "-" ]; then
        HOURS=$(echo "$SMART_INFO" | grep -E "power.on" | grep -o '[0-9]\+' | head -n1)
    fi
    
    if [ -n "$HOURS" ] && [ "$HOURS" != "-" ] && [ "$HOURS" -gt 0 ] 2>/dev/null; then
        DAYS=$((HOURS / 24))
        echo "    - Betriebsstunden: $HOURS Stunden ($DAYS Tage)"
    fi
    
    # Wear Leveling (fuer SSDs)
    WEAR=$(echo "$SMART_INFO" | grep -E "Wear_Leveling_Count|Media_Wearout_Indicator|Percentage Used" | head -n1 | awk '{print $4}')
    if [ -n "$WEAR" ] && [ "$WEAR" != "-" ] && [ "$WEAR" -gt 0 ] 2>/dev/null; then
        echo "    - SSD Abnutzung: $WEAR%"
        if [ "$WEAR" -lt 10 ]; then
            echo "      (WARNUNG: SSD stark abgenutzt!)"
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    fi
    
    echo ""
}

# Pruefe alle Festplatten
for disk in $DISKS; do
    check_disk "$disk"
done

# Zusammenfassung
echo "=========================================="
echo "ZUSAMMENFASSUNG"
echo "=========================================="
echo "Gefundene Festplatten: $TOTAL_DISKS"
echo "Geprueft (mit S.M.A.R.T.): $CHECKED_DISKS"
echo "Kritische Probleme: $CRITICAL_COUNT"
echo "Warnungen: $WARNING_COUNT"
echo ""

# Entscheidung
if [ $CHECKED_DISKS -eq 0 ]; then
    echo "=== ERGEBNIS: OK (KEINE S.M.A.R.T. FESTPLATTEN) ==="
    echo "Keine Festplatten mit S.M.A.R.T. Unterstuetzung gefunden."
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
elif [ $CRITICAL_COUNT -gt 0 ]; then
    echo "=== ERGEBNIS: FEHLER ==="
    echo "Es wurden $CRITICAL_COUNT kritische Probleme gefunden!"
    echo "Bitte ueberpruefen Sie die betroffenen Festplatten!"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    echo "=== ERGEBNIS: WARNUNG ==="
    echo "Es wurden $WARNING_COUNT Warnungen gefunden."
    echo "Empfehlung: Festplatten weiter beobachten."
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
else
    echo "=== ERGEBNIS: OK ==="
    echo "Alle Festplatten sind gesund!"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
fi
