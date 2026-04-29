# ============================================================
# Alpha Desk — Crypto Macro Auto-Updater v2
# Pokrece Claude da analizira vijesti i pusha macro-context.json
# Raspored: svakih 3 sata (Task Scheduler)
# Novo: fearGreed, regime, sentimentScore direktno uparen sa signal engineom
# ============================================================

$REPO_PATH  = "C:\Users\ttovernic\Downloads\Alphadesk"
$JSON_PATH  = "$REPO_PATH\macro-context.json"
$GIT_PATH   = "C:\Program Files\Git\mingw64\bin\git.exe"

# Dodaj git u PATH ako nije
$env:PATH = "C:\Program Files\Git\mingw64\bin;C:\Program Files\Git\cmd;" + $env:PATH

# ── TOKEN ────────────────────────────────────────────────────
$GITHUB_TOKEN = [System.Environment]::GetEnvironmentVariable('ALPHADESK_GH_TOKEN','User')
if (-not $GITHUB_TOKEN) { $GITHUB_TOKEN = $env:ALPHADESK_GH_TOKEN }
if (-not $GITHUB_TOKEN) {
    Write-Host "[ERROR] ALPHADESK_GH_TOKEN nije postavljen." -ForegroundColor Red
    exit 1
}

# ── 1. Pull najnovijeg stanja ─────────────────────────────────
Write-Host "[1/5] Pull s GitHuba..."
Set-Location $REPO_PATH
& git pull "https://$GITHUB_TOKEN@github.com/pajdo2/alphadesk.git" main 2>&1 | Out-Null

# ── 1b. Ucitaj prethodni JSON za change detection ─────────────
$PREV_CONTEXT = ""
if (Test-Path $JSON_PATH) {
    try {
        $prevParsed = Get-Content $JSON_PATH -Raw | ConvertFrom-Json
        $PREV_CONTEXT = @"

## PRETHODNI PODACI (za usporedbu i change detection):
- Datum zadnje analize: $($prevParsed.lastUpdated)
- DXY tada: $($prevParsed.dxy)
- Oil tada: $($prevParsed.oil)
- BTC dominance tada: $($prevParsed.btcDom)%
- Fear & Greed tada: $($prevParsed.fearGreed)
- Regime tada: $($prevParsed.regime)
- macroPenalty tada: $($prevParsed.macroPenalty)
- aiSummary tada: $($prevParsed.aiSummary)

U changeSummary naglasi sto se promijenilo od zadnje analize (porast/pad DXY, FG, dominance itd).
"@
        Write-Host "[1b] Prethodni JSON ucitan za usporedbu (datum: $($prevParsed.lastUpdated))"
    } catch {
        Write-Host "[1b] Prethodni JSON nije mogao biti ucitan — nastavljam bez njega."
    }
}

# ── 2. Claude analiza ────────────────────────────────────────
Write-Host "[2/5] Claude analizira trziste..."

$PROMPT = @"
Ti si crypto market analyst koji radi azuriranje makro konteksta za trading dashboard.
Tvoj output DIREKTNO utjece na signal engine — svako polje ima konkretan ucinak na scoring.

## TOKENI: BTC, ETH, XRP, SOL, BNB, ADA, LINK, AVAX, SUI
$PREV_CONTEXT
## KORACI — izvrsi SVE pretrage:

1. WebSearch pretrage:
   - "crypto fear greed index today site:alternative.me OR coinmarketcap.com"
   - "bitcoin dominance today percentage site:coinmarketcap.com OR coingecko.com"
   - "crude oil WTI price today"
   - "DXY US dollar index today"
   - "stablecoin dominance USDT USDC today percentage"
   - "Bitcoin BTC news today 2026"
   - "Ethereum ETH news today 2026"
   - "XRP Ripple news today 2026"
   - "Solana SOL news today 2026"
   - "BNB Binance news today 2026"
   - "Chainlink LINK news today 2026"
   - "Avalanche AVAX news today 2026"
   - "Cardano ADA news today 2026"
   - "Sui SUI crypto news today 2026"

2. Nakon pretrage, napisi TOCNO ovu JSON strukturu u datoteku: $JSON_PATH

POJASNJENJA POLJA (citaj pazljivo — svako polje direktno ulazi u signal engine):

"fearGreed": broj 0-100
  0-24 = Extreme Fear (bullish signal za kupnju), 25-49 = Fear, 50-74 = Greed, 75-100 = Extreme Greed (bearish signal)

"regime": jedna od tocno ovih vrijednosti:
  "BULL"        — BTC iznad SMA200, FG > 55, altovi rastu
  "BEAR"        — BTC ispod SMA200, FG < 30, kapital izlazi
  "ALT_SEASON"  — BTC dom < 45%, altovi outperformaju BTC
  "CRAB"        — sideways, FG 35-55, nema jasnog trenda
  "VOLATILE"    — veliki swingovi, nejasno, visoki ATR
  "NEUTRAL"     — default kada nije jasno

"macroPenalty": broj 0-6, zbroji bodove prema ovim pravilima:
  +2 ako warActive = true (geopoliticki rat aktivno utjece na trzista)
  +2 ako DXY > 108 (jako jak dolar = bearish kripto), +1 ako DXY 106-108
  -1 ako DXY < 100 (slab dolar = bullish kripto)
  +1 ako Oil > 110 (inflacijski pritisak), +2 ako Oil > 125
  +1 ako fearGreed > 75 (trziste je pohlepno = rizik korekcije)
  -1 ako fearGreed < 20 (ekstremni strah = kupovna prilika, smanji penalty)
  Ukupno: zaokruzi na 0-6

