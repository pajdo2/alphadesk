// .github/scripts/track.mjs — 24/7 auto-close aktivnih predikcija (preporuka #1)
// Cita tracker.json, dohvaca cijene s Binancea, zatvara predikcije po
// stop / target / time-exit. Commit samo na stvarnu promjenu.
//
// Komplementira app logiku: parcijalni TP / chandelier / CHoCH rade kad je
// app OTVOREN (trebaju TA podatke). Ova skripta hvata jednoznacne izlaze
// (stop pogodjen, target pogodjen, vrijeme isteklo) i kad je app zatvoren —
// tako da win-rate zapis ostaje tocan u trenutku dogadjaja, ne retroaktivno.
import fs from 'node:fs';

const FILE = 'tracker.json';
const DAY = 24 * 3600 * 1000;

function readJson() {
  try { return JSON.parse(fs.readFileSync(FILE, 'utf8')); }
  catch (e) { return null; }
}

async function fetchPrice(sym) {
  const pair = String(sym).replace(/USDT$/, '') + 'USDT';
  const urls = [
    `https://api.binance.com/api/v3/ticker/price?symbol=${pair}`,
    `https://api.binance.us/api/v3/ticker/price?symbol=${pair}`
  ];
  for (const u of urls) {
    try {
      const r = await fetch(u);
      if (!r.ok) continue;
      const d = await r.json();
      const p = parseFloat(d.price);
      if (p > 0) return p;
    } catch (e) { /* probaj sljedeci */ }
  }
  return null;
}

function elapsedOf(p) {
  const ts = p.timestamp || parseInt(p.id) || Date.now();
  return Date.now() - ts;
}

async function main() {
  const data = readJson();
  if (!data || !Array.isArray(data.predictions)) {
    console.log('Nema tracker.json ili predictions niza — izlazim.');
    return;
  }
  const active = data.predictions.filter(p => p && p.status === 'AKTIVAN');
  if (!active.length) { console.log('Nema aktivnih predikcija.'); return; }
  console.log(`Aktivnih predikcija: ${active.length}`);

  let changed = 0;
  for (const p of active) {
    const cur = await fetchPrice(p.sym);
    if (cur == null) { console.log(`  Cijena nedostupna: ${p.sym} — preskacem.`); continue; }
    const isShort = p.direction === 'SHORT';
    const pct = isShort ? (p.entry - cur) / p.entry * 100 : (cur - p.entry) / p.entry * 100;

    // peak/valley update (info za analizu)
    if (isShort) {
      if (p.valleyPrice == null || cur < p.valleyPrice) { p.valleyPrice = +cur.toFixed(8); p.valleyPct = +((p.entry - cur) / p.entry * 100).toFixed(2); }
    } else {
      if (p.peakPrice == null || cur > p.peakPrice) { p.peakPrice = +cur.toFixed(8); p.peakPct = +((cur - p.entry) / p.entry * 100).toFixed(2); }
    }
    // milestone d-hitovi
    const tgt = p.target;
    if (isShort) {
      if (cur <= (p.d1Target || tgt)) p.d1Hit = true;
      if (cur <= (p.d2Target || tgt)) p.d2Hit = true;
      if (cur <= tgt) p.d3Hit = true;
    } else {
      if (cur >= (p.d1Target || tgt)) p.d1Hit = true;
      if (cur >= (p.d2Target || tgt)) p.d2Hit = true;
      if (cur >= tgt) p.d3Hit = true;
    }

    const elapsed = elapsedOf(p);
    const windowDays = p.targetPct === 10 ? 5 : 3;
    let reason = null, hit = false;
    if (isShort) {
      if (cur >= p.stop) { reason = '🛑 Stop-loss (24/7)'; hit = false; }
      else if (cur <= tgt) { reason = '🎯 Target (24/7)'; hit = true; }
      else if (elapsed >= windowDays * DAY) { reason = '⏰ Vrijeme isteklo (24/7)'; hit = cur < p.entry; }
    } else {
      if (cur <= p.stop) { reason = '🛑 Stop-loss (24/7)'; hit = false; }
      else if (cur >= tgt) { reason = '🎯 Target (24/7)'; hit = true; }
      else if (elapsed >= windowDays * DAY) { reason = '⏰ Vrijeme isteklo (24/7)'; hit = cur > p.entry; }
    }

    if (reason) {
      // Blended P&L ako je app vec uzeo parcijalni TP (50% na D1)
      let finalPct = +pct.toFixed(2);
      if (p.partialHit && p.partialPct != null) {
        finalPct = +(0.5 * p.partialPct + 0.5 * pct).toFixed(2);
        hit = finalPct > 0;
      }
      p.status = hit ? 'POGODAK' : 'PROMAŠAJ';
      p.closePrice = +cur.toFixed(8);
      p.closePct = finalPct;
      p.autoClose = true;
      p.closeReason = reason;
      changed++;
      console.log(`  Zatvoren ${p.sym}: ${p.status} ${p.closePct}% (${reason})`);
    }
  }

  if (changed > 0) {
    data.updatedAt = new Date().toISOString();
    fs.writeFileSync(FILE, JSON.stringify(data, null, 2));
    console.log(`Azurirano ${changed} predikcija — tracker.json zapisan.`);
  } else {
    console.log('Nema promjena.');
  }
}

main().catch(e => { console.error('Greska:', e); process.exitCode = 1; });
