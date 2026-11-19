// marine_feature_map.js — the names map's editing (marine_feature_map.R puts it into the page by og_script()): plan 074 step
// 12, the named-features study's 132_names_map.js moved here (plan 076 step 6, the smoke test of ogis). Given `og` alone
// (ogis's seam) and MapLibre's own API on og.map; where it reaches past them, `GAP`.
// As 75's page: a click on a name shows where each chart printed it, a marker that drags and turns, Earlier and Later a
// whole zoom, the rule's zoom; Save appends the edit (the route `edit`), Place back reverts. The search finds the aids and
// wrecks too, and only shows them. Internal (Landhelgisgæslan's chart names; not for navigation). Written by Claude (AI),
// 2026-11-18; moved 2026-11-19.
const map = og.map, NAMES = "names";
const body = og.panel("Find and edit a name");
body.classList.add("nm");
body.innerHTML = `
  <input class="nm-q" type="search" placeholder="Find a name" autocomplete="off">
  <ul class="nm-hits"></ul>
  <section class="nm-sel" hidden>
    <p class="nm-name"></p>
    <div class="nm-muted nm-info"></div>
    <div class="nm-row"><label>Angle</label><input class="nm-rot" type="range" min="-90" max="90" step="1" value="0"><span class="nm-angle">0°</span></div>
    <div class="nm-row"><button data-turn="-5">−5°</button><button data-turn="-1">−1°</button><button class="nm-level">level</button><button data-turn="1">+1°</button><button data-turn="5">+5°</button>
      <button class="nm-chartangle" title="the finest chart that turns it">the charts'</button></div>
    <div class="nm-row"><span class="nm-zoomtxt"></span></div>
    <div class="nm-row nm-muted"><span class="nm-waittxt"></span></div>
    <div class="nm-row"><button class="nm-earlier" title="a whole zoom earlier (,)">Earlier</button><button class="nm-later" title="a whole zoom later (.)">Later</button><button class="nm-rule" title="the zoom the rule gives it">the rule's</button></div>
    <div class="nm-row"><button class="nm-save nm-primary" disabled>Save</button><button class="nm-close">Close</button><button class="nm-revert" title="the computed place and angle">Place back</button></div>
    <div class="nm-status"></div>
    <div class="nm-muted">Where the charts printed it:</div>
    <ul class="nm-lets"></ul>
  </section>
  <p class="nm-muted"><kbd>[</kbd> <kbd>]</kbd> turn 5° (with <kbd>Shift</kbd> 1°) · <kbd>,</kbd> <kbd>.</kbd> a zoom earlier, later · <kbd>Enter</kbd> save · <kbd>Esc</kbd> close.</p>`;
const $ = s => body.querySelector(s);

// a route of the page's own, its arguments in a JSON body (ogis 2026.11.18.2's og.fetch() encoded the whole name,
// so a query or a path could not reach the route; mended in 2026.11.18.4; a body works under either)
async function call(name, args = {}) {
  const r = await og.fetch(name, { method: "POST", body: JSON.stringify(args) });
  if (!r.ok) throw new Error((await r.text()) || r.statusText);
  return r.json();
}

// The charts' colours (75's), coarse to fine
const CHARTS = ["sjokort_2milljon", "sjokort_1milljon", "sjokort_300thusund", "sjokort_K42", "sjokort_100thusund", "sjokort_K44",
                "sjokort_35_40_50thusund", "sjokort_15thusund", "sjokort_10thusund"];
const CCOL = ["#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00", "#a65628", "#f781bf", "#999999", "#1b9e77"];
const chartCol = c => CCOL[Math.max(0, CHARTS.indexOf(c))];

