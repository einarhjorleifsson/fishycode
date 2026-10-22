// The vessel overview page's script (plan 030 step 4; decisions 140, 143, 177 and 178). One vessel at a time, over a
// range of years. The R service sends each panel's rows once, as parquet; DuckDB-WASM holds them, and every interaction
// runs here with no further request (decision 137, ask h).
//
// One view (decision 178; maintainer, 2026-10-22), where two modes were (decision 143): Where | When always on top, then
// panels that fold, the summary first and the details on expanding. The fishing is the subject, the vessel its context:
// the speed chart with its activity record (the lanes), the window's activity, hauls and landings, the trips with their
// records and checks, and the window's pings. The map, the chart, the lanes, the cards and the slider share one time
// window. The map's layers follow the maintainer's asjo app (plan 030 §4.2). Internal use only: the photos are a
// newspaper's.
import * as duckdb from 'https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@1.28.0/+esm';

const $ = (id) => document.getElementById(id);
const TOKEN = document.querySelector('meta[name="mapbox-token"]').content;
// Bundle mode (products/exports/vessel_demo.R): the page is opened as a file, with no service. Each vessel's answers are
// in a script beside it, data/v<vid>.js, as the service would give them for the bundle's window; the meta tag says what
// the bundle holds. Its vessels are anonymised: no register, photos, call sign or MMSI.
const BUNDLE = document.querySelector('meta[name="bundle"]')?.content || '';
document.body.classList.toggle('bundle', !!BUNDLE);
const status = (msg) => { $('status').textContent = msg; };
const fmt = (ms) => (ms == null ? '' : new Date(ms).toISOString().slice(0, 16).replace('T', ' '));
const dstr = (ms) => (ms == null ? '' : new Date(ms).toISOString().slice(0, 10));
const esc = (x) => String(x ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const sqlstr = (x) => `'${String(x).replace(/'/g, "''")}'`;
const num = (x, d = 0) => (x == null || x === '' || Number.isNaN(x) ? '' : Number(x).toLocaleString('en-GB', { maximumFractionDigits: d }));
const many = (n, one, more = `${one}s`) => `${num(n)} ${n === 1 ? one : more}`;
const DAY = 864e5, HOUR = 36e5, GAP = 30 * 6e4;
// The service's version this page was written for (api.R, API_VERSION). A server started before its code changed sends
// another, or none: say so plainly, rather than fail in silence.
const API = '2026-10-22.4';
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
// A page opened as a file may not fetch(), but it may load a script: the bundle's data are scripts, each loaded once
const scripts = new Map();
const loadScript = (src) => {
  if (!scripts.has(src)) scripts.set(src, new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src; s.onload = res; s.onerror = () => rej(new Error(`${src} did not load`));
    document.head.append(s);
  }));
  return scripts.get(src);
};
// The bundle holds one window of time, so a range of years is never asked again: only the latest n, or a register
// table, which is empty for every vessel (FD.empty)
async function bundled(endpoint, params) {
  const file = endpoint === 'vessels' ? 'vessels' : `v${params.vid}`;
  await loadScript(`data/${file}.js`);
  const key = [endpoint, params.table, params.n && `n${params.n}`].filter(Boolean).join('/');
  const b64 = window.FD?.[file]?.[key] ?? window.FD?.empty?.[key];
  if (b64 == null) throw new Error(`the bundle holds no ${key} for ${file}`);
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}
const fetchParquet = async (endpoint, params) => {
  if (BUNDLE) return bundled(endpoint, params);
  const r = await fetch(`/api/${endpoint}?${new URLSearchParams(params)}`);
  const v = r.headers.get('X-Overview-Api');
  if (v !== API) {
    banner(`<b>The service is older than this page</b> (service ${esc(v || 'unknown')}, page ${API}). Restart it: click
      <b>Vessel overview</b> in Applications, or run <code>products/vessel_overview/start.sh</code>, which restarts an older
      server by itself. Then reload this page.`);
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
const S = { vid: null, name: '', from: null, to: null, tr: null, win: [0, 0], hover: -1, trip: null, haul: null, haulOpen: false,
            tripSel: new Set(), haulSel: new Set(),
            stations: [], hauls: [], wins: [], trips: [], landings: [], years: [], lanes: null, expanded: new Set(), tripPage: 0, pingPage: 0,
            history: false, about: {}, assumed: null, assumedBase: null, ready: false };
// The user's choices (maintainer, 2026-10-18: "if one selects a new vessel - all the users selections besides the new
// vessels should be preserved"). The page starts on these defaults; from then on each choice the user makes is the
// default for the next vessel. They are in the address too, so a reload or a shared link keeps them, with the open tab.
//   years: 'latest' (the vessel's last year on AIS), 'all', or 'from-to'
//   win: 'last' (the last n trips and the current one), 'month', 'range' (the loaded years), or 'custom' (a to b)
//   lay: what the map draws, each on or off (maintainer, 2026-10-22: "you could think of clickable options, then none can
//        go. that is also for the hex"): the window's 'points' and the 'line' joining them, and around the window the
//        fishing hours in hexagons ('hex') and the whole 'track'. All off leaves the last position heard.
//   open: the panels open (PANELS); the rest are folded to their bars
const PANELS = ['lanes', 'activity', 'trips', 'pings'];
const LAYERS = ['points', 'line', 'hex', 'track'];
const P = { years: 'latest', win: 'last', n: 3, a: null, b: null, lay: new Set(['points', 'line']), open: new Set(['activity', 'trips']) };
const drawn = (k) => P.lay.has(k);
// The gear after the last logbook trip, where no logbook covers the time (decision 143). The landing's own gear first:
// a time takes the gear of the next landing (maintainer, 2026-10-18: "the gear is in the 'last landing', better than
// using the logbooks"). The previous logbook trip's gear only where that landing records none ("if a logbook is missing
// from vessels last trip, assume that the gear is the same gear as from the previous trip"). Better still would be the
// gear read from the track, a TODO of its own (TODO 86).
// It applies only where a logbook is missing: the last landing has no logbook trip, and only from the last logbook
// trip's return to that landing. A vessel that stopped fishing gets no gear.
const assumedAt = (t) => S.assumed && t > S.assumed.after && t <= S.assumed.until;
function gearAfter(t) {   // { gear, landing: the day of the landing that gives it, or null for the previous trip's }
  if (!assumedAt(t)) return null;
  const l = (S.landOnly || []).find((x) => x.d + DAY >= t);   // the next landing, in the loaded years
  const g = l ? l.gear : S.assumed.landingGear, day = l ? l.day : S.assumed.lastDay;
  if (g) return { gear: g, landing: day };
  return S.assumed.gear ? { gear: S.assumed.gear, landing: null } : null;
}
const gearAt = (t, recorded) => (recorded ? { gear: recorded, recorded: true } : gearAfter(t) || { gear: '' });
const gearWords = (g) => (g.landing ? `${g.gear}, as the landing of ${g.landing} records it` : `${g.gear}, assumed as on the previous logbook trip`);
const isOpen = (k) => P.open.has(k);

// The map ------------------------------------------------------------------------------------------------------------
const INFERNO = [[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66], [245, 125, 21], [250, 193, 39], [252, 255, 164]];
function speedColour(s) {
  const x = (Math.max(0, Math.min(12, s)) / 12) * (INFERNO.length - 1);
  const i = Math.min(Math.floor(x), INFERNO.length - 2), f = x - i, a = INFERNO[i], b = INFERNO[i + 1];
  return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f];
}
const FILTER = new deck.DataFilterExtension({ filterSize: 1 }), FILTER2 = new deck.DataFilterExtension({ filterSize: 2 });
// the window's pings are joined in time order (maintainer, 2026-10-18), faintly, but not across a gap of more than two
// hours, so the hourly positions of the early years still join
const LINE_GAP = 2 * HOUR;
// A bundle has no token: it draws Esri's light grey canvas, which needs no key. A page opened as a file sends no
// Referer, and CARTO's and OpenStreetMap's tiles refuse it (tested 2026-10-20)
const TILES = TOKEN.startsWith('pk.')
  ? [`https://api.mapbox.com/styles/v1/mapbox/light-v11/tiles/256/{z}/{x}/{y}?access_token=${TOKEN}`, '© Mapbox © OpenStreetMap', 19]
  : BUNDLE ? ['https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
              'Tiles © Esri: Esri, HERE, Garmin, © OpenStreetMap contributors', 16] : null;
// a basemap layer for each map: a layer belongs to one deck
const makeBasemap = () => (TILES
  ? new deck.TileLayer({
      id: 'basemap', minZoom: 0, maxZoom: TILES[2], tileSize: 256,
      data: TILES[0],
      renderSubLayers: (props) => {
        const { west, south, east, north } = props.tile.bbox;
        return new deck.BitmapLayer(props, { data: null, image: props.data, bounds: [west, south, east, north] });
      },
    })
  : null);
const basemap = makeBasemap();
$('attrib').textContent = TILES ? TILES[1] : 'no basemap: MAPBOX_TOKEN is not set';
// the pings' colours, named on the map: what a colour means is never left to be guessed
$('speedlegend').innerHTML = `speed 0<span class="ramp" style="background:linear-gradient(to right, ${
  INFERNO.map((c) => `rgb(${c.join(',')})`).join(', ')})"></span>12+ knots`;

// The map's shape is fixed, the same for every vessel, mode and window; only the zoom changes (maintainer, 2026-10-18:
// "the aspect ratio of the 'leaflet' should be fixed across vessel ... the zoom level is the only thing that can
// change"). It is the shape of the fishing grounds around Iceland at the same distance per pixel both ways. 98% of the
// Icelandic fleet's fishing pings in 2016 and 2024 lie in lon -32 to -5, lat 59 to 70, and nearly all of those in the
// box below. At 65°N a degree of longitude is 0.42 of a degree of latitude (47 against 111 km), so the box is 752 by
// 556 km: 1.35 times as wide as tall, on the map's Web Mercator projection too. Where takes a third of the row (index.html),
// and the map is as tall as that width needs.
const GROUNDS = [[-27.5, 62.5], [-11.5, 67.5]];
const merc = (lat) => Math.log(Math.tan(Math.PI / 4 + (lat * Math.PI) / 360));
const MAP_RATIO = ((GROUNDS[1][0] - GROUNDS[0][0]) * Math.PI) / 180 / (merc(GROUNDS[1][1]) - merc(GROUNDS[0][1]));
$('map').style.aspectRatio = String(MAP_RATIO);
// The zoom a map is at, for the hexagons' size
const view = { zoom: 5, latitude: 65 };
function groundsView(el = $('map'), at = view) {   // the fishing grounds' frame for a map element
  const { width, height } = el.getBoundingClientRect();
  const v = new deck.WebMercatorViewport({ width: Math.max(width, 200), height: Math.max(height, 200) }).fitBounds(GROUNDS, { padding: 10 });
  at.zoom = v.zoom; at.latitude = v.latitude;
  return { longitude: v.longitude, latitude: v.latitude, zoom: v.zoom };
}
let afterRender = null;
const deckgl = new deck.Deck({
  parent: $('map'), controller: true, initialViewState: groundsView(),
  onAfterRender: () => { if (afterRender) { const f = afterRender; afterRender = null; f(); } },
  onViewStateChange: ({ viewState }) => {
    const before = hexKm();
    view.zoom = viewState.zoom; view.latitude = viewState.latitude;
    if (drawn('hex') && hexKm() !== before) { S.hexDom = null; render(); }
  },
  getTooltip, onHover: ({ layer, index }) => { if (layer && layer.id === 'pings' && index >= 0) setHover(index, 'map'); },
  layers: basemap ? [basemap] : [],
});

const hours = (ms) => (ms - S.tr.t0) / HOUR;
function layers() {
  const L = basemap ? [basemap] : [], tr = S.tr;
  if (!tr || !tr.n) return L;
  const range = [hours(S.win[0]), hours(S.win[1])];
  // outside the window: the whole loaded track, its fishing hours in hexagons, or nothing but the window's pings
  if (drawn('track')) L.push(new deck.PathLayer({
    id: 'track', data: tr.paths, getPath: (d) => d.path, widthUnits: 'meters', getWidth: 300, widthMinPixels: 1,
    widthMaxPixels: 5, getColor: [70, 80, 100, 90], pickable: true, autoHighlight: true, highlightColor: [0, 0, 0, 149],
  }));
  // fishing effort per hexagon: fixed cells, a quantity and a legend, where a heat map would only smooth (maintainer:
  // "hex-layer instead of heatmap may be better science"). The cells are regular on the Web Mercator map, sized by the
  // zoom (hexKm) and coloured by viridis, a step per decade of hours (hexLayer)
  if (drawn('hex') && tr.fish.length) {
    const km = hexKm();
    if (km !== S.hexKm) { S.hexKm = km; S.hexDom = null; }   // hexagons of another size: their decades learnt again
    if (S.hexDom) $('hexlegend').innerHTML = hexLegend(S.hexDom, km);
    L.push(hexLayer('hex', tr.fish, (d) => d.p, cellHours, km, S.hexDom, (dom) => { S.hexDom = dom; render(); }));
  }
  // the points can be turned off (maintainer, 2026-10-18: "turn off any ping points"); the line is then drawn stronger,
  // so the track stays plain. With both off the window is not drawn: the map shows what it shows around it
  const dots = drawn('points');
  if (drawn('line')) L.push(new deck.LineLayer({
    id: 'window-line', data: tr.lineData, getColor: dots ? [40, 50, 70, 80] : [30, 40, 60, 220], getWidth: dots ? 1 : 1.5,
    widthUnits: 'pixels', extensions: [FILTER2], filterRange: [range, range], updateTriggers: { getColor: dots, getWidth: dots },
  }));
  if (dots) L.push(new deck.ScatterplotLayer({
    id: 'pings', data: tr.pingData, radiusUnits: 'meters', getRadius: 400, radiusMinPixels: 2, radiusMaxPixels: 6,
    pickable: true, extensions: [FILTER], filterRange: range,
  }));
  // The logbook's positions are never drawn: the map holds the AIS track alone, and a haul meets the pings by time
  // only, on the chart (maintainer, 2026-10-20: logbook positions must never join the AIS feed)
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
    if (!(i >= 0 && i < tr.n)) return null;   // a pick left from a track no longer loaded
    const head = layer.id === 'last' ? `<b>${esc(S.name)} (${S.vid})</b><br>last position heard<br>` : '';
    const what = tr.fishing[i] ? 'fishing (fishing_flow)' : (tr.port_call_id[i] >= 0 ? 'in port' : 'at sea, not fishing');
    const g = gearAt(tr.t[i], tr.gear[i]);
    const gear = g.gear ? `, ${esc(g.recorded ? g.gear : gearWords(g))}` : '';
    return { html: `${head}<b>${fmt(tr.t[i])} UTC</b><br>${num(tr.speed[i], 1)} knots, heading ${num(tr.heading[i])}°<br>` +
      `${what}${gear}<br>${num(tr.lat[i], 4)} N, ${num(tr.lon[i], 4)} E` };
  }
  if (layer.id === 'hex' && object) {
    const pts = object.points || [];
    return { html: `<b>${fmtHours(cellHours(pts))} hours of fishing effort</b> in this ${hexKm()} km hexagon<br>` +
      `the time steps of its ${many(pts.length, 'fishing ping')}, each to the next ping` };
  }
  if (layer.id === 'track' && object) return { text: `the track between ports (voyage ${object.voyage_id})` };
  return null;
}
// The map's frame for a time span. A vessel that fished in it is framed on its fishing, not its steaming (maintainer,
// 2026-10-18: "if a fishing vessel, the zoom level 'start' would be the fishing events only, not steaming. could use
// crude measure"): the 1-99% range of the fishing pings' positions, so a stray fishing flag does not widen it. With
// fewer than 5 fishing pings, the whole track in the span.
const FIT_MIN_FISHING = 5;
function fitTo(a, b, glide = false) {
  const tr = S.tr, i0 = lower(tr.t, a), i1 = lower(tr.t, b + 1);
  const fishing = tr.fishCum[i1] - tr.fishCum[i0] >= FIT_MIN_FISHING;
  // the map draws voyages only, so it frames the window's voyage pings, and the harbour when there are none
  const pick = (i) => !fishing || tr.fishing[i];
  let idx = [];
  for (let i = i0; i < i1; i++) if (pick(i) && tr.voyage_id[i] >= 0) idx.push(i);
  if (!idx.length) for (let i = i0; i < i1; i++) if (pick(i)) idx.push(i);
  const xs = Float64Array.from(idx, (i) => tr.lon[i]), ys = Float64Array.from(idx, (i) => tr.lat[i]);
  if (!xs.length) return;
  xs.sort(); ys.sort();
  const q = (v, p) => v[Math.round(p * (v.length - 1))], lo = fishing ? 0.01 : 0, hi = 1 - lo;
  const x0 = q(xs, lo), x1 = q(xs, hi), y0 = q(ys, lo), y1 = q(ys, hi);
  // a vessel in port for the whole window gives a single point: give the box a least size, about 2 km
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, hx = Math.max((x1 - x0) / 2, 0.02), hy = Math.max((y1 - y0) / 2, 0.01);
  const { width, height } = $('map').getBoundingClientRect();
  const pad = Math.min(40, width / 4, height / 4);   // and room for the bar of choices along the map's top
  try {
    const v = new deck.WebMercatorViewport({ width: Math.max(width, 200), height: Math.max(height, 200) })
      .fitBounds([[cx - hx, cy - hy], [cx + hx, cy + hy]], { padding: { top: pad + 24, bottom: pad, left: pad, right: pad } });
    view.zoom = Math.min(v.zoom, 11); view.latitude = v.latitude;
    // after a choice on the chart the map glides to its frame, so the eye follows where the window went
    deckgl.setProps({ initialViewState: { longitude: v.longitude, latitude: v.latitude, zoom: view.zoom,
                                          ...(glide ? { transitionDuration: 300 } : {}) } });
  } catch (e) {
    view.zoom = 8; view.latitude = cy;
    deckgl.setProps({ initialViewState: { longitude: cx, latitude: cy, zoom: 8 } });
  }
  if (drawn('hex')) render();   // the hexagons' size follows the zoom
}

