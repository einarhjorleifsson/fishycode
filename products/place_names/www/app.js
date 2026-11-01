// The place-name explorer's script (plan 045 step 1, its first, read-only part; plan 044). The service sends the names,
// places, synonyms, spellings and footprints once; the page holds them and does every filter and link itself. A name's
// occurrences are asked when it is chosen, and kept.
'use strict';
const $ = (id) => document.getElementById(id);
const esc = (x) => String(x ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const num = (x, d = 0) => (x == null || Number.isNaN(x) ? '' : Number(x).toLocaleString('en-GB', { maximumFractionDigits: d }));
const status = (msg) => { $('status').textContent = msg; };
// The service's version this page was written for (api.R, API_VERSION)
const API = '2026-11-01.1';
function banner(html) {
  let b = $('banner');
  if (!b) { b = document.createElement('div'); b.id = 'banner'; document.body.prepend(b); }
  b.style.cssText = 'background:#fee2e2;color:#7f1d1d;padding:8px 14px;border-bottom:1px solid #fca5a5';
  b.innerHTML = html;
}
window.addEventListener('unhandledrejection', (e) => banner(`Something went wrong: ${esc(e.reason?.message || e.reason)}`));
window.addEventListener('error', (e) => banner(`Something went wrong: ${esc(e.message)}`));

async function api(endpoint, params) {
  const r = await fetch(`/api/${endpoint}${params ? `?${new URLSearchParams(params)}` : ''}`);
  const v = r.headers.get('X-Place-Names-Api');
  if (v !== API) banner(`<b>The service is older than this page</b> (service ${esc(v || 'unknown')}, page ${API}): restart it
    (<code>place_names_stop(); place_names()</code>, or the terminal's <code>server.R</code>) and reload.`);
  if (!r.ok) throw new Error(`${endpoint}: ${r.status} ${await r.text()}`);
  return r.json();
}
// columns as arrays (jsonlite's dataframe = "columns") into one object per row
function rows(c) {
  const k = Object.keys(c), n = k.length ? c[k[0]].length : 0, out = new Array(n);
  for (let i = 0; i < n; i++) { const o = {}; for (const f of k) o[f] = c[f][i]; out[i] = o; }
  return out;
}
// As the gazetteer makes its key (curate/place_name_evidence.R, name_key()): "Litli-Banki" and "Littli banki" meet
const FOLD = 'áéíóúýöäåøü', PLAIN = 'aeiouyoaaou';
const nameKey = (s) => String(s).toLowerCase().replace(/ð/g, 'd').replace(/þ/g, 'th').replace(/æ/g, 'ae')
  .replace(/[áéíóúýöäåøü]/g, (c) => PLAIN[FOLD.indexOf(c)]).replace(/[^a-z0-9?]/g, '').replace(/([a-z])\1+/g, '$1');

// The sources in ColorBrewer's Paired, 12 colours for 12 sources: a light and dark pair is a family of witness, the
// commoner source light and the rarer dark (and drawn on top), so the rarer stands out where both lie
const SOURCES = [
  ['trackwell', 'Trackwell hauls', '#a6cee3'], ['plotter', 'plotter marks', '#1f78b4'],     // the fishermen's own
  ['lmi', 'LMÍ', '#b2df8a'], ['sjokort', 'sea charts', '#33a02c'],                       // the official maps
  ['channel', 'channel', '#fb9a99'], ['fiskmerki', 'tag recaptures', '#e31a1c'],           // MFRI's samples
  ['oracle', 'Oracle (orri, skikar)', '#fdbf6f'], ['uv', 'uv closures', '#ff7f00'],        // registers and regulations
  ['skjalfandi', 'Skjálfandi', '#cab2d6'], ['qgis', 'QGIS', '#6a3d9a'],                   // areas drawn by hand
  ['article', 'articles', '#ffff99'], ['isor', 'ÍSOR', '#b15928']];                        // text, with no position
const COLOUR = Object.fromEntries(SOURCES.map(([id, , c]) => [id, c]));
const TOTAL = {};
const LABEL = Object.fromEntries(SOURCES.map(([id, l]) => [id, l]));
const dot = (s) => `<span class="dot" style="background:${COLOUR[s] || '#999'}"></span>`;

// The footprints coloured by one class of their names, each in a ColorBrewer scheme: the terrain in Dark2 (a hazard in
// Set1's red, no terrain word grey), the cross-check in RdYlGn's ends (agreeing green, disagreeing red, several places
// orange, one family grey), the level in YlGnBu (broad names dark). Each value's colour also marks it in the panel.
const SCHEMES = {
  terrain: { label: 'terrain', colours: { bank: '#1b9e77', deep: '#7570b3', edge: '#d95f02', ridge: '#e7298a',
                                          hill: '#66a61e', horn: '#e6ab02', bay: '#a6761d', hazard: '#e41a1c', other: '#999999' } },
  outcome: { label: 'cross-check', colours: { confirmed: '#1a9641', 'several places': '#fdae61', disagree: '#d7191c',
                                              single: '#999999', text: '#cccccc' } },
  level: { label: 'level', colours: { 1: '#253494', 2: '#2c7fb8', 3: '#41b6c4', 4: '#a1dab4' } },
};
const ONE_COLOUR = '#1f5f8b';   // the footprints coloured by nothing
const schemeColour = (sc) => (SCHEMES[sc]
  ? ['match', ['to-string', ['get', sc]], ...Object.entries(SCHEMES[sc].colours).flat(), '#999999'] : ONE_COLOUR);
// a grey value (no terrain word, one family, no position) drawn fainter, so the coloured classes carry the map
const GREY = ['other', 'single', 'text'];
const schemeOpacity = (sc, o) => (SCHEMES[sc] ? ['match', ['to-string', ['get', sc]], GREY, o * 0.4, o] : o * 0.6);
const swatch = (c) => `<span class="dot" style="background:${c}"></span>`;

// State: the data held, the list's filters, the chosen name and its occurrences
const D = { names: [], byKey: new Map(), children: new Map(), syn: new Map(), variants: new Map(), places: new Map(),
            search: new Map(), foot: null, evidence: new Map() };
// evOff: the sources of the chosen name's occurrences switched off, on the map and in its table
const S = { key: null, shown: 300, list: [], evOff: new Set() };
// The list's filters: one value each ('' for all), and the sources as a set (empty for all)
const FILTERS = [['class', 'f-class'], ['terrain', 'f-terrain'], ['gear', 'f-gear'], ['outcome', 'f-outcome'], ['level', 'f-level']];
const F = { class: '', terrain: '', gear: '', outcome: '', level: '', src: new Set() };

// The map ------------------------------------------------------------------------------------------------------------
const OWN = new Set(['labels', 'foot', 'sel', 'ev', 'places']);   // our sources, kept through a change of base map
let FONT = ['Open Sans Regular'];
const empty = { type: 'FeatureCollection', features: [] };
// the first base map is ramb's first, 'light' (Carto Positron), whose glyphs the names are written in
const map = new maplibregl.Map({ container: 'map', style: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
                                 center: [-19, 65], zoom: 5, hash: 'map', attributionControl: { compact: true } });
map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');
map.addControl(new maplibregl.ScaleControl({ unit: 'metric' }), 'bottom-left');
// the style is enough to add our layers: the map's own `load` waits for tiles drawn, which a hidden tab never draws
const mapReady = new Promise((res) => map.once('style.load', res));

// The names: upright and semi-bold, unlike the base map's thin italic sea names, in dark ink with a narrow soft halo
// (a broad white one smeared them over the footprints), the chosen name's wider; light ink with a dark halo on a dark
// base
const DARK_BASES = new Set(['dark', 'satellite']);
const labelPaint = (base) => (DARK_BASES.has(base)
  ? { 'text-color': ['case', ['get', 'chosen'], '#fdba74', '#f8fafc'], 'text-halo-color': 'rgba(15, 23, 42, 0.8)',
      'text-halo-width': ['case', ['get', 'chosen'], 2, 1.2], 'text-halo-blur': 0.4 }
  : { 'text-color': ['case', ['get', 'chosen'], '#9a3412', '#0f1d2b'], 'text-halo-color': 'rgba(255, 255, 255, 0.85)',
      'text-halo-width': ['case', ['get', 'chosen'], 2, 1.1], 'text-halo-blur': 0.4 });
// The base map's own sea names are left out: the gazetteer holds them (LMÍ's), and two of one name in two places confuse
const baseWater = (l) => l.type === 'symbol' && /^water_?name/.test(l.id);
function addLayers() {
  const fonts = map.getStyle().layers.map((l) => l.layout?.['text-font']).filter(Array.isArray);
  FONT = fonts.find((f) => /SemiBold|Bold/.test(f[0]) && !/Italic/.test(f[0])) ?? fonts.find((f) => !/Italic/.test(f[0])) ?? FONT;
  for (const l of map.getStyle().layers.filter(baseWater)) map.setLayoutProperty(l.id, 'visibility', 'none');
  map.addSource('foot', { type: 'geojson', data: D.foot || empty });
  map.addSource('labels', { type: 'geojson', data: empty });
  map.addSource('sel', { type: 'geojson', data: empty });
  map.addSource('ev', { type: 'geojson', data: empty });
  map.addSource('places', { type: 'geojson', data: empty });
  // every footprint of a name in the list, from its minimum zoom less one, as the effort map draws them
  const fromZoom = ['any', ['==', ['get', 'always'], true], ['<=', ['-', ['coalesce', ['get', 'min_zoom'], 11], 1], ['zoom']]];
  map.addLayer({ id: 'foot-fill', type: 'fill', source: 'foot', filter: ['all', ['==', ['get', 'listed'], true], fromZoom],
                 paint: { 'fill-color': schemeColour(SCHEME), 'fill-opacity': schemeOpacity(SCHEME, 0.12) } });
  map.addLayer({ id: 'foot-line', type: 'line', source: 'foot', filter: ['all', ['==', ['get', 'listed'], true], fromZoom],
                 paint: { 'line-color': schemeColour(SCHEME), 'line-width': 0.7, 'line-opacity': schemeOpacity(SCHEME, 0.6) } });
  // the chosen name's footprint, its occurrences over it, and the outlines of its own (dark on a white casing, seen on
  // any base and over any colour), its parent's (dashed) and its children's over them
  map.addLayer({ id: 'sel-fill', type: 'fill', source: 'sel', filter: ['==', ['get', 'role'], 'self'],
                 paint: { 'fill-color': '#0f172a', 'fill-opacity': 0.08 } });
  map.addLayer({ id: 'ev', type: 'circle', source: 'ev',
                 layout: { 'circle-sort-key': ['get', 'sort'] },
                 paint: { 'circle-radius': ['interpolate', ['linear'], ['zoom'], 5, 2.4, 10, 4.5],
                          'circle-color': ['get', 'colour'], 'circle-opacity': 0.85,
                          'circle-stroke-color': 'rgba(15, 23, 42, 0.45)', 'circle-stroke-width': 0.5 } });
  map.addLayer({ id: 'sel-casing', type: 'line', source: 'sel', filter: ['!=', ['get', 'role'], 'child'],
                 paint: { 'line-color': '#fff', 'line-width': 4.5, 'line-opacity': 0.85 } });
  map.addLayer({ id: 'sel-line', type: 'line', source: 'sel', filter: ['!=', ['get', 'role'], 'parent'],
                 paint: { 'line-color': ['match', ['get', 'role'], 'self', '#0f172a', '#475569'],
                          'line-width': ['match', ['get', 'role'], 'self', 2.5, 1.2] } });
  map.addLayer({ id: 'sel-parent', type: 'line', source: 'sel', filter: ['==', ['get', 'role'], 'parent'],
                 paint: { 'line-color': '#0f172a', 'line-width': 1.8, 'line-dasharray': [3, 2] } });
  map.addLayer({ id: 'places', type: 'circle', source: 'places',
                 paint: { 'circle-radius': 11, 'circle-color': '#fff', 'circle-stroke-color': '#0f172a', 'circle-stroke-width': 2 } });
  map.addLayer({ id: 'places-n', type: 'symbol', source: 'places',
                 layout: { 'text-field': ['to-string', ['get', 'place']], 'text-font': FONT, 'text-size': 13,
                           'text-allow-overlap': true, 'icon-allow-overlap': true } });
  // the names in the list, from their minimum zoom, broad names first where labels collide; a short list (a filter's
  // or a search's) at every zoom, each with a dot
  const shown = ['any', ['==', ['get', 'always'], true], ['<=', ['coalesce', ['get', 'min_zoom'], 11], ['zoom']]];
  map.addLayer({ id: 'dots', type: 'circle', source: 'labels', filter: ['==', ['get', 'always'], true],
                 paint: { 'circle-radius': 2.5, 'circle-color': '#1f3b57' } });
  map.addLayer({ id: 'labels', type: 'symbol', source: 'labels', filter: shown,
                 layout: { 'text-field': ['get', 'name'], 'text-font': FONT,
                           'text-size': ['match', ['coalesce', ['get', 'level'], 4], 1, 19, 2, 17, 3, 15, 14],
                           'symbol-sort-key': ['+', ['*', 100000, ['coalesce', ['get', 'level'], 4]], ['-', 0, ['get', 'n']]],
                           'text-padding': 3, 'text-letter-spacing': 0.02 },
                 paint: labelPaint('light') });
}

// the footprints of the names in the list, on or off
$('m-foot').addEventListener('change', () => {
  for (const l of ['foot-fill', 'foot-line']) map.setLayoutProperty(l, 'visibility', $('m-foot').checked ? 'visible' : 'none');
});
// the footprints' colours: a scheme, and its legend, whose values filter the list (a second click takes the filter off)
let SCHEME = 'terrain';
function drawLegend() {
  const sc = SCHEMES[SCHEME];
  $('m-legend').innerHTML = sc ? Object.entries(sc.colours).map(([v, c]) => `<span class="chip${F[SCHEME] === v ? ' on' : ''}"
    data-v="${esc(v)}" title="only the names whose ${sc.label} is ${esc(v)}">${swatch(c)}${SCHEME === 'level' ? `level ${esc(v)}` : esc(v)}</span>`).join('') : '';
}
$('m-colour').addEventListener('change', () => {
  SCHEME = $('m-colour').value;
  for (const [l, p] of [['foot-fill', 'fill'], ['foot-line', 'line']]) {
    map.setPaintProperty(l, `${p}-color`, schemeColour(SCHEME));
    map.setPaintProperty(l, `${p}-opacity`, schemeOpacity(SCHEME, p === 'fill' ? 0.12 : 0.6));
  }
  drawLegend();
});
$('m-legend').addEventListener('click', (e) => {
  const c = e.target.closest('.chip');
  if (!c) return;
  F[SCHEME] = F[SCHEME] === c.dataset.v ? '' : c.dataset.v;
  $(`f-${SCHEME}`).value = F[SCHEME];
  applyFilters();
});
// The base maps are ramb's (rb_map_basemaps(), as the effort map's). A raster base or none has no glyphs of its own:
// the labels keep the previous style's, and our layers are carried over the change (as ramb's viewer does)
let BASEMAPS = [];
function baseStyle(b) {
  if (b.style) return b.style;
  const layers = [{ id: 'base-bg', type: 'background', paint: { 'background-color': '#eef0f2' } }];
  if (!b.tiles) return { version: 8, sources: {}, layers };
  return { version: 8, layers: [...layers, { id: 'base', type: 'raster', source: 'base' }],
           sources: { base: { type: 'raster', tiles: [b.tiles], tileSize: 256, maxzoom: b.maxzoom, attribution: b.attribution ?? '' } } };
}
$('m-base').addEventListener('change', () => {
  const b = BASEMAPS.find((x) => x.id === $('m-base').value);
  if (!b) return;
  popup?.remove();
  map.setStyle(baseStyle(b), { transformStyle: (prev, next) => {
    if (!prev) return next;
    const own = prev.layers.filter((l) => OWN.has(l.source))
      .map((l) => (l.id === 'labels' ? { ...l, paint: labelPaint(b.id) } : l));
    const base = next.layers.map((l) => (baseWater(l) ? { ...l, layout: { ...l.layout, visibility: 'none' } } : l));
    const sources = Object.fromEntries(Object.entries(prev.sources).filter(([k]) => OWN.has(k)));
    return { ...next, glyphs: next.glyphs ?? prev.glyphs, sources: { ...next.sources, ...sources }, layers: [...base, ...own] };
  } });
});

// The data ------------------------------------------------------------------------------------------------------------
async function load() {
  status('loading the gazetteer');
  const [names, places, syn, variants, foot, bases] = await Promise.all(
    ['names', 'places', 'synonyms', 'variants', 'footprints', 'basemaps'].map((e) => api(e)));
  BASEMAPS = bases;
  $('m-base').innerHTML = bases.map((b) => `<option value="${esc(b.id)}">${esc(b.label)}</option>`).join('');
  D.names = rows(names);
  for (const n of D.names) {
    D.byKey.set(n.key, n);
    if (n.parent_key) (D.children.get(n.parent_key) ?? D.children.set(n.parent_key, []).get(n.parent_key)).push(n);
    n.sources = SOURCES.map(([s]) => s).filter((s) => n[`n_${s}`] > 0);
  }
  for (const p of rows(places)) (D.places.get(p.key) ?? D.places.set(p.key, []).get(p.key)).push(p);
  // a candidate pair is listed under both its keys
  for (const y of rows(syn)) {
    (D.syn.get(y.key_a) ?? D.syn.set(y.key_a, []).get(y.key_a)).push({ ...y, other: y.key_b, other_name: y.name_b });
    if (y.key_b) (D.syn.get(y.key_b) ?? D.syn.set(y.key_b, []).get(y.key_b)).push({ ...y, other: y.key_a, other_name: y.name_a });
  }
  for (const v of rows(variants)) (D.variants.get(v.key) ?? D.variants.set(v.key, []).get(v.key)).push(v);
  // what the search reads: the key, and each spelling's own key
  for (const n of D.names) D.search.set(n.key, [n.key, ...(D.variants.get(n.key) ?? []).map((v) => nameKey(v.name))]);
  for (const f of foot.features) {
    const n = D.byKey.get(f.properties.key);
    Object.assign(f.properties, { min_zoom: n?.min_zoom ?? null, size: n?.size_km ?? null, listed: true,
                                  terrain: n?.terrain ?? null, outcome: n?.outcome ?? null, level: n?.level ?? null });
  }
  D.foot = foot;
  // each source's occurrences in all, so the rarer sources' points are drawn over the commoner
  for (const [src] of SOURCES) TOTAL[src] = D.names.reduce((a, n) => a + (n[`n_${src}`] ?? 0), 0);
}

// The list ------------------------------------------------------------------------------------------------------------
// a name's value for a filter, with 'none' where it has none
const val = (n, f) => (n[f] == null || n[f] === '' ? 'none' : String(n[f]));
// each filter's choices with their counts over every name, the commonest first ('level' in its own order)
function buildFilters() {
  for (const [f, id] of FILTERS) {
    const c = new Map();
    for (const n of D.names) c.set(val(n, f), (c.get(val(n, f)) ?? 0) + 1);
    const opts = [...c].sort((a, b) => (f === 'level' ? a[0].localeCompare(b[0]) : b[1] - a[1]));
    $(id).innerHTML = `<option value="">all</option>` + opts.map(([v, k]) => `<option value="${esc(v)}">${esc(v)} (${num(k)})</option>`).join('');
    $(id).addEventListener('change', () => { F[f] = $(id).value; applyFilters(); });
  }
  $('f-src').innerHTML = SOURCES.map(([id, l]) => {
    const k = D.names.filter((n) => n[`n_${id}`] > 0).length;
    return `<span class="chip" data-src="${id}" title="${num(k)} names">${dot(id)} ${esc(l)}</span>`;
  }).join('');
}
$('f-src').addEventListener('click', (e) => {
  const c = e.target.closest('.chip');
  if (!c) return;
  F.src.has(c.dataset.src) ? F.src.delete(c.dataset.src) : F.src.add(c.dataset.src);
  c.classList.toggle('on', F.src.has(c.dataset.src));
  applyFilters();
});
function clearFilters() {
  for (const [f, id] of FILTERS) { F[f] = ''; $(id).value = ''; }
  F.src.clear();
  for (const c of document.querySelectorAll('#f-src .chip')) c.classList.remove('on');
  applyFilters();
}
const filtered = () => FILTERS.some(([f]) => F[f] !== '') || F.src.size > 0;
function matches(n, qk) {
  for (const [f] of FILTERS) if (F[f] !== '' && val(n, f) !== F[f]) return false;
  if (F.src.size && !n.sources.some((x) => F.src.has(x))) return false;
  if (!qk) return true;
  return D.search.get(n.key).some((k) => k.includes(qk));
}
function applyFilters() {
  const qk = nameKey($('q').value);
  let list = D.names.filter((n) => matches(n, qk));
  // a typed name: the exact key first, then those that begin with it, then the rest, each by positions
  if (qk) {
    const rank = (n) => (n.key === qk ? 0 : D.search.get(n.key).some((k) => k.startsWith(qk)) ? 1 : 2);
    list = list.map((n, i) => [rank(n), i, n]).sort((a, b) => a[0] - b[0] || a[1] - b[1]).map((x) => x[2]);
  }
  S.list = list; S.shown = 300;
  drawList(); drawLabels(); drawLegend();
}
function drawList() {
  const L = S.list;
  $('count').innerHTML = `<span>${num(L.length)} of ${num(D.names.length)} names</span>` +
    (filtered() ? '<button id="clear" title="every filter back to all">clear filters</button>' : '');
  const sub = (n) => [n.class !== 'name' ? n.class : '', n.terrain !== 'other' ? n.terrain : '',
                      n.n_positioned ? `${num(n.n_positioned)} positions` : 'no position',
                      n.n_places > 1 ? `${n.n_places} places` : ''].filter(Boolean).join(' · ');
  $('list').innerHTML = L.slice(0, S.shown).map((n) =>
    `<div class="item${n.key === S.key ? ' on' : ''}" data-key="${esc(n.key)}"><div class="nm">${esc(n.name)}</div>
       <div class="sub">${n.sources.map(dot).join('')} ${esc(sub(n))}</div></div>`).join('') +
    (L.length > S.shown ? `<div class="more"><button id="more">${num(Math.min(300, L.length - S.shown))} more</button></div>` : '');
}
$('count').addEventListener('click', (e) => { if (e.target.id === 'clear') clearFilters(); });
$('list').addEventListener('click', (e) => {
  if (e.target.id === 'more') { S.shown += 300; drawList(); return; }
  const it = e.target.closest('.item');
  if (it) choose(it.dataset.key);
});
$('q').addEventListener('input', () => applyFilters());
$('q').addEventListener('keydown', (e) => { if (e.key === 'Enter' && S.list.length) choose(S.list[0].key); });

// a list this short is drawn at every zoom
const SHORT = 500;
// the names in the list on the map: a label at each name's main place, and one at each other place of a name
function drawLabels() {
  if (!map.getSource('labels')) return;
  const f = [], always = S.list.length <= SHORT;
  for (const n of S.list) {
    const props = { key: n.key, name: n.name, n: n.n_positioned ?? 0, level: n.level, min_zoom: n.min_zoom,
                    chosen: n.key === S.key, always };
    if (n.label_lon != null) f.push({ type: 'Feature', properties: props, geometry: { type: 'Point', coordinates: [n.label_lon, n.label_lat] } });
    for (const p of D.places.get(n.key) ?? []) if (!p.main) f.push({ type: 'Feature', properties: props,
                                                                      geometry: { type: 'Point', coordinates: [p.lon, p.lat] } });
  }
  map.getSource('labels').setData({ type: 'FeatureCollection', features: f });
  const listed = new Set(S.list.map((n) => n.key));
  for (const x of D.foot.features) Object.assign(x.properties, { listed: listed.has(x.properties.key), always });
  map.getSource('foot').setData(D.foot);
}

// A chosen name ---------------------------------------------------------------------------------------------------------
async function choose(key, { fly = true } = {}) {
  const n = D.byKey.get(key);
  if (!n) return;
  if (key !== S.key) S.evOff.clear();
  S.key = key;
  if (location.hash !== `#key=${encodeURIComponent(key)}`) history.replaceState(null, '', `#key=${encodeURIComponent(key)}${mapHash()}`);
  for (const el of document.querySelectorAll('#list .item')) el.classList.toggle('on', el.dataset.key === key);
  // the list scrolls to the name, the page does not (scrollIntoView would move the page too, on a narrow screen)
  const it = document.querySelector(`#list .item[data-key="${CSS.escape(key)}"]`), L = $('list');
  if (it && (it.offsetTop < L.scrollTop || it.offsetTop + it.offsetHeight > L.scrollTop + L.clientHeight))
    L.scrollTop = it.offsetTop - L.clientHeight / 3;
  drawLabels();
  drawSelection(n);
  drawDetail(n, null);
  if (fly) flyTo(n);
  status(`${n.name}: loading its occurrences`);
  if (!D.evidence.has(key)) D.evidence.set(key, rows(await api('evidence', { key })));
  if (S.key !== key) return;   // another name was chosen meanwhile
  const ev = D.evidence.get(key);
  drawEvidence(ev);
  drawDetail(n, ev);
  status(`${n.name}: ${num(ev.length)} occurrences`);
}
// MapLibre keeps the map's position in its own hash parameter; the chosen name rides beside it
const mapHash = () => { const m = location.hash.match(/map=[^&]*/); return m ? `&${m[0]}` : ''; };

const footOf = (key) => D.foot.features.find((f) => f.properties.key === key);
function drawSelection(n) {
  if (!map.getSource('sel')) return;
  const f = [];
  const add = (key, role) => { const x = footOf(key); if (x) f.push({ ...x, properties: { key, role } }); };
  add(n.key, 'self');
  if (n.parent_key) add(n.parent_key, 'parent');
  for (const c of D.children.get(n.key) ?? []) add(c.key, 'child');
  map.getSource('sel').setData({ type: 'FeatureCollection', features: f });
  const pl = D.places.get(n.key) ?? [];
  map.getSource('places').setData({ type: 'FeatureCollection', features: pl.length > 1 ? pl.map((p) => (
    { type: 'Feature', properties: { place: p.place }, geometry: { type: 'Point', coordinates: [p.lon, p.lat] } })) : [] });
  map.getSource('ev').setData(empty);
}
function drawEvidence(ev) {
  if (!map.getSource('ev')) return;
  // a position flagged as impossible or at zero is kept in the table, not drawn; Trackwell's picklist summary repeats
  // the hauls, so it is not drawn either
  const f = [];
  ev.forEach((e, i) => {
    if (e.lon != null && !e.position_flag && !e.summary && !S.evOff.has(e.source)) f.push(
      { type: 'Feature', properties: { i, colour: COLOUR[e.source] || '#999', sort: -(TOTAL[e.source] ?? 0) }, geometry: { type: 'Point', coordinates: [e.lon, e.lat] } });
  });
  map.getSource('ev').setData({ type: 'FeatureCollection', features: f });
}
// the name's footprint and places in view; with neither, its median
function flyTo(n) {
  const b = new maplibregl.LngLatBounds();
  const x = footOf(n.key);
  const walk = (c) => (typeof c[0] === 'number' ? b.extend(c) : c.forEach(walk));
  if (x) walk(x.geometry.coordinates);
  for (const p of D.places.get(n.key) ?? []) b.extend([p.lon, p.lat]);
  if (b.isEmpty() && n.lon != null) b.extend([n.lon, n.lat]);
  if (b.isEmpty()) return;
  map.fitBounds(b, { padding: 60, maxZoom: Math.max(9, n.min_zoom ?? 9), duration: 600 });
}

// The detail panel ------------------------------------------------------------------------------------------------------
const go = (key, text) => (D.byKey.has(key) ? `<a class="go" data-key="${esc(key)}">${esc(text)}</a>` : esc(text));
const badge = (text, colour) => `<span class="badge">${colour ? swatch(colour) : ''}${esc(text)}</span>`;
function drawDetail(n, ev) {
  const fact = (k, v) => (v === '' || v == null ? '' : `<tr><td>${k}</td><td>${v}</td></tr>`);
  const children = (D.children.get(n.key) ?? []).slice().sort((a, b) => (b.n_positioned ?? 0) - (a.n_positioned ?? 0));
  const syn = D.syn.get(n.key) ?? [];
  const vars = D.variants.get(n.key) ?? [];
  const pl = D.places.get(n.key) ?? [];
  const parent = n.parent_key ? D.byKey.get(n.parent_key) : null;
  let h = `<h2>${esc(n.name)}</h2>
    <div class="muted" style="margin:2px 0 6px">key <code>${esc(n.key)}</code></div>
    <div>${badge(n.class)}${n.terrain !== 'other' ? badge(n.terrain, SCHEMES.terrain.colours[n.terrain]) : ''}${
      badge(n.outcome, SCHEMES.outcome.colours[n.outcome])}${n.level ? badge(`level ${n.level}`, SCHEMES.level.colours[n.level]) : ''}</div>
    <table class="facts" style="margin-top:8px">
    ${fact('Positions', n.n_positioned ? `${num(n.n_positioned)} (precision ${n.precision})` : 'none')}
    ${fact('Sources', n.sources.map((s) => `${dot(s)} ${esc(LABEL[s])} ${num(n[`n_${s}`])}`).join('<br>'))}
    ${fact('Years', n.year_first ? `${n.year_first}–${n.year_last}` : '')}
    ${fact('Vessels', n.n_vessel ? num(n.n_vessel) : '')}
    ${fact('Spread (r80)', n.r80_km != null ? `${num(n.r80_km, 1)} km` : '')}
    ${fact('Footprint', n.size_km != null ? `${num(n.size_km, 1)} km a side` : 'none')}
    ${fact('Depth', n.depth_m != null ? `${num(n.depth_m)} m, slope ${num(n.slope_deg, 1)}°, BPI ${num(n.bpi_m)} m` : '')}
    ${fact('Gear', n.gear ? `${esc(n.gear)} (${num(100 * n.gear_share)} % of Trackwell's hauls)` : '')}
    ${fact('Cross-check', `${esc(n.families || '')}${n.max_family_km != null ? ` · ${num(n.max_family_km, 1)} km apart at most` : ''}`)}
    ${fact('Shown from', n.min_zoom != null ? `zoom ${n.min_zoom}` : '')}
    ${fact('Region', esc(n.region))}
    ${fact('LMÍ', n.in_lmi ? `yes${n.lmi_class ? ` (${esc(n.lmi_class)})` : ''}` : '')}
    </table>
    <h3>Parent and children</h3>
    <table class="facts">
    ${fact('Parent', parent ? `${go(parent.key, parent.name)} <span class="muted">(${esc(n.parent_basis)})</span>` : '<span class="muted">none</span>')}
    ${fact(`Children (${children.length})`, children.length ? children.map((c) => go(c.key, c.name)).join(', ') : '<span class="muted">none</span>')}
    </table>`;
  h += `<h3>Spellings (${vars.length})</h3><table><tr><th>spelling</th><th class="n">n</th><th>sources</th><th>rule</th></tr>
    ${vars.map((v) => `<tr><td>${esc(v.name)}${v.class !== 'name' ? ` <span class="muted">${esc(v.class)}</span>` : ''}
      ${v.repaired_to ? `<br><span class="muted">repaired to ${esc(v.repaired_to)}</span>` : ''}
      ${v.reading ? `<br><span class="muted">read as ${esc(v.reading)}</span>` : ''}</td>
      <td class="n">${num(v.n)}</td><td>${esc(v.sources)}</td><td>${esc(v.rule)}</td></tr>`).join('')}</table>`;
  h += `<h3>Candidate synonyms (${syn.length})</h3>` + (syn.length ? `<table><tr><th>name</th><th>relation</th><th class="n">letters</th><th class="n">km</th></tr>
    ${syn.map((y) => `<tr><td>${go(y.other, y.other_name ?? y.other ?? '')}</td><td>${esc(String(y.relation).replace(/_/g, ' '))}</td>
      <td class="n">${num(y.letters)}</td><td class="n">${num(y.km, 1)}</td></tr>`).join('')}</table>`
    : '<div class="muted">none</div>');
  if (pl.length > 1) h += `<h3>Places (${pl.length})</h3><table><tr><th>place</th><th class="n">positions</th><th class="n">share</th><th class="n">support</th><th>families</th></tr>
    ${pl.map((p) => `<tr class="click" data-lon="${p.lon}" data-lat="${p.lat}"><td>${p.place}${p.main ? ' (main)' : ''}</td>
      <td class="n">${num(p.n)}</td><td class="n">${num(100 * p.share)} %</td><td class="n">${num(p.support)}</td><td>${esc(p.families)}</td></tr>`).join('')}</table>`;
  h += '<h3>Occurrences</h3>' + (ev ? drawOccurrences(ev) : '<div class="muted">loading…</div>');
  $('detail').innerHTML = h;
}
function drawOccurrences(ev) {
  if (!ev.length) return '<div class="muted">none</div>';
  const by = new Map();
  for (const e of ev) by.set(e.source, (by.get(e.source) ?? 0) + 1);
  let h = `<div class="chips" title="a click shows or hides a source's occurrences">${[...by].map(([s, k]) =>
    `<span class="chip${S.evOff.has(s) ? ' off' : ''}" data-evsrc="${esc(s)}">${dot(s)} ${esc(LABEL[s] || s)} ${num(k)}</span>`).join('')}</div>`;
  // occurrences by year, where they have a time, of the sources switched on, each bar stacked by source
  const timed = ev.filter((e) => e.time && !S.evOff.has(e.source));
  if (timed.length) {
    const yr = (e) => +e.time.slice(0, 4);
    const y0 = timed.reduce((a, e) => Math.min(a, yr(e)), 9999), y1 = timed.reduce((a, e) => Math.max(a, yr(e)), 0);
    const c = Array.from({ length: y1 - y0 + 1 }, () => new Map());
    for (const e of timed) { const m = c[yr(e) - y0]; m.set(e.source, (m.get(e.source) ?? 0) + 1); }
    const tot = c.map((m) => [...m.values()].reduce((a, b) => a + b, 0)), mx = Math.max(...tot);
    h += `<div class="bars" style="margin-top:8px">${c.map((m, i) =>
      `<div style="height:${tot[i] ? Math.max(4, 100 * tot[i] / mx) : 0}%" title="${y0 + i}: ${num(tot[i])}">${
        SOURCES.filter(([x]) => m.has(x)).map(([x]) => `<span style="flex:${m.get(x)};background:${COLOUR[x]}"></span>`).join('')}</div>`).join('')}</div>
      <div class="barlab"><span>${y0}</span><span>${y1}</span></div>`;
  }
  const on = [];
  ev.forEach((e, i) => { if (!S.evOff.has(e.source)) on.push(i); });
  const shown = on.slice(0, 200);
  h += `<table style="margin-top:8px"><tr><th>source</th><th>as written</th><th>where</th><th>time</th><th class="n">vid</th><th>gear</th></tr>
    ${shown.map((i) => [ev[i], i]).map(([e, i]) => `<tr class="click" data-i="${i}"><td>${dot(e.source)} ${esc(e.source)}</td><td>${esc(e.name)}</td>
      <td>${esc(e.position_kind ?? '')}${e.position_flag ? ` <span class="badge flag">${esc(e.position_flag)}</span>` : ''}${e.summary ? ' <span class="muted">summary</span>' : ''}</td>
      <td>${esc(e.time ?? '')}</td><td class="n">${e.vid ?? ''}</td><td>${esc(e.gear ?? '')}</td></tr>`).join('')}</table>`;
  if (on.length > shown.length) h += `<div class="muted" style="margin-top:4px">the first ${shown.length} of ${num(on.length)} shown</div>`;
  return h;
}
$('detail').addEventListener('click', (e) => {
  const c = e.target.closest('.chip[data-evsrc]');
  if (c) {
    const src = c.dataset.evsrc, ev = D.evidence.get(S.key);
    S.evOff.has(src) ? S.evOff.delete(src) : S.evOff.add(src);
    drawEvidence(ev);
    const top = $('detail').scrollTop;
    drawDetail(D.byKey.get(S.key), ev);
    $('detail').scrollTop = top;
    return;
  }
  const a = e.target.closest('a.go');
  if (a) { choose(a.dataset.key); return; }
  const tr = e.target.closest('tr.click');
  if (!tr) return;
  if (tr.dataset.lon) { map.flyTo({ center: [+tr.dataset.lon, +tr.dataset.lat], zoom: Math.max(map.getZoom(), 8) }); return; }
  const ev = D.evidence.get(S.key)?.[+tr.dataset.i];
  if (ev?.lon != null) { map.flyTo({ center: [ev.lon, ev.lat], zoom: Math.max(map.getZoom(), 9) }); evPopup(ev, [ev.lon, ev.lat]); }
});

// Clicks on the map: an occurrence, else a name's label, else the smallest footprint under the click ----------------
let popup = null;
function evPopup(e, at) {
  popup?.remove();
  const row = (k, v) => (v == null || v === '' ? '' : `<tr><td class="muted">${k}</td><td>${esc(v)}</td></tr>`);
  popup = new maplibregl.Popup({ maxWidth: '320px' }).setLngLat(at).setHTML(`<b>${dot(e.source)} ${esc(e.name)}</b><table>
    ${row('source', `${LABEL[e.source] || e.source} (${e.source_table})`)}${row('position', `${e.position_kind ?? ''}, ${e.position_basis ?? ''}`)}
    ${row('time', e.time)}${row('vid', e.vid)}${row('gear', e.gear)}${row('square', e.square_w ? `${e.square_w} × ${e.square_h}°` : '')}
    ${row('LMÍ feature', e.lmi_feature)}${row('ÍSOR group', e.isor_group)}${row('uv area', e.uv_type)}</table>`).addTo(map);
}
map.on('click', (e) => {
  const box = [[e.point.x - 4, e.point.y - 4], [e.point.x + 4, e.point.y + 4]];
  const hit = map.queryRenderedFeatures(box, { layers: ['ev'] })[0];
  if (hit) { evPopup(D.evidence.get(S.key)[hit.properties.i], e.lngLat); return; }
  const lab = map.queryRenderedFeatures(box, { layers: ['labels'] })[0];
  if (lab) { choose(lab.properties.key, { fly: false }); return; }
  const fp = map.queryRenderedFeatures(e.point, { layers: ['foot-fill', 'sel-fill'] });
  if (fp.length) {
    const k = fp.map((f) => f.properties.key).filter((k) => D.byKey.has(k))
      .sort((a, b) => (D.byKey.get(a).size_km ?? 1e9) - (D.byKey.get(b).size_km ?? 1e9))[0];
    if (k) choose(k, { fly: false });
  }
});
for (const l of ['ev', 'labels', 'foot-fill']) {
  map.on('mouseenter', l, () => { map.getCanvas().style.cursor = 'pointer'; });
  map.on('mouseleave', l, () => { map.getCanvas().style.cursor = ''; });
}

// a name's address pasted into this tab, or the hash changed by hand
window.addEventListener('hashchange', () => {
  const k = new URLSearchParams(location.hash.slice(1)).get('key');
  if (k && k !== S.key && D.byKey.has(k)) choose(k);
});

// Start -----------------------------------------------------------------------------------------------------------------
(async () => {
  await load();
  buildFilters();
  applyFilters();
  status(`${num(D.names.length)} names`);
  const k = new URLSearchParams(location.hash.slice(1)).get('key');
  if (k && D.byKey.has(k)) choose(k, { fly: !/map=/.test(location.hash) });
  // the list does not wait for the map: its layers come when its style has loaded, drawn as they stand then
  await mapReady;
  addLayers();
  drawLabels();
  if (S.key) {
    drawSelection(D.byKey.get(S.key));
    if (D.evidence.has(S.key)) drawEvidence(D.evidence.get(S.key));
  }
})();