// The script's own layers: a clicked name's letterings, the lines from it to them, its extent in LMÍ. GAP: ogis
// keeps only its own layers when the base map changes (setStyle), so the script adds its own again after each change
const EMPTY = { type: "FeatureCollection", features: [] };
const own = { lets: EMPTY, links: EMPTY, lmiext: EMPTY };
function addOwn() {
  if (map.getSource("nm-lets")) return;
  const below = og.layer(NAMES).styles[0];
  for (const k of Object.keys(own)) map.addSource("nm-" + k, { type: "geojson", data: own[k] });
  map.addLayer({ id: "nm-lmiext-fill", type: "fill", source: "nm-lmiext", filter: ["==", ["geometry-type"], "Polygon"], paint: { "fill-color": "#08519c", "fill-opacity": 0.12 } }, below);
  map.addLayer({ id: "nm-lmiext-line", type: "line", source: "nm-lmiext", paint: { "line-color": "#08519c", "line-width": 1.8, "line-opacity": 0.85 } }, below);
  map.addLayer({ id: "nm-links", type: "line", source: "nm-links", paint: { "line-color": "#555", "line-width": 1, "line-dasharray": [2, 2] } }, below);
  map.addLayer({ id: "nm-lets-dot", type: "circle", source: "nm-lets", paint: { "circle-radius": 5, "circle-color": ["get", "col"], "circle-stroke-color": "#fff", "circle-stroke-width": 1.2 } });
  map.addLayer({ id: "nm-lets-label", type: "symbol", source: "nm-lets", layout: { "text-field": ["get", "chart_label"], "text-font": ["Noto Sans Regular"],
    "text-size": 12, "text-offset": [0, 1.1], "text-anchor": "top", "text-allow-overlap": true }, paint: { "text-color": ["get", "col"], "text-halo-color": "#fff", "text-halo-width": 1.5 } });
}
function setOwn(k, data) { own[k] = data; map.getSource("nm-" + k)?.setData(data); }
map.on("styledata", () => { if (map.getSource(og.layer(NAMES).source)) addOwn(); });
addOwn();

// A name's size at a zoom, as the names layer draws it (132_names_map.R: a ground smaller at low zooms)
const GROUND = /(grunn|banki|flak|fláki)$/i;
const shrinkAt = z => Math.min(1, Math.max(0.7, 0.7 + 0.3 * (z - 6) / 3));
const labelPx = P => (P.style === "water" && GROUND.test(P.name)) ? Math.max(10, +P.size * shrinkAt(map.getZoom())) : +P.size;
// 81's spot, in text heights up (132_names_map.R's `up`): a level name a line above or below its place; an edited name none
const LEVEL = 0.5;
const upOf = P => (P.edited || Math.abs(+P.rot || 0) >= LEVEL) ? 0 : Math.sign(+P.dy || 0) * (1.25 * +P.size + 5) / +P.size;
// GAP: the offset's key on each feature, ogis's own encoding of an offset by a column (og_off, "x|y" to a thousandth)
const offKey = up => `0.000|${up.toFixed(3)}`;
// where a name is drawn: its place, or a line above or below it; the marker starts there, so a click does not move it
function drawnAt(P, c) {
  const up = upOf(P); if (!up) return c.slice();
  const p = map.project(c), q = map.unproject([p.x, p.y - up * labelPx(P)]);
  return [q.lng, q.lat];
}

// The zoom a name deserves (71's rule or the maintainer's) and from when it is drawn, waiting for room (81; 99 never)
const NEVER = 99, dz = P => +(P.z_rule ?? P.z0);
const shownFrom = P => Math.ceil(+P.z0 - 1e-9);            // og_text(): from the first whole zoom at or above its start
const waitText = P => +P.z0 >= NEVER ? `Never drawn: no room${P.delayed_by ? ", it waits for " + P.delayed_by : ""}.`
  : `${+P.z0 > dz(P) + 0.005 ? `Its start ${P.z0}: it waits for room${P.delayed_by ? ", for " + P.delayed_by : ""}` : `Its start ${P.z0}, the zoom it deserves`}; shown from zoom ${shownFrom(P)}.`;
