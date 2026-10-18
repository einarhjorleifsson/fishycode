// The vessel overview page's script (plan 030 step 4; decisions 140 and 143). One vessel at a time, over a range of
// years. The R service sends each panel's rows once, as parquet; DuckDB-WASM holds them, and every interaction runs
// here with no further request (decision 137, ask h).
//
// Two modes on one page (maintainer, 2026-10-18: "the user could be a quality control person or just a layman"):
// - Overview, in plain words: a summary, the map, the speed chart with trips, hauls and landings marked, and a trip
//   table that opens into its hauls.
// - Quality control: the same, and every record with its basis; an event lane on the chart's time axis (logbook trip,
//   setting, fishing, hauling, landing, stays in port, voyages, the flow's fishing flag, AIS gaps); per-trip warnings
//   where the logbook's hauls and the pings' fishing flag disagree; and the pings of the window.
// The map, the chart, the lane and the slider share one time window. The map's layers follow the maintainer's asjo app
// (plan 030 §4.2). Internal use only: the photos are a newspaper's.
import * as duckdb from 'https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@1.28.0/+esm';

const $ = (id) => document.getElementById(id);
const TOKEN = document.querySelector('meta[name="mapbox-token"]').content;
const status = (msg) => { $('status').textContent = msg; };
const fmt = (ms) => (ms == null ? '' : new Date(ms).toISOString().slice(0, 16).replace('T', ' '));
const dstr = (ms) => (ms == null ? '' : new Date(ms).toISOString().slice(0, 10));
const esc = (x) => String(x ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const sqlstr = (x) => `'${String(x).replace(/'/g, "''")}'`;
const num = (x, d = 0) => (x == null || x === '' || Number.isNaN(x) ? '' : Number(x).toLocaleString('en-GB', { maximumFractionDigits: d }));
const DAY = 864e5, HOUR = 36e5, GAP = 30 * 6e4;
// The service's version this page was written for (api.R, API_VERSION). A server started before its code changed sends
// another, or none: say so plainly, rather than fail in silence.
const API = '2026-10-18.3';
function banner(html) {
  let b = $('banner');
  if (!b) { b = document.createElement('div'); b.id = 'banner'; document.body.prepend(b); }
  b.style.cssText = 'background:#fee2e2;color:#7f1d1d;padding:10px 16px;border-bottom:1px solid #fca5a5;font-size:14px';
  b.innerHTML = html;
}
window.addEventListener('unhandledrejection', (e) => banner(`Something went wrong: ${esc(e.reason?.message || e.reason)}`));

// DuckDB-WASM ---------------------------------------------------------------------------------------------------------
status('starting DuckDB');
const bundle = await duckdb.selectBundle(duckdb.getJsDelivrBundles());
const workerUrl = URL.createObjectURL(new Blob([`importScripts("${bundle.mainWorker}");`], { type: 'text/javascript' }));
const db = new duckdb.AsyncDuckDB(new duckdb.VoidLogger(), new Worker(workerUrl));
await db.instantiate(bundle.mainModule, bundle.pthreadWorker);
const conn = await db.connect();

// A panel's rows: fetched as parquet, then held as a DuckDB table. Fetches run together, ingestion one at a time.
let fileNo = 0;
const fetchParquet = async (endpoint, params) => {
  const r = await fetch(`/api/${endpoint}?${new URLSearchParams(params)}`);
  const v = r.headers.get('X-Overview-Api');
  if (v !== API) {
    banner(`<b>The service is older than this page</b> (service ${esc(v || 'unknown')}, page ${API}). Stop
      <code>server.R</code> with Ctrl-C in its terminal, start it again, and reload this page.`);
    throw new Error('the service and the page differ in version');
  }
  if (!r.ok) throw new Error(`${endpoint}: ${r.status} ${await r.text()}`);
  return new Uint8Array(await r.arrayBuffer());
};
async function ingest(table, buf) {
  const name = `f${++fileNo}.parquet`;
  await db.registerFileBuffer(name, buf);
  await conn.query(`CREATE OR REPLACE TABLE ${table} AS SELECT * FROM '${name}'`);
  await db.dropFile(name);
}
async function loadAll(specs) {
  const bufs = await Promise.all(specs.map(([, endpoint, params]) => fetchParquet(endpoint, params)));
  for (let i = 0; i < specs.length; i++) await ingest(specs[i][0], bufs[i]);
}
const rows = async (sql) => (await conn.query(sql)).toArray().map((r) => r.toJSON());
const table = (cols, data, opts = {}) => data.length
  ? `<table><tr>${cols.map(([, h, n]) => `<th${n ? ' class="n"' : ''}>${h}</th>`).join('')}</tr>${data.map((r, i) =>
      `<tr${opts.click ? ` class="click" data-i="${i}"` : ''}>${cols.map(([k, , n]) => `<td${n ? ' class="n"' : ''}>${r[k] === undefined ? '' : (opts.raw?.includes(k) ? r[k] : esc(r[k]))}</td>`).join('')}</tr>`).join('')}</table>`
  : `<div class="note">${opts.empty || 'none'}</div>`;
// the first index whose value is at least x, in a sorted array
function lower(a, x, key = (v) => v) {
  let lo = 0, hi = a.length;
  while (lo < hi) { const m = (lo + hi) >> 1; if (key(a[m]) < x) lo = m + 1; else hi = m; }
  return lo;
}

// State ----------------------------------------------------------------------------------------------------------------
const S = { vid: null, name: '', mode: 'ov', from: null, to: null, tr: null, win: [0, 0], hover: -1, trip: null,
            stations: [], hauls: [], trips: [], landings: [], years: [], lanes: null, expanded: new Set(), tripPage: 0, pingPage: 0,
            history: false, about: {}, assumed: null, assumedBase: null };
// The gear after the last logbook trip, where no logbook covers the time: the previous logbook trip's (maintainer,
// 2026-10-18: "if a logbook is missing from vessels last trip, assume that the gear is the same gear as from the
// previous trip"). Better still would be the gear read from the track, a TODO of its own (TODO 86).
const gearAt = (t, recorded) => (recorded ? { gear: recorded, assumed: false }
  : S.assumed && t > S.assumed.after && t <= S.assumed.until ? { gear: S.assumed.gear, assumed: true } : { gear: '', assumed: false });
// It applies only where a logbook is missing: the last landing has no logbook trip, and only from the last logbook
// trip's return to that landing. A vessel that stopped fishing gets no assumed gear.
const assumedAt = (t) => S.assumed && t > S.assumed.after && t <= S.assumed.until;
const qc = () => S.mode === 'qc';

// The map ------------------------------------------------------------------------------------------------------------
const INFERNO = [[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66], [245, 125, 21], [250, 193, 39], [252, 255, 164]];
function speedColour(s) {
  const x = (Math.max(0, Math.min(12, s)) / 12) * (INFERNO.length - 1);
  const i = Math.min(Math.floor(x), INFERNO.length - 2), f = x - i, a = INFERNO[i], b = INFERNO[i + 1];
  return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f];
}
const FILTER = new deck.DataFilterExtension({ filterSize: 1 });
const basemap = TOKEN.startsWith('pk.')
  ? new deck.TileLayer({
      id: 'basemap', minZoom: 0, maxZoom: 19, tileSize: 256,
      data: `https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/256/{z}/{x}/{y}?access_token=${TOKEN}`,
      renderSubLayers: (props) => {
        const { west, south, east, north } = props.tile.bbox;
        return new deck.BitmapLayer(props, { data: null, image: props.data, bounds: [west, south, east, north] });
      },
    })
  : null;
$('attrib').textContent = basemap ? '© Mapbox © OpenStreetMap' : 'no basemap: MAPBOX_TOKEN is not set';

let afterRender = null;
const deckgl = new deck.Deck({
  parent: $('map'), controller: true, initialViewState: { longitude: -20, latitude: 64.5, zoom: 5 },
  onAfterRender: () => { if (afterRender) { const f = afterRender; afterRender = null; f(); } },
  getTooltip, onHover: ({ layer, index }) => { if (layer && layer.id === 'pings' && index >= 0) setHover(index, 'map'); },
  layers: basemap ? [basemap] : [],
});

const hours = (ms) => (ms - S.tr.t0) / HOUR;
function layers() {
  const L = basemap ? [basemap] : [], tr = S.tr;
  if (!tr || !tr.n) return L;
  const range = [hours(S.win[0]), hours(S.win[1])];
  L.push(new deck.PathLayer({
    id: 'track', data: tr.paths, getPath: (d) => d.path, widthUnits: 'meters', getWidth: 300, widthMinPixels: 1,
    widthMaxPixels: 5, getColor: [70, 80, 100, 90], pickable: true, autoHighlight: true, highlightColor: [0, 0, 0, 149],
  }));
  L.push(new deck.ScatterplotLayer({
    id: 'pings', data: tr.pingData, radiusUnits: 'meters', getRadius: 400, radiusMinPixels: 2, radiusMaxPixels: 6,
    pickable: true, extensions: [FILTER], filterRange: range,
  }));
  L.push(new deck.LineLayer({
    id: 'stations', data: S.stations, getSourcePosition: (d) => [d.lon1, d.lat1], getTargetPosition: (d) => [d.lon2, d.lat2],
    getColor: (d) => (d.tid === S.trip ? [220, 30, 30, 255] : [20, 20, 20, 210]), getWidth: 3, pickable: true,
    getFilterValue: (d) => hours(d.t1), extensions: [FILTER], filterRange: range,
    updateTriggers: { getColor: S.trip, getFilterValue: tr.t0 },
  }));
  L.push(new deck.ScatterplotLayer({
    id: 'last', data: [tr.n - 1], getPosition: (i) => [tr.lon[i], tr.lat[i]], radiusUnits: 'meters', getRadius: 3000,
    radiusMinPixels: 4, radiusMaxPixels: 20, getFillColor: [255, 0, 240, 128], pickable: true,
  }));
  L.push(new deck.ScatterplotLayer({
    id: 'hover', data: S.hover >= 0 ? [S.hover] : [], getPosition: (i) => [tr.lon[i], tr.lat[i]], radiusUnits: 'pixels',
    getRadius: 7, stroked: true, filled: false, getLineColor: [0, 0, 0, 255], lineWidthMinPixels: 2,
    updateTriggers: { getPosition: S.hover },
  }));
  return L;
}
const render = () => deckgl.setProps({ layers: layers() });

