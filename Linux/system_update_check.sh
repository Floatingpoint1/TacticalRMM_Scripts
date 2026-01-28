#!/bin/bash

# Skript zur Überprüfung verfügbarer Updates auf Debian/Ubuntu-Systemen
# Rainer IT Services® - System Update Check Script für TacticalRMM
# Version: 1.1 (sprachunabhängig)

# Exit Codes für TacticalRMM
# 0 = Alles OK, keine Updates
# 1 = Updates verfügbar

echo "================================"
echo "Rainer IT Services® System Update Check"
echo "================================"
echo ""

# Prüfen ob als Root ausgeführt wird
if [ "$EUID" -ne 0 ]; then 
    echo "FEHLER: Skript muss als Root/sudo ausgeführt werden!"
    exit 1
fi

# Paketlisten aktualisieren
echo "[1/3] Aktualisiere Paketlisten..."
apt-get update -qq 2>/dev/null || apt update -qq 2>/dev/null

# Verfügbare Updates zählen (sprachunabhängig - ignoriert erste Zeile)
UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)

echo ""
echo "[2/3] Prüfe verfügbare Updates..."
echo ""

if [ "$UPDATES" -eq 0 ]; then
    echo "✓ System ist auf dem neuesten Stand!"
    echo "  Alle Pakete sind aktuell installiert."
    exit 0
else
    echo "⚠ Es sind $UPDATES Update(s) verfügbar:"
    echo ""
    
    # Temporäre Datei für die Ausgabe
    TEMP_FILE=$(mktemp)
    
    # Header
    printf "%-40s %-20s %-20s %-15s\n" "PAKET" "INSTALLIERT" "VERFÜGBAR" "VERFÜGBAR SEIT"
    printf "%-40s %-20s %-20s %-15s\n" "========================================" "====================" "====================" "==============="
    
    # Updates auflisten mit Details (erste Zeile überspringen)
    apt list --upgradable 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        PACKAGE=$(echo "$line" | cut -d'/' -f1)
        AVAILABLE_VERSION=$(echo "$line" | grep -oP '\d+[^\s]+' | head -1)
        INSTALLED_VERSION=$(dpkg -l | grep "^ii  $PACKAGE " | awk '{print $3}' | head -1)
        
        # Datum des verfügbaren Pakets ermitteln
        PKG_DATE=$(apt-cache show "$PACKAGE" 2>/dev/null | grep -i "^Date:" | head -1 | cut -d':' -f2- | xargs)
        
        if [ -z "$PKG_DATE" ]; then
            PKG_DATE="unbekannt"
        else
            # Datum formatieren (nur das Datum, nicht die Zeit)
            PKG_DATE=$(echo "$PKG_DATE" | grep -oP '\d{1,2}\s+\w+\s+\d{4}|\d{4}-\d{2}-\d{2}' | head -1)
            if [ -z "$PKG_DATE" ]; then
                PKG_DATE="unbekannt"
            fi
        fi
        
        printf "%-40s %-20s %-20s %-15s\n" "$PACKAGE" "$INSTALLED_VERSION" "$AVAILABLE_VERSION" "$PKG_DATE"
    done | tee "$TEMP_FILE"
    
    echo ""
    echo "[3/3] Zusammenfassung"
    echo "─────────────────────────────────────────"
    echo "Verfügbare Updates: $UPDATES"
    echo ""
    
    # Sicherheitsupdates prüfen (sprachunabhängig)
    SECURITY_UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2 | grep -iE "security|sicherheit" | wc -l)
    if [ "$SECURITY_UPDATES" -gt 0 ]; then
        echo "⚠ WICHTIG: $SECURITY_UPDATES Sicherheitsupdate(s) verfügbar!"
        echo ""
    fi
    
    echo "Führen Sie folgende Befehle aus, um Updates zu installieren:"
    echo "  sudo apt update"
    echo "  sudo apt upgrade"
    echo ""
    echo "Für automatische Installation:"
    echo "  sudo apt update && sudo apt upgrade -y"
    echo ""
    
    # Ausgabe in Log-Datei speichern (optional)
    LOG_DIR="/var/log/ris-update-check"
    if [ -w "/var/log" ] 2>/dev/null; then
        mkdir -p "$LOG_DIR" 2>/dev/null
        LOG_FILE="$LOG_DIR/update-check-$(date +%Y%m%d-%H%M%S).log"
        cp "$TEMP_FILE" "$LOG_FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "Log gespeichert unter: $LOG_FILE"
        fi
    fi
    
    rm -f "$TEMP_FILE"
    
    # TacticalRMM Fehlermeldung
    echo ""
    echo "ERROR: $UPDATES Update(s) verfügbar und müssen installiert werden!"
    
    exit 1
fi
