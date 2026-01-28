#!/bin/bash
# Tactical RMM check (Proxmox VE):
# Prüft Proxmox-Logs auf:
#   "EFI disk without 'ms-cert=2023'"
#
# Exit 0 = OK / nicht PVE
# Exit 1 = Warning/Fail

set -u

PATTERN="EFI disk without 'ms-cert=2023'"

# --- Nur auf Proxmox VE ausführen ---
if [[ ! -d /etc/pve ]] || ! command -v pveversion >/dev/null 2>&1; then
  # Kein Proxmox -> OK und stoppen
  echo "OK: Not a Proxmox VE host."
  exit 0
fi

FOUND_LINES=""

# 1) systemd journal (letzte 30 Tage)
if command -v journalctl >/dev/null 2>&1; then
  JHITS="$(journalctl --no-pager --since "30 days ago" 2>/dev/null | grep -F "$PATTERN" || true)"
  if [[ -n "$JHITS" ]]; then
    FOUND_LINES+=$'\n'"[journalctl] "$'\n'"$JHITS"
  fi
fi

# 2) /var/log/pve/*
if [[ -d /var/log/pve ]]; then
  PHITS="$(grep -R -n -F "$PATTERN" /var/log/pve 2>/dev/null || true)"
  if [[ -n "$PHITS" ]]; then
    FOUND_LINES+=$'\n'"[/var/log/pve]"$'\n'"$PHITS"
  fi
fi

# 3) klassische Syslogs (fallback)
for f in /var/log/syslog /var/log/messages; do
  if [[ -f "$f" ]]; then
    SHITS="$(grep -n -F "$PATTERN" "$f" 2>/dev/null || true)"
    if [[ -n "$SHITS" ]]; then
      FOUND_LINES+=$'\n'"[$f]"$'\n'"$SHITS"
    fi
  fi
done

if [[ -n "$FOUND_LINES" ]]; then
  echo "WARNING: Found log entries matching: $PATTERN"
  # Ausgabe begrenzen (TRMM-sicher)
  echo "$FOUND_LINES" | tail -n 50
  exit 1
fi

echo "OK: No matching Proxmox log entries found."
exit 0