function getTooltip({ layer, index, object }) {
  const tr = S.tr;
  if (!layer || !tr) return null;
  if (layer.id === 'pings' || layer.id === 'last') {
    const i = layer.id === 'last' ? tr.n - 1 : index;
    const head = layer.id === 'last' ? `<b>${esc(S.name)} (${S.vid})</b><br>last position heard<br>` : '';
    const what = tr.fishing[i] ? (qc() ? 'fishing_flow' : 'fishing') : (tr.stay[i] >= 0 ? 'in port' : 'at sea');
    const g = gearAt(tr.t[i], tr.gear[i]);
    const gear = g.gear ? `, ${esc(g.gear)}${g.assumed ? ' (assumed: the previous trip\'s gear)' : ''}` : '';
    return { html: `${head}<b>${fmt(tr.t[i])} UTC</b><br>${num(tr.speed[i], 1)} knots, heading ${num(tr.heading[i])}°<br>` +
      `${what}${gear}<br>${num(tr.lat[i], 4)} N, ${num(tr.lon[i], 4)} E` };
  }
  if (layer.id === 'track' && object) return { text: qc() ? `voyage ${object.voyage}` : 'the track between ports' };
  if (layer.id === 'stations' && object) return { html: `haul on ${esc(object.day)}, ${esc(object.gear)}, ${num(object.kg)} kg<br>gear in ${fmt(object.t1)}, out ${fmt(object.t4)}` };
  return null;
}
function fitTo(a, b) {
  const tr = S.tr; let x0 = 180, x1 = -180, y0 = 90, y1 = -90;
  for (let i = lower(tr.t, a); i < tr.n && tr.t[i] <= b; i++) {
    x0 = Math.min(x0, tr.lon[i]); x1 = Math.max(x1, tr.lon[i]); y0 = Math.min(y0, tr.lat[i]); y1 = Math.max(y1, tr.lat[i]);
  }
  if (x0 > x1) return;
  // a vessel in port for the whole window gives a single point: give the box a least size, about 2 km
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, hx = Math.max((x1 - x0) / 2, 0.02), hy = Math.max((y1 - y0) / 2, 0.01);
  const { width, height } = $('map').getBoundingClientRect();
  try {
    const v = new deck.WebMercatorViewport({ width: Math.max(width, 200), height: Math.max(height, 200) })
      .fitBounds([[cx - hx, cy - hy], [cx + hx, cy + hy]], { padding: Math.min(40, width / 4, height / 4) });
    deckgl.setProps({ initialViewState: { longitude: v.longitude, latitude: v.latitude, zoom: Math.min(v.zoom, 11) } });
  } catch (e) {
    deckgl.setProps({ initialViewState: { longitude: cx, latitude: cy, zoom: 8 } });
  }
}

// The speed chart ----------------------------------------------------------------------------------------------------
let plot = null, lanes = null, cursorFromMap = false;
const SYNC = uPlot.sync('vessel');
// The speed chart and the event lane share one left gutter (axis and its label), so a time falls at the same x in both
const GUTTER = { size: 118, labelSize: 18, labelFont: '600 11px system-ui', font: '11px system-ui' };
const PADDING = [8, 28, null, null];   // a fixed right margin: the chart's last time label no longer widens only the chart
const inside = (arr, t, maxDur) => { for (let i = lower(arr, t - maxDur, (d) => d.a); i < arr.length && arr[i].a <= t; i++) if (arr[i].b >= t) return arr[i]; return null; };
const tripAt = (t) => inside(S.trips, t, 120 * DAY);

function drawTrips(u) {   // bands behind the speed line, one per logbook trip
  const { ctx } = u, { left, top, width, height } = u.bbox, x0 = u.scales.x.min * 1000, x1 = u.scales.x.max * 1000;
  ctx.save(); ctx.beginPath(); ctx.rect(left, top, width, height); ctx.clip();
  for (let i = lower(S.trips, x0 - 120 * DAY, (d) => d.a); i < S.trips.length && S.trips[i].a <= x1; i++) {
    const d = S.trips[i];
    if (d.b < x0) continue;
    const a = u.valToPos(d.a / 1000, 'x', true), b = u.valToPos(d.b / 1000, 'x', true);
    ctx.fillStyle = d.tid === S.trip ? 'rgba(214,39,40,0.16)' : (i % 2 ? 'rgba(31,111,235,0.10)' : 'rgba(31,111,235,0.17)');
    ctx.fillRect(a, top, Math.max(1, b - a), height);
  }
  ctx.restore();
}
function drawMarks(u) {   // hauls as bars at the top, landings as triangles at the bottom
  const { ctx } = u, { left, top, width, height } = u.bbox, x0 = u.scales.x.min * 1000, x1 = u.scales.x.max * 1000;
  const px = devicePixelRatio || 1, h = 6 * px;
  ctx.save(); ctx.beginPath(); ctx.rect(left, top, width, height); ctx.clip();
  for (let i = lower(S.hauls, x0 - 7 * DAY, (d) => d.a); i < S.hauls.length && S.hauls[i].a <= x1; i++) {
    const d = S.hauls[i];
    if (d.b < x0) continue;
    const a = u.valToPos(d.a / 1000, 'x', true), b = u.valToPos(d.b / 1000, 'x', true);
    ctx.fillStyle = '#9aa5b1'; ctx.fillRect(a, top + 2 * px, Math.max(px, b - a), h);
    if (d.t2 != null && d.t3 != null) {
      const c = u.valToPos(d.t2 / 1000, 'x', true), e = u.valToPos(d.t3 / 1000, 'x', true);
      ctx.fillStyle = d.tid === S.trip ? '#b71c1c' : '#2e7d32'; ctx.fillRect(c, top + 2 * px, Math.max(px, e - c), h);
    }
  }
  ctx.fillStyle = '#e07b00';
  for (let i = lower(S.landings, x0 - DAY, (d) => d.d); i < S.landings.length && S.landings[i].d <= x1; i++) {
    const x = u.valToPos((S.landings[i].d + 12 * HOUR) / 1000, 'x', true), y = top + height;
    ctx.beginPath(); ctx.moveTo(x, y - 9 * px); ctx.lineTo(x - 5 * px, y); ctx.lineTo(x + 5 * px, y); ctx.closePath(); ctx.fill();
  }
  ctx.restore();
}
function describe(t) {   // what is going on at time t, in the mode's words
  const tp = tripAt(t), hl = inside(S.hauls, t, 7 * DAY), out = [`${fmt(t)} UTC`];
  if (qc()) {
    if (tp) out.push(`trip ${tp.tid} (${tp.schema}) ${fmt(tp.a)} – ${fmt(tp.b)}`);
    if (hl) out.push(`haul ${hl.sid}: t1 ${fmt(hl.t1)}, t2 ${fmt(hl.t2)}, t3 ${fmt(hl.t3)}, t4 ${fmt(hl.t4)}, ${hl.gear}, ${num(hl.kg)} kg`);
  } else {
    if (tp) out.push(`on a fishing trip, ${dstr(tp.a)} to ${dstr(tp.b)}: ${tp.n} hauls, ${num(tp.kg / 1000, 1)} t`);
    if (hl) out.push(`gear in the water (${hl.gear}), ${num(hl.kg)} kg caught in this haul`);
    if (!tp && !hl) out.push(assumedAt(t)
      ? `no logbook yet; gear assumed ${S.assumed.gear}, as on the previous trip`
      : 'no fishing trip in the logbook at this time');
  }
  if (qc() && !tp && assumedAt(t)) out.push(`after the last logbook trip: gear assumed ${S.assumed.gear} (${S.assumed.tid})`);
  return out.join(' · ');
}
function makePlot() {
  const tr = S.tr;
  plot?.destroy();
  plot = new uPlot({
    width: $('plot').clientWidth || 600, height: 190, legend: { show: false }, padding: PADDING,
    scales: { x: { time: true }, y: { range: [0, Math.max(12, tr.maxSpeed)] } },
    series: [{}, { label: 'speed', stroke: '#1f6feb', width: 1, points: { show: false } },
             { label: 'fishing', stroke: '#d62728', width: 1.5, points: { show: false }, spanGaps: false }],
    axes: [{ font: GUTTER.font }, { ...GUTTER, label: 'knots' }],
    cursor: { sync: { key: SYNC.key }, drag: { x: true, y: false, setScale: false }, points: { show: false } },
    hooks: {
      drawClear: [drawTrips], draw: [drawMarks],
      setSelect: [(u) => {
        if (u.select.width < 3) return;
        const a = u.posToVal(u.select.left, 'x') * 1000, b = u.posToVal(u.select.left + u.select.width, 'x') * 1000;
        u.setSelect({ left: 0, width: 0, top: 0, height: 0 }, false);
        setWindow(a, b, 'plot');
      }],
      setCursor: [(u) => {
        if (u.cursor.left == null || u.cursor.left < 0) { $('hoverinfo').textContent = ''; return; }
        $('hoverinfo').textContent = describe(u.posToVal(u.cursor.left, 'x') * 1000);
        if (!cursorFromMap && u.cursor.idx != null) setHover(u.cursor.idx, 'plot');
      }],
    },
  }, [tr.ts, tr.speed, tr.fishSpeed], $('plot'));
  clickToSelect(plot);
}
// a click (not a drag) on a trip selects it
function clickToSelect(u) {
  let down = null;
  u.over.addEventListener('mousedown', (e) => { down = e.clientX; });
  u.over.addEventListener('mouseup', (e) => {
    const x = down; down = null;
    if (x == null || Math.abs(e.clientX - x) > 3 || u.cursor.left == null) return;
    const tp = tripAt(u.posToVal(u.cursor.left, 'x') * 1000);
    if (tp) selectTrip(tp.tid, tp.schema).catch((err) => status(String(err)));
  });
}

