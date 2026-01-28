#!/bin/bash

#######################################################
# Rainer IT Services® TacticalRMM - Unattended-Upgrades Check
# Prueft Installation, Konfiguration und Funktionalitaet
# Platform: Linux (Debian/Ubuntu)
# Shell Type: Bash
# Exit Codes:
#   0 = Alles OK
#   1 = Fehler gefunden
#######################################################

echo "=========================================="
echo "Rainer IT Services® Unattended-Upgrades Check"
echo "=========================================="
echo "Start: $(date '+%d.%m.%Y %H:%M:%S')"
echo ""

# Zaehler fuer Probleme
ERRORS=0
WARNINGS=0
CHECKS_PASSED=0
TOTAL_CHECKS=0

# Funktion: Check durchfuehren
check() {
    local check_name=$1
    local check_result=$2
    local is_critical=${3:-1}  # Standard: kritisch (1=kritisch, 0=warnung)
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$check_result" -eq 0 ]; then
        echo "  ✓ $check_name"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        return 0
    else
        if [ "$is_critical" -eq 1 ]; then
            echo "  ✗ $check_name (FEHLER)"
            ERRORS=$((ERRORS + 1))
        else
            echo "  ⚠ $check_name (WARNUNG)"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    fi
}

#######################################################
# 1. SYSTEM-PRUEFUNG
#######################################################

echo "--- SYSTEM-PRUEFUNG ---"
echo ""

# OS-Erkennung
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=$ID
    OS_VERSION_CODENAME=$VERSION_CODENAME
    OS_NAME=$PRETTY_NAME
    echo "Betriebssystem: $OS_NAME"
    echo "OS-ID: $OS_ID"
    echo "Codename: $OS_VERSION_CODENAME"
    echo ""
else
    echo "FEHLER: Konnte /etc/os-release nicht finden!"
    ERRORS=$((ERRORS + 1))
fi

# Pruefen ob Debian oder Ubuntu
if [[ "$OS_ID" != "debian" && "$OS_ID" != "ubuntu" ]]; then
    echo "WARNUNG: Dieses System ist weder Debian noch Ubuntu!"
    WARNINGS=$((WARNINGS + 1))
fi

#######################################################
# 2. VIRTUALISIERUNGS-ERKENNUNG
#######################################################

echo "--- VIRTUALISIERUNGS-PRUEFUNG ---"
echo ""

IS_VIRTUAL=0
VIRT_TYPE=""

# Virtualisierung erkennen
if command -v systemd-detect-virt &> /dev/null; then
    VIRT_DETECT=$(systemd-detect-virt 2>/dev/null)
    if [ "$VIRT_DETECT" != "none" ] && [ -n "$VIRT_DETECT" ]; then
        IS_VIRTUAL=1
        VIRT_TYPE="$VIRT_DETECT"
    fi
fi

# LXC Container Check
if [ -f /proc/1/environ ]; then
    if grep -qa "container=lxc" /proc/1/environ 2>/dev/null; then
        IS_VIRTUAL=1
        VIRT_TYPE="lxc"
    fi
fi

if [ $IS_VIRTUAL -eq 1 ]; then
    echo "Umgebung: VIRTUALISIERT ($VIRT_TYPE)"
else
    echo "Umgebung: PHYSISCH"
fi
echo ""

#######################################################
# 3. PAKET-INSTALLATION PRUEFEN
#######################################################

echo "--- PAKET-INSTALLATION ---"
echo ""

# unattended-upgrades installiert?
if dpkg -l | grep -q "^ii  unattended-upgrades"; then
    PACKAGE_VERSION=$(dpkg -l | grep "^ii  unattended-upgrades" | awk '{print $3}')
    check "unattended-upgrades installiert (Version: $PACKAGE_VERSION)" 0 1
else
    check "unattended-upgrades installiert" 1 1
fi

echo ""

#######################################################
# 4. KONFIGURATIONSDATEIEN PRUEFEN
#######################################################

echo "--- KONFIGURATIONSDATEIEN ---"
echo ""