const stepFrom = z => Math.round(+z);

// The names layer's data, read once from MapLibre and changed in place by an edit, then sent whole (og.setData)
let namesData = null;
async function namesNow() { return namesData ??= await map.getSource(og.layer(NAMES).source).getData(); }
// GAP: a feature found by og_row, ogis's own number of a row (the route `feature` numbers them as given)
async function changeFeature(row, fn) {
  const d = await namesNow(), f = d.features.find(x => x.properties.og_row === row);
  if (f) { fn(f); og.setData(NAMES, d); }
}

// The names edited since the server started, laid on the names as sent (GAP: ogis reads a whole layer's data once,
// when the server starts, so a page opened again after a save would show the name where it was)
call("changed").then(async ch => {
  if (!ch.length) return;
  const d = await namesNow(), by = new Map(d.features.map(f => [f.properties.og_row, f]));
  for (const P of ch) { const f = by.get(+P.og_row); if (!f) continue;
    f.geometry.coordinates = [+P.lon, +P.lat]; f.properties.turn = -(+P.rot || 0); f.properties.og_off = offKey(upOf(P)); f.properties.z0 = +P.z0;
    f.properties.hand = P.edited || P.zoom_by ? "by hand" : "computed"; }
  og.setData(NAMES, d);
}).catch(err => console.warn("names map: the edits since the server started were not laid on", err));

