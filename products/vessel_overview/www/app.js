// The vessel overview page's script (plan 030 step 4). One vessel at a time. The R service sends each panel's rows
// once, as parquet; DuckDB-WASM holds them, and every interaction runs here with no further request (decision 137,
// ask h). The map, the time-speed plot and the slider share one time window. The map's layers follow the maintainer's
// asjo app (plan 030 §4.2). Internal use only: the photos are a newspaper's.
import * as duckdb from 'https://cdn.jsdelivr.net/npm/@duckdb/duckdb-wasm@1.28.0/+esm';

const $ = (id) => document.getElementById(id);
const TOKEN = document.querySelector('meta[name="mapbox-token"]').content;
const status = (msg) => { $('status').textContent = msg; };
const fmt = (ms) => (ms == null ? '' : new Date(ms).toISOString().slice(0, 16).replace('T', ' '));
const esc = (x) => String(x ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const num = (x, d = 0) => (x == null || x === '' ? '' : Number(x).toLocaleString('en-GB', { maximumFractionDigits: d }));
const DAY = 864e5;

// DuckDB-WASM -----------------------------------------------------------------------------------------------------------
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

// State: the vessel, its trail, the time window, the ping under the cursor, the chosen trip --------------------------------
const S = { vid: null, name: '', tr: null, year: null, win: [0, 0], hover: -1, trip: null, stations: [] };

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

const hours = (ms) => (ms - S.tr.t0) / 36e5;
function layers() {
  const L = basemap ? [basemap] : [], tr = S.tr;
  if (!tr || !tr.n) return L;
  L.push(new deck.PathLayer({
    id: 'track', data: tr.paths, getPath: (d) => d.path, widthUnits: 'meters', getWidth: 300, widthMinPixels: 1,
    widthMaxPixels: 5, getColor: [70, 80, 100, 90], pickable: true, autoHighlight: true, highlightColor: [0, 0, 0, 149],
  }));
  L.push(new deck.ScatterplotLayer({
    id: 'pings', data: tr.pingData, radiusUnits: 'meters', getRadius: 400, radiusMinPixels: 2, radiusMaxPixels: 6,
    pickable: true, extensions: [FILTER], filterRange: [hours(S.win[0]), hours(S.win[1])],
  }));
  L.push(new deck.LineLayer({
    id: 'stations', data: S.stations, getSourcePosition: (d) => [d.lon1, d.lat1], getTargetPosition: (d) => [d.lon2, d.lat2],
    getColor: (d) => (d.tid === S.trip ? [220, 30, 30, 255] : [20, 20, 20, 210]), getWidth: 3, pickable: true,
    updateTriggers: { getColor: S.trip },
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
    const head = layer.id === 'last' ? `<b>${esc(S.name)} (${S.vid})</b><br>last position<br>` : '';
    return { html: `${head}<b>${fmt(tr.t[i])} UTC</b><br>${num(tr.speed[i], 1)} kn, heading ${num(tr.heading[i])}°<br>` +
      `${esc(tr.gear[i])}${tr.fishing[i] ? ' · fishing' : ''}<br>${num(tr.lat[i], 4)} N, ${num(tr.lon[i], 4)} E` };
  }
  if (layer.id === 'track' && object) return { text: `voyage ${object.voyage}` };
  if (layer.id === 'stations' && object) return { html: `station ${esc(object.day)}, ${esc(object.gear)}<br>${fmt(object.t1)} – ${fmt(object.t4)}` };
  return null;
}

// The time-speed plot ------------------------------------------------------------------------------------------------
let plot = null, cursorFromMap = false;
function makePlot() {
  const tr = S.tr;
  plot?.destroy();
  plot = new uPlot({
    width: $('plot').clientWidth || 600, height: 170, legend: { show: false },
    scales: { x: { time: true }, y: { range: [0, Math.max(12, tr.maxSpeed)] } },
    series: [{}, { label: 'speed', stroke: '#1f6feb', width: 1, points: { show: false } }],
    axes: [{}, { label: 'knots', size: 50 }],
    cursor: { drag: { x: true, y: false, setScale: false }, points: { show: false } },
    hooks: {
      setSelect: [(u) => {
        if (u.select.width < 3) return;
        const a = u.posToVal(u.select.left, 'x') * 1000, b = u.posToVal(u.select.left + u.select.width, 'x') * 1000;
        u.setSelect({ left: 0, width: 0, top: 0, height: 0 }, false);
        setWindow(a, b, 'plot');
      }],
      setCursor: [(u) => { if (!cursorFromMap && u.cursor.idx != null) setHover(u.cursor.idx, 'plot'); }],
    },
  }, [tr.ts, tr.speed], $('plot'));
}
window.addEventListener('resize', () => plot && plot.setSize({ width: $('plot').clientWidth, height: 170 }));

function setHover(i, source) {
  S.hover = i;
  render();
  if (source === 'map' && plot) {
    cursorFromMap = true;
    plot.setCursor({ left: plot.valToPos(S.tr.ts[i], 'x'), top: plot.valToPos(S.tr.speed[i], 'y') });
    cursorFromMap = false;
  }
}

// The window: one state, three views ---------------------------------------------------------------------------------
let lastRedraw = null, onRedraw = null;
function setWindow(a, b, source) {
  const tr = S.tr;
  a = Math.max(tr.t0, Math.min(a, tr.t1));
  b = Math.max(a + 6e4, Math.min(b, tr.t1));
  S.win = [a, b];
  const t0 = performance.now();
  if (source !== 'slider') { $('from').value = a / 1000; $('to').value = b / 1000; }
  plot.setScale('x', { min: a / 1000, max: b / 1000 });
  $('window-label').textContent = `${fmt(a)} – ${fmt(b)} UTC`;
  afterRender = () => {
    lastRedraw = performance.now() - t0;
    $('perf').textContent = `redraw ${Math.round(lastRedraw)} ms, ${S.tr.n.toLocaleString('en-GB')} pings`;
    if (onRedraw) { const f = onRedraw; onRedraw = null; f(lastRedraw); }
  };
  render();
}
function slider() {
  let a = +$('from').value * 1000, b = +$('to').value * 1000;
  if (a > b) [a, b] = [b, a];
  setWindow(a, b, 'slider');
}
$('from').addEventListener('input', slider);
$('to').addEventListener('input', slider);
$('month').addEventListener('click', () => S.tr && setWindow(S.tr.t1 - 30 * DAY, S.tr.t1));
$('all').addEventListener('click', () => S.tr && setWindow(S.tr.t0, S.tr.t1));
let playing = false;
$('play').addEventListener('click', () => {
  if (!S.tr) return;
  playing = !playing;
  $('play').textContent = playing ? 'Pause' : 'Play';
  const step = () => {
    if (!playing) return;
    const [a, b] = S.win, w = b - a, d = w / 40;
    if (b + d > S.tr.t1) { playing = false; $('play').textContent = 'Play'; return; }
    setWindow(a + d, b + d);
    requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
});

// The trail of one year ----------------------------------------------------------------------------------------------
async function loadTrail(year) {
  status(`loading ${year}`);
  await ingest('trail', await fetchParquet('trail', { vid: S.vid, year }));
  const tbl = await conn.query(`SELECT epoch_ms(time)::DOUBLE AS t, lon::FLOAT AS lon, lat::FLOAT AS lat,
      coalesce(speed, 0)::FLOAT AS speed, coalesce(heading, 0)::FLOAT AS heading, coalesce(voyage, -1)::INTEGER AS voyage,
      coalesce(fishing_flow, false)::INTEGER AS fishing, coalesce(gear, '') AS gear
    FROM trail WHERE lon IS NOT NULL AND lat IS NOT NULL ORDER BY time`);
  const col = (k) => tbl.getChild(k).toArray();
  const tr = { n: tbl.numRows, t: col('t'), lon: col('lon'), lat: col('lat'), speed: col('speed'), heading: col('heading'),
               voyage: col('voyage'), fishing: col('fishing'), gear: col('gear') };
  if (!tr.n) { S.tr = null; S.year = null; render(); status(`no pings in ${year}`); return; }
  tr.t0 = tr.t[0]; tr.t1 = tr.t[tr.n - 1];
  tr.ts = new Float64Array(tr.n); tr.pos = new Float32Array(2 * tr.n); tr.col = new Uint8Array(4 * tr.n);
  tr.th = new Float32Array(tr.n);
  let maxSpeed = 0;
  const byVoyage = new Map();
  for (let i = 0; i < tr.n; i++) {
    tr.ts[i] = tr.t[i] / 1000; tr.th[i] = (tr.t[i] - tr.t0) / 36e5;
    tr.pos[2 * i] = tr.lon[i]; tr.pos[2 * i + 1] = tr.lat[i];
    const c = speedColour(tr.speed[i]);
    tr.col[4 * i] = c[0]; tr.col[4 * i + 1] = c[1]; tr.col[4 * i + 2] = c[2]; tr.col[4 * i + 3] = 230;
    if (tr.speed[i] > maxSpeed && tr.speed[i] < 30) maxSpeed = tr.speed[i];
    const v = tr.voyage[i];
    if (v >= 0) { if (!byVoyage.has(v)) byVoyage.set(v, []); byVoyage.get(v).push([tr.lon[i], tr.lat[i]]); }
  }
  tr.maxSpeed = Math.ceil(maxSpeed);
  tr.paths = [...byVoyage].map(([voyage, path]) => ({ voyage, path }));
  tr.pingData = { length: tr.n, attributes: { getPosition: { value: tr.pos, size: 2 }, getFillColor: { value: tr.col, size: 4 },
                                              getFilterValue: { value: tr.th, size: 1 } } };
  S.tr = tr; S.year = year; S.hover = -1;
  for (const id of ['from', 'to']) { $(id).min = tr.t0 / 1000; $(id).max = tr.t1 / 1000; $(id).step = 60; }
  makePlot();
  const a = Math.max(tr.t0, tr.t1 - 30 * DAY);
  fitTo(a, tr.t1);
  setWindow(a, tr.t1);
  status(`vid ${S.vid}, ${year}: ${tr.n.toLocaleString('en-GB')} pings`);
}
function fitTo(a, b) {
  const tr = S.tr; let x0 = 180, x1 = -180, y0 = 90, y1 = -90;
  for (let i = 0; i < tr.n; i++) if (tr.t[i] >= a && tr.t[i] <= b) {
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

// The panels ----------------------------------------------------------------------------------------------------------
const HIST = ['vessel', 'identification', 'measurement', 'owners', 'operators', 'events'];
const table = (cols, data, opts = {}) => data.length
  ? `<table><tr>${cols.map(([, h]) => `<th>${h}</th>`).join('')}</tr>${data.map((r, i) =>
      `<tr${opts.click ? ` class="click" data-i="${i}"` : ''}>${cols.map(([k]) => `<td>${esc(r[k])}</td>`).join('')}</tr>`).join('')}</table>`
  : `<div class="note">${opts.empty || 'none'}</div>`;

async function renderRegister() {
  const r = (await rows(`SELECT *, strftime(mmsi_t1, '%Y-%m-%d') AS m1, strftime(mmsi_t2, '%Y-%m-%d') AS m2,
                                strftime(note_date, '%Y-%m-%d') AS nd FROM register`))[0];
  if (!r) { $('register').innerHTML = '<div class="note">not in vessel.parquet</div>'; S.name = ''; return; }
  S.name = r.vessel || '';
  $('title').textContent = `${r.vessel ?? ''} · vid ${S.vid}${r.cs ? ' · ' + r.cs : ''}`;
  const f = [['Name', r.vessel], ['Call sign', r.cs], ['MMSI', r.mmsi && `${r.mmsi}${r.m1 ? ` (${r.m1} – ${r.m2 ?? ''})` : ''}`],
             ['IMO', r.imo], ['Local sign', r.uid], ['Flag', r.flag], ['Status', r.status], ['Length', r.loa && `${num(r.loa, 1)} m`],
             ['Power', r.kw && `${num(r.kw)} kW`], ['GRT / GT', [r.grt, r.bwt].filter((x) => x != null).map((x) => num(x, 1)).join(' / ')],
             ['Note', [r.note_fate, r.nd].filter(Boolean).join(', ')], ['Source', r.source]];
  $('register').innerHTML = `<dl>${f.filter(([, v]) => v != null && v !== '').map(([k, v]) => `<dt>${k}</dt><dd>${esc(v)}</dd>`).join('')}</dl>`;
}

async function renderHistory() {
  const d = (x) => `strftime(${x}, '%Y-%m-%d')`;
  const own = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, name, percentage FROM hist_owners ORDER BY valid_from DESC LIMIT 8`);
  const ops = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, name FROM hist_operators ORDER BY valid_from DESC LIMIT 8`);
  const idn = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, home_port, call_sign FROM hist_identification ORDER BY valid_from DESC LIMIT 8`);
  const ves = await rows(`SELECT ${d('valid_from')} AS f, ${d('valid_to')} AS t, name, usage_category FROM hist_vessel ORDER BY valid_from DESC LIMIT 8`);
  const ev = await rows(`SELECT ${d('date')} AS date, event, fate FROM hist_events ORDER BY date DESC LIMIT 8`);
  $('history').innerHTML =
    `<h3 class="note">Name and use</h3>${table([['f', 'from'], ['t', 'to'], ['name', 'name'], ['usage_category', 'use']], ves)}` +
    `<h3 class="note">Owners</h3>${table([['f', 'from'], ['t', 'to'], ['name', 'name'], ['percentage', '%']], own)}` +
    `<h3 class="note">Operators</h3>${table([['f', 'from'], ['t', 'to'], ['name', 'name']], ops)}` +
    `<h3 class="note">Home port and call sign</h3>${table([['f', 'from'], ['t', 'to'], ['home_port', 'home port'], ['call_sign', 'call sign']], idn)}` +
    `<h3 class="note">Events</h3>${table([['date', 'date'], ['event', 'event'], ['fate', 'fate']], ev)}`;
}

async function renderLandings() {
  const L = await rows(`SELECT strftime(date, '%Y-%m-%d') AS day, port, coalesce(gear_name, gear) AS gear,
      round(sum(catch) / 1000, 2)::DOUBLE AS tonnes,
      string_agg(sid::VARCHAR, ', ' ORDER BY catch DESC) AS species
    FROM landings GROUP BY ".lid", schema, date, port, gear_name, gear ORDER BY date DESC`);
  L.forEach((r) => { r.species = r.species.split(', ').slice(0, 4).join(', ') + (r.species.split(', ').length > 4 ? ', …' : ''); });
  $('landings').innerHTML = table([['day', 'date'], ['port', 'port'], ['gear', 'gear'], ['tonnes', 'tonnes'], ['species', 'species (codes, largest first)']], L,
                                  { empty: 'no landing' });
}

async function renderTrips() {
  const T = await rows(`SELECT t.".tid" AS tid, epoch_ms(t.T1)::DOUBLE AS a, epoch_ms(t.T2)::DOUBLE AS b,
      strftime(t.T1, '%Y-%m-%d %H:%M') AS t1, strftime(t.T2, '%Y-%m-%d %H:%M') AS t2, t.port,
      (SELECT count(*) FROM stations s WHERE s.".tid" = t.".tid" AND s.schema = t.schema)::INTEGER AS stations,
      (SELECT round(sum(c.catch) / 1000, 2) FROM station_catch c JOIN stations s USING (".sid", schema)
        WHERE s.".tid" = t.".tid" AND s.schema = t.schema)::DOUBLE AS tonnes
    FROM trips t ORDER BY t.T2 DESC`);
  S.stations = await rows(`SELECT ".tid" AS tid, lon1, lat1, coalesce(lon2, lon1) AS lon2, coalesce(lat2, lat1) AS lat2,
      strftime(date, '%Y-%m-%d') AS day, coalesce(gear, '') AS gear, epoch_ms(t1)::DOUBLE AS t1, epoch_ms(t4)::DOUBLE AS t4
    FROM stations WHERE lon1 IS NOT NULL AND lat1 IS NOT NULL`);
  $('trips').innerHTML = table([['t1', 'departure'], ['t2', 'landing'], ['port', 'port'], ['stations', 'stations'], ['tonnes', 'tonnes']], T,
                               { click: true, empty: 'no logbook trip' });
  $('trips').querySelectorAll('tr.click').forEach((tr) => tr.addEventListener('click', async () => {
    const r = T[+tr.dataset.i];
    S.trip = r.tid;
    $('trips').querySelectorAll('tr').forEach((x) => x.classList.toggle('sel', x === tr));
    if (!r.a || !r.b) { render(); return; }
    // a trip in another year than the one loaded: load its year first (a trip over New Year shows its landing year)
    const y = new Date(r.b).getUTCFullYear();
    if (y !== S.year && [...$('year').options].some((o) => +o.value === y)) { $('year').value = y; await loadTrail(y); }
    if (S.tr && S.year === y) { fitTo(r.a, r.b); setWindow(r.a - 36e5, r.b + 36e5); } else { render(); status(`no trail in ${y}`); }
  }));
}

let photos = [], photoAt = 0;
function showPhoto() {
  const p = photos[photoAt];
  if (!p) { $('photo-body').innerHTML = '<div class="note">no photo: the 2022 mbl scrape has none for this vessel</div>'; return; }
  const credit = [p.exif_artist ? `Photo: ${p.exif_artist}` : 'Photographer not given', 'mbl.is, 200 mílur',
                  p.exif_date ? `taken ${p.exif_date}` : 'date unknown, before 2022-12-28'].join(' · ');
  $('photo-body').innerHTML = `<img src="/photo?vid=${S.vid}&file=${encodeURIComponent(p.file)}" alt="vessel ${S.vid}">
    <div class="note">${esc(credit)}${photos.length > 1 ? ` · ${photoAt + 1} of ${photos.length}, click for the next` : ''}
    ${p.kind === 'thumbnail' ? ' · thumbnail only' : ''}<br>Internal use only.</div>`;
  $('photo-body').querySelector('img').addEventListener('click', () => { photoAt = (photoAt + 1) % photos.length; showPhoto(); });
}
async function renderPhoto() {
  photos = await rows(`SELECT file, kind, exif_artist, strftime(exif_date, '%Y-%m-%d') AS exif_date FROM photos ORDER BY best DESC, kind, image_no`);
  photoAt = 0;
  showPhoto();
}

// Choosing a vessel ----------------------------------------------------------------------------------------------------
async function choose(vid, year) {
  const t = performance.now();
  status(`loading vid ${vid}`);
  S.vid = vid; S.trip = null; S.tr = null; render();
  await loadAll([['register', 'register', { vid }], ...HIST.map((h) => [`hist_${h}`, 'hist', { vid, table: h }]),
                 ['landings', 'landings', { vid, n: 20 }], ['trips', 'trips', { vid, n: 10 }], ['stations', 'stations', { vid, n: 10 }],
                 ['station_catch', 'station_catch', { vid, n: 10 }], ['trail_years', 'trail_years', { vid }], ['photos', 'photos', { vid }]]);
  await renderRegister(); await renderHistory(); await renderLandings(); await renderTrips(); await renderPhoto();
  const years = await rows('SELECT year, n::INTEGER AS n FROM trail_years ORDER BY year DESC');
  $('year').innerHTML = years.map((y) => `<option value="${y.year}">${y.year} (${y.n.toLocaleString('en-GB')} pings)</option>`).join('');
  if (!years.length) { plot?.destroy(); plot = null; $('window-label').textContent = ''; status(`vid ${vid}: no trail`); return; }
  const y = years.some((x) => x.year === year) ? year : years[0].year;
  $('year').value = y;
  await loadTrail(y);
  $('perf').textContent += ` · vessel loaded in ${Math.round(performance.now() - t)} ms`;
}
$('year').addEventListener('change', () => loadTrail(+$('year').value).catch((e) => status(String(e))));

function fromHash() {
  const h = new URLSearchParams(location.hash.slice(1));
  const vid = parseInt(h.get('vid'), 10);
  if (!Number.isInteger(vid)) return;
  choose(vid, parseInt(h.get('year'), 10)).then(() => { if (h.get('bench')) bench(); }).catch((e) => status(String(e)));
}
window.addEventListener('hashchange', fromHash);
$('search').addEventListener('change', () => {
  const vid = parseInt($('search').value, 10);
  if (Number.isInteger(vid)) location.hash = `vid=${vid}`;
});

// A measure of responsiveness: 20 window moves on the loaded year, each timed to the map's next frame ----------------------
async function bench() {
  const tr = S.tr, out = [];
  if (!tr) return;
  for (let k = 1; k <= 20; k++) {
    const b = tr.t0 + ((tr.t1 - tr.t0) * k) / 20;
    out.push(await new Promise((res) => { onRedraw = res; setWindow(b - 30 * DAY, b); }));
  }
  const sorted = [...out].sort((a, b) => a - b);
  const r = { pings: tr.n, moves: 20, median_ms: Math.round(sorted[10]), max_ms: Math.round(sorted[19]),
              each_ms: out.map(Math.round) };
  document.body.dataset.bench = JSON.stringify(r);
  status(`bench: median ${r.median_ms} ms, max ${r.max_ms} ms, ${r.pings} pings`);
  return r;
}
window.overviewBench = bench;   // for the check in plan 030 step 4: run it from the console on a loaded vessel

// Start ----------------------------------------------------------------------------------------------------------------
const V = await (async () => { await ingest('vessels', await fetchParquet('vessels', {}));
  return rows(`SELECT vid, coalesce(vessel, '') AS vessel, coalesce(cs, '') AS cs, coalesce(mmsi, '') AS mmsi FROM vessels ORDER BY vid`); })();
$('vessels').innerHTML = V.map((v) => `<option value="${v.vid}">${esc(`${v.vid} ${v.vessel} ${v.cs} ${v.mmsi}`)}</option>`).join('');
status(`${V.length.toLocaleString('en-GB')} vessels: choose one`);
fromHash();
