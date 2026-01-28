#!/bin/bash

#######################################################
# Rainer IT Services Tactical RMM - 
# Prueft den Status aller ZFS Storage Pools
# Platform: Linux (Debian/Ubuntu)
# Shell Type: Bash
#######################################################

echo "=== ZFS POOL HEALTH CHECK ==="
echo "Start: $(date '+%d.%m.%Y %H:%M:%S')"
echo ""

# Zaehler fuer Probleme
CRITICAL_COUNT=0
WARNING_COUNT=0
TOTAL_POOLS=0

# Pruefe ob ZFS installiert ist
if ! command -v zpool &> /dev/null; then
    echo "FEHLER: ZFS ist nicht installiert!"
    echo "Installation mit: sudo apt-get install zfsutils-linux"
    echo ""
    echo "=== ERGEBNIS: FEHLER ==="
    exit 1
fi

echo "--- ZFS POOLS SCANNEN ---"
echo ""

# Finde alle ZFS Pools
POOLS=$(zpool list -H -o name 2>/dev/null)

if [ -z "$POOLS" ]; then
    echo "INFO: Keine ZFS Pools gefunden"
    echo ""
    echo "=== ERGEBNIS: OK ==="
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
fi

echo "Gefundene ZFS Pools:"
for pool in $POOLS; do
    echo "  - $pool"
    TOTAL_POOLS=$((TOTAL_POOLS + 1))
done
echo ""
echo "Gesamtanzahl: $TOTAL_POOLS"
echo ""