// A name chosen ----------------------------------------------------------------------------------------------------------
let sel = null, marker = null, base = null, dirty = { moved: false, turned: false, zoomed: false }, zpend = null, saving = false;
const esc = s => String(s ?? "").replace(/[&<>]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
function showDirty() {
  const any = dirty.moved || dirty.turned || dirty.zoomed;
  $(".nm-save").disabled = !any || saving;
  $(".nm-status").textContent = any ? "Not saved: " + [dirty.moved && "moved", dirty.turned && "turned", dirty.zoomed && "zoom changed"].filter(Boolean).join(", ") : "";
}
function setZoom(z) {
  if (!sel) return;
  zpend = Math.max(3, Math.min(18, +z)); const comp = +sel.P.comp_z0;
  $(".nm-zoomtxt").innerHTML = `Deserves its name from zoom <b>${zpend}</b>` + (zpend === comp ? " (the rule's)" : `, the rule ${comp}`);
  dirty.zoomed = !!base && zpend !== base.z0; showDirty();
}
function setRot(r) {
  r = Math.max(-90, Math.min(90, Math.round(r * 10) / 10));
  $(".nm-rot").value = r; $(".nm-angle").textContent = r + "°";
  if (marker) marker.setRotation(r);
  dirty.turned = !!base && r !== base.rot; showDirty();
}
function linksData() {
  if (!sel || !marker) return EMPTY;
  const p = marker.getLngLat();
  return { type: "FeatureCollection", features: (sel.lets || []).map(l => ({ type: "Feature", properties: {}, geometry: { type: "LineString", coordinates: [[p.lng, p.lat], [l.lon, l.lat]] } })) };
}
async function select(feature) {
  const P = await call("feature", { feature });
  close();
  const at = drawnAt(P, [+P.lon, +P.lat]);
  sel = { P, row: +P.og_row };
  base = { lng: at[0], lat: at[1], rot: +P.rot || 0, z0: dz(P) };
  og.filter(NAMES, "sel", ["!=", ["get", "og_row"], sel.row]);   // GAP: og_row, as above
  const el = document.createElement("div");
  el.className = "nm-lbl" + (P.style === "isle" ? " isle" : P.style === "land" ? " land" : "");
  el.textContent = P.name; el.style.fontSize = labelPx(P) + "px";
  marker = new maplibregl.Marker({ element: el, draggable: true, rotationAlignment: "map", pitchAlignment: "map", rotation: base.rot }).setLngLat(at).addTo(map);
  marker.on("drag", () => setOwn("links", linksData()));
  marker.on("dragend", () => { const p = marker.getLngLat(); dirty.moved = Math.abs(p.lng - base.lng) > 1e-7 || Math.abs(p.lat - base.lat) > 1e-7; showDirty(); });
  $(".nm-name").textContent = P.name;
  $(".nm-info").innerHTML = [P.src === "lmi" ? "LMÍ's name (IS 50V)" : "", P.src === "isor" ? "ÍSOR's name (the seabed map)" : "",
    P.lmi ? "LMÍ: " + P.lmi : "", P.isor ? "ÍSOR: " + P.isor : "",
    P.lmi_source ? (P.src === "isor" ? "ÍSOR's source: " : "LMÍ's source (heimild): ") + P.lmi_source + (P.lmi_source_kind ? " [" + P.lmi_source_kind + "]" : "") : "",
    P.printed ? "printed " + P.printed : "", P.place, P.angle, P.edited ? "edited " + P.edited : "", P.aids ? "aids on it: " + P.aids : "",
    P.island_flags ? "island flags: " + P.island_flags : "",
    (P.src === "lmi" || P.src === "isor") ? `the rule's zoom ${P.comp_z0}: its extent ${P.box}` : `the rule's zoom ${P.comp_z0}: its box ${P.box}, its letters ${P.letters}`,
    P.balanced && P.balanced !== "no" ? "brought forward: " + P.balanced : "", P.zoom_by ? "zoom set by hand (" + P.zoom_by + ")" : ""]
    .filter(Boolean).map(esc).join("<br>");
  $(".nm-sel").hidden = false; dirty = { moved: false, turned: false, zoomed: false }; setRot(base.rot); setZoom(base.z0);
  $(".nm-waittxt").textContent = waitText(P);
  setOwn("lmiext", EMPTY);
  if (P.src === "lmi" || P.src === "isor" || P.lmi)
    call("extent", { id: ((P.src === "lmi" || P.src === "isor") ? "" : "c") + P.feature }).then(g => { if (sel?.P.feature === P.feature) setOwn("lmiext", g); }).catch(() => {});
  const lets = await call("letterings", { feature: P.feature });
  if (sel?.P.feature !== P.feature) return;                 // closed, or another name chosen, while it was fetched
  sel.lets = lets;
  setOwn("lets", { type: "FeatureCollection", features: lets.map(l => ({ type: "Feature", properties: { ...l, col: chartCol(l.chart) }, geometry: { type: "Point", coordinates: [l.lon, l.lat] } })) });
  setOwn("links", linksData());
  $(".nm-lets").innerHTML = "";
  for (const l of lets.sort((a, b) => b.scale - a.scale)) {
    const li = document.createElement("li"), turned = Math.abs(((l.runs_deg - 90 + 90) % 180 + 180) % 180 - 90) > 10;
    li.innerHTML = `<i style="background:${chartCol(l.chart)}"></i><span></span>`;
    li.querySelector("span").textContent = `${l.chart_label}: ${l.name}${turned ? ", turned " + Math.round(l.runs_deg) + "° from north" : ""}`;
    li.addEventListener("click", () => map.easeTo({ center: [l.lon, l.lat] }));
    $(".nm-lets").append(li);
  }
}
function close() {
  marker?.remove(); marker = null; sel = null; base = null;
  setOwn("lets", EMPTY); setOwn("links", EMPTY); setOwn("lmiext", EMPTY);
  og.filter(NAMES, "sel", null);
  $(".nm-sel").hidden = true;
}
og.on("click", NAMES, async ({ row }) => {
  const r = await row(); if (!r) return;                    // clicked again meanwhile
  const id = r.find(c => c.name === "feature")?.value;
  if (id != null) select(+id).catch(err => { $(".nm-status").textContent = "Not shown: " + err.message; });
});
map.on("zoom", () => { if (marker && sel) marker.getElement().style.fontSize = labelPx(sel.P) + "px"; });

// Turn, zoom, save, place back ---------------------------------------------------------------------------------------------
$(".nm-rot").addEventListener("input", e => setRot(+e.target.value));
body.querySelectorAll("[data-turn]").forEach(b => b.addEventListener("click", () => setRot(+$(".nm-rot").value + +b.dataset.turn)));
$(".nm-level").addEventListener("click", () => setRot(0));
$(".nm-chartangle").addEventListener("click", () => {
  const t = (sel?.lets || []).filter(l => Math.abs(((l.runs_deg - 90 + 90) % 180 + 180) % 180 - 90) > 10).sort((a, b) => a.scale - b.scale)[0];
  if (!t) { $(".nm-status").textContent = "No chart turns this name."; return; }
  setRot((((t.runs_deg - 90) % 180) + 270) % 180 - 90);
});
$(".nm-earlier").addEventListener("click", () => setZoom(Math.max(3, stepFrom(zpend) - 1)));
$(".nm-later").addEventListener("click", () => setZoom(Math.min(18, stepFrom(zpend) + 1)));
$(".nm-rule").addEventListener("click", () => sel && setZoom(+sel.P.comp_z0));
$(".nm-close").addEventListener("click", close);
async function post(b) { const j = await call("edit", b); if (!j.ok) throw new Error(j.why || "not saved"); return j; }
$(".nm-save").addEventListener("click", async () => {
  if (saving || !sel || !(dirty.moved || dirty.turned || dirty.zoomed)) return;
  // what is saved, and then shown as saved, is the panel as it stands now
  const p = marker.getLngLat(), rot = +$(".nm-rot").value, z = zpend, d = { ...dirty }, P = sel.P, mine = sel;
  const who = { feature: +P.feature, name: P.name, comp_lon: +P.comp_lon, comp_lat: +P.comp_lat };
  saving = true; showDirty();
  try {
    let j = null;
    if (d.moved || d.turned) {
      j = await post({ ...who, lon: p.lng, lat: p.lat, rot, action: d.moved && d.turned ? "move and turn" : d.moved ? "move" : "turn" });
      // drawn where it was put: an edited name has no offset above or below
      P.lon = p.lng; P.lat = p.lat; P.rot = rot; P.edited = j.at;
      await changeFeature(mine.row, f => { f.geometry.coordinates = [p.lng, p.lat]; f.properties.turn = -rot; f.properties.og_off = offKey(0); f.properties.hand = "by hand"; });
    }
    if (d.zoomed) {
      const back = z === +P.comp_z0;
      j = await post({ ...who, action: back ? "zoom back" : "zoom", z0: z, comp_z0: +P.comp_z0 });
      P.z_rule = z; P.z0 = z; P.delayed_by = ""; P.zoom_by = back ? "" : "the maintainer, " + j.at;
      await changeFeature(mine.row, f => { f.properties.z0 = z; if (!back) f.properties.hand = "by hand"; });
    }
    saving = false;
    if (sel === mine) {
      base = { lng: p.lng, lat: p.lat, rot, z0: z }; const q = marker.getLngLat();
      dirty = { moved: Math.abs(q.lng - p.lng) > 1e-7 || Math.abs(q.lat - p.lat) > 1e-7, turned: +$(".nm-rot").value !== rot, zoomed: zpend !== z };
      showDirty(); $(".nm-waittxt").textContent = waitText(P);
      $(".nm-status").textContent = "Saved " + j.at + (dirty.moved || dirty.turned || dirty.zoomed ? "; changed since, not saved" : "");
    } else showDirty();
  } catch (err) { saving = false; showDirty(); if (sel === mine) $(".nm-status").textContent = "Not saved: " + err.message; }
});
$(".nm-revert").addEventListener("click", async () => {
  if (!sel) return;
  const P = sel.P, row = sel.row;
  try {
    await post({ feature: +P.feature, name: P.name, action: "revert", comp_lon: +P.comp_lon, comp_lat: +P.comp_lat });
    const back = { ...P, edited: "", rot: +P.comp_rot || 0 };
    await changeFeature(row, f => { f.geometry.coordinates = [+P.comp_lon, +P.comp_lat]; f.properties.turn = -(+P.comp_rot || 0); f.properties.og_off = offKey(upOf(back));
      if (!P.zoom_by) f.properties.hand = "computed"; });
    await select(+P.feature);
    $(".nm-status").textContent = "Back at the computed place and angle (its zoom as it was).";
  } catch (err) { $(".nm-status").textContent = "Not reverted: " + err.message; }
});
document.addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT" && e.target.type === "search") return;
  if (!sel) return;
  if (e.key === "[" || e.key === "{") { setRot(+$(".nm-rot").value - (e.shiftKey ? 1 : 5)); e.preventDefault(); }
  else if (e.key === "]" || e.key === "}") { setRot(+$(".nm-rot").value + (e.shiftKey ? 1 : 5)); e.preventDefault(); }
  else if (e.key === ",") { $(".nm-earlier").click(); e.preventDefault(); }
  else if (e.key === ".") { $(".nm-later").click(); e.preventDefault(); }
  else if (e.key === "Enter") { e.preventDefault(); $(".nm-save").click(); }   // Enter saves only
  else if (e.key === "Escape") close();
});