# 50unattended-upgrades vorhanden?
CONFIG_FILE="/etc/apt/apt.conf.d/50unattended-upgrades"
if [ -f "$CONFIG_FILE" ]; then
    check "$CONFIG_FILE vorhanden" 0 1
    
    # Pruefen ob Datei nicht leer ist
    if [ -s "$CONFIG_FILE" ]; then
        check "$CONFIG_FILE nicht leer" 0 1
    else
        check "$CONFIG_FILE nicht leer" 1 1
    fi
    
    # Pruefen ob Origins-Pattern definiert ist
    if grep -q "Unattended-Upgrade::Origins-Pattern" "$CONFIG_FILE" 2>/dev/null; then
        check "Origins-Pattern konfiguriert" 0 1
    else
        check "Origins-Pattern konfiguriert" 1 1
    fi
    
    # Pruefen ob mindestens Debian/Ubuntu Security aktiviert ist
    if grep -E "origin=Debian.*security|origin=Ubuntu.*security" "$CONFIG_FILE" | grep -v "^//" | grep -q "origin"; then
        check "Security-Updates aktiviert" 0 1
    else
        check "Security-Updates aktiviert" 1 1
    fi
    
    # Pruefen ob Remove-Unused-Dependencies gesetzt ist
    if grep -q "Unattended-Upgrade::Remove-Unused-Dependencies" "$CONFIG_FILE" 2>/dev/null; then
        if grep "Unattended-Upgrade::Remove-Unused-Dependencies" "$CONFIG_FILE" | grep -v "^//" | grep -q "true"; then
            check "Automatische Bereinigung aktiviert" 0 0
        else
            check "Automatische Bereinigung aktiviert" 1 0
        fi
    else
        check "Automatische Bereinigung konfiguriert" 1 0
    fi
    
else
    check "$CONFIG_FILE vorhanden" 1 1
fi

# Dpkg::Options pruefen (in beliebiger apt.conf.d Datei)
DPKG_CHECK=0
if apt-config dump 2>/dev/null | grep -q "Dpkg::Options.*force-confold"; then
    DPKG_CHECK=0
elif [ -f "/etc/apt/apt.conf.d/02dpkg-options" ]; then
    if grep -q "force-confold" "/etc/apt/apt.conf.d/02dpkg-options" 2>/dev/null; then
        DPKG_CHECK=0
    else
        DPKG_CHECK=1
    fi
elif grep -q "Dpkg::Options" "$CONFIG_FILE" 2>/dev/null; then
    if grep "Dpkg::Options" "$CONFIG_FILE" | grep -v "^//" | grep -q "force-confold"; then
        DPKG_CHECK=0
    else
        DPKG_CHECK=1
    fi
else
    DPKG_CHECK=1
fi

check "Dpkg-Optionen konfiguriert (non-interactive)" $DPKG_CHECK 1

# 10periodic oder 20auto-upgrades vorhanden?
PERIODIC_FILE="/etc/apt/apt.conf.d/10periodic"
AUTO_UPGRADES_FILE="/etc/apt/apt.conf.d/20auto-upgrades"

if [ -f "$PERIODIC_FILE" ]; then
    check "$PERIODIC_FILE vorhanden" 0 1
    ACTIVE_CONFIG="$PERIODIC_FILE"
elif [ -f "$AUTO_UPGRADES_FILE" ]; then
    check "$AUTO_UPGRADES_FILE vorhanden" 0 1
    ACTIVE_CONFIG="$AUTO_UPGRADES_FILE"
else
    check "Periodic-Konfiguration vorhanden" 1 1
    ACTIVE_CONFIG=""
fi

# Pruefen ob Periodic aktiviert ist
if [ -n "$ACTIVE_CONFIG" ] && [ -f "$ACTIVE_CONFIG" ]; then
    # Pruefen ob Unattended-Upgrade aktiviert ist
    if grep -q 'APT::Periodic::Unattended-Upgrade.*"1"' "$ACTIVE_CONFIG" 2>/dev/null; then
        check "Automatische Updates aktiviert" 0 1
    else
        check "Automatische Updates aktiviert" 1 1
    fi
    
    # Pruefen ob Update-Package-Lists aktiviert ist
    if grep -q 'APT::Periodic::Update-Package-Lists.*"1"' "$ACTIVE_CONFIG" 2>/dev/null; then
        check "Paketlisten-Update aktiviert" 0 1
    else
        check "Paketlisten-Update aktiviert" 1 0
    fi
