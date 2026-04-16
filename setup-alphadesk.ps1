# ============================================================
# Alpha Desk — SETUP SKRIPTA
# Pokrenuti jednom kao Administrator da postavi:
#   1. GitHub token (trajno, sigurno)
#   2. Windows Task Scheduler — svaka 3 sata automatski
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Alpha Desk — Automatski Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$SCRIPT_PATH = "$env:USERPROFILE\Downloads\Alphadesk\update-macro.ps1"
$TASK_NAME   = "AlphadeskMacroUpdate"

# ── KORAK 1: GitHub token ────────────────────────────────────
Write-Host "[1/3] GitHub Personal Access Token" -ForegroundColor Yellow
Write-Host "      Idi na: github.com → Settings → Developer settings → Personal access tokens"
Write-Host "      Scope koji treba: repo (read + write contents)"
Write-Host ""

$existingToken = [System.Environment]::GetEnvironmentVariable('ALPHADESK_GH_TOKEN','User')
if ($existingToken) {
    Write-Host "      Token vec postoji: " -NoNewline
    Write-Host ($existingToken.Substring(0,[Math]::Min(8,$existingToken.Length)) + "...") -ForegroundColor Green
    $useExisting = Read-Host "      Koristiti postojeci? (Y/n)"
    if ($useExisting -eq 'n' -or $useExisting -eq 'N') { $existingToken = $null }
}

if (-not $existingToken) {
    $secureToken = Read-Host "      Upiši GitHub token (ghp_...)" -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

    if (-not $plainToken -or $plainToken.Length -lt 10) {
        Write-Host "      [ERROR] Token je prazan ili prekratak." -ForegroundColor Red
        exit 1
    }

    # Spremi kao trajnu User env varijablu
    [System.Environment]::SetEnvironmentVariable('ALPHADESK_GH_TOKEN', $plainToken, 'User')
    Write-Host "      Token spremljen trajno." -ForegroundColor Green
}

# ── KORAK 2: Provjeri da update-macro.ps1 postoji ───────────
Write-Host ""
Write-Host "[2/3] Provjera skripte..." -ForegroundColor Yellow
if (!(Test-Path $SCRIPT_PATH)) {
    Write-Host "      [ERROR] Ne mogu naci: $SCRIPT_PATH" -ForegroundColor Red
    Write-Host "      Provjeri da je Alphadesk mapa u Downloads." -ForegroundColor Red
    exit 1
}
Write-Host "      Skripta pronađena: $SCRIPT_PATH" -ForegroundColor Green

# ── KORAK 3: Task Scheduler ──────────────────────────────────
Write-Host ""
Write-Host "[3/3] Registriram Windows Task Scheduler..." -ForegroundColor Yellow

# Ukloni stari task ako postoji
Unregister-ScheduledTask -TaskName $TASK_NAME -Confirm:$false -ErrorAction SilentlyContinue

# PowerShell executable
$psExe = (Get-Command powershell.exe).Source

# Action: pokrenuti update-macro.ps1
$action = New-ScheduledTaskAction `
    -Execute $psExe `
    -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$SCRIPT_PATH`""

# Trigger: svaka 3 sata, pocevsi od sljedeće pune ure
$startTime = (Get-Date).Date.AddHours([Math]::Ceiling((Get-Date).Hour + 1))
$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Hours 3) `
    -Once `
    -At $startTime `
    -RepetitionDuration ([TimeSpan]::MaxValue)

# Postavke: pokrenuti i kad nije logiran, ne budit računalo
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

# Registracija — koristi trenutnog korisnika
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TASK_NAME `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Alpha Desk: Claude automatski analizira crypto macro i pushа na GitHub" `
    -Force | Out-Null

# Provjeri
$task = Get-ScheduledTask -TaskName $TASK_NAME -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "      Task registriran!" -ForegroundColor Green
    Write-Host "      Ime:      $TASK_NAME"
    Write-Host "      Ucestalost: svaka 3 sata"
    Write-Host "      Sljedece pokretanje: $startTime"
} else {
    Write-Host "      [ERROR] Task nije registriran. Pokreni kao Administrator." -ForegroundColor Red
    exit 1
}

# ── ZAVRŠETAK ─────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup završen!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Claude ce automatski azurirati macro analizu svaka 3 sata."
Write-Host "  Mozete i rucno pokrenuti: Start-ScheduledTask -TaskName '$TASK_NAME'"
Write-Host ""
Write-Host "  Zelite li pokrenuti analizu ODMAH? (Y/n)" -NoNewline
$runNow = Read-Host " "
if ($runNow -ne 'n' -and $runNow -ne 'N') {
    Write-Host ""
    Write-Host "  Pokrecem analizu..." -ForegroundColor Yellow
    & $SCRIPT_PATH
}
