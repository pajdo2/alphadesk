# ============================================================
# Alpha Desk — Crypto Macro Auto-Updater
# Pokrece Claude da analizira vijesti i pusha macro-context.json
# Raspored: svakih 3 sata (Task Scheduler)
# ============================================================

# ── TOKEN: čita iz Windows Credential Manager ────────────────
function Get-AlphadeskToken {
    try {
        $cred = Get-StoredCredential -Target "AlphadeskGitHub" -ErrorAction SilentlyContinue
        if ($cred) { return $cred.GetNetworkCredential().Password }
    } catch {}
    # Fallback: env varijabla ili trajni registry
    $tok = [System.Environment]::GetEnvironmentVariable('ALPHADESK_GH_TOKEN','User')
    if ($tok) { return $tok }
    $tok = $env:ALPHADESK_GH_TOKEN
    if ($tok) { return $tok }
    return $null
}

$GITHUB_TOKEN = Get-AlphadeskToken
if (-not $GITHUB_TOKEN) {
    Write-Host "[ERROR] GitHub token nije pronaden. Pokreni setup-alphadesk.ps1 da konfiguriras token." -ForegroundColor Red
    exit 1
}

$REPO_URL = "https://github.com/ttovernic/alphadesk.git"
$REPO_PATH = "$env:USERPROFILE\alphadesk-data"
$JSON_PATH = "$REPO_PATH\macro-context.json"

# ── 1. Kloniraj ili ažuriraj lokalni repo ────────────────────
if (!(Test-Path $REPO_PATH)) {
    Write-Host "[1/4] Kloniram repozitorij..."
    git clone "https://$GITHUB_TOKEN@github.com/ttovernic/alphadesk.git" $REPO_PATH
} else {
    Write-Host "[1/4] Azuriram repozitorij..."
    Set-Location $REPO_PATH
    git pull --rebase "https://$GITHUB_TOKEN@github.com/ttovernic/alphadesk.git" main 2>&1 | Out-Null
}

Set-Location $REPO_PATH

# ── 2. Pokretanje Claude analize ─────────────────────────────
Write-Host "[2/4] Pokrecam Claude analizu vijesti..."

$PROMPT = @"
Ti si crypto market analyst. Tvoj zadatak je pretraziti najnovije vijesti i trzisne uvjete te napisati azurirani macro-context.json.

## TOKENI: BTC, ETH, XRP, SOL, BNB, ADA, LINK, AVAX, SUI

## KORACI:

1. WebSearch pretrage (izvrsi svaku):
   - "crypto fear greed index today"
   - "bitcoin dominance today percentage"
   - "crude oil price today"
   - "stablecoin dominance crypto today"
   - "geopolitical risk crypto today"
   - "Bitcoin BTC news today"
   - "Ethereum ETH news today"
   - "XRP Ripple news today"
   - "Solana SOL news today"
   - "BNB Binance news today"
   - "Chainlink LINK news today"
   - "Avalanche AVAX news today"
   - "Cardano ADA news today"
   - "Sui SUI crypto news today"

2. Na temelju rezultata napisi tocno ovu JSON strukturu u datoteku: $JSON_PATH

{
  "lastUpdated": "<ISO timestamp sada>",
  "warActive": <true/false — ima li aktivnog geopolitickog rata koji utjece na trziste>,
  "macroPenalty": <0-6 — koliko jak je macro negativni pritisak>,
  "oil": <cijena WTI nafte u USD>,
  "btcDom": <BTC dominance postotak>,
  "stableDom": <ukupna stablecoin dominance postotak>,
  "aiSummary": "<2-3 recenice na hrvatskom o trenutnom trzistu>",
  "catalysts": {
    "BTC": ["<pozitivna vijest max 65 znakova>"],
    "ETH": [], "XRP": [], "SOL": [], "BNB": [],
    "ADA": [], "LINK": [], "AVAX": [], "SUI": []
  },
  "warnings": {
    "BTC": ["<negativna vijest max 65 znakova>"],
    "ETH": [], "XRP": [], "SOL": [], "BNB": [],
    "ADA": [], "LINK": [], "AVAX": [], "SUI": []
  }
}

VAZNO: Napisi SAMO validni JSON bez komentara ili markdown blokova.
"@

claude --allowedTools "WebSearch,WebFetch,Write" -p $PROMPT

# ── 3. Provjeri je li datoteka kreirana ──────────────────────
if (!(Test-Path $JSON_PATH)) {
    Write-Host "[ERROR] macro-context.json nije kreiran. Provjeri Claude CLI instalaciju." -ForegroundColor Red
    exit 1
}

Write-Host "[3/4] macro-context.json kreiran."

# ── 4. Commit i push na GitHub ───────────────────────────────
Write-Host "[4/4] Pusham na GitHub..."

Set-Location $REPO_PATH
git config user.email "claude-agent@localhost"
git config user.name "Claude Agent"
git add macro-context.json
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm"
git commit -m "macro: auto-update $timestamp"
git push "https://$GITHUB_TOKEN@github.com/ttovernic/alphadesk.git" HEAD:main

Write-Host ""
Write-Host "OK macro-context.json azuriran i pushani na GitHub!" -ForegroundColor Green
Write-Host "   Vidljivo na: https://raw.githubusercontent.com/ttovernic/alphadesk/main/macro-context.json"