fi

echo ""

#######################################################
# 5. SYSTEMD-SERVICE PRUEFEN
#######################################################

echo "--- SYSTEMD-DIENSTE ---"
echo ""

# apt-daily.timer
if systemctl is-enabled apt-daily.timer &>/dev/null; then
    check "apt-daily.timer enabled" 0 1
else
    check "apt-daily.timer enabled" 1 1
fi

if systemctl is-active apt-daily.timer &>/dev/null; then
    check "apt-daily.timer active" 0 1
else
    check "apt-daily.timer active" 1 1
fi

# apt-daily-upgrade.timer
if systemctl is-enabled apt-daily-upgrade.timer &>/dev/null; then
    check "apt-daily-upgrade.timer enabled" 0 1
else
    check "apt-daily-upgrade.timer enabled" 1 1
fi

if systemctl is-active apt-daily-upgrade.timer &>/dev/null; then
    check "apt-daily-upgrade.timer active" 0 1
else
    check "apt-daily-upgrade.timer active" 1 1
fi

echo ""

#######################################################
# 6. LETZTE AUSFUEHRUNG PRUEFEN
#######################################################

echo "--- LETZTE AUSFUEHRUNG ---"
echo ""

LOG_FILE="/var/log/unattended-upgrades/unattended-upgrades.log"

