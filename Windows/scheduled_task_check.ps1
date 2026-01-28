<#
    .SYNOPSIS
    Prüft geplante Aufgaben auf Fehler
    
    .DESCRIPTION
    Dieses Skript überprüft alle aktiven Tasks in der Windows Aufgabenplanung
    auf Fehler und gibt detaillierte Fehlermeldungen aus.
    Bestimmte System-Tasks und der Microsoft-Ordner werden ausgeschlossen.
    
    .OUTPUTS
    Exit 0: Alle Tasks OK
    Exit 1: Mindestens ein Task mit Fehler
    
    .NOTES
    Version: 1.4
    Autor: Rainer IT Services
    Shell Type: PowerShell
    Platform: Windows
#>

$ErrorActionPreference = 'SilentlyContinue'

# Hole alle geplanten Tasks (nur aktivierte)
$Tasks = Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' }

# Array für fehlerhafte Tasks
$FailedTasks = @()

foreach ($Task in $Tasks) {
    # Prüfe auf Ausschlüsse
    $ShouldExclude = $false
    
    # Schließe Microsoft-Ordner aus
    if ($Task.TaskPath -like '\Microsoft\*') {
        $ShouldExclude = $true
    }
    
    # Schließe OneDrive-Tasks aus (mit dynamischen SIDs)
    if ($Task.TaskName -like 'OneDrive Reporting*' -or
        $Task.TaskName -like 'OneDrive Startup Task*' -or
        $Task.TaskName -like 'OneDrive Per-Machine Standalone Update Task*' -or
        $Task.TaskName -like 'CreateExplorerShellUnelevatedTask*') {
        $ShouldExclude = $true
    }
    
    # Schließe weitere bekannte Tasks aus
    if ($Task.TaskName -like 'User_Feed_Synchronization*' -or
        $Task.TaskName -like 'Optimize Start Menu Cache Files*' -or
        $Task.TaskName -like 'MicrosoftEdgeUpdateTaskMachineCore*' -or
        $Task.TaskName -like 'MicrosoftEdgeUpdateTaskMachineUA*' -or
        $Task.TaskName -like 'ZoomUpdateTaskUse*' -or
        $Task.TaskName -like 'Teamviewer-QS-updater*') {
        $ShouldExclude = $true
    }
    
    # Schließe G DATA Tasks aus
    if ($Task.TaskPath -like '\G DATA\*') {
        $ShouldExclude = $true
    }
    
    # Überspringe ausgeschlossene Tasks
    if ($ShouldExclude) {
        continue
    }
    
    # Hole Task-Informationen
    $TaskInfo = Get-ScheduledTaskInfo -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction SilentlyContinue
    
    if ($TaskInfo) {
        # LastTaskResult: 0 oder 0x0 = Erfolg, alles andere = Fehler
        if ($TaskInfo.LastTaskResult -ne 0) {
            $FailedTasks += [PSCustomObject]@{
                TaskName       = $Task.TaskName
                TaskPath       = $Task.TaskPath
                LastRunTime    = $TaskInfo.LastRunTime
                LastResult     = "0x{0:X}" -f $TaskInfo.LastTaskResult
                State          = $Task.State
            }
        }
    }
}

# Ausgabe und Exit-Code
if ($FailedTasks.Count -eq 0) {
    Write-Output "Alle geplanten Aufgaben sind fehlerfrei."
    exit 0
}
else {
    Write-Output "Es wurden $($FailedTasks.Count) fehlerhafte Task(s) gefunden:"
    Write-Output ""
    
    foreach ($Failed in $FailedTasks) {
        Write-Output "Task: $($Failed.TaskPath)$($Failed.TaskName)"
        Write-Output "  Status: $($Failed.State)"
        Write-Output "  Letzter Lauf: $($Failed.LastRunTime)"
        Write-Output "  Fehlercode: $($Failed.LastResult)"
        Write-Output "---"
    }
    
    exit 1
}