// The event lane (Quality control) -------------------------------------------------------------------------------------
const LANES = [
  ['logbook trip', 'trip', '#1f6feb88'], ['setting t1-t2', 'set', '#9aa5b1'], ['fishing t2-t3', 'fish', '#2e7d32'],
  ['hauling t3-t4', 'haul', '#7b5ea7'], ['landing', 'land', '#e07b00'], ['in port (stay)', 'stay', '#5d6b78'],
  ['voyage', 'voy', '#4a7bd0'], ['fishing_flow', 'flow', '#d62728'], [`AIS gap > ${GAP / 6e4} min`, 'gap', '#111827'],
];
function laneLists() {   // every lane as intervals {a, b} sorted by a, with its longest interval for the search
  const tr = S.tr, L = { trip: S.trips, set: [], fish: [], haul: [], land: [], stay: [], voy: [], flow: [], gap: [] };
  for (const h of S.hauls) {
    if (h.t1 != null && h.t2 != null) L.set.push({ a: h.t1, b: h.t2, h });
    if (h.t2 != null && h.t3 != null) L.fish.push({ a: h.t2, b: h.t3, h });
    if (h.t3 != null && h.t4 != null) L.haul.push({ a: h.t3, b: h.t4, h });
  }
  for (const d of S.landings) L.land.push({ a: d.d, b: d.d + DAY, d });
  if (tr) {
    const runs = (key, ok, out) => {
      let s = -1;
      for (let i = 0; i <= tr.n; i++) {
        const same = i < tr.n && ok(i) && s >= 0 && key(i) === key(s) && tr.t[i] - tr.t[i - 1] <= GAP;
        if (s >= 0 && !same) { out.push({ a: tr.t[s], b: tr.t[i - 1], id: key(s) }); s = -1; }
        if (s < 0 && i < tr.n && ok(i)) s = i;
      }
    };
    runs((i) => tr.stay[i], (i) => tr.stay[i] >= 0, L.stay);
    runs((i) => tr.voyage[i], (i) => tr.voyage[i] >= 0, L.voy);
    runs(() => 1, (i) => tr.fishing[i] === 1, L.flow);
    for (let i = 1; i < tr.n; i++) if (tr.t[i] - tr.t[i - 1] > GAP) L.gap.push({ a: tr.t[i - 1], b: tr.t[i] });
  }
  for (const k of Object.keys(L)) { L[k].sort((x, y) => x.a - y.a); L[k].maxDur = L[k].reduce((m, d) => Math.max(m, d.b - d.a), 0); }
  return L;
}
function drawLanes(u) {
  const { ctx } = u, { left, top, width, height } = u.bbox, x0 = u.scales.x.min * 1000, x1 = u.scales.x.max * 1000;
  const rowH = height / LANES.length;
  ctx.save(); ctx.beginPath(); ctx.rect(left, top, width, height); ctx.clip();
  LANES.forEach(([, key, colour], r) => {
    const arr = S.lanes[key], y = top + r * rowH + rowH * 0.2, h = rowH * 0.6;
    ctx.fillStyle = r % 2 ? '#fafbfc' : '#f1f3f5'; ctx.fillRect(left, top + r * rowH, width, rowH);
    for (let i = lower(arr, x0 - arr.maxDur, (d) => d.a); i < arr.length && arr[i].a <= x1; i++) {
      const d = arr[i];
      if (d.b < x0) continue;
      const a = u.valToPos(d.a / 1000, 'x', true), b = u.valToPos(d.b / 1000, 'x', true);
      ctx.fillStyle = key === 'trip' && d.tid === S.trip ? '#d6272888' : key === 'voy' ? (d.id % 2 ? '#4a7bd0' : '#8ab4f8') : colour;
      ctx.fillRect(a, y, Math.max(key === 'land' ? 3 : 1, b - a), h);
    }
  });
  ctx.restore();
}
function makeLanes() {
  lanes?.destroy(); lanes = null;
  if (!qc() || !S.tr) return;
  const tr = S.tr, n = LANES.length;
  lanes = new uPlot({
    width: $('lanes').clientWidth || 600, height: 22 * n + 30, legend: { show: false }, padding: PADDING,
    scales: { x: { time: true, min: S.win[0] / 1000, max: S.win[1] / 1000 }, y: { range: [0, n] } },
    series: [{}, { show: false }],
    axes: [{ show: false }, { ...GUTTER, label: 'events', splits: () => LANES.map((_, i) => n - i - 0.5), values: () => LANES.map((l) => l[0]),
                              grid: { show: false }, ticks: { show: false } }],
    cursor: { sync: { key: SYNC.key }, drag: { x: true, y: false, setScale: false }, points: { show: false }, y: false },
    hooks: {
      draw: [drawLanes],
      setSelect: [(u) => {
        if (u.select.width < 3) return;
        const a = u.posToVal(u.select.left, 'x') * 1000, b = u.posToVal(u.select.left + u.select.width, 'x') * 1000;
        u.setSelect({ left: 0, width: 0, top: 0, height: 0 }, false);
        setWindow(a, b, 'plot');
      }],
      setCursor: [(u) => {
        if (u.cursor.left == null || u.cursor.left < 0 || u.cursor.top == null || u.cursor.top < 0) return;
        const t = u.posToVal(u.cursor.left, 'x') * 1000, r = Math.min(n - 1, Math.floor(u.cursor.top / (u.bbox.height / devicePixelRatio / n)));
        const [label, key] = LANES[r], d = inside(S.lanes[key], t, S.lanes[key].maxDur);
        const what = !d ? 'nothing' : key === 'trip' ? `trip ${d.tid}, ${fmt(d.a)} – ${fmt(d.b)}`
          : d.h ? `haul ${d.h.sid}, ${fmt(d.a)} – ${fmt(d.b)}` : key === 'land' ? `landing on ${dstr(d.a)}, ${num(d.d.t, 2)} t`
          : key === 'gap' ? `no ping for ${num((d.b - d.a) / 6e4)} min` : `${fmt(d.a)} – ${fmt(d.b)}${d.id != null && key !== 'flow' ? ` (id ${d.id})` : ''}`;
        $('hoverinfo').textContent = `${describe(t)} · lane ${label}: ${what}`;
      }],
    },
  }, [[tr.t0 / 1000, tr.t1 / 1000], [null, null]], $('lanes'));
  clickToSelect(lanes);
}
window.addEventListener('resize', () => {
  plot && plot.setSize({ width: $('plot').clientWidth, height: 190 });
  lanes && lanes.setSize({ width: $('lanes').clientWidth, height: 22 * LANES.length + 30 });
});

function setHover(i, source) {
  S.hover = i;
  render();
  if (source === 'map' && plot) {
    cursorFromMap = true;
    plot.setCursor({ left: plot.valToPos(S.tr.ts[i], 'x'), top: plot.valToPos(S.tr.speed[i], 'y') });
    cursorFromMap = false;
  }
}