// Find a name: the whole name first, then a name it begins, then any; each kind nearest the map's centre first ---------
let qSeq = 0;
$(".nm-q").addEventListener("input", async () => {
  const q = $(".nm-q").value.trim(), seq = ++qSeq, c = map.getCenter();
  if (q.length < 2) { $(".nm-hits").innerHTML = ""; return; }
  const r = await call("search", { q, lon: c.lng, lat: c.lat }).catch(() => null);
  if (seq !== qSeq || !r) return;                            // typed on meanwhile
  $(".nm-hits").innerHTML = "";
  if (r.n > r.hits.length) { const li = document.createElement("li"); li.className = "nm-muted";
    li.textContent = `${r.n} names; the ${r.hits.length} listed are the nearest the map's centre (the whole name first)`; $(".nm-hits").append(li); }
  for (const P of r.hits) {
    const li = document.createElement("li");
    if (P.type === "aid" || P.type === "wreck") {           // an aid or a wreck: found and shown, not edited here
      li.textContent = `${P.name} · ${P.type === "aid" ? "aid (" + P.style + ")" : "wreck"} · ${P.km < 1 ? "here" : (P.km < 10 ? P.km.toFixed(1) : Math.round(P.km)) + " km " + P.dir}`;
      li.addEventListener("click", () => map.jumpTo({ center: [+P.lon, +P.lat], zoom: Math.min(18, Math.max(map.getZoom(), +P.z0 + 0.5)) }));
      $(".nm-hits").append(li); continue;
    }
    li.textContent = `${P.name} · ${P.style === "water" ? "sea" : P.style}${P.src === "lmi" ? " (LMÍ)" : P.src === "isor" ? " (ÍSOR)" : ""} · zoom ${dz(P)}` +
      `${+P.z0 >= NEVER ? ", never drawn" : ", shown from " + shownFrom(P)} · ${P.km < 1 ? "here" : (P.km < 10 ? P.km.toFixed(1) : Math.round(P.km)) + " km " + P.dir}`;
    li.addEventListener("click", () => { const zs = +P.z0 >= NEVER ? Math.ceil(dz(P)) : shownFrom(P);
      map.jumpTo({ center: [+P.lon, +P.lat], zoom: Math.min(18, Math.max(map.getZoom(), zs + 0.5)) }); select(+P.feature); });
    $(".nm-hits").append(li);
  }
});