"sentimentScore": za svaki token, broj od -3 do +3:
  +3 = izuzetno bullish (ETF odobrenje, velicina institucionalnog ulaska, halving)
  +2 = bullish (pozitivna regulacija, veliki partnership, strong upgrade)
  +1 = blago pozitivno (manje dobre vijesti, rast ekosustava)
   0 = neutralno, nema znacajnih vijesti
  -1 = blago negativno (manja prodaja, FUD, sitni problemi)
  -2 = bearish (negativna regulacija, hack manjih razmjera, whale dump)
  -3 = izuzetno bearish (SEC tuzba, veliki hack, ban, whale panic sell)

"catalysts": lista bullish vijesti za svaki token, max 65 znakova svaka
"warnings": lista bearish vijesti/rizika za svaki token, max 65 znakova svaka
"aiSummary": 2-3 recenice NA HRVATSKOM, ukljuci: DXY kontekst, fear&greed, sto ocekivati
"changeSummary": 1 recenica NA HRVATSKOM o promjenama od zadnje analize (ako je dostupno)

3. Napisi u datoteku $JSON_PATH TOCNO ovaj format:
{
  "lastUpdated": "<ISO timestamp sada>",
  "warActive": <true ili false>,
  "macroPenalty": <0-6>,
  "oil": <broj>,
  "dxy": <broj>,
  "btcDom": <broj>,
  "stableDom": <broj>,
  "fearGreed": <0-100>,
  "regime": "<BULL|BEAR|ALT_SEASON|CRAB|VOLATILE|NEUTRAL>",
  "aiSummary": "<2-3 recenice HR>",
  "changeSummary": "<1 recenica HR o promjenama>",
  "catalysts": {
    "BTC": ["<vijest max 65 znakova>"],
    "ETH": [], "XRP": [], "SOL": [], "BNB": [],
    "ADA": [], "LINK": [], "AVAX": [], "SUI": []
  },
  "warnings": {
    "BTC": [],
    "ETH": [], "XRP": [], "SOL": [], "BNB": [],
    "ADA": [], "LINK": [], "AVAX": [], "SUI": []
  },
  "sentimentScore": {
    "BTC": 0, "ETH": 0, "XRP": 0, "SOL": 0,
    "BNB": 0, "ADA": 0, "LINK": 0, "AVAX": 0, "SUI": 0
  }
}

VAZNO:
- Napisi SAMO validni JSON u datoteku. Bez markdown blokova, bez komentara, bez objasnjenja.
- Svako polje mora biti prisutno.
- sentimentScore mora imati SVE tokene s brojevima (ne stringove).
- regime mora biti tocno jedna od 6 navedenih vrijednosti.
"@

$claudeExe = "C:\Users\ttovernic\.local\bin\claude.exe"
& $claudeExe --allowedTools "WebSearch,WebFetch,Write" -p $PROMPT

# ── 3. Validacija ─────────────────────────────────────────────
Write-Host "[3/5] Validacija JSON-a..."
if (!(Test-Path $JSON_PATH)) {
    Write-Host "[ERROR] macro-context.json nije kreiran." -ForegroundColor Red
    exit 1
}
try {
    $parsed = Get-Content $JSON_PATH -Raw | ConvertFrom-Json
    if (-not $parsed.lastUpdated) { throw "Nedostaje lastUpdated" }
    if ($null -eq $parsed.fearGreed) { throw "Nedostaje fearGreed" }
    if (-not $parsed.regime) { throw "Nedostaje regime" }
    if ($null -eq $parsed.sentimentScore) { throw "Nedostaje sentimentScore" }
    $validRegimes = @("BULL","BEAR","ALT_SEASON","CRAB","VOLATILE","NEUTRAL")
    if ($validRegimes -notcontains $parsed.regime) { throw "Nevalidan regime: $($parsed.regime)" }
    Write-Host "[3/5] JSON validan." -ForegroundColor Green
    Write-Host "      Datum:      $($parsed.lastUpdated)"
    Write-Host "      Oil:        $($parsed.oil) | DXY: $($parsed.dxy) | BTC Dom: $($parsed.btcDom)%"
    Write-Host "      Fear&Greed: $($parsed.fearGreed) | Regime: $($parsed.regime) | Penalty: $($parsed.macroPenalty)"
    Write-Host "      BTC sent:   $($parsed.sentimentScore.BTC) | ETH: $($parsed.sentimentScore.ETH) | SOL: $($parsed.sentimentScore.SOL)"
} catch {
    Write-Host "[ERROR] JSON nije validan: $_" -ForegroundColor Red
    exit 1
}

# ── 4. Retry ako nedostaju kljucna polja ──────────────────────
# (Opcija: dodaj retry logiku ovdje ako je potrebno)

# ── 5. Git commit + push ──────────────────────────────────────
Write-Host "[5/5] Commit i push na GitHub..."

Set-Location $REPO_PATH
& git config user.email "claude-agent@localhost"
& git config user.name "Claude Agent"
& git add macro-context.json
$ts = Get-Date -Format "yyyy-MM-ddTHH:mm"
$regimeTag = if ($parsed.regime) { $parsed.regime.ToLower() } else { "neutral" }
& git commit -m "macro: $regimeTag · FG $($parsed.fearGreed) · DXY $($parsed.dxy) · $ts"
& git push "https://$GITHUB_TOKEN@github.com/pajdo2/alphadesk.git" master:main 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Gotovo! macro-context.json azuriran." -ForegroundColor Green
    Write-Host "  $($parsed.aiSummary)"
    if ($parsed.changeSummary) { Write-Host "  Promjene: $($parsed.changeSummary)" -ForegroundColor Cyan }
} else {
    Write-Host "[ERROR] Push nije uspio (exit $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}