// The window: one state, every view ------------------------------------------------------------------------------------
let onRedraw = null, pingTimer = null;
function setWindow(a, b, source) {
  const tr = S.tr;
  if (!tr) return;
  a = Math.max(tr.t0, Math.min(a, tr.t1));
  b = Math.max(a + 6e4, Math.min(b, tr.t1));
  S.win = [a, b];
  const t0 = performance.now();
  if (source !== 'slider') { $('wfrom').value = a / 1000; $('wto').value = b / 1000; }
  plot.setScale('x', { min: a / 1000, max: b / 1000 });
  lanes?.setScale('x', { min: a / 1000, max: b / 1000 });
  $('window-label').textContent = `${fmt(a)} – ${fmt(b)} UTC`;
  afterRender = () => {
    const ms = performance.now() - t0;
    $('perf').textContent = `redraw ${Math.round(ms)} ms, ${tr.n.toLocaleString('en-GB')} pings loaded`;
    if (onRedraw) { const f = onRedraw; onRedraw = null; f(ms); }
  };
  render();
  if (qc()) { clearTimeout(pingTimer); pingTimer = setTimeout(() => { S.pingPage = 0; renderPings(); }, 150); }
}
function slider() {
  let a = +$('wfrom').value * 1000, b = +$('wto').value * 1000;
  if (a > b) [a, b] = [b, a];
  setWindow(a, b, 'slider');
}
$('wfrom').addEventListener('input', slider);
$('wto').addEventListener('input', slider);
$('month').addEventListener('click', () => S.tr && setWindow(S.tr.t1 - 30 * DAY, S.tr.t1));
$('all').addEventListener('click', () => S.tr && setWindow(S.tr.t0, S.tr.t1));
let playing = false;
$('play').addEventListener('click', () => {
  if (!S.tr) return;
  playing = !playing;
  $('play').textContent = playing ? 'Pause' : 'Play';
  const step = () => {
    if (!playing) return;
    const [a, b] = S.win, d = (b - a) / 40;
    if (b + d > S.tr.t1) { playing = false; $('play').textContent = 'Play'; return; }
    setWindow(a + d, b + d);
    requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
});

// Selecting a trip: the window, the map's view, the red band, its row opened ------------------------------------------
async function tripYear(tid, schema) {   // the year a trip landed, from whichever table holds it
  for (const t of ['f_trips', 'h_trips', 'trips']) {
    try {
      const r = (await rows(`SELECT year(T2)::INTEGER AS y FROM ${t} WHERE ".tid" = ${sqlstr(tid)}${schema ? ` AND schema = ${sqlstr(schema)}` : ''}`))[0];
      if (r) return r.y;
    } catch (e) { /* that table is not loaded */ }
  }
  return null;
}
async function selectTrip(tid, schema, opts = {}) {
  let d = S.trips.find((x) => x.tid === tid && (!schema || x.schema === schema));
  if (!d) {   // a trip outside the loaded years: load the year it landed
    const y = await tripYear(tid, schema);
    if (y == null) return;
    await loadRange(y, y);
    d = S.trips.find((x) => x.tid === tid);
    if (!d) return;
  }
  S.trip = d.tid;
  S.expanded.add(d.tid);
  const order = [...S.trips].sort((x, y) => y.a - x.a);
  S.tripPage = Math.floor(order.findIndex((x) => x.tid === d.tid) / TRIPS_PER_PAGE);
  showTab('now');
  const [a, b] = d.span || [d.a, d.b];   // the trip and every haul of it, which the logbook may put outside T1-T2
  if (S.tr) { fitTo(a, b); setWindow(a - HOUR, b + HOUR); plot.redraw(false); lanes?.redraw(false); }
  await renderTrips();
  if (opts.scroll !== false) document.querySelector(`#trips tr[data-tid="${CSS.escape(d.tid)}"]`)?.scrollIntoView({ block: 'nearest' });
}

// The years of trail, trips, hauls and landings --------------------------------------------------------------------
async function loadRange(from, to) {
  const t = performance.now();
  S.from = Math.min(from, to); S.to = Math.max(from, to);
  $('from').value = S.from; $('to').value = S.to;
  status(`loading ${S.from}–${S.to}`);
  const yrs = { vid: S.vid, from: S.from, to: S.to };
  const hasTrail = S.years.some((y) => y >= S.from && y <= S.to);
  await loadAll([...(hasTrail ? [['trail', 'trail', yrs]] : []), ['trips', 'trips', yrs], ['stations', 'stations', yrs],
                 ['station_catch', 'station_catch', yrs], ['landings', 'landings', yrs]]);
  S.trips = await rows(`SELECT t.".tid" AS tid, t.schema, epoch_ms(t.T1)::DOUBLE AS a, epoch_ms(t.T2)::DOUBLE AS b,
      coalesce(t.port, '') AS port, t.T1_basis AS b1, t.T2_basis AS b2, count(s.".sid")::INTEGER AS n,
      coalesce(sum(c.kg), 0)::DOUBLE AS kg
    FROM trips t LEFT JOIN stations s USING (".tid", schema)
    LEFT JOIN (SELECT ".sid", schema, sum(catch) AS kg FROM station_catch GROUP BY ALL) c USING (".sid", schema)
    WHERE t.T1 IS NOT NULL AND t.T2 IS NOT NULL GROUP BY ALL ORDER BY a`);
  S.stations = await rows(`SELECT s.".tid" AS tid, s.schema, s.".sid" AS sid, lon1, lat1, coalesce(lon2, lon1) AS lon2,
      coalesce(lat2, lat1) AS lat2, epoch_ms(coalesce(t1, date))::DOUBLE AS t1, epoch_ms(t2)::DOUBLE AS t2,
      epoch_ms(t3)::DOUBLE AS t3, epoch_ms(coalesce(t4, t3, t2, t1, date))::DOUBLE AS t4, coalesce(gear, '') AS gear,
      coalesce(target, '') AS target, coalesce(gear_basis, '') AS gear_basis, strftime(date, '%Y-%m-%d') AS day, z1, z2, station_type, duration_m, effort, effort_unit,
      coalesce(c.kg, 0)::DOUBLE AS kg
    FROM stations s LEFT JOIN (SELECT ".sid", schema, sum(catch) AS kg FROM station_catch GROUP BY ALL) c USING (".sid", schema)
    WHERE lon1 IS NOT NULL AND lat1 IS NOT NULL ORDER BY t1`);
  S.hauls = S.stations.map((h) => ({ ...h, a: h.t1, b: h.t4 }));
  S.landings = await rows(`SELECT epoch_ms(date)::DOUBLE AS d, round(sum(catch) / 1000, 2)::DOUBLE AS t
    FROM landings GROUP BY ".lid", schema, date ORDER BY d`);
  S.expanded = new Set(); S.tripPage = 0; S.trip = null;
  if (hasTrail) await buildTrail(); else { S.tr = null; plot?.destroy(); plot = null; lanes?.destroy(); lanes = null; $('window-label').textContent = ''; render(); }
  tripChecks();
  S.lanes = laneLists();
  if (S.tr) makeLanes();
  await renderTrips();
  renderSummary();
  if (qc()) renderPings();
  setHash();
  status(`${S.from}–${S.to}: ${S.tr ? S.tr.n.toLocaleString('en-GB') + ' pings, ' : 'no AIS, '}${S.trips.length} trips, ` +
         `${S.stations.length} hauls, ${S.landings.length} landings · ${Math.round(performance.now() - t)} ms`);
}
async function buildTrail() {
  const tbl = await conn.query(`SELECT epoch_ms(time)::DOUBLE AS t, lon::FLOAT AS lon, lat::FLOAT AS lat,
      coalesce(speed, 0)::FLOAT AS speed, coalesce(heading, 0)::FLOAT AS heading, coalesce(voyage, -1)::INTEGER AS voyage,
      coalesce(stay, -1)::INTEGER AS stay, coalesce(fishing_flow, false)::INTEGER AS fishing, coalesce(gear, '') AS gear
    FROM trail WHERE lon IS NOT NULL AND lat IS NOT NULL ORDER BY time`);
  const col = (k) => tbl.getChild(k).toArray();
  const tr = { n: tbl.numRows, t: col('t'), lon: col('lon'), lat: col('lat'), speed: col('speed'), heading: col('heading'),
               voyage: col('voyage'), stay: col('stay'), fishing: col('fishing'), gear: col('gear') };
  if (!tr.n) { S.tr = null; render(); return; }
  tr.t0 = tr.t[0]; tr.t1 = tr.t[tr.n - 1];
  tr.ts = new Float64Array(tr.n); tr.pos = new Float32Array(2 * tr.n); tr.col = new Uint8Array(4 * tr.n);
  tr.th = new Float32Array(tr.n); tr.fishSpeed = new Array(tr.n); tr.fishCum = new Int32Array(tr.n + 1);
  let maxSpeed = 0;
  const byVoyage = new Map();
  for (let i = 0; i < tr.n; i++) {
    tr.ts[i] = tr.t[i] / 1000; tr.th[i] = (tr.t[i] - tr.t0) / HOUR;
    tr.pos[2 * i] = tr.lon[i]; tr.pos[2 * i + 1] = tr.lat[i];
    const c = speedColour(tr.speed[i]);
    tr.col[4 * i] = c[0]; tr.col[4 * i + 1] = c[1]; tr.col[4 * i + 2] = c[2]; tr.col[4 * i + 3] = 230;
    tr.fishSpeed[i] = tr.fishing[i] ? tr.speed[i] : null;
    tr.fishCum[i + 1] = tr.fishCum[i] + (tr.fishing[i] ? 1 : 0);
    if (tr.speed[i] > maxSpeed && tr.speed[i] < 30) maxSpeed = tr.speed[i];
    const v = tr.voyage[i];
    if (v >= 0) { if (!byVoyage.has(v)) byVoyage.set(v, []); byVoyage.get(v).push([tr.lon[i], tr.lat[i]]); }
  }
  tr.maxSpeed = Math.ceil(maxSpeed);
  tr.paths = [...byVoyage].map(([voyage, path]) => ({ voyage, path }));
  tr.pingData = { length: tr.n, attributes: { getPosition: { value: tr.pos, size: 2 }, getFillColor: { value: tr.col, size: 4 },
                                              getFilterValue: { value: tr.th, size: 1 } } };
  S.tr = tr; S.hover = -1;
  for (const id of ['wfrom', 'wto']) { $(id).min = tr.t0 / 1000; $(id).max = tr.t1 / 1000; $(id).step = 60; }
  makePlot();
  const a = Math.max(tr.t0, tr.t1 - 30 * DAY);
  S.win = [a, tr.t1];
  fitTo(a, tr.t1);
  setWindow(a, tr.t1);
}
const reloadYears = () => S.vid && loadRange(+$('from').value, +$('to').value).catch((e) => status(String(e)));
$('from').addEventListener('change', reloadYears);
$('to').addEventListener('change', reloadYears);

// Where the logbook and the pings disagree, per trip (Quality control). Linear: prefix sums over the sorted pings.
// A haul is judged on the window the vessel attends it (docs/grammar.qmd): hauling, t3-t4, for static gear, whose
// nets or lines may be set on an earlier trip; the tow, t2-t3, for towed gear; t1-t4 where the gear is not known.
const STATIC = new Set(['GNS', 'GND', 'GTR', 'GTN', 'GEN', 'LLS', 'LLD', 'FPO', 'FPN', 'FYK']);
const MOBILE = new Set(['OTB', 'OTM', 'OTT', 'PTB', 'PTM', 'TBB', 'SDN', 'SSC', 'SPR', 'PS', 'DRB', 'HMD', 'LHM', 'LHP', 'LTL']);
function attended(h) {
  if (STATIC.has(h.gear)) return { a: h.t3 ?? h.t1, b: h.t4, rule: 'static: t3-t4' };
  if (MOBILE.has(h.gear)) return { a: h.t2 ?? h.t1, b: h.t3 ?? h.t4, rule: 'towed: t2-t3' };
  return { a: h.t1, b: h.t4, rule: 'gear unknown: t1-t4' };
}
function tripChecks() {
  const tr = S.tr, byTrip = new Map();
  for (const h of S.hauls) { if (!byTrip.has(h.tid)) byTrip.set(h.tid, []); byTrip.get(h.tid).push(h); }
  const count = (a, b) => (tr ? lower(tr.t, b + 1) - lower(tr.t, a) : 0);
  const fishing = (a, b) => (tr ? tr.fishCum[lower(tr.t, b + 1)] - tr.fishCum[lower(tr.t, a)] : 0);
  for (const d of S.trips) {
    const hs = (byTrip.get(d.tid) || []).filter((h) => h.schema === d.schema);
    d.hauls = hs;
    for (const h of hs) h.att = attended(h);
    const SLACK = 15 * 6e4;   // T1 and T2 are often given to the quarter hour
    d.haulsOutside = hs.filter((h) => h.att.a < d.a - SLACK || h.att.b > d.b + SLACK).length;
    d.span = [Math.min(d.a, ...hs.map((h) => h.t1)), Math.max(d.b, ...hs.map((h) => h.t4))];
    if (!tr || d.b < tr.t0 || d.a > tr.t1) { d.pings = null; continue; }
    d.pings = count(d.a, d.b); d.fishPings = fishing(d.a, d.b);
    d.haulsNoFishing = hs.filter((h) => fishing(h.att.a, h.att.b) === 0).length;
    // fishing pings of the trip outside every haul's attended window: the trip's fishing minus the fishing in their union
    const iv = hs.map((h) => [h.att.a, h.att.b]).sort((x, y) => x[0] - y[0]), merged = [];
    for (const [a, b] of iv) { if (merged.length && a <= merged.at(-1)[1]) merged.at(-1)[1] = Math.max(merged.at(-1)[1], b); else merged.push([a, b]); }
    d.fishOutside = d.fishPings - merged.reduce((s, [a, b]) => s + fishing(Math.max(a, d.a), Math.min(b, d.b)), 0);
  }
}
const warnings = (d) => {
  if (d.pings == null) return '<span class="badge">no AIS loaded</span>';
  const w = [];
  if (d.pings === 0) w.push('<span class="badge bad">no pings in the trip</span>');
  if (d.n === 0) w.push('<span class="badge warn">no haul recorded</span>');
  if (d.haulsOutside) w.push(`<span class="badge bad">${d.haulsOutside} haul${d.haulsOutside > 1 ? 's' : ''} attended outside T1-T2</span>`);
  if (d.haulsNoFishing) w.push(`<span class="badge warn">${d.haulsNoFishing} haul${d.haulsNoFishing > 1 ? 's' : ''} without fishing pings</span>`);
  if (d.fishOutside > 0) w.push(`<span class="badge warn">${d.fishOutside} fishing pings outside hauls</span>`);
  return w.length ? w.join('') : '<span class="badge ok">agree</span>';
};

// The trip table: newest first, a click opens its hauls ----------------------------------------------------------------
const TRIPS_PER_PAGE = 25;
async function renderTrips() {
  const order = [...S.trips].sort((x, y) => y.a - x.a), total = order.length;
  if (!total) { $('trips').innerHTML = '<div class="note">No logbook trip in these years.</div>'; return; }
  const pages = Math.ceil(total / TRIPS_PER_PAGE);
  S.tripPage = Math.max(0, Math.min(S.tripPage, pages - 1));
  const page = order.slice(S.tripPage * TRIPS_PER_PAGE, (S.tripPage + 1) * TRIPS_PER_PAGE);
  const species = new Map();
  const open = page.filter((d) => S.expanded.has(d.tid));
  if (open.length) {   // species by haul, only for the opened trips
    const sids = open.flatMap((d) => d.hauls.map((h) => h.sid)).join(',');
    if (sids) for (const r of await rows(`SELECT ".sid" AS sid, string_agg(sid::VARCHAR || ': ' || round(catch)::VARCHAR, ', ' ORDER BY catch DESC) AS sp
        FROM station_catch WHERE ".sid" IN (${sids}) GROUP BY 1`)) species.set(r.sid, r.sp);
  }
  const ov = !qc();
  const head = ov
    ? ['', 'departure', 'return', 'days', 'port', 'hauls', 'catch (t)']
    : ['', 'trip (.tid)', 'schema', 'T1', 'T2', 'T1 / T2 basis', 'port', 'hauls', 'catch (t)', 'pings', 'fishing pings', 'checks'];
  const num_ = new Set(ov ? [3, 5, 6] : [7, 8, 9, 10]);
  let html = `<table><tr>${head.map((h, i) => `<th${num_.has(i) ? ' class="n"' : ''}>${h}</th>`).join('')}</tr>`;
  for (const d of page) {
    const isOpen = S.expanded.has(d.tid), cls = `click${d.tid === S.trip ? ' sel' : ''}`;
    const cells = ov
      ? [dstr(d.a), dstr(d.b), num((d.b - d.a) / DAY, 1), esc(d.port), d.n, num(d.kg / 1000, 2)]
      : [esc(d.tid), esc(d.schema), fmt(d.a), fmt(d.b), `${esc(d.b1 ?? '')} / ${esc(d.b2 ?? '')}`, esc(d.port), d.n, num(d.kg / 1000, 2),
         d.pings ?? '', d.fishPings ?? '', warnings(d)];
    html += `<tr class="${cls}" data-tid="${esc(d.tid)}" data-schema="${esc(d.schema)}"><td><span class="caret">${isOpen ? '▾' : '▸'}</span></td>` +
      cells.map((c, i) => `<td${num_.has(i + 1) ? ' class="n"' : ''}>${c}</td>`).join('') + '</tr>';
    if (isOpen) html += `<tr class="sub"><td colspan="${head.length}">${haulTable(d, species)}</td></tr>`;
  }
  html += '</table>';
  if (pages > 1) html += `<div class="pager"><button data-d="-1" ${S.tripPage === 0 ? 'disabled' : ''}>‹ newer</button>
    trips ${S.tripPage * TRIPS_PER_PAGE + 1}–${Math.min(total, (S.tripPage + 1) * TRIPS_PER_PAGE)} of ${total}
    <button data-d="1" ${S.tripPage >= pages - 1 ? 'disabled' : ''}>older ›</button></div>`;
  $('trips').innerHTML = html;
  $('trips').querySelectorAll('tr.click[data-tid]').forEach((row) => row.addEventListener('click', () => {
    const tid = row.dataset.tid;
    if (S.expanded.has(tid) && S.trip === tid) { S.expanded.delete(tid); renderTrips(); return; }
    selectTrip(tid, row.dataset.schema, { scroll: false }).catch((e) => status(String(e)));
  }));
  $('trips').querySelectorAll('tr.haul').forEach((row) => row.addEventListener('click', (e) => {
    e.stopPropagation();
    const h = S.hauls.find((x) => String(x.sid) === row.dataset.sid);
    if (h && S.tr) { fitTo(h.t1 - HOUR, h.t4 + HOUR); setWindow(h.t1 - 30 * 6e4, h.t4 + 30 * 6e4); }
  }));
  $('trips').querySelectorAll('.pager button').forEach((b) => b.addEventListener('click', () => { S.tripPage += +b.dataset.d; renderTrips(); }));
}
function haulTable(d, species) {
  if (!d.hauls.length) return '<div class="note">No haul is recorded for this trip.</div>';
  const fishIn = (h) => (S.tr && h.att ? S.tr.fishCum[lower(S.tr.t, h.att.b + 1)] - S.tr.fishCum[lower(S.tr.t, h.att.a)] : null);
  if (!qc()) {
    return `<table><tr><th>gear in</th><th>gear out</th><th>gear</th><th class="n">depth (m)</th><th class="n">catch (kg)</th><th>main species (codes)</th></tr>` +
      d.hauls.map((h) => `<tr class="click haul" data-sid="${h.sid}" title="show this haul on the chart and map"><td>${fmt(h.t1)}</td><td>${fmt(h.t4)}</td><td>${esc(h.gear)}</td>
        <td class="n">${num(h.z1)}</td><td class="n">${num(h.kg)}</td><td>${esc((species.get(h.sid) || '').split(', ').slice(0, 3).map((x) => x.split(':')[0]).join(', '))}</td></tr>`).join('') + '</table>';
  }
  return `<table><tr><th>.sid</th><th>type</th><th>t1</th><th>t2</th><th>t3</th><th>t4</th><th>gear / target</th><th class="n">min</th>
    <th>effort</th><th>start</th><th>end</th><th class="n">z1-z2</th><th>judged on</th><th class="n">fishing pings</th><th>catch kg by species</th></tr>` +
    d.hauls.map((h) => { const f = fishIn(h); return `<tr class="click haul" data-sid="${h.sid}"><td>${h.sid}</td><td>${esc(h.station_type)}</td>
      <td>${fmt(h.t1)}</td><td>${fmt(h.t2)}</td><td>${fmt(h.t3)}</td><td>${fmt(h.t4)}</td><td>${esc(h.gear) || '<span class="badge warn">none</span>'} ${esc(h.target)}${h.gear_basis && h.gear_basis !== 'recorded' ? ` <span class="note">(${esc(h.gear_basis)})</span>` : ''}</td>
      <td class="n">${num(h.duration_m)}</td><td>${num(h.effort, 1)} ${esc(h.effort_unit)}</td>
      <td>${num(h.lat1, 3)}, ${num(h.lon1, 3)}</td><td>${num(h.lat2, 3)}, ${num(h.lon2, 3)}</td><td class="n">${num(h.z1)}-${num(h.z2)}</td><td>${esc(h.att?.rule ?? '')}</td>
      <td class="n">${f == null ? '' : f === 0 ? '<span class="badge warn">0</span>' : f}</td><td>${esc(species.get(h.sid) || '')}</td></tr>`; }).join('') + '</table>';
}

// The pings of the window (Quality control) -----------------------------------------------------------------------------
const PINGS_PER_PAGE = 100;
async function renderPings() {
  if (!qc()) return;
  if (!S.tr) { $('pings').innerHTML = '<div class="note">No AIS in these years.</div>'; return; }
  const [a, b] = S.win, i0 = lower(S.tr.t, a), i1 = lower(S.tr.t, b + 1), total = i1 - i0;
  const P = await rows(`SELECT epoch_ms(time)::DOUBLE AS ms, strftime(time, '%Y-%m-%d %H:%M:%S') AS t, round(lat, 4)::DOUBLE AS lat,
      round(lon, 4)::DOUBLE AS lon, round(speed, 1)::DOUBLE AS speed, round(heading)::DOUBLE AS heading, provider, voyage, stay,
      gear, phase, fishing_flow::VARCHAR AS fishing, ".tid" AS tid, ".sid" AS sid
    FROM trail WHERE epoch_ms(time) BETWEEN ${a} AND ${b} ORDER BY time LIMIT ${PINGS_PER_PAGE} OFFSET ${S.pingPage * PINGS_PER_PAGE}`);
  const pages = Math.ceil(total / PINGS_PER_PAGE);
  $('pings').innerHTML = `<div class="note">${total.toLocaleString('en-GB')} pings in the window; click one to find it on the map and chart.</div>
    <div class="scroll">${table([['t', 'time (UTC)'], ['lat', 'lat', true], ['lon', 'lon', true], ['speed', 'speed', true], ['heading', 'heading', true],
      ['provider', 'provider'], ['voyage', 'voyage', true], ['stay', 'stay', true], ['gear', 'gear'], ['phase', 'phase'], ['fishing', 'fishing_flow'],
      ['tid', '.tid'], ['sid', '.sid', true]], P, { click: true, empty: 'no ping in the window' })}</div>` +
    (pages > 1 ? `<div class="pager"><button data-d="-1" ${S.pingPage === 0 ? 'disabled' : ''}>‹ earlier</button>
      ${S.pingPage * PINGS_PER_PAGE + 1}–${Math.min(total, (S.pingPage + 1) * PINGS_PER_PAGE)} of ${total.toLocaleString('en-GB')}
      <button data-d="1" ${S.pingPage >= pages - 1 ? 'disabled' : ''}>later ›</button></div>` : '');
  $('pings').querySelectorAll('tr.click').forEach((row) => row.addEventListener('click', () => setHover(lower(S.tr.t, P[+row.dataset.i].ms), 'map')));
  $('pings').querySelectorAll('.pager button').forEach((x) => x.addEventListener('click', () => { S.pingPage += +x.dataset.d; renderPings(); }));
}

// About this vessel: a summary in the mode's words ------------------------------------------------------------------
function renderSummary() {
  const A = S.about, v = V.find((x) => x.vid === S.vid) || {}, tr = S.tr;
  if (!S.vid) return;
  const lastHeard = tr && v.last_ping && dstr(tr.t1) === v.last_ping
    ? `${fmt(tr.t1)} UTC, ${tr.stay[tr.n - 1] >= 0 ? 'in port' : 'at sea'}` : (v.last_ping || 'never');
  const tonnes = S.landings.reduce((s, d) => s + d.t, 0);
  if (!qc()) {
    const kind = A.use ? A.use.toLowerCase() : 'vessel';
    const parts = [A.loa && `${num(A.loa, 1)} m long`, A.built && `built ${A.built}`, A.home && `home port ${A.home}`].filter(Boolean);
    $('summary').innerHTML = `<p><b>${esc(S.name || 'vid ' + S.vid)}</b> is a ${esc(kind)}${parts.length ? ', ' + esc(parts.join(', ')) : ''}.</p><ul>
      <li>Last heard on AIS: ${esc(lastHeard)}.</li>
      <li>Last landing: ${A.lastLanding ? esc(A.lastLanding) : 'none recorded'}.</li>
      <li>In ${S.from === S.to ? S.from : `${S.from}–${S.to}`}: ${S.trips.length} fishing trips in the logbook, ${num(tonnes, 1)} t landed in ${S.landings.length} landings.</li></ul>
      <div class="note">Type, length and home port from the register (history to 2023-12-19). Species are shown as codes.</div>`;
  } else {
    const warn = S.trips.filter((d) => d.pings === 0 || d.haulsOutside || d.haulsNoFishing || d.fishOutside > 0).length;
    $('summary').innerHTML = `<dl><dt>vid</dt><dd>${S.vid}</dd><dt>call sign</dt><dd>${esc(v.cs)}</dd><dt>MMSI</dt><dd>${esc(v.mmsi)}</dd>
      <dt>on the trail</dt><dd>${v.first_year ?? '—'} – ${esc(v.last_ping || '—')}</dd><dt>last landing</dt><dd>${esc(v.last_landing || '—')}</dd>
      <dt>loaded</dt><dd>${S.from}–${S.to}: ${tr ? tr.n.toLocaleString('en-GB') : 0} pings, ${S.trips.length} trips, ${S.stations.length} hauls, ${S.landings.length} landings</dd>
      <dt>trips with checks</dt><dd>${warn} of ${S.trips.length}</dd><dt>usage (register)</dt><dd>${esc(A.use || '—')}</dd>
      <dt>last logbook trip</dt><dd>${S.assumedBase ? `${esc(S.assumedBase.tid)}, T2 ${esc(S.assumedBase.day)}` : '—'}${S.assumed ? `; to the last landing the gear is assumed ${esc(S.assumed.gear)}` : ''}</dd></dl>`;
  }
}

// The Activity tab: photo, the last landing, the trip that landed it --------------------------------------------------
let photos = [], photoAt = 0;
function showPhoto() {
  const p = photos[photoAt];
  if (!p) { $('photo-body').innerHTML = '<div class="note">No photo of this vessel in the 2022 mbl scrape.</div>'; return; }
  const credit = [p.exif_artist ? `Photo: ${p.exif_artist}` : 'Photographer not given', 'mbl.is, 200 mílur',
                  p.exif_date ? `taken ${p.exif_date}` : 'date unknown, before 2022-12-28'].join(' · ');
  $('photo-body').innerHTML = `<img src="/photo?vid=${S.vid}&file=${encodeURIComponent(p.file)}" alt="${esc(S.name || 'vessel ' + S.vid)}">
    <div class="note">${esc(credit)}${photos.length > 1 ? ` · ${photoAt + 1} of ${photos.length}, click for the next` : ''}
    ${p.kind === 'thumbnail' ? ' · thumbnail only' : ''} · internal use only</div>`;
  $('photo-body').querySelector('img').addEventListener('click', () => { photoAt = (photoAt + 1) % photos.length; showPhoto(); });
}
async function renderNow() {
  photos = await rows(`SELECT file, kind, exif_artist, strftime(exif_date, '%Y-%m-%d') AS exif_date FROM photos ORDER BY best DESC, kind, image_no`);
  photoAt = 0; showPhoto();
  const u = (await rows(`SELECT usage_category AS use, construction_year AS built FROM a_vessel ORDER BY valid_from DESC LIMIT 1`))[0] || {};
  const h = (await rows(`SELECT home_port FROM a_ident ORDER BY valid_from DESC LIMIT 1`))[0] || {};
  const r = (await rows(`SELECT loa FROM a_register`))[0] || {};
  S.about = { use: u.use, built: u.built, home: h.home_port ? h.home_port.charAt(0) + h.home_port.slice(1).toLowerCase() : null, loa: r.loa };
  const L = await rows(`SELECT ".lid" AS lid, schema, strftime(date, '%Y-%m-%d') AS day, year(date)::INTEGER AS y, port,
      coalesce(gear_name, gear) AS gear, sid, round(catch)::DOUBLE AS kg FROM last_landing ORDER BY catch DESC`);
  if (!L.length) { $('last-landing').innerHTML = '<div class="note">No landing recorded.</div>'; $('last-trip').innerHTML = ''; S.about.lastLanding = null; return; }
  const l = L[0], total = L.reduce((s, x) => s + x.kg, 0);
  S.about.lastLanding = `${l.day} in ${l.port}, ${num(total / 1000, 2)} t`;
  $('last-landing').innerHTML = `<dl><dt>Date</dt><dd>${esc(l.day)}</dd><dt>Port</dt><dd>${esc(l.port)}</dd>
    <dt>Gear</dt><dd>${esc(l.gear)}</dd><dt>Total</dt><dd>${num(total / 1000, 2)} t</dd></dl>` +
    table([['sid', 'species (code)'], ['kg', 'kg', true]], L.map((x) => ({ ...x, kg: num(x.kg) })));
  const link = await rows(`SELECT ".tid" AS tid, schema, match_type FROM landing_trips WHERE ".lid" = ${l.lid} AND schema_land = ${sqlstr(l.schema)}`);
  S.assumed = null;
  if (!link.length) {
    S.assumed = S.assumedBase && Date.parse(`${l.day}T00:00:00Z`) > S.assumedBase.after
      ? { ...S.assumedBase, until: Date.parse(`${l.day}T00:00:00Z`) + DAY } : null;
    const A = S.assumed, lgear = l.gear || '';
    const assumed = !A ? '' : qc()
      ? `<dl><dt>gear assumed</dt><dd>${esc(A.gear)}, from the previous logbook trip ${esc(A.tid)} (T2 ${esc(A.day)})</dd>
         <dt>landing's gear</dt><dd>${esc(lgear)}</dd></dl>`
      : `<p>Until the logbook comes in, the gear is assumed to be <b>${esc(A.gear)}</b>, as on the previous logbook trip
         (returned ${esc(A.day)}). The landing itself records ${esc(lgear) || 'no gear'}.</p>`;
    $('last-trip').innerHTML = `<div class="note">${qc() ? 'lid_map links no logbook trip to this landing.' : 'No logbook trip is linked to this landing yet.'}</div>${assumed}`;
    return;
  }
  const yrs = { vid: S.vid, from: l.y, to: l.y };
  await loadAll([['f_trips', 'trips', yrs], ['f_stations', 'stations', yrs], ['f_catch', 'station_catch', yrs]]);
  const tids = link.map((x) => sqlstr(x.tid)).join(',');
  const T = await rows(`SELECT ".tid" AS tid, schema, strftime(T1, '%Y-%m-%d %H:%M') AS t1, strftime(T2, '%Y-%m-%d %H:%M') AS t2, port
    FROM f_trips WHERE ".tid" IN (${tids})`);
  const H = await rows(`SELECT strftime(coalesce(s.t1, s.date), '%Y-%m-%d %H:%M') AS t1, strftime(s.t4, '%m-%d %H:%M') AS t4,
      coalesce(s.gear, '') AS gear, round(s.lat1, 3)::DOUBLE AS lat, round(s.lon1, 3)::DOUBLE AS lon, round(sum(c.catch))::DOUBLE AS kg
    FROM f_stations s LEFT JOIN f_catch c USING (".sid", schema) WHERE s.".tid" IN (${tids})
    GROUP BY s.".sid", s.schema, s.t1, s.date, s.t4, s.gear, s.lat1, s.lon1 ORDER BY 1`);
  $('last-trip').innerHTML = T.map((t) => `<dl><dt>Departure</dt><dd>${esc(t.t1)}</dd><dt>Return</dt><dd>${esc(t.t2)}</dd>
      <dt>Port</dt><dd>${esc(t.port)}</dd>${qc() ? `<dt>.tid</dt><dd>${esc(t.tid)}</dd><dt>lid_map</dt><dd>${esc(link[0].match_type)}</dd>` : ''}</dl>
      <button class="show-trip" data-tid="${esc(t.tid)}" data-schema="${esc(t.schema)}">Show this trip on the map and chart</button>`).join('') +
    `<h3>Hauls (${H.length})</h3><div class="scroll">${table([['t1', 'gear in'], ['t4', 'gear out'], ['gear', 'gear'],
      ['lat', 'lat', true], ['lon', 'lon', true], ['kg', 'kg', true]], H.map((x) => ({ ...x, kg: num(x.kg) })), { empty: 'no haul recorded' })}</div>`;
  $('last-trip').querySelectorAll('.show-trip').forEach((b) => b.addEventListener('click',
    () => selectTrip(b.dataset.tid, b.dataset.schema).catch((e) => status(String(e)))));
}

// The History tab: register, all landings, all trips, loaded when first opened ------------------------------------------
const hpages = { land: 0, trip: 0 };
const PAGE = 50;
async function renderHistory() {
  if (S.history) return;
  status(`loading the history of vid ${S.vid}`);
  const t = performance.now(), all = { vid: S.vid, from: 1900, to: 2100 };
  const HIST = ['vessel', 'identification', 'measurement', 'owners', 'operators', 'events'];
  await loadAll([['register', 'register', { vid: S.vid }], ...HIST.map((h) => [`hist_${h}`, 'hist', { vid: S.vid, table: h }]),
                 ['h_landings', 'landings', all], ['h_trips', 'trip_summary', all]]);
  const r = (await rows(`SELECT *, strftime(mmsi_t1, '%Y-%m-%d') AS m1, strftime(mmsi_t2, '%Y-%m-%d') AS m2,
                                strftime(note_date, '%Y-%m-%d') AS nd FROM register`))[0];
  const f = r ? [['Name', r.vessel], ['Call sign', r.cs], ['MMSI', r.mmsi && `${r.mmsi}${r.m1 ? ` (${r.m1} – ${r.m2 ?? ''})` : ''}`],
             ['IMO', r.imo], ['Local sign', r.uid], ['Flag', r.flag], ['Status', r.status], ['Length', r.loa && `${num(r.loa, 1)} m`],
             ['Power', r.kw && `${num(r.kw)} kW`], ['GRT / GT', [r.grt, r.bwt].filter((x) => x != null).map((x) => num(x, 1)).join(' / ')],
             ['Note', [r.note_fate, r.nd].filter(Boolean).join(', ')], ['Source', r.source]] : [];
  $('register').innerHTML = r ? `<dl>${f.filter(([, v]) => v != null && v !== '').map(([k, v]) => `<dt>${k}</dt><dd>${esc(v)}</dd>`).join('')}</dl>`
                              : '<div class="note">Not in today\'s register.</div>';
  const d = (x) => `strftime(${x}, '%Y-%m-%d')`;
  const ves = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, name, usage_category FROM hist_vessel ORDER BY valid_from DESC`);
  const own = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, name, percentage FROM hist_owners ORDER BY valid_from DESC`);
  const ops = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, name FROM hist_operators ORDER BY valid_from DESC`);
  const idn = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, home_port, call_sign FROM hist_identification ORDER BY valid_from DESC`);
  const ev = await rows(`SELECT ${d('date')} AS date, event, fate FROM hist_events ORDER BY date DESC`);
  $('reghist').innerHTML =
    `<h3>Name and use</h3>${table([['f', 'from'], ['t', 'to'], ['name', 'name'], ['usage_category', 'use']], ves)}` +
    `<h3>Owners</h3>${table([['f', 'from'], ['t', 'to'], ['name', 'name'], ['percentage', '%', true]], own)}` +
    `<h3>Operators</h3>${table([['f', 'from'], ['t', 'to'], ['name', 'name']], ops)}` +
    `<h3>Home port and call sign</h3>${table([['f', 'from'], ['t', 'to'], ['home_port', 'home port'], ['call_sign', 'call sign']], idn)}` +
    `<h3>Events</h3>${table([['date', 'date'], ['event', 'event'], ['fate', 'fate']], ev)}`;
  const ly = await rows(`SELECT year(date)::INTEGER AS y, count(DISTINCT (".lid", schema))::INTEGER AS n,
      round(sum(catch) / 1000, 1)::DOUBLE AS t FROM h_landings GROUP BY 1 ORDER BY 1 DESC`);
  $('h-land-years').innerHTML = table([['y', 'year'], ['n', 'landings', true], ['t', 'tonnes', true]], ly.map((x) => ({ ...x, t: num(x.t, 1) })), { empty: 'no landing' });
  const ty = await rows(`SELECT year(T2)::INTEGER AS y, count(*)::INTEGER AS n, sum(stations)::INTEGER AS h,
      round(sum(catch) / 1000, 1)::DOUBLE AS t FROM h_trips GROUP BY 1 ORDER BY 1 DESC`);
  $('h-trip-years').innerHTML = table([['y', 'year'], ['n', 'trips', true], ['h', 'hauls', true], ['t', 'tonnes', true]], ty.map((x) => ({ ...x, t: num(x.t, 1) })), { empty: 'no logbook trip' });
  hpages.land = 0; hpages.trip = 0;
  await pageLandings(); await pageTrips();
  S.history = true;
  status(`history of vid ${S.vid} loaded in ${Math.round(performance.now() - t)} ms`);
}
function pager(id, page, total) {
  const last = Math.max(0, Math.ceil(total / PAGE) - 1);
  return `<div class="pager"><button data-p="${id}" data-d="-1" ${page <= 0 ? 'disabled' : ''}>‹ newer</button>
    ${total ? `${page * PAGE + 1}–${Math.min(total, (page + 1) * PAGE)} of ${total.toLocaleString('en-GB')}` : ''}
    <button data-p="${id}" data-d="1" ${page >= last ? 'disabled' : ''}>older ›</button></div>`;
}
function bindPager(el, key, total, fn) {
  $(el).querySelectorAll('button[data-p]').forEach((b) => b.addEventListener('click', () => {
    hpages[key] = Math.max(0, Math.min(Math.ceil(total / PAGE) - 1, hpages[key] + +b.dataset.d)); fn();
  }));
}
async function pageLandings() {
  const total = (await rows(`SELECT count(DISTINCT (".lid", schema))::INTEGER AS n FROM h_landings`))[0].n;
  const L = await rows(`SELECT strftime(date, '%Y-%m-%d') AS day, port, coalesce(gear_name, gear) AS gear,
      round(sum(catch) / 1000, 2)::DOUBLE AS t, string_agg(sid::VARCHAR, ', ' ORDER BY catch DESC) AS species
    FROM h_landings GROUP BY ".lid", schema, date, port, gear_name, gear ORDER BY date DESC, ".lid" DESC
    LIMIT ${PAGE} OFFSET ${hpages.land * PAGE}`);
  L.forEach((r) => { const s = r.species.split(', '); r.species = s.slice(0, 4).join(', ') + (s.length > 4 ? ', …' : ''); r.t = num(r.t, 2); });
  $('h-land').innerHTML = table([['day', 'date'], ['port', 'port'], ['gear', 'gear'], ['t', 'tonnes', true], ['species', 'species (codes)']], L, { empty: 'no landing' }) +
    pager('land', hpages.land, total);
  bindPager('h-land', 'land', total, pageLandings);
}
async function pageTrips() {
  const total = (await rows(`SELECT count(*)::INTEGER AS n FROM h_trips`))[0].n;
  const T = await rows(`SELECT ".tid" AS tid, schema, strftime(T1, '%Y-%m-%d %H:%M') AS t1, strftime(T2, '%Y-%m-%d %H:%M') AS t2,
      port, stations, round(catch / 1000, 2)::DOUBLE AS t FROM h_trips ORDER BY T2 DESC LIMIT ${PAGE} OFFSET ${hpages.trip * PAGE}`);
  $('h-trips').innerHTML = table([['t1', 'departure'], ['t2', 'return'], ['port', 'port'], ['stations', 'hauls', true], ['t', 'tonnes', true]],
                                 T.map((x) => ({ ...x, t: num(x.t, 2) })), { click: true, empty: 'no logbook trip' }) + pager('trip', hpages.trip, total);
  $('h-trips').querySelectorAll('tr.click').forEach((row) => row.addEventListener('click', () => {
    const x = T[+row.dataset.i]; selectTrip(x.tid, x.schema).catch((e) => status(String(e)));
  }));
  bindPager('h-trips', 'trip', total, pageTrips);
}