// The speed chart ----------------------------------------------------------------------------------------------------
let plot = null, lanes = null, cursorFromMap = false;
const SYNC = uPlot.sync('vessel');
// The speed chart and the activity record's lanes share one narrow left gutter, the speed's values only, so a time falls
// at the same x in both and the data get the width (maintainer, 2026-10-22: "make margin smaller so there more space
// for viewing the data"). The lanes carry their names inside; the legend names the unit.
const FONT = '11px system-ui';
const AXIS = { size: 24, gap: 3, ticks: { size: 4 }, font: FONT };
const PADDING = [8, 18, null, 2];   // a fixed right margin, the same for both, for the last time label
const inside = (arr, t, maxDur) => { for (let i = lower(arr, t - maxDur, (d) => d.a); i < arr.length && arr[i].a <= t; i++) if (arr[i].b >= t) return arr[i]; return null; };
const tripAt = (t) => inside(S.trips, t, 120 * DAY);

function drawTrips(u) {   // bands behind the speed line, one per logbook trip
  const { ctx } = u, { left, top, width, height } = u.bbox, x0 = u.scales.x.min * 1000, x1 = u.scales.x.max * 1000;
  ctx.save(); ctx.beginPath(); ctx.rect(left, top, width, height); ctx.clip();
  for (let i = lower(S.trips, x0 - 120 * DAY, (d) => d.a); i < S.trips.length && S.trips[i].a <= x1; i++) {
    const d = S.trips[i];
    if (d.b < x0) continue;
    const a = u.valToPos(d.a / 1000, 'x', true), b = u.valToPos(d.b / 1000, 'x', true);
    ctx.fillStyle = S.tripSel.has(d.key) ? 'rgba(214,39,40,0.16)' : (i % 2 ? 'rgba(31,111,235,0.10)' : 'rgba(31,111,235,0.17)');
    ctx.fillRect(a, top, Math.max(1, b - a), height);
  }
  ctx.restore();
}
// Hauls as bars at the top, from the windows the flow gives them (curate/station_window.R), not the logbook's own t1-t4,
// so a haul with a date alone is its day, not a hairline at midnight (decision 177): setting in grey; towing, hauling or
// jigging in green; a day in pale green. The chosen trip's in red, the chosen haul's in black. Landings are triangles at
// the bottom.
const WIN_COLOUR = { set: '#9aa5b1', tow: '#2e7d32', haul: '#2e7d32', jig: '#2e7d32', day: '#a5d6a7', logbook: '#9aa5b1' };
const winColour = (w) => (S.haulSel.has(w.h.key) ? '#111827' : S.tripSel.has(w.h.tkey) && w.phase !== 'set'
  ? (w.phase === 'day' ? '#ef9a9a' : '#b71c1c') : WIN_COLOUR[w.phase] || '#9aa5b1');
function drawMarks(u) {
  const { ctx } = u, { left, top, width, height } = u.bbox, x0 = u.scales.x.min * 1000, x1 = u.scales.x.max * 1000;
  const px = devicePixelRatio || 1, h = 6 * px;
  ctx.save(); ctx.beginPath(); ctx.rect(left, top, width, height); ctx.clip();
  for (let i = lower(S.wins, x0 - (S.wins.maxDur || 0), (d) => d.a); i < S.wins.length && S.wins[i].a <= x1; i++) {
    const w = S.wins[i];
    if (w.b < x0) continue;
    const a = u.valToPos(w.a / 1000, 'x', true), b = u.valToPos(w.b / 1000, 'x', true);
    ctx.fillStyle = winColour(w); ctx.fillRect(a, top + 2 * px, Math.max(px, b - a), h);
  }
  ctx.fillStyle = '#e07b00';
  for (let i = lower(S.landings, x0 - DAY, (d) => d.d); i < S.landings.length && S.landings[i].d <= x1; i++) {
    const x = u.valToPos((S.landings[i].d + 12 * HOUR) / 1000, 'x', true), y = top + height;
    ctx.beginPath(); ctx.moveTo(x, y - 9 * px); ctx.lineTo(x - 5 * px, y); ctx.lineTo(x + 5 * px, y); ctx.closePath(); ctx.fill();
  }
  ctx.restore();
}
const PHASE_WORDS = { set: 'setting the gear', tow: 'towing', haul: 'hauling', jig: 'jigging', logbook: 'gear in the water' };
function describe(t) {   // what is going on at time t, in words, with the records' ids in brackets
  const tp = tripAt(t), hw = inside(S.wins, t, S.wins.maxDur || 0), hl = hw?.h, out = [`${fmt(t)} UTC`];
  if (tp) out.push(`on a logbook trip, ${dstr(tp.T1)} to ${dstr(tp.T2)}: ${tp.n} hauls, ${num(tp.kg / 1000, 1)} t (trip ${tp.tid}, ${tp.schema})`);
  if (hl) out.push(`${hw.phase === 'day' ? 'a haul on this day, the logbook gives its date only' : PHASE_WORDS[hw.phase] || 'gear in the water'}: ` +
                   `${hl.gear || 'gear not known'}, ${num(hl.kg)} kg (haul ${hl.sid}, ${hw.phase} window, ${hw.basis})`);
  const g = !tp && gearAfter(t);
  if (g) out.push(`no logbook yet; gear ${gearWords(g)} (after trip ${S.assumed.tid})`);
  else if (!tp && !hl) out.push('no logbook trip at this time');
  return out.join(' · ');
}
// The chart's speed is capped at 15 knots (maintainer, 2026-10-18: vessels rarely go above 12-15 knots, and fishing is
// well below that): a ping above it is drawn at the cap, and the hover text gives its real speed
const SPEED_CAP = 15, PLOT_H = 230;
const HOVER_HINT = $('hoverinfo').textContent;   // the page's own words, while no time is under the cursor
// The chart is as tall as the map beside it, less the When panel's other lines, so the two end together: the width the
// narrower gutter saved went to Where, which made the map taller (maintainer, 2026-10-22). Never under PLOT_H, and
// PLOT_H on one column.
function plotH() {
  if (!$('p-map').offsetParent || matchMedia('(max-width: 1000px)').matches) return PLOT_H;
  return Math.max(PLOT_H, $('p-map').offsetHeight - ($('p-chart').offsetHeight - $('plot').offsetHeight));
}
// The speed line is drawn trip by trip (maintainer, 2026-10-18: "the when time-speed graph should be segmentized by trip
// - i.e. not a line between entry to harbour to exit from harbour"). A ping in port has no point (plotSpeed is null), and
// the line breaks where the voyage changes; within one voyage it is joined, across an AIS gap too ("you can show a
// stretch if the voyage is the same"). A ping on no voyage and in no port call joins nothing ("a line is drawn between
// time-speed points within any voyage").
function tripGaps(u, sidx, idx0, idx1, nullGaps) {
  const tr = S.tr, xs = u.data[0], gaps = [];
  if (!tr) return nullGaps;   // the previous vessel's chart, redrawn while the next one loads
  for (let i = idx0 + 1; i <= idx1; i++) {
    if (tr.voyage_id[i] < 0 || tr.voyage_id[i] !== tr.voyage_id[i - 1])
      uPlot.addGap(gaps, Math.round(u.valToPos(xs[i - 1], 'x', true)), Math.round(u.valToPos(xs[i], 'x', true)));
  }
  // merged with uPlot's own gaps at the nulls: overlapping gaps cancel each other in its clip, and the line shows again
  const out = [];
  for (const g of [...nullGaps, ...gaps].sort((a, b) => a[0] - b[0])) {
    const last = out.at(-1);
    if (last && g[0] <= last[1]) last[1] = Math.max(last[1], g[1]); else out.push([g[0], g[1]]);
  }
  return out;
}
function makePlot() {
  const tr = S.tr;
  plot?.destroy();
  plot = new uPlot({
    width: $('plot').clientWidth || 600, height: plotH(), legend: { show: false }, padding: PADDING,
    scales: { x: { time: true }, y: { range: [0, SPEED_CAP] } },
    series: [{}, { label: 'speed', stroke: '#1f6feb', width: 1, points: { show: false }, gaps: tripGaps },
             { label: 'fishing', stroke: '#d62728', width: 1.5, points: { show: false }, spanGaps: false, gaps: tripGaps }],
    axes: [{ font: FONT }, AXIS],
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
        if (u.cursor.left == null || u.cursor.left < 0) { $('hoverinfo').textContent = HOVER_HINT; return; }
        $('hoverinfo').textContent = describe(u.posToVal(u.cursor.left, 'x') * 1000);
        if (!cursorFromMap && u.cursor.idx != null) setHover(u.cursor.idx, 'plot');
      }],
    },
  }, [tr.ts, tr.plotSpeed, tr.fishSpeed], $('plot'));
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
    if (tp) selectTrip(tp.tid, tp.schema, { scroll: false }).catch((err) => status(String(err)));
  });
}

// The activity record: one lane per kind of record on the chart's time axis, folded under the chart until opened ---------
// Each lane is named inside itself, above its bars, so the chart and the lanes keep one narrow gutter and nothing is
// drawn over the data. A lane's colour is its kind's everywhere on the page.
const LANES = [
  ['logbook trip', 'trip', '#1f6feb88'], ['haul: setting', 'set', '#9aa5b1'], ['haul: towing, hauling, jigging', 'fish', '#2e7d32'],
  ['haul: date only', 'day', '#a5d6a7'], ['landing', 'land', '#e07b00'], ['in port (port call)', 'call', '#5d6b78'],
  ['voyage', 'voy', '#4a7bd0'], ['fishing (fishing_flow)', 'flow', '#d62728'], ['AIS gap at sea', 'gap', '#111827'],
];
const LANE_H = 20;
function laneLists() {   // every lane as intervals {a, b} sorted by a, with its longest interval for the search
  const tr = S.tr, L = { trip: S.trips, set: [], fish: [], day: [], land: [], call: [], voy: [], flow: [], gap: [] };
  // the hauls' windows as the flow made them (station_window), one lane for the set, one for the attended phases
  for (const w of S.wins) (w.phase === 'set' ? L.set : w.phase === 'day' ? L.day : L.fish).push(w);
  for (const d of S.landings) L.land.push({ a: d.d, b: d.d + DAY, d });
  if (tr) {
    // a run of the fishing flag, ended by a gap in the AIS
    const runs = (key, ok, out) => {
      let s = -1;
      for (let i = 0; i <= tr.n; i++) {
        const same = i < tr.n && ok(i) && s >= 0 && key(i) === key(s) && tr.t[i] - tr.t[i - 1] <= GAP;
        if (s >= 0 && !same) { out.push({ a: tr.t[s], b: tr.t[i - 1], id: key(s) }); s = -1; }
        if (s < 0 && i < tr.n && ok(i)) s = i;
      }
    };
    // the port calls and voyages as the flow made them, one bar each from start to end, whatever the AIS did in between
    // (maintainer, 2026-10-18: "it should reflect what is in the data. ergo: should not have an independent mind")
    L.call = [...S.portCalls]; L.voy = [...S.voy];
    runs(() => 1, (i) => tr.fishing[i] === 1, L.flow);
    // a gap between two pings of one port call is the vessel lying in port, not a hole in the track (maintainer, 2026-10-18:
    // "the ais gap in the graph should not include when vessel is in harbour"); a gap that leaves or reaches a port is kept
    const inPort = (i) => tr.port_call_id[i - 1] >= 0 && tr.port_call_id[i] === tr.port_call_id[i - 1];
    for (let i = 1; i < tr.n; i++) if (tr.t[i] - tr.t[i - 1] > GAP && !inPort(i)) L.gap.push({ a: tr.t[i - 1], b: tr.t[i] });
  }
  for (const k of Object.keys(L)) { L[k].sort((x, y) => x.a - y.a); L[k].maxDur = L[k].reduce((m, d) => Math.max(m, d.b - d.a), 0); }
  return L;
}
function drawLanes(u) {
  const { ctx } = u, { left, top, width, height } = u.bbox, x0 = u.scales.x.min * 1000, x1 = u.scales.x.max * 1000;
  const rowH = height / LANES.length, px = devicePixelRatio || 1;
  ctx.save(); ctx.beginPath(); ctx.rect(left, top, width, height); ctx.clip();
  ctx.font = `${10 * px}px system-ui`; ctx.textBaseline = 'top'; ctx.textAlign = 'left';   // uPlot leaves its axes' 'right'
  LANES.forEach(([label, key, colour], r) => {
    const arr = S.lanes[key], y = top + r * rowH + rowH * 0.5, h = rowH * 0.42;
    ctx.fillStyle = r % 2 ? '#fafbfc' : '#f1f3f5'; ctx.fillRect(left, top + r * rowH, width, rowH);
    ctx.fillStyle = '#5d6b78'; ctx.fillText(label, left + 4 * px, top + r * rowH + 1 * px);
    for (let i = lower(arr, x0 - arr.maxDur, (d) => d.a); i < arr.length && arr[i].a <= x1; i++) {
      const d = arr[i];
      if (d.b < x0) continue;
      const a = u.valToPos(d.a / 1000, 'x', true), b = u.valToPos(d.b / 1000, 'x', true);
      ctx.fillStyle = key === 'trip' && S.tripSel.has(d.key) ? '#d6272888' : key === 'voy' ? (d.id % 2 ? '#4a7bd0' : '#8ab4f8')
        : d.h && S.haulSel.has(d.h.key) ? '#111827' : colour;
      ctx.fillRect(a, y, Math.max(key === 'land' ? 3 : 1, b - a), h);
    }
  });
  ctx.restore();
}
function makeLanes() {
  lanes?.destroy(); lanes = null;
  if (!isOpen('lanes') || !S.tr) return;
  const tr = S.tr, n = LANES.length;
  lanes = new uPlot({
    width: $('lanes').clientWidth || 600, height: LANE_H * n + 8, legend: { show: false }, padding: [4, PADDING[1], 4, PADDING[3]],
    scales: { x: { time: true, min: S.win[0] / 1000, max: S.win[1] / 1000 }, y: { range: [0, n] } },
    series: [{}, { show: false }],
    axes: [{ show: false }, { ...AXIS, splits: () => [], values: () => [], grid: { show: false }, ticks: { show: false } }],
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
        const what = !d ? 'nothing' : key === 'trip' ? `trip ${d.tid}, T1 ${fmt(d.T1)} – T2 ${fmt(d.T2)}`
          : d.h ? `haul ${d.h.sid}, ${d.phase} window ${fmt(d.a)} – ${fmt(d.b)} (${d.basis})` : key === 'land' ? `landing on ${dstr(d.a)}, ${num(d.d.t, 2)} t`
          : key === 'gap' ? `no ping for ${num((d.b - d.a) / 6e4)} min` : `${fmt(d.a)} – ${fmt(d.b)}${d.id != null && key !== 'flow' ? ` (id ${d.id})` : ''}`;
        $('hoverinfo').textContent = `${describe(t)} · lane ${label}: ${what}`;
      }],
    },
  }, [[tr.t0 / 1000, tr.t1 / 1000], [null, null]], $('lanes'));
  clickToSelect(lanes);
}
function fitPanels() {
  plot?.setSize({ width: $('plot').clientWidth, height: plotH() });
  lanes?.setSize({ width: $('lanes').clientWidth, height: LANE_H * LANES.length + 8 });
}
// the chart follows its panel's width, which a scroll bar's coming and going also moves
new ResizeObserver(() => requestAnimationFrame(fitPanels)).observe($('p-chart'));
window.addEventListener('resize', () => {
  fitPanels();
});