if [ -f "$LOG_FILE" ]; then
    check "Log-Datei vorhanden" 0 1
    
    # Letzte Ausfuehrung finden
    LAST_RUN=$(grep -E "INFO (Starting|Stopping) unattended upgrades script" "$LOG_FILE" 2>/dev/null | tail -n 1 | grep -oP '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}')
    
    if [ -n "$LAST_RUN" ]; then
        echo "  Letzte Ausfuehrung: $LAST_RUN"
        
        # Pruefen ob letzter Lauf innerhalb der letzten 7 Tage war
        LAST_RUN_TIMESTAMP=$(date -d "$LAST_RUN" +%s 2>/dev/null || echo "0")
        CURRENT_TIMESTAMP=$(date +%s)
        
        if [ "$LAST_RUN_TIMESTAMP" -gt 0 ]; then
            DAYS_AGO=$(( (CURRENT_TIMESTAMP - LAST_RUN_TIMESTAMP) / 86400 ))
            echo "  Tage seit letzter Ausfuehrung: $DAYS_AGO"
            
            if [ "$DAYS_AGO" -le 2 ]; then
                check "Letzte Ausfuehrung aktuell (<= 2 Tage)" 0 0
            elif [ "$DAYS_AGO" -le 7 ]; then
                check "Letzte Ausfuehrung aktuell (<= 7 Tage)" 1 0
            else
                check "Letzte Ausfuehrung aktuell" 1 1
            fi
        else
            echo "  WARNUNG: Konnte Zeitstempel nicht parsen"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo "  WARNUNG: Keine Ausfuehrung im Log gefunden"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    # Pruefen auf Fehler im Log - ROBUSTER mit tr
    ERROR_COUNT=$(grep "ERROR" "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' \n')
    ERROR_COUNT=${ERROR_COUNT:-0}  # Fallback auf 0 wenn leer
    
    if [ "$ERROR_COUNT" -gt 0 ] 2>/dev/null; then
        echo "  Fehler im Log gefunden: $ERROR_COUNT"
        check "Keine Fehler im Log" 1 0
    else
        check "Keine Fehler im Log" 0 0
    fi
    
else
    check "Log-Datei vorhanden" 1 0
    echo "  HINWEIS: Moeglicherweise wurde unattended-upgrades noch nie ausgefuehrt"
fi

echo ""

#######################################################
# 7. LOCALE-PRUEFUNG
#######################################################

echo "--- LOCALE-KONFIGURATION ---"
echo ""

# Pruefen ob Locales korrekt konfiguriert sind
if locale -a 2>/dev/null | grep -q "de_DE.utf8\|de_DE.UTF-8"; then
    check "Deutsche Locale vorhanden" 0 0
else
    check "Deutsche Locale vorhanden" 1 0
fi

if locale -a 2>/dev/null | grep -q "en_US.utf8\|en_US.UTF-8"; then
    check "Englische Locale vorhanden" 0 0
else
    check "Englische Locale vorhanden" 1 0
fi

# Pruefen ob powermgmt-base installiert ist (verhindert Warnungen)
if dpkg -l | grep -q "^ii  powermgmt-base"; then
    check "powermgmt-base installiert" 0 0
else
    check "powermgmt-base installiert (verhindert Warnungen)" 1 0
fi

echo ""

#######################################################
# 8. DRY-RUN TEST
#######################################################

echo "--- FUNKTIONALITAETS-TEST (DRY-RUN) ---"
echo ""

if command -v unattended-upgrade &> /dev/null; then
    echo "Fuehre Test-Lauf durch (kann 10-30 Sekunden dauern)..."
    
    # Dry-Run ausfuehren und auf Fehler pruefen
    DRY_RUN_OUTPUT=$(unattended-upgrade --dry-run 2>&1)
    DRY_RUN_EXIT=$?
    
    if [ $DRY_RUN_EXIT -eq 0 ]; then
        check "Dry-Run erfolgreich" 0 1
    else
        check "Dry-Run erfolgreich" 1 1
        echo "  Fehlerausgabe (letzte 10 Zeilen):"
        echo "$DRY_RUN_OUTPUT" | tail -n 10 | sed 's/^/    /'
    fi
    
    # Pruefen ob Updates gefunden wurden
    if echo "$DRY_RUN_OUTPUT" | grep -q "Packages that will be upgraded"; then
        UPGRADE_COUNT=$(echo "$DRY_RUN_OUTPUT" | grep -A 20 "Packages that will be upgraded" | grep -c "^  " | tr -d ' \n')
        echo "  Verfuegbare Updates: ${UPGRADE_COUNT:-0}"
    fi
else
    check "unattended-upgrade Befehl verfuegbar" 1 1
fi

echo ""

#######################################################
# 9. ZUSAMMENFASSUNG
#######################################################

echo "=========================================="
echo "ZUSAMMENFASSUNG"
echo "=========================================="
echo ""
echo "Durchgefuehrte Checks: $TOTAL_CHECKS"
echo "Bestanden: $CHECKS_PASSED"
echo "Fehler: $ERRORS"
echo "Warnungen: $WARNINGS"
echo ""

# Bewertung
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "=== ERGEBNIS: OK ==="
    echo "Unattended-upgrades ist korrekt installiert und konfiguriert!"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
elif [ $ERRORS -eq 0 ] && [ $WARNINGS -gt 0 ]; then
    echo "=== ERGEBNIS: OK (MIT WARNUNGEN) ==="
    echo "Unattended-upgrades funktioniert, aber es gibt $WARNINGS Warnung(en)."
    echo "Empfehlung: Konfiguration optimieren."
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
else
    echo "=== ERGEBNIS: FEHLER ==="
    echo "Es wurden $ERRORS kritische Fehler gefunden!"
    echo ""
    echo "EMPFOHLENE MASSNAHMEN:"
    echo "  1. Rainer IT Services Unattended-Upgrades Installer ausfuehren"
    echo "  2. Konfiguration manuell pruefen: $CONFIG_FILE"
    echo "  3. Systemd-Timer pruefen: systemctl status apt-daily.timer"
    echo "  4. Logs pruefen: /var/log/unattended-upgrades/"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    
    # TacticalRMM Fehlermeldung
    echo ""
    echo "ERROR: Unattended-upgrades ist nicht korrekt konfiguriert! ($ERRORS Fehler, $WARNINGS Warnungen)"
    exit 1
fi
