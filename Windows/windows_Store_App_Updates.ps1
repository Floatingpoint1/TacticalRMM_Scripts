#Requires -Version 5.1
<#
    .SYNOPSIS
    TRMM - Microsoft Store App Updates
    
    .DESCRIPTION
    Aktualisiert Microsoft Store Apps
    Timeout-optimiert für Tactical RMM
    
    .OUTPUTS
    Exit 0: Erfolgreich
    Exit 1: Fehler
    
    .NOTES
    Version: 1.0 TRMM
    Autor: Rainer IT Services
    Shell Type: PowerShell
    Timeout: ~5-10 Min
#>

$ErrorActionPreference = "Continue"
$script:HasErrors = $false

# ============================================================================
# KONFIGURATION
# ============================================================================

$LogPath = "C:\Logs\TRMM_Updates"
$LogFile = "$LogPath\StoreUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Type] $Message"
    Write-Output $logEntry
    
    try {
        if (-not (Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
    catch {}
}

# ============================================================================
# HAUPTFUNKTION
# ============================================================================

function Main {
    # Prozess-Titel
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM - Store Updates - $env:COMPUTERNAME"
    } catch {}
    
    Write-Log "=== TRMM STORE APP UPDATES ===" -Type Info
    Write-Log "Start: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
    Write-Log "Computer: $env:COMPUTERNAME" -Type Info
    
    # ========================================================================
    # METHODE 1: CIM (Enterprise MDM)
    # ========================================================================
    
    Write-Log "Methode 1: CIM Update Scan..." -Type Info
    try {
        $cimResult = Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" `
            -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" `
            -ErrorAction Stop | 
            Invoke-CimMethod -MethodName UpdateScanMethod
        
        if ($cimResult.ReturnValue -eq 0) {
            Write-Log "Store-Update-Scan erfolgreich gestartet" -Type Success
        }
        else {
            Write-Log "Store-Update-Scan Code: $($cimResult.ReturnValue)" -Type Warning
            throw "CIM-Methode nicht erfolgreich"
        }
    }
    catch {
        Write-Log "CIM-Methode fehlgeschlagen, versuche winget..." -Type Warning
        
        # ====================================================================
        # METHODE 2: winget (Fallback)
        # ====================================================================
        
        try {
            $null = winget --version 2>$null
            Write-Log "Methode 2: winget msstore..." -Type Info
            
            $storeUpdates = winget upgrade --source msstore 2>&1 | Out-String
            
            if ($storeUpdates -match "Keine.*gefunden|No.*found|No installed") {
                Write-Log "Keine Store-Updates verfügbar" -Type Success
            }
            else {
                Write-Log "Store-Updates gefunden - installiere..." -Type Info
                winget upgrade --source msstore --all --silent --accept-package-agreements --accept-source-agreements 2>&1 | 
                    ForEach-Object { Write-Log $_ -Type Info }
                Write-Log "Store-Updates via winget abgeschlossen" -Type Success
            }
        }
        catch {
            Write-Log "winget-Methode fehlgeschlagen: $($_.Exception.Message)" -Type Error
            $script:HasErrors = $true
        }
    }
    
    # ========================================================================
    # STORE CACHE RESET
    # ========================================================================
    
    Write-Log "Setze Store-Cache zurück..." -Type Info
    try {
        $wsreset = Start-Process "WSReset.exe" -WindowStyle Hidden -PassThru -ErrorAction Stop
        
        # Max. 30 Sekunden warten
        $timeout = 30
        $elapsed = 0
        while (-not $wsreset.HasExited -and $elapsed -lt $timeout) {
            Start-Sleep -Seconds 1
            $elapsed++
        }
        
        if ($wsreset.HasExited) {
            Write-Log "Store-Cache zurückgesetzt" -Type Success
        }
        else {
            $wsreset.Kill()
            Write-Log "WSReset Timeout - abgebrochen" -Type Warning
        }
    }
    catch {
        Write-Log "Store-Cache-Reset fehlgeschlagen: $($_.Exception.Message)" -Type Warning
    }
    
    # ========================================================================
    # ABSCHLUSS
    # ========================================================================
    
    Write-Log "=== ABGESCHLOSSEN ===" -Type Info
    Write-Log "Ende: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
    Write-Log "Log: $LogFile" -Type Info
    
    if ($script:HasErrors) {
        Write-Log "Beendet mit Fehlern" -Type Error
        exit 1
    }
    else {
        Write-Log "Erfolgreich" -Type Success
        exit 0
    }
}

# ============================================================================
# START
# ============================================================================

try {
    Main
}
catch {
    Write-Log "KRITISCHER FEHLER: $($_.Exception.Message)" -Type Error
    exit 1
}
