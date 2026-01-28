# Registry-Pfad für Windows Update Blockierung
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$pauseUpdatesKey = "PauseFeatureUpdates"
$targetVersionKey = "TargetReleaseVersion"
$targetVersionInfoKey = "TargetReleaseVersionInfo"

# Prüfen, ob eine Sperre existiert
if (Test-Path $regPath) {
    $existingVersion = (Get-ItemProperty -Path $regPath -Name $targetVersionInfoKey -ErrorAction SilentlyContinue).$targetVersionInfoKey
    if ($existingVersion) {
        Remove-ItemProperty -Path $regPath -Name $pauseUpdatesKey -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name $targetVersionKey -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $regPath -Name $targetVersionInfoKey -ErrorAction SilentlyContinue
        Write-Host "Windows Updates sind jetzt erlaubt! Vorher blockierte Version: $existingVersion"
        exit 0
    }
}

Write-Host "Es gibt keine bestehende Update-Sperre."
