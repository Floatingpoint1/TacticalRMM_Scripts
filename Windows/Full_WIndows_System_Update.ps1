#Requires -Version 5.1
<#
    .SYNOPSIS
    Umfassendes System-Update-Skript für Windows
    
    .DESCRIPTION
    Aktualisiert automatisch:
    - Windows Updates (inkl. Microsoft Updates)
    - Installierte Software via winget/Chocolatey
    - Microsoft Store Apps
    
    Ausgeschlossen: Wazuh Agent (Security Monitoring)
    
    .PARAMETER SkipWindowsUpdates
    Überspringt Windows Updates
    
    .PARAMETER SkipSoftwareUpdates
    Überspringt Software-Updates (winget/choco)
    
    .PARAMETER SkipStoreApps
    Überspringt Microsoft Store App Updates
    
    .PARAMETER NoReboot
    Verhindert automatischen Neustart
    
    .OUTPUTS
    Exit 0: Alle Updates erfolgreich
    Exit 1: Fehler bei Updates oder fehlende Admin-Rechte
    
    .NOTES
    Version: 2.2 TRMM
    Autor: Rainer IT Services
    Shell Type: PowerShell
    Platform: Windows
    Erfordert: Administrator-Rechte
#>

# ============================================================================
# PARAMETER
# ============================================================================

param(
    [switch]$SkipWindowsUpdates,
    [switch]$SkipSoftwareUpdates,
    [switch]$SkipStoreApps,
    [switch]$NoReboot
)

$ErrorActionPreference = "Continue"

# ============================================================================
# KONFIGURATION
# ============================================================================

# Log-Pfad
$LogPath = "C:\Logs\TRMM_SystemUpdate"
$LogFile = "$LogPath\Update_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Ausschlussliste - Diese Pakete werden NICHT aktualisiert
$ExcludedPackages = @(
    "Wazuh",
    "wazuh-agent",
    "WazuhAgent",
    "TacticalAgent"
)

# Globaler Fehler-Tracker
$script:HasErrors = $false

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
    
    # Konsolen-Ausgabe
    Write-Output $logEntry
    
    # Datei-Log
    try {
        if (-not (Test-Path $LogPath)) {
            New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
        }
        $logEntry | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
    catch {
        Write-Output "Log-Fehler: $($_.Exception.Message)"
    }
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-RequiredModule {
    param([string]$ModuleName)
    
    if (Get-Module -ListAvailable -Name $ModuleName) {
        Write-Log "Modul '$ModuleName' bereits installiert" -Type Success
        return $true
    }
    
    try {
        Write-Log "Installiere Modul: $ModuleName..." -Type Info
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
        Write-Log "Modul '$ModuleName' installiert" -Type Success
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler bei Installation von ${ModuleName}: $errorMsg" -Type Error
        $script:HasErrors = $true
        return $false
    }
}

# ============================================================================
# UPDATE-FUNKTIONEN
# ============================================================================

function Update-WindowsSystem {
    Write-Log "=== WINDOWS UPDATES ===" -Type Info
    
    # Prozess-Titel aktualisieren
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM System Update - Windows Updates"
    } catch {}
    
    $moduleInstalled = Install-RequiredModule -ModuleName "PSWindowsUpdate"
    if (-not $moduleInstalled) {
        Write-Log "PSWindowsUpdate nicht verfügbar - überspringe" -Type Warning
        return
    }
    
    try {
        Import-Module PSWindowsUpdate -ErrorAction Stop
        
        # Microsoft Update Service registrieren
        $null = Add-WUServiceManager -MicrosoftUpdate -Confirm:$false -ErrorAction SilentlyContinue
        
        # Updates suchen
        Write-Log "Suche Windows Updates..." -Type Info
        $VerbosePreference = "SilentlyContinue"
        $updates = Get-WindowsUpdate -MicrosoftUpdate -ErrorAction Stop
        $VerbosePreference = "Continue"
        
        if ($updates.Count -eq 0) {
            Write-Log "Keine Windows Updates verfügbar" -Type Success
            return
        }
        
        Write-Log "Gefunden: $($updates.Count) Update(s)" -Type Info
        foreach ($update in $updates) {
            Write-Log "  - $($update.Title)" -Type Info
        }
        
        # Updates installieren
        Write-Log "Installiere Windows Updates..." -Type Info
        
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
        
        Write-Log "Windows Updates abgeschlossen" -Type Success
        
        # Neustart-Status
        try {
            $rebootRequired = Get-WURebootStatus -Silent
            if ($rebootRequired.RebootRequired) {
                Write-Log "NEUSTART ERFORDERLICH" -Type Warning
            }
        }
        catch {}
        
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Fehler bei Windows Updates: $errorMsg" -Type Error
        $script:HasErrors = $true
    }
}

