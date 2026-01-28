#Requires -Version 5.1
<#
    .SYNOPSIS
    TRMM - Software Updates (3rd Party)
    
    .DESCRIPTION
    Aktualisiert Software via winget und Chocolatey
    Timeout-optimiert für Tactical RMM
    
    .PARAMETER ExcludePackages
    Komma-getrennte Liste von auszuschließenden Paketen
    
    .OUTPUTS
    Exit 0: Erfolgreich
    Exit 1: Fehler oder keine Admin-Rechte
    
    .NOTES
    Version: 1.1 TRMM
    Autor: Rainer IT Services
    Shell Type: PowerShell
    Timeout: ~10-20 Min
#>

param(
    [string]$ExcludePackages = "Wazuh,wazuh-agent,WazuhAgent,TacticalAgent"
)

$ErrorActionPreference = "Continue"
$script:HasErrors = $false

# ============================================================================
# KONFIGURATION
# ============================================================================

$LogPath = "C:\Logs\TRMM_Updates"
$LogFile = "$LogPath\SoftwareUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Ausschlussliste aus Parameter
$ExcludedPackages = $ExcludePackages -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

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
    catch {
        Write-Output "Log-Fehler"
    }
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
        $Host.UI.RawUI.WindowTitle = "TRMM - Software Updates - $env:COMPUTERNAME"
    } 
    catch {
        # Kein UI verfuegbar
    }
    
    Write-Log "=== TRMM SOFTWARE UPDATES ===" -Type Info
    Write-Log "Start: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
    Write-Log "Computer: $env:COMPUTERNAME" -Type Info
    
    if ($ExcludedPackages.Count -gt 0) {
        Write-Log "Ausschlussliste: $($ExcludedPackages -join ', ')" -Type Info
    }
    
    # Admin-Check
    if (-not (Test-IsAdmin)) {
        Write-Log "FEHLER: Administrator-Rechte erforderlich!" -Type Error
        exit 1
    }
    
    $updatesFound = $false
    
    # ========================================================================
    # WINGET
    # ========================================================================
    
    $wingetAvailable = $false
    try {
        $wingetVersion = winget --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $wingetAvailable = $true
            Write-Log "winget verfuegbar: $wingetVersion" -Type Success
        }
    }
    catch {
        Write-Log "winget nicht verfuegbar" -Type Warning
    }
    
    if ($wingetAvailable) {
        Write-Log "--- WINGET UPDATES ---" -Type Info
        
        try {
            # Titel aktualisieren
            try {
                $Host.UI.RawUI.WindowTitle = "TRMM - Software Updates - winget"
            } 
            catch {
                # Kein UI
            }
            
            # Verfuegbare Updates holen
            Write-Log "Pruefe winget-Updates..." -Type Info
            $upgradeOutput = winget upgrade --accept-source-agreements 2>&1
            $upgradeList = $upgradeOutput | Out-String
            
            if ($upgradeList -match "Keine.*gefunden|No.*found|No installed") {
                Write-Log "Keine winget-Updates verfuegbar" -Type Success
            }
            else {
                $updatesFound = $true
                Write-Log "winget-Updates gefunden - starte Installation..." -Type Info
                
                # Parse Output
                $lines = $upgradeOutput | Where-Object { 
                    $_ -match '^\S+' -and 
                    $_ -notmatch 'Name|---|----|Keine|No|verfuegbar|available|Aktualisierungen|upgrades' 
                }
                
                foreach ($line in $lines) {
                    # Package ID extrahieren
                    if ($line -match '\s+([\w\.-]+\.[\w\.-]+)\s+') {
                        $packageId = $matches[1]
                        
                        # Ausschluss-Check
                        $shouldSkip = $false
                        foreach ($excluded in $ExcludedPackages) {
                            if ($packageId -match $excluded) {
                                Write-Log "Ueberspringe: $packageId (ausgeschlossen)" -Type Warning
                                $shouldSkip = $true
                                break
                            }
                        }
                        
                        if (-not $shouldSkip) {
                            Write-Log "Update: $packageId" -Type Info
                            
                            try {
                                $Host.UI.RawUI.WindowTitle = "TRMM - Software Updates - $packageId"
                            } 
                            catch {
                                # Kein UI
                            }
                            
                            $upgradeResult = winget upgrade --id $packageId --silent --accept-package-agreements --accept-source-agreements 2>&1
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Log "  OK: $packageId aktualisiert" -Type Success
                            }
                            else {
                                Write-Log "  WARNUNG: $packageId Fehler (Code: $LASTEXITCODE)" -Type Warning
                            }
                        }
                    }
                }
                
                Write-Log "winget-Updates abgeschlossen" -Type Success
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "winget-Update fehlgeschlagen: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    
    # ========================================================================
    # CHOCOLATEY
    # ========================================================================
    
    $chocoAvailable = $false
    try {
        $chocoVersion = choco --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $chocoAvailable = $true
            Write-Log "Chocolatey verfuegbar: $chocoVersion" -Type Success
        }
    }
    catch {
        Write-Log "Chocolatey nicht verfuegbar" -Type Warning
    }
    
    if ($chocoAvailable) {
        Write-Log "--- CHOCOLATEY UPDATES ---" -Type Info
        
        try {
            # Titel aktualisieren
            try {
                $Host.UI.RawUI.WindowTitle = "TRMM - Software Updates - Chocolatey"
            } 
            catch {
                # Kein UI
            }
            
            Write-Log "Pruefe Chocolatey-Updates..." -Type Info
            $outdated = choco outdated --limit-output 2>&1
            
            if ($outdated -match "Chocolatey|^$" -or $outdated.Count -eq 0) {
                Write-Log "Keine Chocolatey-Updates verfuegbar" -Type Success
            }
            else {
                $updatesFound = $true
                Write-Log "Chocolatey-Updates gefunden - starte Installation..." -Type Info
                
                if ($ExcludedPackages.Count -gt 0) {
                    $exceptParam = $ExcludedPackages -join ","
                    $chocoResult = choco upgrade all -y --except="$exceptParam" 2>&1
                    $chocoResult | ForEach-Object { Write-Log $_ -Type Info }
                }
                else {
                    $chocoResult = choco upgrade all -y 2>&1
                    $chocoResult | ForEach-Object { Write-Log $_ -Type Info }
                }
                
                Write-Log "Chocolatey-Updates abgeschlossen" -Type Success
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Chocolatey-Update fehlgeschlagen: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    
    # ========================================================================
    # ABSCHLUSS
    # ========================================================================
    
    if (-not $wingetAvailable -and -not $chocoAvailable) {
        Write-Log "WARNUNG: Keine Paketmanager verfuegbar!" -Type Warning
        Write-Log "Installiere winget oder Chocolatey fuer Software-Updates" -Type Warning
    }
    
    if (-not $updatesFound -and ($wingetAvailable -or $chocoAvailable)) {
        Write-Log "Keine Software-Updates verfuegbar" -Type Success
    }
    
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
    $errorMsg = $_.Exception.Message
    Write-Log "KRITISCHER FEHLER: $errorMsg" -Type Error
    exit 1
}
