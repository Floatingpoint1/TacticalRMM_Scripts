#!/bin/bash

#######################################################
# Rainer IT Services - Reboot Required Check
# Prueft ob ein System-Neustart aussteht
# Platform: Linux (Debian/Ubuntu)
# Shell Type: Bash
#######################################################

echo "=== REBOOT REQUIRED CHECK ==="
echo "Start: $(date '+%d.%m.%Y %H:%M:%S')"
echo ""

# Flags fuer verschiedene Pruefungen
REBOOT_REQUIRED=0
REBOOT_REASONS=()

echo "--- PRUEFUNGEN DURCHFUEHREN ---"
echo ""

# 1. Standard Debian/Ubuntu Reboot-Required File
echo "[1/4] Pruefe /var/run/reboot-required..."
if [ -f /var/run/reboot-required ]; then
    echo "  >> NEUSTART ERFORDERLICH"
    REBOOT_REQUIRED=1
    
    # Zeige Gruende an falls verfuegbar
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo ""
        echo "  Betroffene Pakete:"
        while IFS= read -r pkg; do
            echo "    - $pkg"
            REBOOT_REASONS+=("Paket: $pkg")
        done < /var/run/reboot-required.pkgs
    fi
else
    echo "  >> OK - Kein Standard-Reboot-Flag"
fi
echo ""

# 2. Kernel-Version pruefen
echo "[2/4] Pruefe Kernel-Version..."
RUNNING_KERNEL=$(uname -r)
INSTALLED_KERNEL=$(dpkg -l | grep -E "^ii.*linux-image-[0-9]" | awk '{print $2}' | sed 's/linux-image-//' | sort -V | tail -n1)

echo "  Laufender Kernel: $RUNNING_KERNEL"
echo "  Installierter Kernel: $INSTALLED_KERNEL"

if [ "$RUNNING_KERNEL" != "$INSTALLED_KERNEL" ]; then
    echo "  >> NEUSTART ERFORDERLICH - Kernel wurde aktualisiert"
    REBOOT_REQUIRED=1
    REBOOT_REASONS+=("Kernel-Update: $RUNNING_KERNEL -> $INSTALLED_KERNEL")
else
    echo "  >> OK - Kernel ist aktuell"
fi
echo ""

# 3. Systemd pruefen (falls verfuegbar)
echo "[3/4] Pruefe Systemd Units..."
if command -v systemctl &> /dev/null; then
    # Pruefe ob systemd-Daemon selbst neu geladen werden muss
    if systemctl status systemd-logind.service 2>/dev/null | grep -q "binary changed on disk"; then
        echo "  >> NEUSTART EMPFOHLEN - Systemd-Komponenten aktualisiert"
        REBOOT_REQUIRED=1
        REBOOT_REASONS+=("Systemd-Daemon aktualisiert")
    else
        echo "  >> OK - Systemd ist aktuell"
    fi
else
    echo "  >> UEBERSPRUNGEN - Systemd nicht verfuegbar"
fi
echo ""

# 4. Pruefe auf laufende Prozesse mit geloeschten Bibliotheken
echo "[4/4] Pruefe laufende Prozesse mit veralteten Bibliotheken..."

# Zaehle Prozesse die geloeschte/aktualisierte Libs nutzen
OBSOLETE_PROCS=0

if command -v lsof &> /dev/null; then
    # Suche nach Prozessen mit (deleted) Bibliotheken
    DELETED_LIBS=$(lsof 2>/dev/null | grep -E "DEL.*lib" | wc -l)
    
    if [ "$DELETED_LIBS" -gt 0 ]; then
        echo "  >> INFO: $DELETED_LIBS Prozesse nutzen aktualisierte Bibliotheken"
        
        # Zeige betroffene Services
        AFFECTED_SERVICES=$(lsof 2>/dev/null | grep -E "DEL.*lib" | awk '{print $1}' | sort -u | head -n 10)
        
        if [ -n "$AFFECTED_SERVICES" ]; then
            echo ""
            echo "  Betroffene Prozesse (Top 10):"
            echo "$AFFECTED_SERVICES" | while read -r proc; do
                echo "    - $proc"
            done
            
            # Kritische System-Dienste pruefen
            if echo "$AFFECTED_SERVICES" | grep -qE "systemd|init|sshd|dbus"; then
                echo ""
                echo "  >> NEUSTART EMPFOHLEN - Kritische System-Dienste betroffen"
                REBOOT_REQUIRED=1
                REBOOT_REASONS+=("Kritische System-Dienste nutzen alte Bibliotheken")
            fi
        fi
    else
        echo "  >> OK - Alle Prozesse nutzen aktuelle Bibliotheken"
    fi
else
    echo "  >> UEBERSPRUNGEN - lsof nicht installiert"
fi
echo ""

# Alternative: needrestart Tool (falls installiert)
if command -v needrestart &> /dev/null; then
    echo "--- NEEDRESTART ANALYSE ---"
    echo ""
    
    # Fuehre needrestart im Batch-Mode aus
    NEEDRESTART_OUTPUT=$(needrestart -b 2>/dev/null)
    
    if echo "$NEEDRESTART_OUTPUT" | grep -q "NEEDRESTART-KSTA: 1"; then
        echo "  >> NEUSTART ERFORDERLICH (needrestart)"
        REBOOT_REQUIRED=1
        REBOOT_REASONS+=("needrestart erkennt Kernel-Neustart")
    elif echo "$NEEDRESTART_OUTPUT" | grep -q "NEEDRESTART-KSTA: 2"; then
        echo "  >> INFO: Microcode-Update verfuegbar"
    elif echo "$NEEDRESTART_OUTPUT" | grep -q "NEEDRESTART-KSTA: 3"; then
        echo "  >> OK - Kein Kernel-Neustart noetig"
    fi
    echo ""
fi

# Zusammenfassung
echo "=========================================="
echo "ZUSAMMENFASSUNG"
echo "=========================================="

if [ $REBOOT_REQUIRED -eq 1 ]; then
    echo "Status: NEUSTART ERFORDERLICH"
    echo ""
    echo "Gruende:"
    for reason in "${REBOOT_REASONS[@]}"; do
        echo "  - $reason"
    done
    echo ""
    
    # Zeige Uptime
    UPTIME=$(uptime -p 2>/dev/null || uptime)
    echo "Aktuelle Uptime: $UPTIME"
    echo ""
    
    echo "=== ERGEBNIS: WARNUNG ==="
    echo "Ein System-Neustart wird empfohlen!"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
else
    echo "Status: KEIN NEUSTART ERFORDERLICH"
    echo ""
    
    # Zeige Uptime
    UPTIME=$(uptime -p 2>/dev/null || uptime)
    echo "Aktuelle Uptime: $UPTIME"
    echo ""
    
    echo "=== ERGEBNIS: OK ==="
    echo "System ist aktuell, kein Neustart noetig."
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
fi
