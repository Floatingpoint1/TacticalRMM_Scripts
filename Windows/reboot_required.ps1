<#
    .SYNOPSIS
    Prüft ob ein System-Neustart aussteht
    
    .DESCRIPTION
    Prüft verschiedene Windows-Indikatoren für ausstehende Neustarts:
    - Windows Update
    - Pending File Rename Operations
    - Component Based Servicing
    - Computer Rename
    
    .OUTPUTS
    Exit 0: Kein Neustart noetig
    Exit 1: Neustart erforderlich (WARNUNG)
    
    .NOTES
    Version: 1.1
    Autor: Rainer IT Services
    Shell Type: PowerShell
    Platform: Windows
#>

Write-Host "=== REBOOT REQUIRED CHECK ==="
Write-Host "Start: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
Write-Host ""

# Flags
$RebootRequired = $false
$RebootReasons = @()

Write-Host "--- PRUEFUNGEN DURCHFUEHREN ---"
Write-Host ""

# 1. Windows Update
Write-Host "[1/5] Pruefe Windows Update..."

$WURebootKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
if (Test-Path $WURebootKey) {
    Write-Host "  >> NEUSTART ERFORDERLICH - Windows Update"
    $RebootRequired = $true
    $RebootReasons += "Windows Update"
} else {
    Write-Host "  >> OK - Kein Windows Update Neustart"
}
Write-Host ""

# 2. Component Based Servicing (CBS)
Write-Host "[2/5] Pruefe Component Based Servicing..."

$CBSRebootKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
if (Test-Path $CBSRebootKey) {
    Write-Host "  >> NEUSTART ERFORDERLICH - Component Based Servicing"
    $RebootRequired = $true
    $RebootReasons += "Component Based Servicing (CBS)"
} else {
    Write-Host "  >> OK - Kein CBS Neustart"
}
Write-Host ""

# 3. Pending File Rename Operations
Write-Host "[3/5] Pruefe Pending File Rename Operations..."

$PendingFileRenameKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
$PendingFileRename = Get-ItemProperty -Path $PendingFileRenameKey -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue

if ($PendingFileRename) {
    $OperationsCount = $PendingFileRename.PendingFileRenameOperations.Count
    Write-Host "  >> NEUSTART ERFORDERLICH - $OperationsCount File Rename Operation(s)"
    $RebootRequired = $true
    $RebootReasons += "Pending File Rename Operations ($OperationsCount)"
    
    # Zeige erste paar Operationen
    if ($OperationsCount -gt 0) {
        Write-Host ""
        Write-Host "  Erste Operationen:"
        $PendingFileRename.PendingFileRenameOperations | Select-Object -First 5 | ForEach-Object {
            Write-Host "    - $_"
        }
    }
} else {
    Write-Host "  >> OK - Keine Pending File Rename Operations"
}
Write-Host ""

# 4. Computer Rename
Write-Host "[4/5] Pruefe Computer Rename..."

$ActiveComputerName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -Name ComputerName).ComputerName
$PendingComputerName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" -Name ComputerName).ComputerName

if ($ActiveComputerName -ne $PendingComputerName) {
    Write-Host "  >> NEUSTART ERFORDERLICH - Computer Rename"
    Write-Host "     Alt: $ActiveComputerName"
    Write-Host "     Neu: $PendingComputerName"
    $RebootRequired = $true
    $RebootReasons += "Computer Rename: $ActiveComputerName -> $PendingComputerName"
} else {
    Write-Host "  >> OK - Kein Computer Rename"
}
Write-Host ""

# 5. SCCM/ConfigMgr (falls vorhanden)
Write-Host "[5/5] Pruefe SCCM Client..."

try {
    $CCMReboot = Invoke-WmiMethod -Namespace "root\ccm\ClientSDK" -Class "CCM_ClientUtilities" -Name "DetermineIfRebootPending" -ErrorAction SilentlyContinue
    
    if ($CCMReboot) {
        if ($CCMReboot.RebootPending -or $CCMReboot.IsHardRebootPending) {
            Write-Host "  >> NEUSTART ERFORDERLICH - SCCM Client"
            $RebootRequired = $true
            $RebootReasons += "SCCM Client"
        } else {
            Write-Host "  >> OK - Kein SCCM Neustart"
        }
    } else {
        Write-Host "  >> UEBERSPRUNGEN - SCCM Client nicht verfuegbar"
    }
} catch {
    Write-Host "  >> UEBERSPRUNGEN - SCCM Client nicht verfuegbar"
}
Write-Host ""

# Zusatzinfo: Letzte Installation/Boot
Write-Host "--- SYSTEM INFORMATIONEN ---"
Write-Host ""

# Last Boot Time
$LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$Uptime = (Get-Date) - $LastBoot
Write-Host "Letzter Boot: $($LastBoot.ToString('dd.MM.yyyy HH:mm:ss'))"
Write-Host "Uptime: $($Uptime.Days) Tage, $($Uptime.Hours) Stunden, $($Uptime.Minutes) Minuten"
Write-Host ""

# Letztes Windows Update
try {
    $LastUpdate = Get-HotFix | Sort-Object -Property InstalledOn -Descending | Select-Object -First 1
    if ($LastUpdate.InstalledOn) {
        Write-Host "Letztes Update: $($LastUpdate.HotFixID) - $($LastUpdate.InstalledOn.ToString('dd.MM.yyyy'))"
    }
} catch {
    Write-Host "Letztes Update: Nicht verfuegbar"
}
Write-Host ""

# Zusammenfassung
Write-Host "=========================================="
Write-Host "ZUSAMMENFASSUNG"
Write-Host "=========================================="

if ($RebootRequired) {
    Write-Host "Status: NEUSTART ERFORDERLICH"
    Write-Host ""
    Write-Host "Gruende:"
    foreach ($reason in $RebootReasons) {
        Write-Host "  - $reason"
    }
    Write-Host ""
    
    Write-Host "=== ERGEBNIS: WARNUNG ==="
    Write-Host "Ein System-Neustart wird empfohlen!"
    Write-Host ""
    Write-Host "Ende: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
    exit 1  # <-- KORRIGIERT: Exit 1 fuer Warnung!
} else {
    Write-Host "Status: KEIN NEUSTART ERFORDERLICH"
    Write-Host ""
    
    Write-Host "=== ERGEBNIS: OK ==="
    Write-Host "System ist aktuell, kein Neustart noetig."
    Write-Host ""
    Write-Host "Ende: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
    exit 0
}