function setHover(i, source) {
  S.hover = i;
  render();
  if (source === 'map' && plot) {
    cursorFromMap = true;
    plot.setCursor({ left: plot.valToPos(S.tr.ts[i], 'x'), top: plot.valToPos(S.tr.plotSpeed[i] ?? 0, 'y') });
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
  const days = Math.round(((b - a) / DAY) * 10) / 10;
  $('window-label').textContent = `${fmt(a)} – ${fmt(b)} UTC (${num(days, 1)} ${days === 1 ? 'day' : 'days'})`;
  $('pings-sum').textContent = `${(lower(tr.t, b + 1) - lower(tr.t, a)).toLocaleString('en-GB')} pings`;
  afterRender = () => {
    const ms = performance.now() - t0;
    $('perf').textContent = `redraw ${Math.round(ms)} ms, ${tr.n.toLocaleString('en-GB')} pings loaded`;
    if (onRedraw) { const f = onRedraw; onRedraw = null; f(ms); }
  };
  render();
  // the window's cards and pings follow it, once it rests
  clearTimeout(pingTimer); pingTimer = setTimeout(() => { S.pingPage = 0; renderCards(); renderPings(); }, 150);
  if (source === 'plot' || source === 'slider') {
    P.win = 'custom'; P.a = a; P.b = b; markPicked();
    clearTimeout(hashTimer); hashTimer = setTimeout(setHash, 300);   // Safari refuses many replaceState calls in a row
    // the map follows a window chosen on the chart or the slider (maintainer, 2026-10-18: "the zoom should be dynamic
    // here"), framed as at the start, on the fishing in it: at once after a drag, once the slider rests
    clearTimeout(fitTimer); fitTimer = setTimeout(() => fitTo(S.win[0], S.win[1], true), source === 'plot' ? 0 : 200);
  }
}
let hashTimer = null, fitTimer = null;
function slider() {
  let a = +$('wfrom').value * 1000, b = +$('wto').value * 1000;
  if (a > b) [a, b] = [b, a];
  setWindow(a, b, 'slider');
}
$('wfrom').addEventListener('input', slider);
$('wto').addEventListener('input', slider);
// Viridis, R's default ("D"), in six steps; the hexagons' size follows the zoom (maintainer, 2026-10-18): about 12 pixels
// from centre to corner, rounded to a step so the cells re-aggregate only when the step changes
// The hexagons are about 6 pixels from centre to corner, half what they were (maintainer, 2026-10-22: "provide higher
// hex-resolution at any zoom"), rounded to a step so the cells re-aggregate only when the step changes
const HEX_STEPS = [0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50];
const HEX_PX = 6;
function hexKm(at = view) {
  const mpp = (2 * Math.PI * 6378137 * Math.cos((at.latitude * Math.PI) / 180)) / (512 * 2 ** at.zoom);
  const km = (HEX_PX * mpp) / 1000;
  return HEX_STEPS.reduce((b, x) => (Math.abs(Math.log(x / km)) < Math.abs(Math.log(b / km)) ? x : b));
}
const HEX_MIN_H = 0.01;   // a cell of less, a ping or two of a few seconds, is coloured as 0.01 h: log10 of 0 has no place
// A hexagon's effort is the sum of its fishing pings' time steps, the trail's `hours` (each fix to the next in its voyage,
// capped: ramb::rb_add_effort), not a count of pings (maintainer, 2026-10-22: "use the effort (time steps / dt) rather
// than number of pings")
const cellHours = (pts) => pts.reduce((s, d) => s + ((d.source || d).h || 0), 0);   // a picked cell wraps its points
const fmtHours = (x) => (x < 10 ? Number(x.toPrecision(2)).toString() : Math.round(x).toLocaleString('en-GB'));
// the legend in hours: the ends of the scale, and each colour's range on hovering it
// The colour is on a log scale with a step per decade (maintainer, 2026-10-18: "fishing hours should be displayed on a
// log-scale"; 2026-10-22: "show the colour scale on a log scale"): a hexagon's colour is the decade its hours fall in,
// 0.01-0.1, 0.1-1, 1-10 and so on, from the decade of the smallest hexagon to that of the largest, viridis across them,
// and the legend names every bound. The steps are the vessel's own: the scale is not pinned across vessels (the
// maintainer: "lets hold on that").
const VIRIDIS9 = ['#440154', '#472d7b', '#3b528b', '#2c728e', '#21918c', '#28ae80', '#5ec962', '#addc30', '#fde725']
  .map((c) => [1, 3, 5].map((i) => parseInt(c.slice(i, i + 2), 16)));
const VIRIDIS = VIRIDIS9.filter((_, i) => i % 2 === 0).slice(0, 4).concat([VIRIDIS9[6], VIRIDIS9[8]]);   // six steps, before the domain is known
function viridis(n) {   // n colours spread over viridis, the first dark and the last yellow
  if (n === 1) return [VIRIDIS9[4]];
  return Array.from({ length: n }, (_, k) => {
    const x = (k / (n - 1)) * (VIRIDIS9.length - 1), i = Math.min(Math.floor(x), VIRIDIS9.length - 2), f = x - i;
    return VIRIDIS9[i].map((v, j) => Math.round(v + (VIRIDIS9[i + 1][j] - v) * f));
  });
}
const decades = ([lo, hi]) => { const a = Math.max(Math.log10(HEX_MIN_H), Math.floor(lo)); return [a, Math.max(a + 1, Math.ceil(hi - 1e-9))]; };
// A hexagon layer whose colours step by decade. The first draw learns the hexagons' range (dom null); onDomain then
// receives its decades, and the layer is drawn again on them. Changing the domain recolours, it does not re-aggregate.
function hexLayer(id, data, getPosition, sumHours, km, dom, onDomain) {
  return new deck.HexagonLayer({
    id, data, getPosition, getColorValue: (pts) => Math.log10(Math.max(sumHours(pts), HEX_MIN_H)),
    extruded: false, radius: 1000 * km, coverage: 0.94, opacity: 0.75, pickable: true, upperPercentile: 100,
    colorDomain: dom, colorRange: dom ? viridis(dom[1] - dom[0]) : VIRIDIS,
    onSetColorDomain: (got) => {
      const d = decades(got);
      if (!dom || d[0] !== dom[0] || d[1] !== dom[1]) setTimeout(() => onDomain(d), 0);   // after this draw
    },
  });
}
const hexLegend = ([a, b], km) => {
  const cols = viridis(b - a), at = (k) => `<span class="tick">${fmtHours(10 ** k)}</span>`;
  return `effort per ${km} km hexagon, in hours (log scale): ${at(a)}${cols.map((c, k) =>
    `<span class="sw" style="background:rgb(${c.join(',')});margin:0 2px" title="${fmtHours(10 ** (a + k))} to ${fmtHours(10 ** (a + k + 1))} hours"></span>${at(a + k + 1)}`).join('')}`;
};
function showLayers() {
  const hex = drawn('hex') && S.tr?.fish.length > 0;
  $('hexlegend').style.display = hex ? '' : 'none';
  S.hexDom = null;
  $('speedlegend').style.display = drawn('points') ? '' : 'none';
  // the map's subtitle names what it draws
  const inside = drawn('points') ? (drawn('line') ? 'the AIS track in the window, each ping coloured by its speed' : "the window's pings, coloured by their speed")
    : drawn('line') ? 'the AIS track in the window' : "the window's track not drawn";
  const around = [hex && 'fishing hours', drawn('track') && 'the whole track'].filter(Boolean);
  $('where-note').textContent = inside + (around.length ? `; ${around.join(' and ')} around it` : '');
  document.querySelectorAll('#mapctl [data-lay]').forEach((x) => x.classList.toggle('on', drawn(x.dataset.lay)));
  render();
}
// each of the map's layers is a button, on or off
document.querySelectorAll('#mapctl [data-lay]').forEach((b) => b.addEventListener('click', () => {
  if (b.disabled) return;
  const k = b.dataset.lay;
  if (P.lay.has(k)) P.lay.delete(k); else P.lay.add(k);
  showLayers();
  setHash();
}));

// Presets: each sets the window and centres the map on it
function show(a, b) { if (!S.tr) return; fitTo(Math.max(a, S.tr.t0), Math.min(b, S.tr.t1)); setWindow(a, b); }
// The flow's voyages (curate/ais_voyage.R), oldest first; keyed by year and number, which restarts each year
const voyages = () => S.voy || [];
// "Last N trips" is the last N finished trips and then the current one (maintainer, 2026-10-18: "the 'last trip' should
// be last trip and then the current trip"). The finished trips are the logbook's over the loaded track, then the AIS
// voyages after the last of them, whose logbook is not in yet; a vessel with no logbook trip has its voyages. The
// current trip is the track after them while the vessel is at sea at its last ping.
const MIN_VOYAGE = HOUR;   // a shorter move is a shift within a port, not a trip
function lastUnits() {   // newest last
  const tr = S.tr, trips = S.trips.filter((d) => d.b >= tr.t0 && d.a <= tr.t1);
  const after = trips.length ? trips.at(-1).b : -Infinity, atSea = tr.port_call_id[tr.n - 1] < 0;
  const voy = voyages().filter((v) => v.a > after && v.b - v.a >= MIN_VOYAGE && !(atSea && v.b >= tr.t1));
  return { word: trips.length ? 'trips' : 'voyages', units: [...trips, ...voy], atSea };
}
// The button names what it shows; 0 trips is the current trip alone ("the zero here is important", maintainer)
function lastLabel() {
  const n = P.n, { word, atSea } = S.tr ? lastUnits() : { word: 'trips', atSea: false };
  $('last-trips').textContent = n === 0 ? (atSea ? 'The current trip' : 'Since the last trip')
    : `Last ${n} ${n === 1 ? word.slice(0, -1) : word}${atSea ? ' + the current' : ''}`;
}
function showLastTrips() {
  if (!S.tr) return;
  const tr = S.tr, n = P.n, { units, atSea } = lastUnits();
  lastLabel();
  if (n === 0) {   // at sea, the voyage it is on; in port, the time since the last trip
    const cur = atSea ? voyages().at(-1) : null;
    const a = cur && cur.b >= tr.t1 ? cur.a : units.length ? units.at(-1).b : tr.t1 - DAY;
    show(Math.min(a, tr.t1 - HOUR) - HOUR, tr.t1);
    return;
  }
  if (!units.length) { show(tr.t1 - 30 * DAY, tr.t1); return; }
  const pick = units.slice(-n);
  show(Math.min(...pick.map((d) => d.a)) - HOUR, atSea ? tr.t1 : Math.max(...pick.map((d) => d.b)) + HOUR);
}
// The window the user chose, for this vessel: the same kind of window, or the same dates where they overlap its track
function applyWin() {
  if (!S.tr) return;
  lastLabel();
  if (P.win === 'month') show(S.tr.t1 - 30 * DAY, S.tr.t1);
  else if (P.win === 'range') show(S.tr.t0, S.tr.t1);
  else if (P.win === 'custom' && P.a < S.tr.t1 && P.b > S.tr.t0) show(P.a, P.b);
  else showLastTrips();
  markPicked();
}
function markPicked() {
  for (const [id, w] of [['last-trips', 'last'], ['month', 'month'], ['all', 'range']]) $(id).classList.toggle('picked', P.win === w);
}
const preset = (w, f) => () => { if (!S.tr) return; P.win = w; markPicked(); f(); setHash(); };
$('last-trips').addEventListener('click', preset('last', showLastTrips));
$('ntrips').addEventListener('change', () => { P.n = +$('ntrips').value; preset('last', showLastTrips)(); });
$('month').addEventListener('click', preset('month', () => show(S.tr.t1 - 30 * DAY, S.tr.t1)));
$('all').addEventListener('click', preset('range', () => show(S.tr.t0, S.tr.t1)));
$('fit').addEventListener('click', () => S.tr && fitTo(S.win[0], S.win[1]));
$('all-years').addEventListener('click', () => {
  if (!S.vid || !S.years.length) return;
  P.years = 'all';
  loadRange(S.years[0], S.years.at(-1)).catch((e) => status(String(e)));
});
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
  for (const t of ['h_trips', 'trips']) {
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
  S.trip = d.tid; S.selKey = `${d.tid}|${d.schema}`; S.haul = null; S.haulOpen = false;
  S.tripSel = new Set([S.selKey]); S.haulSel = new Set();
  showTab('now');
  const [a, b] = [d.a, d.b];   // the trip and the hauls it attends, which the logbook may put outside T1-T2
  if (S.tr) { fitTo(a, b); setWindow(a - HOUR, b + HOUR); plot.redraw(false); lanes?.redraw(false); }
  if (opts.open) { if (opts.only) S.expanded = new Set(); S.expanded.add(S.selKey); }
  const row = () => document.querySelector(`#trips tr.trip[data-key="${CSS.escape(S.selKey)}"]`);
  if (opts.open || !row()) {   // from the chart or the History tab: the row on its page
    S.tripPage = Math.floor(tripRows().findIndex((r) => r.key === S.selKey) / TRIPS_PER_PAGE);
    await renderTrips();
  } else markSelected();
  if (opts.scroll) row()?.scrollIntoView({ block: 'nearest' });
  setHash();
}
// One haul: the window, the map's frame and the chart on it alone, as a trip's row does for the trip (maintainer,
// 2026-10-22: "if the user selects a single event within a trip the graphs would update accordingly"), its trip opened
// in the table and its record opened under its row, every field (decision 178). Its span is that of its windows
// (station_window): a date-only haul is its day. A second click on the chosen haul closes its record.
async function selectHaul(h, opts = {}) {
  if (S.haul === h.key && S.haulOpen && S.haulSel.size === 1 && !opts.open) { S.haulOpen = false; await renderTrips(); renderCards(); return; }
  const d = S.tripOf.get(h.tkey);
  if (d) {
    S.trip = d.tid; S.selKey = d.key; S.expanded = new Set([S.selKey]);
    S.tripPage = Math.max(0, Math.floor(tripRows().findIndex((r) => r.key === S.selKey) / TRIPS_PER_PAGE));
  }
  S.haul = h.key; S.haulOpen = true;
  S.tripSel = new Set(d ? [d.key] : []); S.haulSel = new Set([h.key]);
  if (S.tr) {
    const pad = h.dateOnly ? 0 : 30 * 6e4;
    fitTo(h.a - 2 * pad, h.b + 2 * pad); setWindow(h.a - pad, h.b + pad); plot.redraw(false); lanes?.redraw(false);
  }
  await renderTrips();
  if (opts.scroll) document.querySelector(`#trips tr.haul[data-key="${CSS.escape(h.key)}"]`)?.scrollIntoView({ block: 'nearest' });
  setHash();
}
// A landing no logbook trip claims: the window on the AIS voyage that ended there, else on the landing's days
function selectLanding(r) {
  S.trip = null; S.selKey = r.key; S.haul = null; S.haulOpen = false; S.tripSel = new Set(); S.haulSel = new Set();
  if (S.tr) {
    const near = voyages().filter((w) => w.b >= r.d - DAY && w.b <= r.d + 2 * DAY)
      .sort((x, y) => Math.abs(x.b - r.d - 12 * HOUR) - Math.abs(y.b - r.d - 12 * HOUR))[0];
    const [a, b] = near ? [near.a, near.b] : [r.d - DAY, r.d + 2 * DAY];
    fitTo(a, b); setWindow(a - HOUR, b + HOUR); plot.redraw(false); lanes?.redraw(false);
  }
  markSelected();
}
function markSelected() {
  document.querySelectorAll('#trips tr.trip, #trips tr.landrow').forEach((row) => row.classList.toggle('sel', isChosen(row.dataset.key)));
}
const isChosen = (key) => S.tripSel.has(key) || key === S.selKey;
// Several at once (maintainer, 2026-10-22: "even allow for selecting a number of trips or if within a trip a number of
// events"), as a list does it: Shift-click chooses the run of rows from the last one clicked, Ctrl- or ⌘-click adds or
// removes one. The window spans what is chosen, the map frames it, and the chart and the lanes draw it, trips red and
// hauls black; a line over the table, or over the trip's hauls, sums it.
const toggled = (set, key) => { const x = new Set(set); if (x.has(key)) x.delete(key); else x.add(key); return [...x]; };
const run = (order, from, to) => {
  const i = order.indexOf(from), j = order.indexOf(to);
  return i < 0 || j < 0 ? [to] : order.slice(Math.min(i, j), Math.max(i, j) + 1);
};
async function chooseTrips(keys, anchor) {
  const ds = keys.map((k) => S.tripOf.get(k)).filter(Boolean);
  S.haulSel = new Set(); S.haul = null; S.haulOpen = false;
  if (!ds.length) { S.tripSel = new Set(); S.trip = null; S.selKey = null; await renderTrips(); setHash(); return; }
  S.tripSel = new Set(ds.map((d) => d.key));
  const an = (S.tripSel.has(anchor) && S.tripOf.get(anchor)) || ds.at(-1);   // not one just taken out
  S.trip = an.tid; S.selKey = an.key;
  if (S.tr) {
    const a = Math.min(...ds.map((d) => d.a)), b = Math.max(...ds.map((d) => d.b));
    fitTo(a, b); setWindow(a - HOUR, b + HOUR); plot.redraw(false); lanes?.redraw(false);
  }
  await renderTrips(); setHash();
}
async function chooseHauls(keys, anchor) {
  const hs = keys.map((k) => S.haulOf.get(k)).filter(Boolean);
  if (!hs.length) { S.haulSel = new Set(); S.haul = null; S.haulOpen = false; await renderTrips(); setHash(); return; }
  S.haulSel = new Set(hs.map((h) => h.key)); S.haul = anchor && S.haulSel.has(anchor) ? anchor : hs.at(-1).key;
  S.haulOpen = hs.length === 1;
  const ts = [...new Set(hs.map((h) => h.tkey))].filter((k) => S.tripOf.has(k));
  S.tripSel = new Set(ts);
  for (const k of ts) S.expanded.add(k);
  if (ts.length) { const d = S.tripOf.get(ts.at(-1)); S.trip = d.tid; S.selKey = d.key; }
  if (S.tr) {
    const pad = hs.every((h) => h.dateOnly) ? 0 : 30 * 6e4, a = Math.min(...hs.map((h) => h.a)), b = Math.max(...hs.map((h) => h.b));
    fitTo(a - 2 * pad, b + 2 * pad); setWindow(a - pad, b + pad); plot.redraw(false); lanes?.redraw(false);
  }
  await renderTrips(); setHash();
}

// The years of trail, trips, hauls and landings --------------------------------------------------------------------
async function loadRange(from, to) {
  const t = performance.now();
  S.from = Math.min(from, to); S.to = Math.max(from, to);
  $('from').value = S.from; $('to').value = S.to;
  status(`loading ${S.from}–${S.to}`);
  const yrs = { vid: S.vid, from: S.from, to: S.to };
  const hasTrail = S.years.some((y) => y >= S.from && y <= S.to);
  await loadAll([...(hasTrail ? [['trail', 'trail', yrs], ['voyages', 'voyages', yrs], ['port_calls', 'port_calls', yrs]] : []),
                 ['trips', 'trips', yrs], ['stations', 'stations', yrs], ['windows', 'windows', yrs],
                 ['station_catch', 'station_catch', yrs], ['landings', 'landings', yrs]]);
  S.trips = await rows(`SELECT t.".tid" AS tid, t.schema, epoch_ms(t.T1)::DOUBLE AS T1, epoch_ms(t.T2)::DOUBLE AS T2,
      coalesce(t.port, '') AS port, t.T1_basis AS b1, t.T2_basis AS b2, count(s.".sid")::INTEGER AS n,
      coalesce(sum(c.kg), 0)::DOUBLE AS kg
    FROM trips t LEFT JOIN stations s USING (".tid", schema)
    LEFT JOIN (SELECT ".sid", schema, sum(catch) AS kg FROM station_catch GROUP BY ALL) c USING (".sid", schema)
    WHERE t.T1 IS NOT NULL AND t.T2 IS NOT NULL GROUP BY ALL ORDER BY T1`);
  S.stations = await rows(`SELECT s.".tid" AS tid, s.schema, s.".sid" AS sid, lon1, lat1, lon2, lat2, epoch_ms(date)::DOUBLE AS d0, epoch_ms(t1)::DOUBLE AS t1, epoch_ms(t2)::DOUBLE AS t2,
      epoch_ms(t3)::DOUBLE AS t3, epoch_ms(t4)::DOUBLE AS t4, coalesce(gear, '') AS gear,
      coalesce(target, '') AS target, coalesce(gear_basis, '') AS gear_basis, strftime(date, '%Y-%m-%d') AS day, z1, z2, station_type, duration_m, effort, effort_unit,
      coalesce(c.kg, 0)::DOUBLE AS kg
    FROM stations s LEFT JOIN (SELECT ".sid", schema, sum(catch) AS kg FROM station_catch GROUP BY ALL) c USING (".sid", schema)
    ORDER BY coalesce(t1, date)`);
  // Each haul's windows as the flow made them (curate/station_window.R): it is drawn, framed and judged by them, and its
  // pings are those carrying its .sid (decision 177). The logbook's t1-t4 stay as recorded, for Quality control to read. A
  // haul with no window (none is expected: a duplicate twin's trip is left out) keeps its logbook times.
  const byKey = new Map();
  for (const w of await rows(`SELECT ".sid" AS sid, schema, phase, epoch_ms(w_start)::DOUBLE AS a, epoch_ms(w_end)::DOUBLE AS b,
      win_basis AS basis FROM windows ORDER BY w_start`)) {
    const k = `${w.sid}|${w.schema}`;
    if (!byKey.has(k)) byKey.set(k, []);
    byKey.get(k).push(w);
  }
  S.wins = [];
  S.hauls = S.stations.map((s) => {
    const h = { ...s, key: `${s.sid}|${s.schema}`, tkey: `${s.tid}|${s.schema}` };
    h.wins = (byKey.get(h.key) || []).map((w) => ({ a: w.a, b: w.b, phase: w.phase, basis: w.basis, h }));
    if (!h.wins.length) {
      const a = h.t1 ?? h.t2 ?? h.t3 ?? h.d0;
      h.wins = [{ a, b: h.t4 ?? h.t3 ?? h.t2 ?? a, phase: 'logbook', basis: 'no window: the logbook times', h }];
    }
    h.a = Math.min(...h.wins.map((w) => w.a)); h.b = Math.max(...h.wins.map((w) => w.b));
    h.dateOnly = h.wins.every((w) => w.phase === 'day');
    S.wins.push(...h.wins);
    return h;
  }).sort((x, y) => x.a - y.a);
  S.wins.sort((x, y) => x.a - y.a);
  S.wins.maxDur = S.wins.reduce((m, w) => Math.max(m, w.b - w.a), 0);
  tripSpans();
  for (const d of S.trips) d.key = `${d.tid}|${d.schema}`;
  S.tripOf = new Map(S.trips.map((d) => [d.key, d]));
  S.haulOf = new Map(S.hauls.map((h) => [h.key, h]));
  // the flow's voyages and port calls, each from its table: the lanes and the presets draw them as they are
  S.voy = hasTrail ? await rows(`SELECT year, voyage_id AS id, epoch_ms(T1)::DOUBLE AS a, epoch_ms(T2)::DOUBLE AS b, pid1, pid2,
      n_pings FROM voyages ORDER BY T1`) : [];
  S.portCalls = hasTrail ? await rows(`SELECT port_call_id AS id, pid, epoch_ms(T_in)::DOUBLE AS a, epoch_ms(T_out)::DOUBLE AS b
    FROM port_calls ORDER BY T_in`) : [];
  S.landings = await rows(`SELECT epoch_ms(date)::DOUBLE AS d, round(sum(catch) / 1000, 2)::DOUBLE AS t
    FROM landings GROUP BY ".lid", schema, date ORDER BY d`);
  // one row per landing, joined to its logbook trip through lid_map: a trip's row shows what it landed, and a landing
  // no trip of the range claims gets a row of its own in the trip table
  const L = await rows(`SELECT ".lid" AS lid, schema, epoch_ms(date)::DOUBLE AS d, strftime(date, '%Y-%m-%d') AS day,
      any_value(port) AS port, any_value(coalesce(gear_name, gear)) AS gear, round(sum(catch) / 1000, 2)::DOUBLE AS t,
      string_agg(sid::VARCHAR || ': ' || round(catch)::BIGINT::VARCHAR || ' kg', ', ' ORDER BY catch DESC) AS sp
    FROM landings GROUP BY 1, 2, 3, 4 ORDER BY d`);
  const links = await rows(`SELECT ".lid" AS lid, schema_land, ".tid" AS tid, schema, match_type FROM landing_trips`);
  const byTrip = new Map(), linked = new Map();
  for (const k of links) {
    linked.set(`${k.lid}|${k.schema_land}`, k);
    const key = `${k.tid}|${k.schema}`;
    if (!byTrip.has(key)) byTrip.set(key, []);
    byTrip.get(key).push(k);
  }
  const byLid = new Map(L.map((l) => [`${l.lid}|${l.schema}`, l]));
  for (const d of S.trips) {
    d.landed = (byTrip.get(`${d.tid}|${d.schema}`) || []).filter((k) => byLid.has(`${k.lid}|${k.schema_land}`))
      .map((k) => ({ ...byLid.get(`${k.lid}|${k.schema_land}`), match: k.match_type }));
    d.landedT = d.landed.reduce((x, l) => x + l.t, 0);
  }
  const inTable = new Set(S.trips.map((d) => `${d.tid}|${d.schema}`));
  S.landRows = L.map((l) => ({ ...l, kind: 'landing', key: `L${l.lid}|${l.schema}`, link: linked.get(`${l.lid}|${l.schema}`) || null }));
  S.landOnly = S.landRows.filter((l) => !l.link || !inTable.has(`${l.link.tid}|${l.link.schema}`));
  S.expanded = new Set(); S.tripPage = 0; S.trip = null; S.selKey = null; S.haul = null; S.haulOpen = false;
  S.tripSel = new Set(); S.haulSel = new Set();
  if (hasTrail) await buildTrail(); else { S.tr = null; plot?.destroy(); plot = null; lanes?.destroy(); lanes = null; $('window-label').textContent = ''; render(); }
  tripChecks();
  S.lanes = laneLists();
  if (S.tr) makeLanes();
  $('all').textContent = `Whole range: ${S.from === S.to ? S.from : `${S.from}–${S.to}`}`;
  const hexb = document.querySelector('#mapctl [data-lay="hex"]'), fished = S.tr && S.tr.fish.length > 0;
  hexb.disabled = !fished;
  hexb.title = fished ? `${num(S.tr.fish.reduce((s, d) => s + d.h, 0))} fishing hours in ${S.tr.fish.length.toLocaleString('en-GB')} pings, these years`
                      : 'no fishing ping in these years';
  showLayers();   // the user's choice of fishing hours stays for the next vessel that fished
  applyWin();
  S.tripPage = S.tr ? windowPage() : 0;
  await renderTrips();
  renderSummary();
  renderCards();
  renderPings();
  setHash();
  status(`${S.from}–${S.to}: ${S.tr ? S.tr.n.toLocaleString('en-GB') + ' pings, ' : 'no AIS, '}${S.trips.length} trips, ` +
         `${S.stations.length} hauls, ${S.landings.length} landings · ${Math.round(performance.now() - t)} ms`);
}
async function buildTrail() {
  const tbl = await conn.query(`SELECT epoch_ms(time)::DOUBLE AS t, lon::FLOAT AS lon, lat::FLOAT AS lat,
      coalesce(speed, 0)::FLOAT AS speed, coalesce(heading, 0)::FLOAT AS heading, coalesce(voyage_id, -1)::INTEGER AS voyage_id,
      coalesce(port_call_id, -1)::INTEGER AS port_call_id, coalesce(fishing_flow, false)::INTEGER AS fishing, coalesce(gear, '') AS gear,
      coalesce("hours", 0)::FLOAT AS h, coalesce(".sid", -1)::DOUBLE AS sid, coalesce(schema, '') AS sch,
      coalesce(phase, '') AS phase
    FROM trail WHERE lon IS NOT NULL AND lat IS NOT NULL ORDER BY time`);
  const col = (k) => tbl.getChild(k).toArray();
  const tr = { n: tbl.numRows, t: col('t'), lon: col('lon'), lat: col('lat'), speed: col('speed'), heading: col('heading'),
               voyage_id: col('voyage_id'), port_call_id: col('port_call_id'), fishing: col('fishing'), gear: col('gear'), h: col('h') };
  if (!tr.n) { S.tr = null; render(); return; }
  tr.t0 = tr.t[0]; tr.t1 = tr.t[tr.n - 1];
  tr.ts = new Float64Array(tr.n); tr.pos = new Float32Array(2 * tr.n); tr.col = new Uint8Array(4 * tr.n);
  tr.th = new Float32Array(tr.n); tr.fishSpeed = new Array(tr.n); tr.fishCum = new Int32Array(tr.n + 1);
  tr.plotSpeed = new Array(tr.n);   // an Array, since a ping in port is null: no point, no line
  tr.paths = [];   // one path per voyage: a new one wherever the number changes, since it restarts each year
  let path = null;
  for (let i = 0; i < tr.n; i++) {
    tr.ts[i] = tr.t[i] / 1000; tr.th[i] = (tr.t[i] - tr.t0) / HOUR;
    tr.pos[2 * i] = tr.lon[i]; tr.pos[2 * i + 1] = tr.lat[i];
    const c = speedColour(tr.speed[i]);
    tr.col[4 * i] = c[0]; tr.col[4 * i + 1] = c[1]; tr.col[4 * i + 2] = c[2]; tr.col[4 * i + 3] = 230;
    tr.plotSpeed[i] = tr.port_call_id[i] >= 0 ? null : tr.speed[i] > SPEED_CAP ? SPEED_CAP : tr.speed[i];
    tr.fishSpeed[i] = tr.fishing[i] ? tr.plotSpeed[i] : null;
    tr.fishCum[i + 1] = tr.fishCum[i] + (tr.fishing[i] ? 1 : 0);
    const v = tr.voyage_id[i];
    if (v < 0) path = null;
    else {
      if (!path || path.voyage_id !== v) { path = { voyage_id: v, path: [] }; tr.paths.push(path); }
      path.path.push([tr.lon[i], tr.lat[i]]);
    }
  }
  // the fishing pings with the hours each stands for (the trail's `hours`, the effort of the fix): the hexagons sum hours,
  // not pings, so a stretch the AIS reported often does not count for more than one it reported seldom
  tr.fish = [];
  for (let i = 0; i < tr.n; i++) if (tr.fishing[i]) tr.fish.push({ p: [tr.lon[i], tr.lat[i]], h: tr.h[i] });
  // Each fix's haul, by the .sid the flow gave it (one fix, one record: decision 090), so a haul's pings are counted as the
  // flow placed them, not by the logbook's times (decision 177). Its fishing pings leave out its set window: a net or a line
  // is judged on its hauling, a set may be made on an earlier trip.
  const sid = col('sid'), sch = col('sch'), phase = col('phase');
  tr.haulKey = new Array(tr.n); tr.bySid = new Map();
  for (let i = 0; i < tr.n; i++) {
    const k = sid[i] >= 0 ? `${sid[i]}|${sch[i]}` : '';
    tr.haulKey[i] = k;
    if (!k) continue;
    let c = tr.bySid.get(k);
    if (!c) tr.bySid.set(k, (c = { n: 0, fish: 0 }));
    c.n++;
    if (tr.fishing[i] && phase[i] !== 'set') c.fish++;
  }
  const m = Math.max(tr.n - 1, 0);   // segment i joins ping i to ping i + 1; both must be in the window
  // the map draws voyages only (maintainer, 2026-10-20): a ping in no voyage, in port above all, is left out, and a
  // segment is drawn within one voyage; the chart keeps every ping
  tr.mapF = new Float32Array(tr.n);
  for (let i = 0; i < tr.n; i++) tr.mapF[i] = tr.voyage_id[i] >= 0 ? tr.th[i] : -1e9;
  tr.segF = new Float32Array(2 * m);
  for (let i = 0; i < m; i++) {
    const ok = tr.t[i + 1] - tr.t[i] <= LINE_GAP && tr.voyage_id[i] >= 0 && tr.voyage_id[i] === tr.voyage_id[i + 1];
    tr.segF[2 * i] = ok ? tr.th[i] : -1e9; tr.segF[2 * i + 1] = ok ? tr.th[i + 1] : -1e9;
  }
  tr.lineData = { length: m, attributes: { getSourcePosition: { value: tr.pos.subarray(0, 2 * m), size: 2 },
                                           getTargetPosition: { value: tr.pos.subarray(2), size: 2 },
                                           getFilterValue: { value: tr.segF, size: 2 } } };
  tr.pingData = { length: tr.n, attributes: { getPosition: { value: tr.pos, size: 2 }, getFillColor: { value: tr.col, size: 4 },
                                              getFilterValue: { value: tr.mapF, size: 1 } } };
  S.tr = tr; S.hover = -1;
  for (const id of ['wfrom', 'wto']) { $(id).min = tr.t0 / 1000; $(id).max = tr.t1 / 1000; $(id).step = 60; }
  makePlot();
  const a = Math.max(tr.t0, tr.t1 - 30 * DAY);
  S.win = [a, tr.t1];
  fitTo(a, tr.t1);
  setWindow(a, tr.t1);
}
const reloadYears = () => {
  if (!S.vid) return;
  const f = +$('from').value, t = +$('to').value;
  P.years = `${Math.min(f, t)}-${Math.max(f, t)}`;
  loadRange(f, t).catch((e) => status(String(e)));
};
$('from').addEventListener('change', reloadYears);
$('to').addEventListener('change', reloadYears);

// Where the logbook and the pings disagree, per trip (Quality control). A haul is judged by the windows the flow gives it
// (station_window, which applies the gear's rule) and by the pings carrying its .sid (decision 177): a static gear on its
// hauling, since nets and lines may be set on an earlier trip; a towed gear on its tow; a date-only haul on its day.
// A trip spans its T1-T2 and the windows its hauls are attended in, so a trip known by its dates alone is its days, as a
// date-only haul is its day (decision 177). Its band on the chart, its pings, the presets and its frame use that span (a, b);
// the table shows T1 and T2 as recorded. A set window is left out: a net may be set on an earlier trip.
function tripSpans() {
  const byTrip = new Map();
  for (const h of S.hauls) {
    h.att = h.wins.filter((w) => w.phase !== 'set');
    if (!h.att.length) h.att = h.wins;
    const k = `${h.tid}|${h.schema}`;
    if (!byTrip.has(k)) byTrip.set(k, []);
    byTrip.get(k).push(h);
  }
  for (const d of S.trips) {
    d.hauls = byTrip.get(`${d.tid}|${d.schema}`) || [];
    const att = d.hauls.flatMap((h) => h.att);
    d.a = Math.min(d.T1, ...att.map((w) => w.a)); d.b = Math.max(d.T2, ...att.map((w) => w.b));
  }
  S.trips.sort((x, y) => x.a - y.a);
}
function tripChecks() {
  const tr = S.tr, SLACK = 15 * 6e4;   // T1 and T2 are often given to the quarter hour
  for (const d of S.trips) {
    const hs = d.hauls;
    for (const h of hs) {
      const c = tr?.bySid.get(h.key);
      h.pings = tr ? c?.n ?? 0 : null; h.fish = tr ? c?.fish ?? 0 : null;
    }
    // a window the haul is attended in lies outside T1-T2; a day only where it misses T1-T2 altogether, since T1 and T2
    // may be dates too
    d.haulsOutside = hs.filter((h) => h.att.some((w) => (w.phase === 'day' ? w.b <= d.T1 || w.a > d.T2
      : w.a < d.T1 - SLACK || w.b > d.T2 + SLACK))).length;
    if (!tr || d.b < tr.t0 || d.a > tr.t1) { d.pings = null; continue; }
    // the trip's pings, those on its own hauls, and its fishing pings on none of them
    const i0 = lower(tr.t, d.a), i1 = lower(tr.t, d.b + 1), own = new Set(hs.map((h) => h.key));
    d.pings = i1 - i0; d.fishPings = tr.fishCum[i1] - tr.fishCum[i0]; d.onHauls = 0; d.fishOutside = 0;
    for (let i = i0; i < i1; i++) {
      if (own.has(tr.haulKey[i])) d.onHauls++;
      else if (tr.fishing[i]) d.fishOutside++;
    }
    d.haulsNoFishing = hs.filter((h) => h.fish === 0).length;
  }
}
const warnings = (d) => {
  if (d.pings == null) return '<span class="badge">no AIS loaded</span>';
  const w = [];
  if (d.pings === 0) w.push('<span class="badge bad">no pings in the trip</span>');
  if (d.n === 0) w.push('<span class="badge warn">no haul recorded</span>');
  if (d.haulsOutside) w.push(`<span class="badge bad">${d.haulsOutside} haul${d.haulsOutside > 1 ? 's' : ''} attended outside T1-T2</span>`);
  if (d.haulsNoFishing) w.push(`<span class="badge warn">${d.haulsNoFishing} haul${d.haulsNoFishing > 1 ? 's' : ''} without fishing pings</span>`);
  if (d.fishOutside > 0) w.push(`<span class="badge warn">${d.fishOutside} fishing pings on no haul of the trip</span>`);
  return w.length ? w.join('') : '<span class="badge ok">✓ agree</span>';
};
const hasChecks = (d) => d.pings === 0 || d.haulsOutside || d.haulsNoFishing || d.fishOutside > 0;

// The trip table, the page's central piece (maintainer, 2026-10-22: "if the trip is the central piece, we should then
// having the landings record related to trips as a table. then clicking on any trip/landings we would explode the event
// (station) related to that trip. then the user could also just click on each event"): each logbook trip with its
// landings under it, one line each, and the landings no trip claims, newest first. A click on a trip or one of its
// landings selects the trip (window, map, chart) and opens its hauls, closing the others; a click on a haul frames it
// alone with its record. The caret opens or closes a row without choosing it. The rows in the window carry a blue edge.
const TRIPS_PER_PAGE = 25;
function tripRows() {
  const trips = S.trips.map((d) => ({ ...d, kind: 'trip', key: `${d.tid}|${d.schema}`, end: d.b }));
  const lands = (S.landOnly || []).map((l) => ({ ...l, end: l.d + 12 * HOUR }));
  return [...trips, ...lands].sort((x, y) => y.end - x.end);
}
// a row in the window: a trip that overlaps it, or a landing with no trip whose day does
const rowInWindow = (r, [a, b] = S.win) => (r.kind === 'trip' ? r.b > a && r.a < b : r.d + DAY > a && r.d < b);
// The trip table's blue edges follow the window once it rests; where none of the window's rows is on the page shown, the
// table turns to the page that holds them
function markInWindow() {
  if (!S.tr || !isOpen('trips')) return;
  const rows = [...document.querySelectorAll('#trips tr.trip, #trips tr.landrow')];
  const inWin = new Set(tripRows().filter((r) => rowInWindow(r)).map((r) => r.key));
  rows.forEach((row) => row.classList.toggle('inwin', inWin.has(row.dataset.key)));
  if (inWin.size && !rows.some((row) => inWin.has(row.dataset.key))) { S.tripPage = windowPage(); renderTrips(); }
}
// The page of the table that holds the window's trips, so the table opens on them, not on the newest (decision 177): the
// newest row that overlaps the window, else the newest before it
function windowPage() {
  const order = tripRows(), [a, b] = S.win;
  let k = order.findIndex((r) => (r.kind === 'trip' ? r.a : r.d) <= b && r.end >= a);
  if (k < 0) k = order.findIndex((r) => r.end <= b);
  return Math.max(0, Math.floor(k / TRIPS_PER_PAGE));
}
// A copy-link button (maintainer, 2026-10-22): the address of the view, or of one trip or haul in it, to report a case
// with. The years in the link are those loaded, so the record is in them.
const linkBtn = (attrs) => `<button class="linkbtn" ${attrs} title="copy a link to it">🔗</button>`;
const topCodes = (sp) => (sp || '').split(', ').slice(0, 3).map((x) => x.split(':')[0]).join(', ');
const topSpecies = (sp) => { const x = (sp || '').split(', '); return x.slice(0, 5).join(', ') + (x.length > 5 ? `, and ${x.length - 5} more` : ''); };
async function renderTrips() {
  const order = tripRows(), total = order.length, warn = S.trips.filter(hasChecks).length;
  $('trips-sum').textContent = `${many(S.trips.length, 'logbook trip')}${S.trips.length ? `, ${num(warn)} with checks` : ''} · ` +
    `${many((S.landOnly || []).length, 'landing')} without a trip in these years`;
  if (!isOpen('trips')) return;
  if (!total) { $('trips').innerHTML = '<div class="note">No logbook trip or landing in these years.</div>'; return; }
  const pages = Math.ceil(total / TRIPS_PER_PAGE);
  S.tripPage = Math.max(0, Math.min(S.tripPage, pages - 1));
  const page = order.slice(S.tripPage * TRIPS_PER_PAGE, (S.tripPage + 1) * TRIPS_PER_PAGE);
  const species = new Map();
  const open = page.filter((d) => d.kind === 'trip' && S.expanded.has(d.key));
  if (open.length) {   // species by haul, only for the opened trips
    const sids = open.flatMap((d) => d.hauls.map((h) => h.sid)).join(',');
    if (sids) for (const r of await rows(`SELECT ".sid" AS sid, string_agg(sid::VARCHAR || ': ' || round(catch)::BIGINT::VARCHAR, ', ' ORDER BY catch DESC) AS sp
        FROM station_catch WHERE ".sid" IN (${sids}) GROUP BY 1`)) species.set(r.sid, r.sp);
  }
  const head = ['', 'departure', 'return', 'days', 'port', 'hauls', 'logbook (t)', 'landed (t)', 'checks: logbook against pings', ''];
  const inWin = (r) => (S.tr && rowInWindow(r) ? ' inwin' : '');
  const numc = new Set([3, 5, 6, 7]);
  const cell = (c, i) => `<td${numc.has(i + 1) ? ' class="n"' : ''}>${c}</td>`;
  let html = chosenTrips() + `<table><tr>${head.map((h, i) => `<th${numc.has(i) ? ' class="n"' : ''}>${h}</th>`).join('')}</tr>`;
  for (const d of page) {
    const isOpenRow = S.expanded.has(d.key);
    let cells;
    if (d.kind === 'trip') {
      const land = d.landed.length ? num(d.landedT, 2) : '';
      cells = [dstr(d.T1), dstr(d.T2), num((d.b - d.a) / DAY, 1), esc(d.port), d.n, num(d.kg / 1000, 2), land, warnings(d),
               linkBtn(`data-link-trip="${esc(d.key)}"`)];
    } else {   // a landing no logbook trip of the range claims
      const g = !d.gear && gearAfter(d.d);
      const gear = d.gear ? ` ${esc(d.gear)}` : g
        ? ` <span class="badge warn" title="the landing records no gear: the previous logbook trip's (decision 143)">gear assumed ${esc(g.gear)}</span>` : '';
      const why = `<span class="badge">${d.link ? 'logbook trip in another year' : 'no logbook'}</span>${gear}`;
      cells = ['', d.day, '', esc(d.port), '', why, num(d.t, 2), '', ''];
    }
    html += `<tr class="click trip${isChosen(d.key) ? ' sel' : ''}${inWin(d)}" data-key="${esc(d.key)}" title="click: show it on the map and chart, with its hauls">` +
      `<td><span class="caret" data-open="1">${isOpenRow ? '▾' : '▸'}</span></td>${cells.map(cell).join('')}</tr>`;
    // a trip's landings, one line each, under it: a click on one is a click on its trip
    if (d.kind === 'trip') for (const l of d.landed) {
      html += `<tr class="click landrow${isChosen(d.key) ? ' sel' : ''}${inWin(d)}" data-key="${esc(d.key)}" title="landing ${esc(l.lid)} (${esc(l.schema)}), lid_map ${esc(l.match)}: click for its trip's hauls">
        <td></td><td colspan="${head.length - 1}"><span class="tri"></span>landed ${esc(l.day)} in ${esc(l.port)}, ${esc(l.gear)}: <b>${num(l.t, 2)} t</b> · ${esc(topSpecies(l.sp))}</td></tr>`;
    }
    if (isOpenRow) html += `<tr class="sub"><td colspan="${head.length}">${d.kind === 'trip'
      ? tripDetails(d) + haulTable(d, species) : landingOnly(d)}</td></tr>`;
  }
  html += '</table>';
  if (pages > 1) html += `<div class="pager"><button data-d="-1" ${S.tripPage === 0 ? 'disabled' : ''}>‹ newer</button>
    ${S.tripPage * TRIPS_PER_PAGE + 1}–${Math.min(total, (S.tripPage + 1) * TRIPS_PER_PAGE)} of ${total}
    <button data-d="1" ${S.tripPage >= pages - 1 ? 'disabled' : ''}>older ›</button></div>`;
  $('trips').innerHTML = html;
  const toggle = (key) => { if (S.expanded.has(key)) S.expanded.delete(key); else S.expanded.add(key); renderTrips(); };
  $('trips').querySelectorAll('tr.trip, tr.landrow').forEach((row) => {
    const r = page.find((x) => x.key === row.dataset.key);
    row.addEventListener('click', (e) => {
      if (e.target.dataset.open) { toggle(r.key); return; }
      if (r.kind === 'trip' && (e.shiftKey || e.metaKey || e.ctrlKey)) {   // several trips
        window.getSelection()?.removeAllRanges();
        const order = tripRows().filter((x) => x.kind === 'trip').map((x) => x.key);
        const keys = e.shiftKey && S.selKey && S.tripOf.has(S.selKey) ? run(order, S.selKey, r.key) : toggled(S.tripSel, r.key);
        chooseTrips(keys, e.shiftKey ? S.selKey : r.key).catch((err) => status(String(err)));
        return;
      }
      if (r.key === S.selKey && S.tripSel.size <= 1 && S.expanded.has(r.key)) { toggle(r.key); return; }   // the chosen row, open: close it
      if (r.kind === 'trip') selectTrip(r.tid, r.schema, { open: true, only: true }).catch((err) => status(String(err)));
      else { selectLanding(r); S.expanded = new Set([r.key]); renderTrips(); }
    });
  });
  $('trips').querySelectorAll('tr.haul').forEach((row) => row.addEventListener('click', (e) => {
    e.stopPropagation();
    const h = S.haulOf.get(row.dataset.key);
    if (!h) return;
    if (e.shiftKey || e.metaKey || e.ctrlKey) {   // several hauls: a run within the trip, or one added or removed
      window.getSelection()?.removeAllRanges();
      const order = (S.tripOf.get(h.tkey)?.hauls || []).map((x) => x.key);
      const keys = e.shiftKey && S.haul && order.includes(S.haul) ? run(order, S.haul, h.key) : toggled(S.haulSel, h.key);
      chooseHauls(keys, e.shiftKey ? S.haul : h.key).catch((err) => status(String(err)));
      return;
    }
    selectHaul(h).catch((err) => status(String(err)));
  }));
  $('trips').querySelector('#clear-chosen')?.addEventListener('click', () => chooseTrips([]).catch((err) => status(String(err))));
  bindLinks($('trips'));
  $('trips').querySelectorAll('.pager button').forEach((b) => b.addEventListener('click', () => { S.tripPage += +b.dataset.d; renderTrips(); }));
}
// the trips chosen, summed, when there are several
function chosenTrips() {
  const ds = [...S.tripSel].map((k) => S.tripOf.get(k)).filter(Boolean);
  if (ds.length < 2) return '';
  const a = Math.min(...ds.map((d) => d.T1)), b = Math.max(...ds.map((d) => d.T2));
  return `<div class="wline" style="margin-bottom:4px"><b>${many(ds.length, 'trip')} chosen</b> · ${dstr(a)} – ${dstr(b)} · ` +
    `${many(ds.reduce((x, d) => x + d.n, 0), 'haul')} · ${num(ds.reduce((x, d) => x + d.kg, 0) / 1000, 2)} t logged · ` +
    `${num(ds.reduce((x, d) => x + d.landedT, 0), 2)} t landed <button id="clear-chosen" class="linkbtn">clear</button></div>`;
}
// a trip's record: its ids, its times as recorded with their basis, and how its pings meet its hauls
const tripDetails = (d) => `<div class="note">trip ${esc(d.tid)} (${esc(d.schema)}) · departure ${fmt(d.T1)}${d.b1 ? ` (${esc(d.b1)})` : ''}
  · return ${fmt(d.T2)}${d.b2 ? ` (${esc(d.b2)})` : ''} · ${d.pings == null ? 'no AIS loaded'
  : `${d.pings} pings in the trip, ${d.onHauls} on its hauls, ${d.fishPings} fishing`}${d.landed.length ? '' : ' · no landing is linked to it'}</div>`;
const landingOnly = (d) => `<h3>Landed</h3><div>${esc(d.day)} in ${esc(d.port)}, ${esc(d.gear)}: <b>${num(d.t, 2)} t</b> · ${esc(d.sp)}
    <span class="note">(landing ${esc(d.lid)}, ${esc(d.schema)})</span></div>
  <div class="note">${d.link ? `lid_map links it to logbook trip ${esc(d.link.tid)}, outside the loaded years.`
    : 'No logbook trip is linked to this landing, so there are no logbook records to show.'}${!d.gear && gearAfter(d.d)
    ? ` The landing records no gear, so it is assumed to be <b>${esc(gearAfter(d.d).gear)}</b>, as on the previous logbook trip (returned ${esc(S.assumed.day)}).` : ''}</div>`;
// A haul's window as text: a day as its date; else its phase, start and end, the end's date only where it differs
const winText = (w) => (w.phase === 'day' ? `day ${dstr(w.a)}`
  : `${w.phase} ${fmt(w.a)} – ${dstr(w.a) === dstr(w.b) ? fmt(w.b).slice(11) : fmt(w.b)}`);
// the swatch of a haul's main window, the colour its bar has on the chart
const haulSwatch = (h) => `<span class="sw" style="background:${WIN_COLOUR[(h.att[0] || h.wins[0]).phase] || '#9aa5b1'}"></span>`;
// A trip's hauls: a row each, in plain words, with its pings; a click frames it and opens its record under it
function haulTable(d, species) {
  if (!d.hauls.length) return '<h3>Hauls</h3><div class="note">No haul is recorded for this trip.</div>';
  const chosen = d.hauls.filter((h) => S.haulSel.has(h.key));
  const sumUp = chosen.length < 2 ? '' : `<div class="wline"><b>${many(chosen.length, 'haul')} chosen</b> · ` +
    `${fmt(Math.min(...chosen.map((h) => h.a)))} – ${fmt(Math.max(...chosen.map((h) => h.b)))} · ${num(chosen.reduce((x, h) => x + h.kg, 0))} kg · ` +
    `${many(chosen.reduce((x, h) => x + (h.pings || 0), 0), 'ping')}, ${num(chosen.reduce((x, h) => x + (h.fish || 0), 0))} fishing</div>`;
  return `<h3>Hauls (${d.hauls.length}): click one to see it alone, with its record; Shift-click a run, ⌘- or Ctrl-click to add one</h3>${sumUp}<table><tr><th></th><th>gear in</th><th>gear out</th>
    <th>gear</th><th class="n">depth (m)</th><th class="n">catch (kg)</th><th>main species (codes)</th>
    <th class="n" title="the pings carrying this haul's .sid">pings</th><th class="n" title="of them fishing (fishing_flow), its set window left out">fishing</th><th></th></tr>` +
    d.hauls.map((h) => {
      const recOpen = h.key === S.haul && S.haulOpen && S.haulSel.size === 1;
      return `<tr class="click haul${S.haulSel.has(h.key) ? ' sel' : ''}" data-key="${esc(h.key)}" title="show this haul alone on the chart and map, with its record">
        <td><span class="caret">${recOpen ? '▾' : '▸'}</span>${haulSwatch(h)}</td><td>${h.dateOnly ? dstr(h.a) : fmt(h.a)}</td>
        <td>${h.dateOnly ? '<span class="note">date only</span>' : fmt(h.b)}</td><td>${esc(h.gear) || '<span class="badge warn">no gear</span>'}</td>
        <td class="n">${num(h.z1)}</td><td class="n">${num(h.kg)}</td><td>${esc(topCodes(species.get(h.sid)))}</td>
        <td class="n">${h.pings ?? ''}</td><td class="n">${h.fish == null ? '' : h.fish === 0 ? '<span class="badge warn">0</span>' : h.fish}</td>
        <td>${linkBtn(`data-link-haul="${esc(h.key)}"`)}</td></tr>` +
        (recOpen ? `<tr class="rec"><td colspan="10">${haulRecord(h, species)}</td></tr>` : '');
    }).join('') + '</table>';
}
// Every field of a haul's record (decision 178): its ids, the logbook's times, the windows the flow gave it, its gear with
// its basis, its effort, its positions as written (never drawn on the map: decision 156), its depth, pings and catch
function haulRecord(h, species) {
  const f = [
    ['record', `haul ${esc(h.sid)} of trip ${esc(h.tid)} (${esc(h.schema)})${h.station_type ? `, ${esc(h.station_type)}` : ''}`],
    ['logbook times', ['t1', 't2', 't3', 't4'].map((k) => `${k} ${h[k] == null ? '—' : fmt(h[k])}`).join(' · ')],
    ['windows (station_window)', h.wins.map((w) => `${esc(winText(w))} <span class="note">${esc(w.basis)}</span>`).join('<br>')],
    ['gear', `${esc(h.gear) || 'none'} ${esc(h.target)}${h.gear_basis ? ` <span class="note">(${esc(h.gear_basis)})</span>` : ''}`],
    ['duration · effort', `${h.duration_m == null ? '—' : `${num(h.duration_m)} min`} · ${h.effort == null ? '—' : `${num(h.effort, 1)} ${esc(h.effort_unit)}`}`],
    ['positions, as written', `start ${h.lat1 == null ? '—' : `${num(h.lat1, 3)}, ${num(h.lon1, 3)}`} · end ${h.lat2 == null ? '—'
      : `${num(h.lat2, 3)}, ${num(h.lon2, 3)}`} <span class="note">(the logbook's; never drawn on the map)</span>`],
    ['depth (m)', h.z1 == null && h.z2 == null ? '—' : `${num(h.z1)}${h.z2 != null ? ` – ${num(h.z2)}` : ''}`],
    ['pings', h.pings == null ? 'no AIS loaded' : `${h.pings} carrying its .sid, ${h.fish} of them fishing (its set window left out)`],
    ['catch (kg by species code)', esc(species.get(h.sid) || 'none recorded')],
  ];
  return `<dl>${f.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl>`;
}

// The window's cards: its activity, its hauls and its landings, drawn again once the window rests (decision 178) ---------
function renderCards() {
  if (!S.vid) return;
  // the window; with no AIS in the loaded years, those years
  const tr = S.tr, [a, b] = tr ? S.win : [Date.UTC(S.from, 0, 1), Date.UTC(S.to + 1, 0, 1)];
  // a haul's windows and a landing's day are half-open: one that only touches the window's edge is not in it
  const hs = S.hauls.filter((h) => (h.b > a && h.a < b) || (h.a === h.b && h.a >= a && h.a <= b));
  // The window's landings are its trips' (maintainer, 2026-10-22: "we want to operate on the trip window. now it is the
  // landing window - that is misleading"): a landing goes with the logbook trip lid_map links it to, wherever its own
  // day falls, and a landing no trip of these years claims goes by its day
  const ls = (S.landRows || []).filter((l) => {
    const d = l.link && S.tripOf.get(`${l.link.tid}|${l.link.schema}`);
    return d ? d.b > a && d.a < b : l.d + DAY > a && l.d < b;
  });
  if (isOpen('activity')) renderActivity(a, b, hs, ls);
  markInWindow();
}
// the logbook trip a landing goes with, by its dates, or that it has none in these years
function tripOfLanding(l) {
  const d = l.link && S.tripOf.get(`${l.link.tid}|${l.link.schema}`);
  if (d) return `<span title="trip ${esc(d.tid)} (${esc(d.schema)}), lid_map ${esc(l.link.match_type)}">${dstr(d.T1).slice(5)} – ${dstr(d.T2).slice(5)}</span>`;
  return `<span class="badge">${l.link ? 'in another year' : 'none'}</span>`;
}
// The window's activity: time at sea and in port by the flow's port calls, its fishing in hours (the trail's effort) and
// by gear, its hauls and logged catch, its landings, and where the logbook and the pings part
function renderActivity(a, b, hs, ls) {
  const tr = S.tr, span = b - a;
  let pings = 0, fish = 0, fishH = 0, noHaul = 0;
  const byGear = new Map();
  if (tr) {
    const i0 = lower(tr.t, a), i1 = lower(tr.t, b + 1);
    pings = i1 - i0;
    for (let i = i0; i < i1; i++) {
      if (!tr.fishing[i]) continue;
      fish++; fishH += tr.h[i];
      const g = tr.gear[i] || 'gear not known';
      byGear.set(g, (byGear.get(g) || 0) + tr.h[i]);
      if (!tr.haulKey[i]) noHaul++;
    }
  }
  const calls = (S.portCalls || []).filter((c) => c.b >= a && c.a <= b);
  const inPort = calls.reduce((s, c) => s + Math.max(0, Math.min(b, c.b) - Math.max(a, c.a)), 0);
  const voy = voyages().filter((v) => v.b >= a && v.a <= b).length;
  const trips = S.trips.filter((d) => d.b > a && d.a < b);
  const kg = hs.reduce((s, h) => s + h.kg, 0), landT = ls.reduce((s, l) => s + l.t, 0);
  const gears = [...byGear].sort((x, y) => y[1] - x[1]).map(([g, x]) => `${esc(g)} ${num(x, 1)} h`).join(' · ');
  const hGear = new Map(); for (const h of hs) hGear.set(h.gear || 'no gear', (hGear.get(h.gear || 'no gear') || 0) + 1);
  const noFish = hs.filter((h) => h.fish === 0).length;
  const sw = (c) => `<span class="sw" style="background:${c}"></span>`;
  const rows = [
    ['time', `${num(span / HOUR, 0)} h: ${num((span - inPort) / HOUR, 0)} h at sea, ${sw('#5d6b78')}${num(inPort / HOUR, 0)} h in port (${many(calls.length, 'port call')}) · ${many(voy, 'voyage')}`],
    ['AIS', tr ? many(pings, 'ping') : 'no AIS in these years'],
    ['fishing', tr ? `${sw('#d62728')}<b>${num(fishH, 1)} h</b> (${many(fish, 'ping')})${gears ? `<br><span class="note">by the pings' gear: ${gears}</span>` : ''}` : '—'],
    ['logbook', `${many(trips.length, 'trip')} · ${sw('#2e7d32')}${many(hs.length, 'haul')}${hGear.size ? ` (${[...hGear].map(([g, n]) => `${num(n)} ${esc(g)}`).join(', ')})` : ''} · <b>${num(kg / 1000, 2)} t</b> logged`],
    ['landed', `<span class="tri"></span>${many(ls.length, 'landing')} · <b>${num(landT, 2)} t</b> <span class="note">(the window's trips')</span>`],
    ['logbook against pings', !tr ? '—' : (noFish || noHaul) ? [noFish ? `<span class="badge warn">${many(noFish, 'haul')} with no fishing ping</span>` : '',
      noHaul ? `<span class="badge warn">${many(noHaul, 'fishing ping')} on no haul</span>` : ''].join(' ')
      : '<span class="badge ok">✓ every haul has fishing pings, every fishing ping a haul</span>'],
  ];
  $('c-activity').innerHTML = `<dl>${rows.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('')}</dl>`;
}

// The pings of the window, every column, when its panel is open ---------------------------------------------------------
const PINGS_PER_PAGE = 100;
async function renderPings() {
  if (!isOpen('pings') || !S.vid) return;
  if (!S.tr) { $('pings').innerHTML = '<div class="note">No AIS in these years.</div>'; return; }
  const [a, b] = S.win, i0 = lower(S.tr.t, a), i1 = lower(S.tr.t, b + 1), total = i1 - i0;
  const P = await rows(`SELECT epoch_ms(time)::DOUBLE AS ms, strftime(time, '%Y-%m-%d %H:%M:%S') AS t, round(lat, 4)::DOUBLE AS lat,
      round(lon, 4)::DOUBLE AS lon, round(speed, 1)::DOUBLE AS speed, round(heading)::DOUBLE AS heading, provider, voyage_id, port_call_id,
      gear, phase, fishing_flow::VARCHAR AS fishing, ".tid" AS tid, ".sid" AS sid
    FROM trail WHERE epoch_ms(time) BETWEEN ${a} AND ${b} ORDER BY time LIMIT ${PINGS_PER_PAGE} OFFSET ${S.pingPage * PINGS_PER_PAGE}`);
  const pages = Math.ceil(total / PINGS_PER_PAGE);
  $('pings').innerHTML = `<div class="note">${total.toLocaleString('en-GB')} pings in the window; click one to find it on the map and chart.</div>
    <div class="scroll">${table([['t', 'time (UTC)'], ['lat', 'lat', true], ['lon', 'lon', true], ['speed', 'speed', true], ['heading', 'heading', true],
      ['provider', 'provider'], ['voyage_id', 'voyage_id', true], ['port_call_id', 'port_call_id', true], ['gear', 'gear'], ['phase', 'phase'], ['fishing', 'fishing_flow'],
      ['tid', '.tid'], ['sid', '.sid', true]], P, { click: true, empty: 'no ping in the window' })}</div>` +
    (pages > 1 ? `<div class="pager"><button data-d="-1" ${S.pingPage === 0 ? 'disabled' : ''}>‹ earlier</button>
      ${S.pingPage * PINGS_PER_PAGE + 1}–${Math.min(total, (S.pingPage + 1) * PINGS_PER_PAGE)} of ${total.toLocaleString('en-GB')}
      <button data-d="1" ${S.pingPage >= pages - 1 ? 'disabled' : ''}>later ›</button></div>` : '');
  $('pings').querySelectorAll('tr.click').forEach((row) => row.addEventListener('click', () => setHover(lower(S.tr.t, P[+row.dataset.i].ms), 'map')));
  $('pings').querySelectorAll('.pager button').forEach((x) => x.addEventListener('click', () => { S.pingPage += +x.dataset.d; renderPings(); }));
}

// The vessel in one line beside the tabs, and in full on the Vessel tab: the fishing is the page's subject, the vessel its
// context (maintainer, 2026-10-22: "the fishing science is the focus not the vessel per se")
function renderSummary() {
  const A = S.about || {}, v = V.find((x) => x.vid === S.vid) || {}, tr = S.tr;
  if (!S.vid) return;
  const lastHeard = tr && v.last_ping && dstr(tr.t1) === v.last_ping
    ? `${fmt(tr.t1)} UTC, ${tr.port_call_id[tr.n - 1] >= 0 ? 'in port' : 'at sea'}` : (v.last_ping || 'never');
  const tonnes = S.landings.reduce((s, d) => s + d.t, 0), range = S.from === S.to ? `${S.from}` : `${S.from}–${S.to}`;
  const kind = A.use ? A.use.toLowerCase() : 'vessel';
  const parts = [A.loa && `${num(A.loa, 1)} m`, A.built && `built ${A.built}`, A.home && `home port ${A.home}`].filter(Boolean);
  const gear = S.assumed ? ` · no logbook since ${esc(S.assumed.day)}: gear ${esc(gearWords(gearAfter(S.assumed.until) || { gear: '—' }))}` : '';
  $('vline').innerHTML = `a ${esc(kind)}${parts.length ? ', ' + esc(parts.join(', ')) : ''} · last heard on AIS ${esc(lastHeard)} · ` +
    `last landing ${A.lastLanding ? esc(A.lastLanding) : 'none recorded'}${gear}`;
  $('summary').innerHTML = `<p><b>${esc(S.name || 'vid ' + S.vid)}</b> is a ${esc(kind)}${parts.length ? ', ' + esc(parts.join(', ')) : ''}.</p>
    <dl>${BUNDLE ? '' : `<dt>call sign</dt><dd>${esc(v.cs || '—')}</dd><dt>MMSI</dt><dd>${esc(v.mmsi || '—')}</dd><dt>IMO</dt><dd>${esc(v.imo || '—')}</dd>
    <dt>local sign</dt><dd>${esc(v.uid || '—')}</dd>`}<dt>vid</dt><dd>${S.vid}</dd>
    <dt>on AIS</dt><dd>${v.first_year ?? '—'} – ${esc(v.last_ping || '—')}; last heard ${esc(lastHeard)}</dd>
    <dt>last landing</dt><dd>${A.lastLanding ? esc(A.lastLanding) : 'none recorded'}</dd>
    <dt>in ${range}</dt><dd>${S.trips.length} logbook trips, ${S.stations.length} hauls, ${num(tonnes, 1)} t landed in ${S.landings.length} landings</dd>
    <dt>last logbook trip</dt><dd>${S.assumedBase ? `${esc(S.assumedBase.tid)}, returned ${esc(S.assumedBase.day)}` : '—'}${S.assumed
      ? `; to the last landing the gear is the landings' (the last records ${esc(S.assumed.landingGear || 'none')}), else the previous trip's ${esc(S.assumed.gear || 'none')}` : ''}</dd></dl>
    <div class="note">${BUNDLE ? `${esc(BUNDLE)}: the register is left out.` : 'Type, length and home port from the register (history to 2023-12-19).'} Species are shown as codes.</div>`;
}

// Photos (the Vessel tab), the vessel's basics, the last landing ----------------------------------------------------
let photos = [], photoAt = 0;
const photoUrl = (p) => `/photo?vid=${S.vid}&file=${encodeURIComponent(p.file)}`;
function showPhoto() {
  const p = photos[photoAt];
  if (!p) { $('photo-body').innerHTML = '<div class="note">No photo of this vessel in the 2022 mbl scrape.</div>'; return; }
  const credit = [p.exif_artist ? `Photo: ${p.exif_artist}` : 'Photographer not given', 'mbl.is, 200 mílur',
                  p.exif_date ? `taken ${p.exif_date}` : 'date unknown, before 2022-12-28'].join(' · ');
  $('photo-body').innerHTML = `<img src="${photoUrl(p)}" alt="${esc(S.name || 'vessel ' + S.vid)}">
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
  S.assumed = null; S.lastKey = null; S.about.lastLanding = null;
  const L = await rows(`SELECT ".lid" AS lid, schema, strftime(date, '%Y-%m-%d') AS day, port, coalesce(gear_name, gear) AS gear,
      round(catch)::DOUBLE AS kg FROM last_landing ORDER BY catch DESC`);
  if (!L.length) return;
  const l = L[0], total = L.reduce((s, x) => s + x.kg, 0);
  S.about.lastLanding = `${l.day} in ${l.port}, ${num(total / 1000, 2)} t`;
  S.lastKey = `L${l.lid}|${l.schema}`;
  // the maintainer's rule (decision 143): a last landing with no logbook trip has the gear of the previous logbook trip
  const link = await rows(`SELECT ".tid" FROM landing_trips WHERE ".lid" = ${l.lid} AND schema_land = ${sqlstr(l.schema)}`);
  const day = Date.parse(`${l.day}T00:00:00Z`);
  if (!link.length && S.assumedBase && day > S.assumedBase.after) S.assumed = { ...S.assumedBase, until: day + DAY, landingGear: l.gear || '', lastDay: l.day };
}

// The Vessel tab: about, every photo, the register today and its history, loaded when first opened ------------------
async function renderVessel() {
  if (S.vesselTab) return;
  status(`loading the register of vid ${S.vid}`);
  const t = performance.now();
  const HIST = ['vessel', 'identification', 'owners', 'operators', 'events'];
  await loadAll(HIST.map((h) => [`hist_${h}`, 'hist', { vid: S.vid, table: h }]));
  const r = (await rows(`SELECT *, strftime(mmsi_t1, '%Y-%m-%d') AS m1, strftime(mmsi_t2, '%Y-%m-%d') AS m2,
                                strftime(note_date, '%Y-%m-%d') AS nd FROM a_register`))[0];
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
  S.vesselTab = true;
  status(`register of vid ${S.vid} loaded in ${Math.round(performance.now() - t)} ms`);
}

// The History tab: all landings and all logbook trips, loaded when first opened ----------------------------------------
const hpages = { land: 0, trip: 0 };
const PAGE = 50;
async function renderHistory() {
  if (S.history) return;
  status(`loading the history of vid ${S.vid}`);
  const t = performance.now(), all = { vid: S.vid, from: 1900, to: 2100 };
  await loadAll([['h_landings', 'landings', all], ['h_trips', 'trip_summary', all],
                 ['h_effort', 'history_effort', { vid: S.vid }], ['h_cells', 'history_cells', { vid: S.vid }]]);
  await buildHistory();
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
    const x = T[+row.dataset.i]; selectTrip(x.tid, x.schema, { open: true, scroll: true }).catch((e) => status(String(e)));
  }));
  bindPager('h-trips', 'trip', total, pageTrips);
}

// The History tab's Where and When (decision 179) -------------------------------------------------------------------------
// The vessel's whole history on a time axis pinned from 2007-09 to now and on the fishing grounds' fixed frame, the same
// for every vessel (maintainer, 2026-10-22: "pin the x-axis always from [2007]-09 to the present irrespective of how long
// the vessel has been in that history. do the same for the hex"), so that two vessels read alike. When: fishing hours
// per month from the trail, and tonnes per month, landed and logged (the logbook's trips, by the month they returned).
// Where: the fishing hours of the months chosen, in hexagons of 2 km or more, since the service sums them in cells of
// about 1 km. A drag or a click on a chart chooses months; the map follows. A bundle holds one window: its axis is
// that window's months.
const MONTH = (ms) => { const d = new Date(ms); return Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1); };
const addMonths = (ms, k) => { const d = new Date(ms); return Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + k, 1); };
const ym = (ms) => new Date(ms).toISOString().slice(0, 7);
const H = { t0: Date.UTC(2007, 8, 1), t1: addMonths(MONTH(Date.now()), 1), range: null, deck: null, base: null,
            view: { zoom: 5, latitude: 65 }, cells: [], effort: null, catch: null };
const H_AXIS = { size: 40, gap: 3, ticks: { size: 4 }, font: FONT };
const histKm = () => Math.max(2, hexKm(H.view));
async function buildHistory() {
  const eff = await rows(`SELECT epoch_ms(month)::DOUBLE AS m, pings::INTEGER AS n, fishing_pings::INTEGER AS fp,
      fishing_hours::DOUBLE AS fh FROM h_effort`);
  // landed by the month its logbook trip returned (lid_map; the last, where it links several), as logged is, so the two
  // compare month by month; a landing with no trip by its own day
  const land = await rows(`WITH k AS (SELECT k.".lid" AS lid, k.schema_land, max(t.T2) AS T2 FROM landing_trips k
        JOIN h_trips t ON t.".tid" = k.".tid" AND t.schema = k.schema GROUP BY ALL)
      SELECT epoch_ms(date_trunc('month', coalesce(k.T2, l.date)))::DOUBLE AS m, (sum(l.catch) / 1000)::DOUBLE AS t
      FROM h_landings l LEFT JOIN k ON k.lid = l.".lid" AND k.schema_land = l.schema GROUP BY 1`);
  const logd = await rows(`SELECT epoch_ms(date_trunc('month', T2))::DOUBLE AS m, (sum(catch) / 1000)::DOUBLE AS t
      FROM h_trips WHERE T2 IS NOT NULL GROUP BY 1`);
  // the cells as columns (up to about 340,000 rows); the hexagons take their row numbers
  const tbl = await conn.query(`SELECT epoch_ms(month)::DOUBLE AS m, lon::FLOAT AS lon, lat::FLOAT AS lat, hours::FLOAT AS h, pings::INTEGER AS n FROM h_cells`);
  H.c = { m: tbl.getChild('m').toArray(), lon: tbl.getChild('lon').toArray(), lat: tbl.getChild('lat').toArray(),
          h: tbl.getChild('h').toArray(), n: tbl.getChild('n').toArray() };
  H.cells = Array.from({ length: tbl.numRows }, (_, i) => i);
  if (BUNDLE) {
    const ms = [...eff, ...land].map((r) => r.m);
    if (ms.length) { H.t0 = Math.min(...ms); H.t1 = addMonths(Math.max(...ms), 1); }
  }
  H.months = [];
  for (let m = H.t0; m < H.t1; m = addMonths(m, 1)) H.months.push(m);
  const by = (list) => new Map(list.map((r) => [r.m, r]));
  const E = by(eff), Lm = by(land), Gm = by(logd);
  H.x = H.months.map((m) => (m + addMonths(m, 1)) / 2000);   // a month's bar at its middle, in seconds
  H.fh = H.months.map((m) => E.get(m)?.fh ?? null);
  H.n = H.months.map((m) => E.get(m)?.n ?? null);
  H.fp = H.months.map((m) => E.get(m)?.fp ?? null);
  H.land = H.months.map((m) => Lm.get(m)?.t ?? null);
  H.logged = H.months.map((m) => Gm.get(m)?.t ?? null);
  H.range = null;
  makeHistoryCharts();
  makeHistoryMap();
  showHistoryRange();
}
function histChart(el, series, data) {
  const u = new uPlot({
    width: el.clientWidth || 600, height: 150, legend: { show: false }, padding: [6, 14, null, 2],
    scales: { x: { time: true, range: () => [H.t0 / 1000, H.t1 / 1000] }, y: { range: (v, lo, hi) => [0, hi > 0 ? hi * 1.05 : 1] } },
    series: [{}, ...series],
    axes: [{ font: FONT }, H_AXIS],
    cursor: { sync: { key: 'history' }, drag: { x: true, y: false, setScale: false }, points: { show: false } },
    hooks: {
      drawClear: [drawHistRange],
      setSelect: [(c) => {
        if (c.select.width < 3) return;
        const a = c.posToVal(c.select.left, 'x') * 1000, b = c.posToVal(c.select.left + c.select.width, 'x') * 1000;
        c.setSelect({ left: 0, width: 0, top: 0, height: 0 }, false);
        setHistRange(MONTH(a), addMonths(MONTH(b), 1));
      }],
      setCursor: [histHover],
    },
  }, [H.x, ...data], el);
  let down = null;   // a click, not a drag, chooses the month under it
  u.over.addEventListener('mousedown', (e) => { down = e.clientX; });
  u.over.addEventListener('mouseup', (e) => {
    const x = down; down = null;
    if (x == null || Math.abs(e.clientX - x) > 3 || u.cursor.left == null || u.cursor.left < 0) return;
    const m = MONTH(u.posToVal(u.cursor.left, 'x') * 1000);
    setHistRange(m, addMonths(m, 1));
  });
  return u;
}
function makeHistoryCharts() {
  H.effort?.destroy(); H.catch?.destroy();
  const bars = uPlot.paths.bars({ size: [0.85, 40] });
  H.effort = histChart($('h-effort'), [{ label: 'fishing hours', fill: '#d62728b3', stroke: '#d62728', width: 0, paths: bars, points: { show: false } }], [H.fh]);
  H.catch = histChart($('h-catch'), [
    { label: 'landed (t)', fill: '#e07b00b3', stroke: '#e07b00', width: 0, paths: bars, points: { show: false } },
    { label: 'logged (t)', stroke: '#2e7d32', width: 0, points: { show: true, size: 5, width: 0, fill: '#2e7d32' } },
  ], [H.land, H.logged]);
}
function drawHistRange(u) {   // the months chosen, shaded on both charts
  if (!H.range) return;
  const { ctx } = u, { top, height } = u.bbox;
  const a = u.valToPos(H.range[0] / 1000, 'x', true), b = u.valToPos(H.range[1] / 1000, 'x', true);
  ctx.save(); ctx.fillStyle = 'rgba(31,111,235,0.14)'; ctx.fillRect(a, top, Math.max(2, b - a), height); ctx.restore();
}
const H_HINT = $('h-hover').textContent;
function histHover(u) {
  const i = u.cursor.idx;
  if (u.cursor.left == null || u.cursor.left < 0 || i == null) { $('h-hover').textContent = H_HINT; return; }
  $('h-hover').textContent = `${ym(H.months[i])}: ` + [H.fh[i] == null ? 'no AIS' : `${num(H.fh[i], 1)} fishing hours (${many(H.fp[i], 'fishing ping')} of ${num(H.n[i])})`,
    `${H.land[i] == null ? 'no landing' : `${num(H.land[i], 1)} t landed`}`, `${H.logged[i] == null ? 'no logbook trip returned' : `${num(H.logged[i], 1)} t logged`}`].join(' · ');
}
function setHistRange(a, b) {
  H.range = a == null ? null : [Math.max(a, H.t0), Math.min(b, H.t1)];
  if (H.range && H.range[0] >= H.range[1]) H.range = null;
  H.effort?.redraw(false); H.catch?.redraw(false);
  showHistoryRange();
}
function showHistoryRange() {
  const [a, b] = H.range || [H.t0, H.t1];
  const label = addMonths(a, 1) === b ? ym(a) : `${ym(a)} – ${ym(addMonths(b, -1))}`;
  const sum = (arr) => H.months.reduce((s, m, i) => s + (m >= a && m < b ? arr[i] || 0 : 0), 0);
  $('h-range').textContent = `${H.range ? label : `every month, ${label}`}: ${num(sum(H.fh), 0)} fishing hours · ` +
    `${num(sum(H.land), 1)} t landed · ${num(sum(H.logged), 1)} t logged`;
  $('h-range-where').textContent = H.range ? label : `every month, ${label}`;
  $('h-open').disabled = !H.range;
  renderHistoryMap();
}
function makeHistoryMap() {
  const v = groundsView($('hmap'), H.view);
  if (H.deck) { H.deck.setProps({ initialViewState: v }); return; }
  H.base = makeBasemap();
  H.deck = new deck.Deck({
    parent: $('hmap'), controller: true, initialViewState: v,
    onViewStateChange: ({ viewState }) => {
      const before = histKm();
      H.view.zoom = viewState.zoom; H.view.latitude = viewState.latitude;
      if (histKm() !== before) { H.dom = null; renderHistoryMap(true); }   // the same months, hexagons of another size
    },
    getTooltip: ({ layer, object }) => {
      if (layer?.id !== 'h-hex' || !object) return null;
      const pts = object.points || [], n = pts.reduce((x, d) => x + H.c.n[cellRow(d)], 0);
      return { html: `<b>${fmtHours(histHours(pts))} hours of fishing effort</b> in this ${histKm()} km hexagon, ` +
        `${$('h-range-where').textContent}<br>the time steps of its ${many(n, 'fishing ping')}, each to the next ping` };
    },
    layers: H.base ? [H.base] : [],
  });
  $('h-attrib').textContent = TILES ? TILES[1] : '';
}
const cellRow = (d) => (typeof d === 'number' ? d : d.source);   // a picked hexagon wraps its rows
const histHours = (pts) => pts.reduce((x, d) => x + H.c.h[cellRow(d)], 0);
function renderHistoryMap(keep = false) {
  if (!H.deck) return;
  const r = H.range;
  if (!keep) {   // the months' rows, and the decades learnt again from them
    H.rows = r ? H.cells.filter((i) => H.c.m[i] >= r[0] && H.c.m[i] < r[1]) : H.cells;
    H.dom = null;
  }
  const L = H.base ? [H.base] : [], km = histKm();
  if (H.rows.length) {
    L.push(hexLayer('h-hex', H.rows, (i) => [H.c.lon[i], H.c.lat[i]], histHours, km, H.dom, (dom) => {
      H.dom = dom; $('h-hexlegend').innerHTML = hexLegend(dom, km); renderHistoryMap(true);
    }));
  } else $('h-hexlegend').textContent = 'no fishing on the trail in these months';
  H.deck.setProps({ layers: L });
}
$('h-all').addEventListener('click', () => setHistRange(null));
$('h-fit').addEventListener('click', () => {
  if (!H.deck) return;
  H.deck.setProps({ initialViewState: { ...groundsView($('hmap'), H.view), transitionDuration: 300 } });
  H.dom = null; renderHistoryMap(true);
});
// the months chosen, on the Activity tab with their pings: their years loaded, the window on them
$('h-open').addEventListener('click', () => {
  if (!H.range) return;
  const [a, b] = H.range, y0 = new Date(a).getUTCFullYear(), y1 = new Date(b - 1).getUTCFullYear();
  P.years = `${y0}-${y1}`; P.win = 'custom'; P.a = a; P.b = b;
  showTab('now');
  loadRange(y0, y1).catch((e) => status(String(e)));
});
new ResizeObserver(() => requestAnimationFrame(() => {
  for (const [u, el] of [[H.effort, 'h-effort'], [H.catch, 'h-catch']]) if (u && $(el).clientWidth) u.setSize({ width: $(el).clientWidth, height: 150 });
})).observe($('h-chart-sec'));

// Tabs and the panels that fold ------------------------------------------------------------------------------------------
const TABS = ['now', 'vessel', 'history'];
const tabOn = () => TABS.find((t) => $(t).classList.contains('on')) || 'now';
function showTab(name) {
  for (const t of TABS) { $(t).classList.toggle('on', t === name); $(`tab-${t}`).classList.toggle('on', t === name); }
  if (name === 'vessel' && S.vid && !S.vesselTab) renderVessel().catch((e) => status(String(e)));
  if (name === 'history' && S.vid && !S.history) renderHistory().catch((e) => status(String(e)));
  if (name === 'now') { fitPanels(); render(); }
  setHash();
}
for (const t of TABS) $(`tab-${t}`).addEventListener('click', () => showTab(t));
function relayout() {
  fitPanels();
  if (S.tr) { fitTo(S.win[0], S.win[1]); render(); }
}
// A panel folds to its bar and opens on a click (maintainer, 2026-10-22: "expandable panels allows thing to be more
// compact"). Which are open is the user's choice, carried to the next vessel and kept in the address. A panel is drawn
// only while open.
function showFolds() {
  document.querySelectorAll('[data-panel]').forEach((el) => el.classList.toggle('closed', !P.open.has(el.dataset.panel)));
}
function setOpen(k, on) {
  if (on) P.open.add(k); else P.open.delete(k);
  showFolds();
  if (k === 'lanes') { if (on) makeLanes(); else { lanes?.destroy(); lanes = null; } }
  if (on && S.ready) {
    if (k === 'pings') { S.pingPage = 0; renderPings(); }
    if (k === 'trips') renderTrips();
    if (k === 'activity') renderCards();
  }
  requestAnimationFrame(fitPanels);
  setHash();
}
document.querySelectorAll('[data-panel] > .fold-bar').forEach((bar) => bar.addEventListener('click', () => {
  const k = bar.parentElement.dataset.panel;
  setOpen(k, !P.open.has(k));
}));

// Copying a link: to the view, or to one trip or haul in it -----------------------------------------------------------
function linkTo(extra = {}) {
  const q = new URLSearchParams(hashFor(S.vid));
  q.set('years', `${S.from}-${S.to}`); q.delete('trip'); q.delete('haul');
  for (const [k, v] of Object.entries(extra)) if (v) q.set(k, v);
  return `${location.href.split('#')[0]}#${q}`;
}
let toastTimer = null;
function toast(msg) {
  const t = $('toast');
  t.textContent = msg; t.style.display = 'block';
  clearTimeout(toastTimer); toastTimer = setTimeout(() => { t.style.display = 'none'; }, 2500);
}
async function copyLink(url, what) {
  try { await navigator.clipboard.writeText(url); toast(`Link to ${what} copied`); }
  catch (e) { window.prompt(`Copy the link to ${what}:`, url); }   // a page without clipboard access
}
function bindLinks(el) {
  el.querySelectorAll('[data-link-trip]').forEach((b) => b.addEventListener('click', (e) => {
    e.stopPropagation(); copyLink(linkTo({ trip: b.dataset.linkTrip }), `trip ${b.dataset.linkTrip.split('|')[0]}`);
  }));
  el.querySelectorAll('[data-link-haul]').forEach((b) => b.addEventListener('click', (e) => {
    e.stopPropagation();
    const h = S.hauls.find((x) => x.key === b.dataset.linkHaul);
    if (h) copyLink(linkTo({ trip: `${h.tid}|${h.schema}`, haul: h.key }), `haul ${h.sid}`);
  }));
}
$('copy-view').addEventListener('click', () => {
  if (!S.vid) return;
  copyLink(linkTo({ trip: [...S.tripSel].join(','), haul: [...S.haulSel].join(',') }), 'this view');
});

// Choosing a vessel ----------------------------------------------------------------------------------------------------
async function choose(vid) {
  S.ready = false;
  status(`loading vid ${vid}`);
  S.vid = vid; S.trip = null; S.selKey = null; S.haul = null; S.haulOpen = false; S.tr = null; S.history = false; S.vesselTab = false;
  S.tripSel = new Set(); S.haulSel = new Set(); render();
  remember(vid);
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
  S.assumedBase = lt ? { ...lt, gear: lg?.gear || '' } : null;
  const thisYear = new Date().getUTCFullYear();
  const first = BUNDLE ? S.years[0] ?? thisYear : Math.min(S.years[0] ?? thisYear, 2007),
        last = BUNDLE ? S.years.at(-1) ?? thisYear : Math.max(S.years.at(-1) ?? thisYear, thisYear);
  const opts = []; for (let y = last; y >= first; y--) opts.push(`<option value="${y}">${y}${S.years.includes(y) ? '' : ' (no AIS)'}</option>`);
  $('from').innerHTML = opts.join(''); $('to').innerHTML = opts.join('');
  const y = S.years.at(-1) ?? thisYear, [f, t] = P.years.split('-').map(Number);
  await renderNow();
  if (P.years === 'all' && S.years.length) await loadRange(S.years[0], S.years.at(-1));
  else if (Number.isInteger(f) && Number.isInteger(t)) await loadRange(f, t);
  else await loadRange(y, y);
  S.ready = true;
  if (tabOn() === 'vessel') await renderVessel();
  if (tabOn() === 'history') await renderHistory();
}

// The vessel list --------------------------------------------------------------------------------------------------------
let V = [], sortKey = 'last_ping', sortDir = -1;
function renderList() {
  const q = $('filter').value.trim().toLowerCase(), trail = $('f-trail').checked, photo = $('f-photo').checked, since = $('f-landed').value;
  const fq = fold(q);
  let X = V.filter((v) => (!trail || v.last_ping) && (!photo || v.photo) && (!since || (v.last_landing && v.last_landing >= since)) &&
    (!fq || fold(`${v.vid} ${v.vessel} ${v.cs} ${v.mmsi} ${v.imo} ${v.uid} ${v.names}`).includes(fq)));
  const key = (v) => v[sortKey] ?? '';
  X.sort((a, b) => (key(a) < key(b) ? -1 : key(a) > key(b) ? 1 : 0) * sortDir);
  $('list-count').textContent = `${X.length.toLocaleString('en-GB')} vessels${X.length > 300 ? ' — the first 300 are shown; type to narrow' : ''}. Click one to open it.`;
  const cols = [['vid', 'number'], ['vessel', 'name'], ['cs', 'call sign'], ['mmsi', 'MMSI'], ['first_year', 'on AIS since'],
                ['last_ping', 'last heard'], ['last_landing', 'last landing'], ['photo', 'photo']]
    .filter(([k]) => !BUNDLE || !['cs', 'mmsi', 'photo'].includes(k));
  X = X.slice(0, 300);
  $('list').innerHTML = `<table><tr>${cols.map(([k, h]) => `<th data-k="${k}" title="sort">${h}${k === sortKey ? (sortDir < 0 ? ' ▾' : ' ▴') : ''}</th>`).join('')}</tr>` +
    X.map((v) => `<tr class="click" data-vid="${v.vid}">${cols.map(([k]) => `<td>${esc(k === 'photo' ? (v.photo ? '✓' : '') : v[k])}</td>`).join('')}</tr>`).join('') + '</table>';
  $('list').querySelectorAll('th').forEach((th) => th.addEventListener('click', () => {
    const k = th.dataset.k; if (k === sortKey) sortDir = -sortDir; else { sortKey = k; sortDir = k === 'vessel' || k === 'cs' ? 1 : -1; } renderList();
  }));
  $('list').querySelectorAll('tr.click').forEach((tr) => tr.addEventListener('click', () => {
    $('drawer').classList.remove('on'); location.hash = hashFor(+tr.dataset.vid);
  }));
}
for (const id of ['filter', 'f-trail', 'f-photo', 'f-landed']) $(id).addEventListener('input', renderList);
$('open-list').addEventListener('click', () => { $('drawer').classList.add('on'); renderList(); $('filter').focus(); });

// The search (maintainer, 2026-10-22: "check what marinetraffic.com does - it allows for search on anything ... and when
// you type the choices then narrows as the user is typing"): one box for the vid, the name, the call sign, MMSI, IMO, the
// local sign and the register's former names. An identifier typed whole comes first, then names that start with the
// text, then names that hold it, then identifiers that start with it, then former names; the most recently heard first
// within each. Icelandic letters match their plain spelling (þ th, ð d, æ ae, accents dropped), so 'thor' finds Þór.
function fold(x) {
  return String(x ?? '').toLowerCase().replace(/þ/g, 'th').replace(/ð/g, 'd').replace(/æ/g, 'ae')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}
const tight = (x) => fold(x).replace(/[\s.-]/g, '');
let SX = [];
const searchIndex = () => { SX = V.map((v) => ({ v, name: fold(v.vessel), names: fold(v.names), ids: [String(v.vid), tight(v.cs), tight(v.mmsi), tight(v.imo), tight(v.uid)] })); };
function search(text) {
  const f = fold(text).trim(), t = tight(text), out = [];
  if (!f) return out;
  for (const x of SX) {
    let rank = 9;
    if (t && x.ids.some((id) => id && id === t)) rank = 0;
    else if (x.name.startsWith(f)) rank = 1;
    else if (x.name.split(/\s+/).some((w) => w.startsWith(f))) rank = 2;
    else if (x.name.includes(f)) rank = 3;
    else if (t && x.ids.some((id) => id && id.startsWith(t))) rank = 4;
    else if (x.names.includes(f)) rank = 5;
    if (rank < 9) out.push({ ...x, rank });
  }
  return out.sort((p, r) => p.rank - r.rank || (r.v.last_ping || '').localeCompare(p.v.last_ping || '') || p.v.vid - r.v.vid);
}
function mark(text, f) {   // the text with its first match of f in bold, matched on the folded spelling
  const s = String(text ?? '');
  if (!f) return esc(s);
  let folded = ''; const at = [];
  for (let i = 0; i < s.length; i++) for (const c of fold(s[i])) { folded += c; at.push(i); }
  const k = folded.indexOf(f);
  if (k < 0) return esc(s);
  const a = at[k], b = at[k + f.length - 1] + 1;
  return `${esc(s.slice(0, a))}<mark>${esc(s.slice(a, b))}</mark>${esc(s.slice(b))}`;
}
// The vessels opened lately, in this browser only: the search shows them before anything is typed
const RECENT = 'vessel-overview.recent';
function recent() { try { return JSON.parse(localStorage.getItem(RECENT) || '[]'); } catch (e) { return []; } }
function remember(vid) { try { localStorage.setItem(RECENT, JSON.stringify([vid, ...recent().filter((x) => x !== vid)].slice(0, 8))); } catch (e) { /* no storage */ } }
let found = [], foundAt = 0;
const SHOW = 12;
function renderResults() {
  const text = $('q').value, f = fold(text).trim(), t = tight(text);
  found = f ? search(text) : recent().map((vid) => SX.find((x) => x.v.vid === vid)).filter(Boolean);
  foundAt = Math.min(foundAt, Math.max(0, Math.min(found.length, SHOW) - 1));
  const row = (x, i) => {
    const v = x.v, former = x.rank === 5 ? (v.names || '').split(' · ').find((n) => fold(n).includes(f)) : null;
    const ids = [v.cs && `call sign ${mark(v.cs, t)}`, v.mmsi && `MMSI ${mark(v.mmsi, t)}`, v.imo && `IMO ${mark(v.imo, t)}`,
                 v.uid && `local sign ${mark(v.uid, t)}`].filter(Boolean).join(' · ');
    return `<div class="res${i === foundAt ? ' on' : ''}" role="option" data-vid="${v.vid}">
      <div><b>${mark(v.vessel || `vid ${v.vid}`, f)}</b> <span class="note">vid ${mark(v.vid, t)}</span></div>
      <div class="sub">${ids ? `${ids} · ` : ''}${v.last_ping ? `last heard ${esc(v.last_ping)}` : 'never heard on AIS'}${v.last_landing ? ` · last landing ${esc(v.last_landing)}` : ''}</div>
      ${former ? `<div class="sub">a former name: ${mark(former, f)}</div>` : ''}</div>`;
  };
  $('results').innerHTML = (f ? '' : `<div class="head">${found.length ? 'opened lately' : 'type a name or a number'}</div>`) +
    found.slice(0, SHOW).map(row).join('') +
    (f && !found.length ? '<div class="foot note">No vessel matches.</div>' : '') +
    `<div class="foot">${f && found.length > SHOW ? `${found.length - SHOW} more: type on, or ` : ''}<a href="#" id="to-list">browse every vessel in a list</a></div>`;
  $('results').hidden = false;
  $('results').querySelectorAll('.res').forEach((el) => el.addEventListener('mousedown', (e) => { e.preventDefault(); openVessel(+el.dataset.vid); }));
  $('to-list').addEventListener('mousedown', (e) => {
    e.preventDefault(); $('results').hidden = true; $('filter').value = $('q').value;
    $('drawer').classList.add('on'); renderList(); $('filter').focus();
  });
}
function openVessel(vid) {
  $('results').hidden = true; $('q').value = ''; $('q').blur();
  location.hash = hashFor(vid);
}
$('q').addEventListener('input', () => { foundAt = 0; renderResults(); });
$('q').addEventListener('focus', renderResults);
$('q').addEventListener('blur', () => { $('results').hidden = true; });
$('q').addEventListener('keydown', (e) => {
  const n = Math.min(found.length, SHOW);
  if (e.key === 'ArrowDown' && n) { foundAt = (foundAt + 1) % n; renderResults(); e.preventDefault(); }
  else if (e.key === 'ArrowUp' && n) { foundAt = (foundAt - 1 + n) % n; renderResults(); e.preventDefault(); }
  else if (e.key === 'Enter' && n) openVessel(found[foundAt].v.vid);
  else if (e.key === 'Escape') $('q').blur();
});
// '/' goes to the search from anywhere but a field
document.addEventListener('keydown', (e) => {
  if (e.key === '/' && !['INPUT', 'SELECT', 'TEXTAREA'].includes(document.activeElement?.tagName)) { e.preventDefault(); $('q').focus(); }
});
$('close-list').addEventListener('click', () => $('drawer').classList.remove('on'));
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') $('drawer').classList.remove('on'); });

// The address holds the vessel and every choice: the years, the window, the map's background, the tab, the open panels
const isoMin = (ms) => new Date(ms).toISOString().slice(0, 16);
function hashFor(vid) {
  const q = new URLSearchParams({ vid, years: P.years, win: P.win, n: P.n, lay: LAYERS.filter(drawn).join(','), tab: tabOn(),
                                  open: PANELS.filter(isOpen).join(',') });
  if (P.win === 'custom') { q.set('a', isoMin(P.a)); q.set('b', isoMin(P.b)); }
  // the selected logbook trip as ".tid|schema": a link then opens that trip with its hauls (maintainer, 2026-10-20)
  if (S.tripSel.size) q.set('trip', [...S.tripSel].join(','));
  if (S.haulSel.size) q.set('haul', [...S.haulSel].join(','));   // and hauls of them, each as .sid|schema
  return q.toString();
}
function setHash() {
  if (!S.vid) return;
  const h = hashFor(S.vid);
  if (location.hash.slice(1) !== h) history.replaceState(null, '', `#${h}`);
}
function fromHash() {
  const h = new URLSearchParams(location.hash.slice(1));
  const vid = parseInt(h.get('vid'), 10), tab = TABS.includes(h.get('tab')) && !(BUNDLE && h.get('tab') === 'vessel') ? h.get('tab') : 'now';
  for (const t of TABS) { $(t).classList.toggle('on', t === tab); $(`tab-${t}`).classList.toggle('on', t === tab); }
  // the open panels; an address of before decision 178 says mode=qc, which showed the lanes and the pings
  if (h.has('open')) P.open = new Set(h.get('open').split(',').filter((k) => PANELS.includes(k)));
  if (h.get('mode') === 'qc') { P.open.add('lanes'); P.open.add('pings'); }
  showFolds();
  // the choices; an address of before 2026-10-18 gives the years as from and to
  const years = h.get('years') || (h.get('from') && h.get('to') ? `${h.get('from')}-${h.get('to')}` : null);
  if (years && /^(latest|all|\d{4}-\d{4})$/.test(years)) P.years = years;
  if (['last', 'month', 'range', 'custom'].includes(h.get('win'))) P.win = h.get('win');
  const a = Date.parse(`${h.get('a')}Z`), b = Date.parse(`${h.get('b')}Z`);
  if (P.win === 'custom') { if (a < b) { P.a = a; P.b = b; } else P.win = 'last'; }
  const n = parseInt(h.get('n'), 10);
  if ([...$('ntrips').options].some((o) => +o.value === n)) P.n = n;
  $('ntrips').value = P.n;
  // what the map draws; an address of before these were buttons says pts (1 points and line, 0 the line, none neither)
  // and bg (none, hex or track)
  if (h.has('lay')) P.lay = new Set(h.get('lay').split(',').filter((k) => LAYERS.includes(k)));
  else if (h.has('pts') || h.has('bg')) {
    P.lay = new Set({ 1: ['points', 'line'], 0: ['line'], none: [] }[h.get('pts') ?? '1'] || ['points', 'line']);
    if (['hex', 'track'].includes(h.get('bg'))) P.lay.add(h.get('bg'));
  }
  markPicked();
  if (!Number.isInteger(vid)) return;
  // the trips and hauls the link names, one or several, each as .tid|schema and .sid|schema
  const keys = (k) => (h.get(k) || '').split(',').filter((x) => x.lastIndexOf('|') > 0);
  const tripKeys = keys('trip'), haulKeys = keys('haul');
  choose(vid).then(async () => {
    if (tripKeys.length === 1) {
      const cut = tripKeys[0].lastIndexOf('|');
      await selectTrip(tripKeys[0].slice(0, cut), tripKeys[0].slice(cut + 1), { open: true, scroll: true });
    } else if (tripKeys.length > 1) await chooseTrips(tripKeys);
    if (haulKeys.length === 1 && S.haulOf.get(haulKeys[0])) await selectHaul(S.haulOf.get(haulKeys[0]), { open: true });
    else if (haulKeys.length > 1) await chooseHauls(haulKeys);
    if (h.get('bench')) bench();
  }).catch((e) => status(String(e)));
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
  const r = { lanes: isOpen('lanes'), pings: tr.n, moves: 20, median_ms: Math.round(sorted[10]), max_ms: Math.round(sorted[19]), each_ms: out.map(Math.round) };
  document.body.dataset.bench = JSON.stringify(r);
  status(`bench: median ${r.median_ms} ms, max ${r.max_ms} ms, ${r.pings} pings`);
  return r;
}
window.overviewBench = bench;   // for the checks in plan 030: run it from the console on a loaded vessel

// Start ----------------------------------------------------------------------------------------------------------------
await ingest('vessels', await fetchParquet('vessels', {}));
V = await rows(`SELECT vid, coalesce(vessel, '') AS vessel, coalesce(cs, '') AS cs, coalesce(mmsi, '') AS mmsi,
    coalesce(imo, '') AS imo, coalesce(uid, '') AS uid, coalesce(names, '') AS names, first_year,
    strftime(last_ping, '%Y-%m-%d') AS last_ping, strftime(last_landing, '%Y-%m-%d') AS last_landing, photo FROM vessels`);
searchIndex();
showFolds();
for (let y = new Date().getUTCFullYear(); y >= 1992; y--) $('f-landed').insertAdjacentHTML('beforeend', `<option value="${y}-01-01">${y}</option>`);
status(BUNDLE ? `${BUNDLE}: ${V.length} vessels` : `${V.length.toLocaleString('en-GB')} vessels`);
if (BUNDLE) { $('f-photo').closest('label').hidden = true; $('filter').placeholder = 'type a number'; $('q').placeholder = 'Search: a vessel number or name'; }
if (location.hash.length > 1) fromHash(); else { $('drawer').classList.add('on'); renderList(); $('filter').focus(); }