// Tabs and modes --------------------------------------------------------------------------------------------------------
function showTab(name) {
  for (const t of ['now', 'history']) { $(t).classList.toggle('on', t === name); $(`tab-${t}`).classList.toggle('on', t === name); }
  if (name === 'history' && S.vid && !S.history) renderHistory().catch((e) => status(String(e)));
  if (name === 'now' && plot) { plot.setSize({ width: $('plot').clientWidth, height: 190 }); lanes?.setSize({ width: $('lanes').clientWidth, height: 22 * LANES.length + 30 }); render(); }
  setHash();
}
$('tab-now').addEventListener('click', () => showTab('now'));
$('tab-history').addEventListener('click', () => showTab('history'));
async function setMode(m) {
  S.mode = m;
  document.body.classList.toggle('qc', m === 'qc');
  $('mode-ov').classList.toggle('on', m === 'ov'); $('mode-qc').classList.toggle('on', m === 'qc');
  setHash();
  if (!S.vid) return;
  if (m === 'qc' && S.tr) { makeLanes(); S.pingPage = 0; await renderPings(); } else { lanes?.destroy(); lanes = null; }
  renderSummary();
  await renderTrips();
  await renderNow();
}
$('mode-ov').addEventListener('click', () => setMode('ov'));
$('mode-qc').addEventListener('click', () => setMode('qc'));

