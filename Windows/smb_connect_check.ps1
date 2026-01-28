<#
.SYNOPSIS
Prueft die Erreichbarkeit eines Netzlaufwerks/UNC-Pfads

.DESCRIPTION
Fuehrt einfache Erreichbarkeitspruefungen fuer Netzlaufwerke durch:
- Ping zum Server
- Test ob UNC-Pfad existiert (Test-Path)
- Keine Lese-/Schreiboperationen

Exit-Codes:
0 = Netzlaufwerk erreichbar (OK)
1 = Netzlaufwerk NICHT erreichbar (ALERT)
2 = Script-Ausfuehrungsfehler oder ungueltige Parameter

.PARAMETER UNCPath
UNC-Pfad zum Netzlaufwerk (z.B. \\DNS_OR_IP\Folder)

.PARAMETER Timeout
Timeout in Sekunden fuer Ping-Test (default: 5)

.OUTPUTS
Status-Information zur Netzlaufwerk-Erreichbarkeit

.NOTES
Version: 2.2
Author: Rainer IT Services
Date: 04/12/2024
Kompatibel mit: Windows Server 2012+, Windows 10+, Windows 11

.EXAMPLE
# Standard-Ausfuehrung
.\script.ps1 -UNCPath "\\DNS_OR_IP\Folder"

.EXAMPLE
# Mit angepasstem Timeout
.\script.ps1 -UNCPath "\\server\share" -Timeout 10
#>

# ============================================================================
# PARAMETER
# ============================================================================

param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$UNCPath = "",
    
    [Parameter(Mandatory=$false)]
    [int]$Timeout = 5
)

# Fehlerbehandlung
$ErrorActionPreference = 'Stop'

# ============================================================================
# FUNKTIONEN
# ============================================================================

function Write-Header {
    param([string]$Title)
    
    Write-Output ""
    Write-Output "=========================================="
    Write-Output "  $Title"
    Write-Output "=========================================="
}

function Test-UNCPathFormat {
    <#
    .SYNOPSIS
    Validiert das UNC-Pfad Format
    #>
    param([string]$Path)
    
    if ($Path -notmatch '^\\\\[^\\]+\\[^\\]+') {
        Write-Output "[FEHLER] Ungueltiges UNC-Pfad Format: $Path"
        Write-Output "Erwartetes Format: \\server\share oder \\IP\share"
        return $false
    }
    return $true
}

function Get-ServerFromUNC {
    <#
    .SYNOPSIS
    Extrahiert Server/IP aus UNC-Pfad
    #>
    param([string]$Path)
    
    if ($Path -match '^\\\\([^\\]+)\\') {
        return $Matches[1]
    }
    return $null
}

function Get-ShareFromUNC {
    <#
    .SYNOPSIS
    Extrahiert Share-Name aus UNC-Pfad
    #>
    param([string]$Path)
    
    if ($Path -match '^\\\\[^\\]+\\([^\\]+)') {
        return $Matches[1]
    }
    return $null
}

function Test-ServerPing {
    <#
    .SYNOPSIS
    Testet Ping-Erreichbarkeit des Servers
    #>
    param(
        [string]$Server,
        [int]$TimeoutSeconds
    )
    
    try {
        Write-Output "Teste Ping zu Server $Server..."
        
        $PingResult = Test-Connection -ComputerName $Server -Count 2 -Quiet -ErrorAction SilentlyContinue
        
        if ($PingResult) {
            # Detaillierte Ping-Statistik
            $PingStats = Test-Connection -ComputerName $Server -Count 4 -ErrorAction SilentlyContinue
            
            if ($PingStats) {
                $AvgResponseTime = ($PingStats | Measure-Object -Property ResponseTime -Average).Average
                Write-Output "[OK] Server ist per Ping erreichbar"
                Write-Output "     Durchschnittliche Antwortzeit: $([math]::Round($AvgResponseTime, 2)) ms"
                return $true
            }
        }
        
        Write-Output "[FEHLER] Server antwortet nicht auf Ping"
        return $false
        
    } catch {
        Write-Output "[FEHLER] Ping-Test fehlgeschlagen: $_"
        return $false
    }
}

