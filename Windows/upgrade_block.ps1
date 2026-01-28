# Registry-Pfad für Windows Update Blockierung
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$pauseUpdatesKey = "PauseFeatureUpdates"
$targetVersionKey = "TargetReleaseVersion"
$targetVersionInfoKey = "TargetReleaseVersionInfo"

# Aktuelle Windows-Version korrekt ermitteln
$currentVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion

# Prüfen, ob die Sperre bereits gesetzt ist
if (Test-Path $regPath) {
    $existingVersion = (Get-ItemProperty -Path $regPath -Name $targetVersionInfoKey -ErrorAction SilentlyContinue).$targetVersionInfoKey
    if ($existingVersion -eq $currentVersion) {
        Write-Host "Updates sind bereits blockiert für Version: $existingVersion"
        exit 0
    }
}

# Sicherstellen, dass der Registry-Pfad existiert
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Blockiert zukünftige Windows-Feature-Updates
Set-ItemProperty -Path $regPath -Name $pauseUpdatesKey -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name $targetVersionKey -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name $targetVersionInfoKey -Value $currentVersion -Type String

Write-Host "Windows Updates sind jetzt blockiert! Zielversion: $currentVersion"