// Choosing a vessel ----------------------------------------------------------------------------------------------------
async function choose(vid, from, to) {
  status(`loading vid ${vid}`);
  S.vid = vid; S.trip = null; S.tr = null; S.history = false; render();
  const v = V.find((x) => x.vid === vid);
  S.name = v?.vessel || '';
  $('title').textContent = `${S.name || 'vid ' + vid}${S.name ? ' · vid ' + vid : ''}${v?.cs ? ' · ' + v.cs : ''}`;
  document.title = `${S.name || 'vid ' + vid} · Vessel overview`;
  await loadAll([['photos', 'photos', { vid }], ['trail_years', 'trail_years', { vid }], ['last_landing', 'landings', { vid, n: 1 }],
                 ['landing_trips', 'landing_trips', { vid }], ['a_register', 'register', { vid }],
                 ['last_trip', 'trips', { vid, n: 1 }], ['last_trip_st', 'stations', { vid, n: 1 }],
                 ['a_vessel', 'hist', { vid, table: 'vessel' }], ['a_ident', 'hist', { vid, table: 'identification' }]]);
  S.years = (await rows('SELECT year FROM trail_years ORDER BY year')).map((r) => r.year);
  const lt = (await rows(`SELECT ".tid" AS tid, epoch_ms(T2)::DOUBLE AS after, strftime(T2, '%Y-%m-%d') AS day FROM last_trip`))[0];
  const lg = (await rows(`SELECT gear, count(*)::INTEGER AS n FROM last_trip_st WHERE coalesce(gear, '') <> '' GROUP BY 1 ORDER BY 2 DESC LIMIT 1`))[0];
  S.assumedBase = lt && lg ? { ...lt, gear: lg.gear } : null;
  const thisYear = new Date().getUTCFullYear();
  const first = Math.min(S.years[0] ?? thisYear, 2007), last = Math.max(S.years.at(-1) ?? thisYear, thisYear);
  const opts = []; for (let y = last; y >= first; y--) opts.push(`<option value="${y}">${y}${S.years.includes(y) ? '' : ' (no AIS)'}</option>`);
  $('from').innerHTML = opts.join(''); $('to').innerHTML = opts.join('');
  const y = S.years.at(-1) ?? thisYear;
  await renderNow();
  await loadRange(Number.isInteger(from) ? from : y, Number.isInteger(to) ? to : y);
  if ($('history').classList.contains('on')) await renderHistory();
}

