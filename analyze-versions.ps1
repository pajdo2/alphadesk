$tracker = Get-Content tracker.json -Raw | ConvertFrom-Json
$preds = $tracker.predictions

# Definicija feature perioda (datum kad je feature stupio na snagu)
$periods = @(
    @{ from = "2026-04-17 00:00"; to = "2026-04-27 20:00"; name = "Apr 17-27: pre-v3.8"; features = "Base scoring engine" }
    @{ from = "2026-04-27 20:00"; to = "2026-04-28 12:00"; name = "Apr 27-28: v3.8-v3.9"; features = "Meme tab 5 poboljsanja, liq heatmap, TA filter" }
    @{ from = "2026-04-28 12:00"; to = "2026-04-28 22:00"; name = "Apr 28: v4.0-v4.2"; features = "Pregled tab, dnevne preporuke, funding sentiment, RSI div, CVD tieri" }
    @{ from = "2026-04-28 22:00"; to = "2026-04-29 09:00"; name = "Apr 28-29: v4.2+"; features = "Wyckoff, ATR-aware, conf bucketi, 8 novih signala (Bayesian, vikend, korelacija)" }
    @{ from = "2026-04-29 09:00"; to = "2026-04-29 21:30"; name = "Apr 29: v4.3+"; features = "Per-signal attribution backtest, Pregled scan unified, Tier 1 entry gates" }
)

Write-Host ""
Write-Host "=== UKUPNO ==="
Write-Host ("Total predikcija: {0}" -f $preds.Count)
$closed = $preds | Where-Object { $_.status -ne "AKTIVAN" }
$wins = $preds | Where-Object { $_.status -eq "POGODAK" }
Write-Host ("Zatvorenih: {0} | Pogodci: {1} | Win rate ukupno: {2}%" -f $closed.Count, $wins.Count, [Math]::Round($wins.Count/$closed.Count*100,1))
Write-Host ""

Write-Host "=== WIN RATE PO FEATURE PERIODU ==="
Write-Host ""
$fmt = "{0,-35} {1,7} {2,6} {3,6} {4,8} {5,9}"
Write-Host ($fmt -f "Period","Total","Wins","Loss","WinRate","AvgConf")
Write-Host ("-" * 80)

foreach ($p in $periods) {
    $fromTs = ([DateTimeOffset]::Parse($p.from, [System.Globalization.CultureInfo]::InvariantCulture)).ToUnixTimeMilliseconds()
    $toTs   = ([DateTimeOffset]::Parse($p.to,   [System.Globalization.CultureInfo]::InvariantCulture)).ToUnixTimeMilliseconds()
    $bucket = $preds | Where-Object { $_.timestamp -ge $fromTs -and $_.timestamp -lt $toTs -and $_.status -ne "AKTIVAN" }
    if ($bucket.Count -eq 0) { continue }
    $w = ($bucket | Where-Object { $_.status -eq "POGODAK" }).Count
    $l = ($bucket | Where-Object { $_.status -eq "PROMAŠAJ" -or $_.status -eq "PROMASAJ" -or $_.status -like "PROMA*" }).Count
    $wr = [Math]::Round($w/$bucket.Count*100,1)
    $avgConf = [Math]::Round(($bucket | Measure-Object -Property conf -Average).Average, 1)
    Write-Host ($fmt -f $p.name, $bucket.Count, $w, $l, "$wr%", "$avgConf%")
}

Write-Host ""
Write-Host "=== TOP 10 NAJBOLJIH PREDIKCIJA (po conf rangu, samo POGODCI) ==="
$wins = $preds | Where-Object { $_.status -eq "POGODAK" } | Sort-Object -Property conf -Descending | Select-Object -First 10
foreach ($w in $wins) {
    $d = [DateTimeOffset]::FromUnixTimeMilliseconds($w.timestamp).ToString("MM-dd HH:mm")
    Write-Host ("  {0,-8} conf {1,3}% target +{2}% [{3}]" -f $w.sym, $w.conf, $w.targetPct, $d)
}

Write-Host ""
Write-Host "=== WIN RATE PO CONF BUCKETIMA (svi zatvoreni) ==="
$buckets = @(
    @{ name = "<40%";   min = 0;   max = 40 }
    @{ name = "40-50%"; min = 40;  max = 50 }
    @{ name = "50-60%"; min = 50;  max = 60 }
    @{ name = "60-70%"; min = 60;  max = 70 }
    @{ name = "70-80%"; min = 70;  max = 80 }
    @{ name = ">=80%";  min = 80;  max = 999 }
)
Write-Host ("{0,-10} {1,7} {2,6} {3,8}" -f "Conf","Total","Wins","WinRate")
Write-Host ("-" * 38)
foreach ($b in $buckets) {
    $bk = $closed | Where-Object { $_.conf -ge $b.min -and $_.conf -lt $b.max }
    if ($bk.Count -eq 0) { continue }
    $w = ($bk | Where-Object { $_.status -eq "POGODAK" }).Count
    $wr = [Math]::Round($w/$bk.Count*100,1)
    Write-Host ("{0,-10} {1,7} {2,6} {3,8}" -f $b.name, $bk.Count, $w, "$wr%")
}

Write-Host ""
Write-Host "=== POGODCI vs PROMASAJI — confidence usporedba ==="
$winConf = ($wins | Measure-Object -Property conf -Average).Average
$lossPreds = $preds | Where-Object { $_.status -like "PROMA*" }
$lossConf = ($lossPreds | Measure-Object -Property conf -Average).Average
Write-Host ("Avg conf POGODAKA:    {0}%" -f [Math]::Round($winConf, 1))
Write-Host ("Avg conf PROMASAJA:   {0}%" -f [Math]::Round($lossConf, 1))
$delta = [Math]::Round($winConf - $lossConf, 1)
Write-Host "Delta:                $delta pt"
