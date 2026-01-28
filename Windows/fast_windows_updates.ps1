#Requires -Version 5.1
<#
    .SYNOPSIS
    TRMM - Windows Updates
    
    .DESCRIPTION
    Installiert Windows und Microsoft Updates
    Timeout-optimiert für Tactical RMM
    
    .PARAMETER NoReboot
    Verhindert automatischen Neustart
    
    .OUTPUTS
    Exit 0: Erfolgreich
    Exit 1: Fehler oder keine Admin-Rechte
    
    .NOTES
    Version: 1.0 TRMM
    Autor: REFLECTS Tactical RMM
    Shell Type: PowerShell
    Timeout: ~15-30 Min
#>

param([switch]$NoReboot)

$ErrorActionPreference = "Continue"
$script:HasErrors = $false

# ============================================================================
# KONFIGURATION
# ============================================================================

$LogPath = "C:\Logs\TRMM_Updates"
$LogFile = "$LogPath\WindowsUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================================
# HAUPTFUNKTION
# ============================================================================

function Main {
    # Prozess-Titel
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM - Windows Updates - $env:COMPUTERNAME"
    } catch {}
    
    Write-Log "=== TRMM WINDOWS UPDATES ===" -Type Info
    Write-Log "Start: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
    Write-Log "Computer: $env:COMPUTERNAME" -Type Info
    
    # Admin-Check
    if (-not (Test-IsAdmin)) {
        Write-Log "FEHLER: Administrator-Rechte erforderlich!" -Type Error
        exit 1
    }
    
    # PSWindowsUpdate Modul
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Log "Installiere PSWindowsUpdate Modul..." -Type Info
        try {
            Install-Module -Name PSWindowsUpdate -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
            Write-Log "Modul installiert" -Type Success
        }
        catch {
            Write-Log "Modul-Installation fehlgeschlagen: $($_.Exception.Message)" -Type Error
            exit 1
        }
    }
    
    # Modul laden
    try {
        Import-Module PSWindowsUpdate -ErrorAction Stop
        Write-Log "PSWindowsUpdate geladen" -Type Success
    }
    catch {
        Write-Log "Modul-Import fehlgeschlagen: $($_.Exception.Message)" -Type Error
        exit 1
    }
    
    # Microsoft Update aktivieren
    try {
        $null = Add-WUServiceManager -MicrosoftUpdate -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Microsoft Update Service aktiviert" -Type Success
    }
    catch {}
    
    # Updates suchen
    Write-Log "Suche Windows Updates..." -Type Info
    try {
        $VerbosePreference = "SilentlyContinue"
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop
        $VerbosePreference = "Continue"
        
        if ($updates.Count -eq 0) {
            Write-Log "Keine Updates verfügbar" -Type Success
            Write-Log "Abgeschlossen: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
            exit 0
        }
        
        Write-Log "Gefunden: $($updates.Count) Update(s)" -Type Info
        foreach ($update in $updates) {
            Write-Log "  - $($update.Title)" -Type Info
        }
    }
    catch {
        Write-Log "Update-Suche fehlgeschlagen: $($_.Exception.Message)" -Type Error
        $script:HasErrors = $true
    }
    
    # Updates installieren
    if ($updates.Count -gt 0) {
        Write-Log "Installiere Updates..." -Type Info
        
        try {
            $installParams = @{
                MicrosoftUpdate = $true
                AcceptAll = $true
                IgnoreReboot = $NoReboot
                ErrorAction = "Continue"
            }
            
            if (-not $NoReboot) {
                $installParams.AutoReboot = $true
            }
            
            Install-WindowsUpdate @installParams
            
            Write-Log "Windows Updates installiert" -Type Success
        }
        catch {
            Write-Log "Update-Installation fehlgeschlagen: $($_.Exception.Message)" -Type Error
            $script:HasErrors = $true
        }
        
        # Neustart-Check
        try {
            $rebootRequired = Get-WURebootStatus -Silent
            if ($rebootRequired.RebootRequired) {
                Write-Log "!!! NEUSTART ERFORDERLICH !!!" -Type Warning
            }
        }
        catch {}
    }
    
    # Abschluss
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