// The vessel list --------------------------------------------------------------------------------------------------------
let V = [], sortKey = 'last_ping', sortDir = -1;
function renderList() {
  const q = $('filter').value.trim().toLowerCase(), trail = $('f-trail').checked, photo = $('f-photo').checked, since = $('f-landed').value;
  let X = V.filter((v) => (!trail || v.last_ping) && (!photo || v.photo) && (!since || (v.last_landing && v.last_landing >= since)) &&
    (!q || `${v.vid} ${v.vessel} ${v.cs} ${v.mmsi}`.toLowerCase().includes(q)));
  const key = (v) => v[sortKey] ?? '';
  X.sort((a, b) => (key(a) < key(b) ? -1 : key(a) > key(b) ? 1 : 0) * sortDir);
  $('list-count').textContent = `${X.length.toLocaleString('en-GB')} vessels${X.length > 300 ? ' — the first 300 are shown; type to narrow' : ''}. Click one to open it.`;
  const cols = [['vid', 'number'], ['vessel', 'name'], ['cs', 'call sign'], ['mmsi', 'MMSI'], ['first_year', 'on AIS since'],
                ['last_ping', 'last heard'], ['last_landing', 'last landing'], ['photo', 'photo']];
  X = X.slice(0, 300);
  $('list').innerHTML = `<table><tr>${cols.map(([k, h]) => `<th data-k="${k}" title="sort">${h}${k === sortKey ? (sortDir < 0 ? ' ▾' : ' ▴') : ''}</th>`).join('')}</tr>` +
    X.map((v) => `<tr class="click" data-vid="${v.vid}">${cols.map(([k]) => `<td>${esc(k === 'photo' ? (v.photo ? '✓' : '') : v[k])}</td>`).join('')}</tr>`).join('') + '</table>';
  $('list').querySelectorAll('th').forEach((th) => th.addEventListener('click', () => {
    const k = th.dataset.k; if (k === sortKey) sortDir = -sortDir; else { sortKey = k; sortDir = k === 'vessel' || k === 'cs' ? 1 : -1; } renderList();
  }));
  $('list').querySelectorAll('tr.click').forEach((tr) => tr.addEventListener('click', () => {
    $('drawer').classList.remove('on'); location.hash = `vid=${tr.dataset.vid}&mode=${S.mode}`;
  }));
}
for (const id of ['filter', 'f-trail', 'f-photo', 'f-landed']) $(id).addEventListener('input', renderList);
$('open-list').addEventListener('click', () => { $('drawer').classList.add('on'); renderList(); $('filter').focus(); });
$('close-list').addEventListener('click', () => $('drawer').classList.remove('on'));
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') $('drawer').classList.remove('on'); });

