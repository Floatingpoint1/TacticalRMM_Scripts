<#
.SYNOPSIS
    UEFI Secure Boot und Zertifikats-Validierung für Tactical RMM
.DESCRIPTION
    Prüft ob UEFI aktiv ist, Secure Boot aktiviert ist und die Microsoft Zertifikate aktuell sind.
    Nur lesende Operationen - keine Systemänderungen.
.NOTES
    Erstellt für: Rainer IT Services
    Sicherheit: Nur Lesezugriff, keine Systemmodifikationen
#>

try {
    # Initialisierung
    $results = @()
    $exitCode = 0
    $allChecksOK = $true

    # ============================================
    # 1. UEFI-Modus Prüfung
    # ============================================
    try {
        $firmwareType = (Get-ComputerInfo -Property BiosFirmwareType).BiosFirmwareType
        
        if ($firmwareType -eq 'Uefi') {
            $results += "[OK] UEFI-Modus: Aktiv"
        } else {
            $results += "[FEHLER] UEFI-Modus: Nicht aktiv (Legacy BIOS erkannt)"
            $allChecksOK = $false
            $exitCode = 1
        }
    } catch {
        $results += "[WARNUNG] UEFI-Modus: Konnte nicht ermittelt werden - $($_.Exception.Message)"
        $allChecksOK = $false
        $exitCode = 1
    }

    # ============================================
    # 2. Secure Boot Status Prüfung
    # ============================================
    try {
        $secureBootEnabled = Confirm-SecureBootUEFI
        
        if ($secureBootEnabled) {
            $results += "[OK] Secure Boot: Aktiviert"
        } else {
            $results += "[FEHLER] Secure Boot: Deaktiviert"
            $allChecksOK = $false
            $exitCode = 1
        }
    } catch {
        $results += "[WARNUNG] Secure Boot: Konnte nicht geprueft werden (moeglicherweise Legacy BIOS) - $($_.Exception.Message)"
        $allChecksOK = $false
        $exitCode = 1
    }

    # ============================================
    # 3. UEFI Zertifikats-Prüfung (nur wenn UEFI aktiv)
    # ============================================
    if ($firmwareType -eq 'Uefi') {
        
        # 3.1 Prüfung: db (Signature Database) - Windows UEFI CA 2023
        try {
            $db_bytes = (Get-SecureBootUEFI -Name db).bytes
            $db_string = [System.Text.Encoding]::ASCII.GetString($db_bytes)
            $has_WindowsCA2023 = $db_string -match "Windows UEFI CA 2023"
            
            if ($has_WindowsCA2023) {
                $results += "[OK] db Zertifikat: Windows UEFI CA 2023 vorhanden"
            } else {
                $results += "[FEHLER] db Zertifikat: Windows UEFI CA 2023 NICHT gefunden"
                $allChecksOK = $false
                $exitCode = 1
            }
        } catch {
            $results += "[WARNUNG] db Zertifikat: Konnte nicht gelesen werden - $($_.Exception.Message)"
            $allChecksOK = $false
            $exitCode = 1
        }

        # 3.2 Prüfung: KEK (Key Exchange Key) - Microsoft KEK 2K CA 2023
        try {
            $kek_bytes = (Get-SecureBootUEFI -Name kek).bytes
            $kek_string = [System.Text.Encoding]::ASCII.GetString($kek_bytes)
            $has_MSKEK2023 = $kek_string -match "Microsoft Corporation KEK 2K CA 2023"
            
            if ($has_MSKEK2023) {
                $results += "[OK] KEK Zertifikat: Microsoft Corporation KEK 2K CA 2023 vorhanden"
            } else {
                $results += "[FEHLER] KEK Zertifikat: Microsoft Corporation KEK 2K CA 2023 NICHT gefunden"
                $allChecksOK = $false
                $exitCode = 1
            }
        } catch {
            $results += "[WARNUNG] KEK Zertifikat: Konnte nicht gelesen werden - $($_.Exception.Message)"
            $allChecksOK = $false
            $exitCode = 1
        }

        # 3.3 Zusätzliche Prüfung: PK (Platform Key) - Optional
        try {
            $pk_bytes = (Get-SecureBootUEFI -Name pk).bytes
            if ($pk_bytes.Length -gt 0) {
                $results += "[OK] PK (Platform Key): Vorhanden"
            } else {
                $results += "[WARNUNG] PK (Platform Key): Leer oder nicht gesetzt"
            }
        } catch {
            $results += "[WARNUNG] PK (Platform Key): Konnte nicht gelesen werden - $($_.Exception.Message)"
        }

        # 3.4 Zusätzliche Prüfung: dbx (Forbidden Signatures) - Optional
        try {
            $dbx_bytes = (Get-SecureBootUEFI -Name dbx).bytes
            if ($dbx_bytes.Length -gt 0) {
                $results += "[OK] dbx (Revocation List): Vorhanden ($($dbx_bytes.Length) Bytes)"
            } else {
                $results += "[WARNUNG] dbx (Revocation List): Leer"
            }
        } catch {
            $results += "[WARNUNG] dbx (Revocation List): Konnte nicht gelesen werden"
        }
    }

    # ============================================
    # Ergebnis-Ausgabe
    # ============================================
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "UEFI & Secure Boot Validierung"
    Write-Host "=========================================="
    
    foreach ($result in $results) {
        Write-Host $result
    }
    
    Write-Host "=========================================="
    
    if ($allChecksOK) {
        Write-Host ""
        Write-Host "[OK] ALLE PRUEFUNGEN ERFOLGREICH - System ist UEFI-konform mit aktuellen Microsoft Zertifikaten" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "[FEHLER] PRUEFUNG FEHLGESCHLAGEN - Bitte Ergebnisse ueberpruefen" -ForegroundColor Yellow
        exit $exitCode
    }

} catch {
    # Globaler Fehler-Handler
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "KRITISCHER FEHLER" -ForegroundColor Red
    Write-Host "=========================================="
    Write-Host "Fehlermeldung: $($_.Exception.Message)"
    Write-Host "Fehlerzeile: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Host "=========================================="
    exit 1
}