# Funktion: Pruefe einzelnen Pool
check_pool() {
    local pool=$1
    local pool_status=""
    local pool_health=""
    
    echo "=========================================="
    echo "Pool: $pool"
    echo "=========================================="
    
    # Hole Pool-Informationen
    pool_health=$(zpool list -H -o health "$pool" 2>/dev/null)
    pool_status=$(zpool status "$pool" 2>/dev/null)
    
    # 1. Pool Health Status
    echo "  Health Status: $pool_health"
    
    case "$pool_health" in
        "ONLINE")
            echo "    >> OK - Pool ist gesund"
            ;;
        "DEGRADED")
            echo "    >> WARNUNG - Pool ist degradiert (Disk ausgefallen?)"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            ;;
        "FAULTED")
            echo "    >> KRITISCH - Pool ist fehlerhaft!"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
            ;;
        "OFFLINE")
            echo "    >> KRITISCH - Pool ist offline!"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
            ;;
        "UNAVAIL")
            echo "    >> KRITISCH - Pool ist nicht verfuegbar!"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
            ;;
        "REMOVED")
            echo "    >> KRITISCH - Pool wurde entfernt!"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
            ;;
        *)
            echo "    >> UNBEKANNT - Status: $pool_health"
            WARNING_COUNT=$((WARNING_COUNT + 1))
            ;;
    esac
    echo ""
    
    # 2. Kapazitaet
    capacity=$(zpool list -H -o capacity "$pool" 2>/dev/null | tr -d '%')
    size=$(zpool list -H -o size "$pool" 2>/dev/null)
    allocated=$(zpool list -H -o allocated "$pool" 2>/dev/null)
    free=$(zpool list -H -o free "$pool" 2>/dev/null)
    
    echo "  Kapazitaet:"
    echo "    - Groesse: $size"
    echo "    - Belegt: $allocated (${capacity}%)"
    echo "    - Frei: $free"
    
    if [ "$capacity" -ge 90 ]; then
        echo "    >> WARNUNG: Pool ist zu ${capacity}% voll!"
        WARNING_COUNT=$((WARNING_COUNT + 1))
    elif [ "$capacity" -ge 80 ]; then
        echo "    >> Info: Pool ist zu ${capacity}% voll"
    fi
    echo ""
    
    # 3. Errors
    read_errors=$(zpool status "$pool" | grep -E "errors:" | head -n1 | awk '{print $NF}')
    write_errors=$(zpool status "$pool" | grep -E "errors:" | sed -n '2p' | awk '{print $NF}')
    cksum_errors=$(zpool status "$pool" | grep -E "errors:" | sed -n '3p' | awk '{print $NF}')
    
    echo "  Errors:"
    echo "    - Read Errors: ${read_errors:-0}"
    echo "    - Write Errors: ${write_errors:-0}"
    echo "    - Checksum Errors: ${cksum_errors:-0}"
    
    # Pruefe auf Errors (nur wenn nicht "No known data errors")
    if echo "$pool_status" | grep -qi "No known data errors"; then
        echo "    >> OK - Keine Fehler"
    else
        # Zaehle tatsaechliche Errors
        total_errors=0
        if [ "$read_errors" != "0" ] && [ "$read_errors" != "No" ]; then
            total_errors=$((total_errors + 1))
        fi
        if [ "$write_errors" != "0" ] && [ "$write_errors" != "No" ]; then
            total_errors=$((total_errors + 1))
        fi
        if [ "$cksum_errors" != "0" ] && [ "$cksum_errors" != "No" ]; then
            total_errors=$((total_errors + 1))
        fi
        
        if [ $total_errors -gt 0 ]; then
            echo "    >> KRITISCH - Fehler gefunden!"
            CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
        fi
    fi
    echo ""
    
    # 4. Scrub Status
    scrub_status=$(zpool status "$pool" | grep -A1 "scan:" | head -n2)
    
    echo "  Scrub Status:"
    if echo "$scrub_status" | grep -qi "scrub in progress"; then
        scrub_progress=$(echo "$scrub_status" | grep -o "[0-9.]*%" | head -n1)
        echo "    - Status: In Progress (${scrub_progress:-0%})"
    elif echo "$scrub_status" | grep -qi "scrub repaired"; then
        scrub_date=$(echo "$scrub_status" | grep -oP '(?<=on ).*')
        echo "    - Status: Abgeschlossen"
        echo "    - Letzter Scrub: $scrub_date"
        
        # Pruefe ob Daten repariert wurden
        if echo "$scrub_status" | grep "0B repaired" >/dev/null; then
            echo "    >> OK - Keine Reparaturen noetig"
        else
            repaired=$(echo "$scrub_status" | grep -oP '\d+[KMGT]?B repaired')
            echo "    >> WARNUNG - Daten repariert: $repaired"
            WARNING_COUNT=$((WARNING_COUNT + 1))
        fi
    elif echo "$scrub_status" | grep -qi "none requested"; then
        echo "    - Status: Noch nie ausgefuehrt"
        echo "    >> Info: Scrub wurde noch nie ausgefuehrt"
    else
        echo "    - Status: Unbekannt"
    fi
    echo ""
    
    # 5. Device Status (alle vdevs/disks)
    echo "  Geraete Status:"
    
    # Hole alle Devices im Pool
    devices=$(zpool status "$pool" | grep -E "^\s+(sd[a-z]+|nvme[0-9]+n[0-9]+|wwn-|ata-|scsi-)" | awk '{print $1, $2}')
    
    if [ -n "$devices" ]; then
        while IFS= read -r device_line; do
            device_name=$(echo "$device_line" | awk '{print $1}')
            device_state=$(echo "$device_line" | awk '{print $2}')
            
            case "$device_state" in
                "ONLINE")
                    echo "    - $device_name: $device_state (OK)"
                    ;;
                "DEGRADED")
                    echo "    - $device_name: $device_state (WARNUNG!)"
                    WARNING_COUNT=$((WARNING_COUNT + 1))
                    ;;
                "FAULTED"|"UNAVAIL"|"OFFLINE"|"REMOVED")
                    echo "    - $device_name: $device_state (KRITISCH!)"
                    CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
                    ;;
                *)
                    echo "    - $device_name: $device_state"
                    ;;
            esac
        done <<< "$devices"
    else
        echo "    - Keine einzelnen Devices gefunden (Mirror/RaidZ?)"
    fi
    echo ""
    
    # 6. Zeige Status Messages
    if echo "$pool_status" | grep -qi "action:\|errors:"; then
        action_msg=$(zpool status "$pool" | sed -n '/action:/,/see:/p' | grep -v "see:")
        if [ -n "$action_msg" ]; then
            echo "  Aktionen erforderlich:"
            echo "$action_msg" | sed 's/^/    /'
            echo ""
        fi
    fi
}

# Pruefe alle Pools
for pool in $POOLS; do
    check_pool "$pool"
done

# Zusammenfassung
echo "=========================================="
echo "ZUSAMMENFASSUNG"
echo "=========================================="
echo "Geprueft: $TOTAL_POOLS Pool(s)"
echo "Kritische Probleme: $CRITICAL_COUNT"
echo "Warnungen: $WARNING_COUNT"
echo ""

# Entscheidung
if [ $CRITICAL_COUNT -gt 0 ]; then
    echo "=== ERGEBNIS: FEHLER ==="
    echo "Es wurden $CRITICAL_COUNT kritische Probleme gefunden!"
    echo "Bitte ueberpruefen Sie die betroffenen ZFS Pools!"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 1
elif [ $WARNING_COUNT -gt 0 ]; then
    echo "=== ERGEBNIS: WARNUNG ==="
    echo "Es wurden $WARNING_COUNT Warnungen gefunden."
    echo "Empfehlung: ZFS Pools weiter beobachten."
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
else
    echo "=== ERGEBNIS: OK ==="
    echo "Alle ZFS Pools sind gesund!"
    echo ""
    echo "Ende: $(date '+%d.%m.%Y %H:%M:%S')"
    exit 0
fi