// The address holds the vessel, the years, the tab and the mode --------------------------------------------------------
function setHash() {
  if (!S.vid) return;
  const h = `vid=${S.vid}&from=${S.from ?? ''}&to=${S.to ?? ''}&tab=${$('history').classList.contains('on') ? 'history' : 'now'}&mode=${S.mode}`;
  if (location.hash.slice(1) !== h) history.replaceState(null, '', `#${h}`);
}
function fromHash() {
  const h = new URLSearchParams(location.hash.slice(1));
  const vid = parseInt(h.get('vid'), 10), hist = h.get('tab') === 'history';
  for (const t of ['now', 'history']) { $(t).classList.toggle('on', (t === 'history') === hist); $(`tab-${t}`).classList.toggle('on', (t === 'history') === hist); }
  S.mode = h.get('mode') === 'qc' ? 'qc' : 'ov';
  document.body.classList.toggle('qc', S.mode === 'qc');
  $('mode-ov').classList.toggle('on', S.mode === 'ov'); $('mode-qc').classList.toggle('on', S.mode === 'qc');
  if (!Number.isInteger(vid)) return;
  choose(vid, parseInt(h.get('from'), 10), parseInt(h.get('to'), 10))
    .then(() => { if (h.get('bench')) bench(); }).catch((e) => status(String(e)));
}
window.addEventListener('hashchange', fromHash);

// A measure of responsiveness: 20 window moves over the loaded range, each timed to the map's next frame ----------------
async function bench() {
  const tr = S.tr, out = [];
  if (!tr) return null;
  for (let k = 1; k <= 20; k++) {
    const b = tr.t0 + ((tr.t1 - tr.t0) * k) / 20;
    out.push(await new Promise((res) => { onRedraw = res; setWindow(b - 30 * DAY, b); }));
  }
  const sorted = [...out].sort((a, b) => a - b);
  const r = { mode: S.mode, pings: tr.n, moves: 20, median_ms: Math.round(sorted[10]), max_ms: Math.round(sorted[19]), each_ms: out.map(Math.round) };
  document.body.dataset.bench = JSON.stringify(r);
  status(`bench: median ${r.median_ms} ms, max ${r.max_ms} ms, ${r.pings} pings`);
  return r;
}
window.overviewBench = bench;   // for the checks in plan 030: run it from the console on a loaded vessel

// Start ----------------------------------------------------------------------------------------------------------------
await ingest('vessels', await fetchParquet('vessels', {}));
V = await rows(`SELECT vid, coalesce(vessel, '') AS vessel, coalesce(cs, '') AS cs, coalesce(mmsi, '') AS mmsi, first_year,
    strftime(last_ping, '%Y-%m-%d') AS last_ping, strftime(last_landing, '%Y-%m-%d') AS last_landing, photo FROM vessels`);
for (let y = new Date().getUTCFullYear(); y >= 1992; y--) $('f-landed').insertAdjacentHTML('beforeend', `<option value="${y}-01-01">${y}</option>`);
status(`${V.length.toLocaleString('en-GB')} vessels`);
if (location.hash.length > 1) fromHash(); else { $('drawer').classList.add('on'); renderList(); $('filter').focus(); }