function Test-UNCPathExists {
    <#
    .SYNOPSIS
    Testet ob UNC-Pfad existiert (ohne Lese-/Schreibzugriff)
    #>
    param([string]$Path)
    
    try {
        Write-Output "Teste Erreichbarkeit des UNC-Pfads..."
        
        # Test-Path prueft nur Existenz, liest keine Inhalte
        if (Test-Path -Path $Path -ErrorAction Stop) {
            Write-Output "[OK] UNC-Pfad ist erreichbar: $Path"
            return $true
        } else {
            Write-Output "[FEHLER] UNC-Pfad nicht erreichbar: $Path"
            return $false
        }
        
    } catch {
        Write-Output "[FEHLER] Zugriff auf UNC-Pfad fehlgeschlagen"
        Write-Output "         Fehlerdetails: $_"
        Write-Output ""
        Write-Output "         Moegliche Ursachen:"
        Write-Output "         - Keine Berechtigung"
        Write-Output "         - Share ist offline"
        Write-Output "         - Netzwerkproblem"
        Write-Output "         - Firewall blockiert SMB (Port 445)"
        return $false
    }
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

try {
    # Header
    Write-Output "================================================================"
    Write-Output "  Network Share Availability Check - REFLECTS IT"
    Write-Output "================================================================"
    Write-Output ""
    Write-Output "Computer:     $env:COMPUTERNAME"
    Write-Output "Benutzer:     $env:USERNAME"
    Write-Output "Datum:        $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')"
    
    # Pruefen ob UNCPath uebergeben wurde
    if ([string]::IsNullOrWhiteSpace($UNCPath)) {
        Write-Output ""
        Write-Output "[FEHLER] Kein UNC-Pfad angegeben!"
        Write-Output ""
        Write-Output "Verwendung:"
        Write-Output "  -UNCPath \`"\\server\share\`""
        Write-Output ""
        Write-Output "Beispiel:"
        Write-Output "  -UNCPath \`"\\DNS_OR_IP\Folder\`""
        Write-Output ""
        Write-Output "In Tactical RMM unter 'Script Arguments' eintragen:"
        Write-Output "  -UNCPath \`"\\DNS_OR_IP\Folder\`""
        exit 2
    }
    
    Write-Output "UNC-Pfad:     $UNCPath"
    Write-Output "Timeout:      $Timeout Sekunden"
    
    # UNC-Pfad validieren
    Write-Header "VALIDIERUNG"
    
    if (-not (Test-UNCPathFormat -Path $UNCPath)) {
        exit 2
    }
    
    Write-Output "[OK] UNC-Pfad Format ist gueltig"
    
    # Server und Share extrahieren
    $Server = Get-ServerFromUNC -Path $UNCPath
    $ShareName = Get-ShareFromUNC -Path $UNCPath
    
    Write-Output "     Server: $Server"
    Write-Output "     Share:  $ShareName"
    
    # Test-Ergebnisse sammeln
    $PingSuccess = $false
    $PathExists = $false
    
    # 1. PING-TEST
    Write-Header "PING-TEST"
    $PingSuccess = Test-ServerPing -Server $Server -TimeoutSeconds $Timeout
    
    # 2. UNC-PFAD ERREICHBARKEITSTEST
    Write-Header "UNC-PFAD ERREICHBARKEITSTEST"
    $PathExists = Test-UNCPathExists -Path $UNCPath
    
    # ZUSAMMENFASSUNG
    Write-Header "ZUSAMMENFASSUNG"
    
    Write-Output "UNC-Pfad:           $UNCPath"
    Write-Output "Server:             $Server"
    Write-Output "Share:              $ShareName"
    Write-Output ""
    Write-Output "Test-Ergebnisse:"
    Write-Output "  Ping:             $(if ($PingSuccess) { 'OK' } else { 'FEHLER' })"
    Write-Output "  UNC-Pfad:         $(if ($PathExists) { 'OK' } else { 'FEHLER' })"
    Write-Output ""
    
    # GESAMTBEWERTUNG
    if ($PathExists) {
        Write-Output "Status: GRUEN - OK"
        Write-Output "[OK] Netzlaufwerk ist erreichbar"
        exit 0
    } else {
        Write-Output "Status: ROT - FEHLER"
        Write-Output "[FEHLER] Netzlaufwerk ist NICHT erreichbar"
        Write-Output ""
        
        # Diagnose-Hinweise
        Write-Output "Diagnose-Hinweise:"
        
        if (-not $PingSuccess) {
            Write-Output "  - Server antwortet nicht auf Ping"
            Write-Output "    -> Pruefen Sie Netzwerkverbindung und Firewall"
        } elseif ($PingSuccess -and -not $PathExists) {
            Write-Output "  - Server erreichbar, aber Share nicht zugreifbar"
            Write-Output "    -> Pruefen Sie:"
            Write-Output "       - Berechtigungen auf dem Share"
            Write-Output "       - Share ist freigegeben und online"
            Write-Output "       - SMB-Protokoll ist aktiviert"
            Write-Output "       - Firewall laesst Port 445 (SMB) zu"
        }
        
        exit 1
    }
    
} catch {
    Write-Output ""
    Write-Output "[KRITISCHER FEHLER] Script-Ausfuehrung fehlgeschlagen"
    Write-Output "Fehler: $_"
    Write-Output "Zeile: $($_.InvocationInfo.ScriptLineNumber)"
    exit 2
}
