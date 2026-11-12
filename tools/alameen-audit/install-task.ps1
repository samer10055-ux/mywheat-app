# install-task.ps1
# Registers a daily Windows Scheduled Task that runs audit-ameen.ps1 every morning.
# Run this ONCE, as Administrator, from the same folder as audit-ameen.ps1.

$ErrorActionPreference = "Stop"

$scriptPath = Join-Path $PSScriptRoot "audit-ameen.ps1"
if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: audit-ameen.ps1 not found next to this script. Put both files in the same folder." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

$taskName = "AmnAudit-Daily"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Daily -At "8:00AM"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Daily read-only audit of Al-Ameen database (AmnMwh26)" | Out-Null

Write-Host "Task '$taskName' installed. It will run every day at 8:00 AM." -ForegroundColor Green
Write-Host "Reports will be saved to: $env:USERPROFILE\Desktop\AmnAudit\"
Write-Host ""
Write-Host "To run it right now as a test, run:"
Write-Host "  Start-ScheduledTask -TaskName `"$taskName`""
Read-Host "Press Enter to close"
