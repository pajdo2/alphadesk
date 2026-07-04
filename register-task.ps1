$SCRIPT_PATH = "C:\Users\ttovernic\Downloads\Alphadesk\update-macro.ps1"
$psExe = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"

Unregister-ScheduledTask -TaskName "AlphadeskMacroUpdate" -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction `
    -Execute $psExe `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`""

$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Hours 3) `
    -Once -At (Get-Date) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName "AlphadeskMacroUpdate" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Alpha Desk: Claude macro auto-update svaka 3 sata" `
    -Force | Out-Null

$t = Get-ScheduledTask -TaskName "AlphadeskMacroUpdate" -ErrorAction SilentlyContinue
if ($t) {
    $info = Get-ScheduledTaskInfo -TaskName "AlphadeskMacroUpdate"
    Write-Host "OK Task registriran! Sljedece: $($info.NextRunTime)" -ForegroundColor Green
    Start-ScheduledTask -TaskName "AlphadeskMacroUpdate"
    Write-Host "OK Analiza pokrenuta!" -ForegroundColor Green
} else {
    Write-Host "GRESKA: Task nije registriran." -ForegroundColor Red
}