function Update-InstalledSoftware {
    Write-Log "=== SOFTWARE UPDATES ===" -Type Info
    
    # Prozess-Titel aktualisieren
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM System Update - Software Updates"
    } catch {}
    
    # Winget prüfen
    $wingetAvailable = $false
    try {
        $null = winget --version 2>$null
        $wingetAvailable = $true
        Write-Log "winget verfügbar" -Type Success
    }
    catch {
        Write-Log "winget nicht verfügbar" -Type Warning
    }
    
    # Chocolatey prüfen
    $chocoAvailable = $false
    try {
        $null = choco --version 2>$null
        $chocoAvailable = $true
        Write-Log "Chocolatey verfügbar" -Type Success
    }
    catch {}
    
    if (-not $wingetAvailable -and -not $chocoAvailable) {
        Write-Log "Keine Paketmanager verfügbar - überspringe" -Type Warning
        return
    }
    
    # === WINGET ===
    if ($wingetAvailable) {
        try {
            Write-Log "Prüfe winget-Updates..." -Type Info
            
            if ($ExcludedPackages.Count -gt 0) {
                Write-Log "Ausschluss: $($ExcludedPackages -join ', ')" -Type Info
            }
            
            # Liste verfügbarer Updates
            $upgradeOutput = winget upgrade 2>&1 | Out-String
            
            if ($upgradeOutput -match "Keine.*gefunden|No.*found") {
                Write-Log "Keine Software-Updates verfügbar" -Type Success
            }
            else {
                Write-Log "Installiere Updates..." -Type Info
                
                # Hole Liste verfügbarer Updates
                $availableLines = winget upgrade --accept-source-agreements 2>&1 | 
                    Select-String -Pattern "^\S" |
                    Where-Object { $_ -notmatch "Name|---|----|Keine|No|verfügbar|available" }
                
                foreach ($line in $availableLines) {
                    $shouldSkip = $false
                    
                    # Prüfe Ausschlüsse
                    foreach ($excluded in $ExcludedPackages) {
                        if ($line -match $excluded) {
                            Write-Log "Überspringe: $excluded" -Type Warning
                            $shouldSkip = $true
                            break
                        }
                    }
                    
                    if (-not $shouldSkip -and $line -match '\s+(\S+\.\S+)\s+') {
                        $packageId = $matches[1]
                        Write-Log "Aktualisiere: $packageId" -Type Info
                        
                        # Titel für aktuelles Paket
                        try {
                            $Host.UI.RawUI.WindowTitle = "TRMM System Update - Software: $packageId"
                        } catch {}
                        
                        $null = winget upgrade --id $packageId --silent --accept-package-agreements --accept-source-agreements 2>&1
                    }
                }
                
                Write-Log "winget-Updates abgeschlossen" -Type Success
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler bei winget-Updates: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    
    # === CHOCOLATEY ===
    if ($chocoAvailable) {
        try {
            Write-Log "Prüfe Chocolatey-Updates..." -Type Info
            
            $outdated = choco outdated --limit-output 2>&1
            
            if ($outdated -match "determined|^$" -or $outdated.Count -eq 0) {
                Write-Log "Keine Chocolatey-Updates verfügbar" -Type Success
            }
            else {
                Write-Log "Installiere Chocolatey-Updates..." -Type Info
                
                # Titel aktualisieren
                try {
                    $Host.UI.RawUI.WindowTitle = "TRMM System Update - Chocolatey Updates"
                } catch {}
                
                if ($ExcludedPackages.Count -gt 0) {
                    $exceptParam = $ExcludedPackages -join ","
                    $null = choco upgrade all -y --except="$exceptParam" 2>&1
                }
                else {
                    $null = choco upgrade all -y 2>&1
                }
                
                Write-Log "Chocolatey-Updates abgeschlossen" -Type Success
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Fehler bei Chocolatey-Updates: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
}

function Update-StoreApps {
    Write-Log "=== STORE APP UPDATES ===" -Type Info
    
    # Prozess-Titel aktualisieren
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM System Update - Store Apps"
    } catch {}
    
    # Methode 1: CIM-basiert
    try {
        Write-Log "Starte Store-Update-Scan..." -Type Info
        
        $cimResult = Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" `
            -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" `
            -ErrorAction Stop | 
            Invoke-CimMethod -MethodName UpdateScanMethod
        
        if ($cimResult.ReturnValue -eq 0) {
            Write-Log "Store-Update-Scan erfolgreich" -Type Success
        }
        else {
            Write-Log "Store-Update-Scan Code: $($cimResult.ReturnValue)" -Type Warning
        }
    }
    catch {
        Write-Log "CIM-Methode fehlgeschlagen, versuche winget..." -Type Warning
        
        # Methode 2: winget
        try {
            $null = winget --version 2>$null
            Write-Log "Aktualisiere Store-Apps via winget..." -Type Info
            $null = winget upgrade --source msstore --silent --accept-package-agreements --accept-source-agreements 2>&1
            Write-Log "Store-Apps via winget aktualisiert" -Type Success
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Store-App-Update fehlgeschlagen: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    
    # Store-Cache zurücksetzen
    try {
        Write-Log "Setze Store-Cache zurück..." -Type Info
        Start-Process "WSReset.exe" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
        Write-Log "Store-Cache zurückgesetzt" -Type Success
    }
    catch {}
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

function Main {
    # Prozess-Titel setzen (im Task-Manager sichtbar)
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM System Update - $env:COMPUTERNAME"
    }
    catch {
        # Fallback falls kein UI verfügbar (z.B. bei PowerShell Core ohne Fenster)
    }
    
    Write-Log "=== TACTICAL RMM SYSTEM UPDATE ===" -Type Info
    Write-Log "Start: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
    Write-Log "Computer: $env:COMPUTERNAME" -Type Info
    Write-Log "Windows: $([System.Environment]::OSVersion.VersionString)" -Type Info
    
    # Administrator-Check
    if (-not (Test-IsAdmin)) {
        Write-Log "FEHLER: Administrator-Rechte erforderlich!" -Type Error
        exit 1
    }
    
    Write-Log "Administrator-Rechte bestätigt" -Type Success
    
    # Update-Prozesse
    if (-not $SkipWindowsUpdates) {
        try { 
            Update-WindowsSystem 
        } 
        catch { 
            $errorMsg = $_.Exception.Message
            Write-Log "Windows Update-Prozess fehlgeschlagen: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    else {
        Write-Log "Windows Updates übersprungen" -Type Info
    }
    
    if (-not $SkipSoftwareUpdates) {
        try { 
            Update-InstalledSoftware 
        } 
        catch { 
            $errorMsg = $_.Exception.Message
            Write-Log "Software Update-Prozess fehlgeschlagen: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    else {
        Write-Log "Software-Updates übersprungen" -Type Info
    }
    
    if (-not $SkipStoreApps) {
        try { 
            Update-StoreApps 
        } 
        catch { 
            $errorMsg = $_.Exception.Message
            Write-Log "Store-App Update-Prozess fehlgeschlagen: $errorMsg" -Type Error
            $script:HasErrors = $true
        }
    }
    else {
        Write-Log "Store-Apps übersprungen" -Type Info
    }
    
    # Prozess-Titel für Abschluss
    try {
        $Host.UI.RawUI.WindowTitle = "TRMM System Update - Abgeschlossen"
    } catch {}
    
    # Abschluss
    Write-Log "=== PROZESS ABGESCHLOSSEN ===" -Type Info
    Write-Log "Ende: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')" -Type Info
    Write-Log "Log-Datei: $LogFile" -Type Info
    
    # Exit-Code
    if ($script:HasErrors) {
        Write-Log "Beendet mit Fehlern" -Type Error
        exit 1
    }
    else {
        Write-Log "Erfolgreich abgeschlossen" -Type Success
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
