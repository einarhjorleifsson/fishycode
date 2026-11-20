// marine_feature_map.js — the names map's editing (marine_feature_map.R puts it into the page by og_script()): plan 074 step
// 12, the named-features study's 132_names_map.js moved here (plan 076 step 6, the smoke test of ogis). Given `og` alone
// (ogis's seam) and MapLibre's own API on og.map; where it reaches past them, `GAP`.
// As 75's page: a click on a name shows where each chart printed it, a marker that drags and turns, Earlier and Later a
// whole zoom, the rule's zoom; Save appends the edit (the route `edit`), Place back reverts. The search finds the aids and
// wrecks too, and only shows them. Internal (Landhelgisgæslan's chart names; not for navigation). Written by Claude (AI),
// 2026-11-18; moved 2026-11-19. Version 2 (plan 080 §5.2): a point kind's name beside its dot, the Rename box (ask e),
// and where the thing is apart from its name: a marker of its own (the ring), Save the point (a row `pin`), Point back;
// and its mound: with a name chosen, a click on ÍSOR's crater offers Link to this mound (a row `link`), Unlink (plan 080 §5.2a).
const map = og.map, NAMES = "names";
const body = og.panel("Find and edit a name");
body.classList.add("nm");
body.innerHTML = `
  <div class="nm-row"><button class="nm-review" title="Claude's proposals, the flagged first (plan 081)">Review the proposals</button><span class="nm-muted nm-review-txt"></span></div>
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
    <div class="nm-row nm-muted nm-mound">Its mound: none. Click one of ÍSOR's craters to link it.</div>
    <div class="nm-row"><button class="nm-link" disabled>Link to this mound</button><button class="nm-unlink">Unlink</button></div>
    <div class="nm-row nm-muted">The ring is where the thing is: drag it, then save the point.</div>
    <div class="nm-row"><button class="nm-savepin" disabled>Save the point</button><button class="nm-unpin" title="the rule's place for the thing">Point back</button></div>
    <div class="nm-row"><input class="nm-newname" type="text" placeholder="a new name" maxlength="80" autocomplete="off"></div>
    <div class="nm-row"><input class="nm-why" type="text" placeholder="why (optional)" maxlength="300" autocomplete="off"><button class="nm-rename" title="the name used from now on; the source's spelling kept">Rename</button>
      <button class="nm-synonym" title="another name of it; the name used unchanged">Add as a synonym</button></div>
    <div class="nm-status"></div>
    <div class="nm-muted">Where the charts printed it:</div>
    <ul class="nm-lets"></ul>
  </section>
  <section class="nm-cand" hidden>
    <p class="nm-name nm-cand-name"></p>
    <div class="nm-muted nm-cand-info"></div>
    <div class="nm-row"><button class="nm-accept nm-primary">Accept</button><button class="nm-reject">Reject</button><button class="nm-cand-close">Close</button></div>
    <div class="nm-status nm-cand-status"></div>
  </section>
  <section class="nm-prop" hidden>
    <p class="nm-muted">Claude's proposal <span class="nm-prop-q"></span></p>
    <p class="nm-name nm-prop-name"></p>
    <div class="nm-muted nm-prop-info"></div>
    <table class="nm-ev"><thead><tr><th>candidate</th><th>witness</th><th>says</th><th></th></tr></thead><tbody></tbody></table>
    <div class="nm-row"><input class="nm-prop-why" type="text" placeholder="why (optional)" maxlength="300" autocomplete="off"></div>
    <div class="nm-row"><button class="nm-prop-accept nm-primary" title="its thing and extent at the next build (a row accept proposal)">Accept</button>
      <button class="nm-prop-reject" title="a row reject proposal">Reject</button><button class="nm-prop-prev">Previous</button><button class="nm-prop-next">Next</button>
      <button class="nm-prop-close">Close</button></div>
    <div class="nm-status nm-prop-status"></div>
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
const own = { lets: EMPTY, links: EMPTY, lmiext: EMPTY, pinned: EMPTY, prop: EMPTY };
function addOwn() {
  if (map.getSource("nm-lets")) return;
  const below = og.layer(NAMES).styles[0];
  for (const k of Object.keys(own)) map.addSource("nm-" + k, { type: "geojson", data: own[k] });
  map.addLayer({ id: "nm-lmiext-fill", type: "fill", source: "nm-lmiext", filter: ["==", ["geometry-type"], "Polygon"], paint: { "fill-color": "#08519c", "fill-opacity": 0.12 } }, below);
  map.addLayer({ id: "nm-lmiext-line", type: "line", source: "nm-lmiext", paint: { "line-color": "#08519c", "line-width": 1.8, "line-opacity": 0.85 } }, below);
  map.addLayer({ id: "nm-links", type: "line", source: "nm-links", paint: { "line-color": "#555", "line-width": 1, "line-dasharray": [2, 2] } }, below);
  map.addLayer({ id: "nm-prop-fill", type: "fill", source: "nm-prop", filter: ["==", ["get", "what"], "extent"], paint: { "fill-color": "#1a9850", "fill-opacity": 0.14 } }, below);
  map.addLayer({ id: "nm-prop-line", type: "line", source: "nm-prop", filter: ["!=", ["get", "what"], "thing"],
    paint: { "line-color": ["match", ["get", "what"], "thalweg", "#542788", "spread", "#f46d43", "#1a9850"], "line-width": ["match", ["get", "what"], "spread", 1.8, 3.2],
      "line-dasharray": ["match", ["get", "what"], "thalweg", ["literal", [2, 1.5]], ["literal", [1, 0]]] } }, below);
  map.addLayer({ id: "nm-prop-thing", type: "circle", source: "nm-prop", filter: ["==", ["get", "what"], "thing"],
    paint: { "circle-radius": 7, "circle-color": "#1a9850", "circle-stroke-color": "#fff", "circle-stroke-width": 2 } });
  map.addLayer({ id: "nm-pinned-dot", type: "circle", source: "nm-pinned", paint: { "circle-radius": 3.5, "circle-color": "#1a1a1a" } });
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
const upOf = P => (P.edited || Math.abs(+P.rot || 0) >= LEVEL || +P.pk === 1) ? 0 : Math.sign(+P.dy || 0) * (1.25 * +P.size + 5) / +P.size;
// a point kind's name to the right of its dot (version 2), until moved by hand
const oxOf = P => (+P.pk === 1 && !P.edited) ? 0.7 : 0;
// GAP: the offset's key on each feature, ogis's own encoding of an offset by a column (og_off, "x|y" to a thousandth)
const offKey = (up, x = 0) => `${x.toFixed(3)}|${up.toFixed(3)}`;
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
    f.geometry.coordinates = [+P.lon, +P.lat]; f.properties.turn = -(+P.rot || 0); f.properties.og_off = offKey(upOf(P), oxOf(P)); f.properties.z0 = +P.z0;
    if (P.name) f.properties.name = P.name;
    f.properties.hand = P.edited || P.zoom_by ? "by hand" : "computed"; }
  og.setData(NAMES, d);
  // the points moved since the server started, laid on the dots as sent
  const moved = ch.filter(P => P.dots_row);
  if (moved.length) {
    const dd = await map.getSource(og.layer("name_dots").source).getData(), byd = new Map(dd.features.map(f => [f.properties.og_row, f]));
    for (const P of moved) { const f = byd.get(+P.dots_row); if (f) f.geometry.coordinates = [+P.thing_lon, +P.thing_lat]; }
    og.setData("name_dots", dd);
  }
}).catch(err => console.warn("names map: the edits since the server started were not laid on", err));

// A name chosen ----------------------------------------------------------------------------------------------------------
let sel = null, marker = null, pinM = null, pinMoved = false, pendingLink = null, lastCraterClick = 0, base = null, dirty = { moved: false, turned: false, zoomed: false }, zpend = null, saving = false;
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
  const pe = document.createElement("div"); pe.className = "nm-pin"; pe.title = "where the thing is";
  pinM = new maplibregl.Marker({ element: pe, draggable: true }).setLngLat([+P.thing_lon, +P.thing_lat]).addTo(map);
  pinMoved = false; $(".nm-savepin").disabled = true;
  pendingLink = null; $(".nm-link").disabled = true;
  $(".nm-mound").textContent = P.seabed ? "Its mound: " + P.seabed + "." : "Its mound: none. Click one of ÍSOR's craters to link it.";
  pinM.on("dragend", () => { pinMoved = true; $(".nm-savepin").disabled = false; $(".nm-status").textContent = "The point moved, not saved."; });
  marker.on("dragend", () => { const p = marker.getLngLat(); dirty.moved = Math.abs(p.lng - base.lng) > 1e-7 || Math.abs(p.lat - base.lat) > 1e-7; showDirty(); });
  $(".nm-name").textContent = P.name;
  $(".nm-newname").value = ""; $(".nm-why").value = "";
  $(".nm-info").innerHTML = [P.src === "lmi" ? "LMÍ's name (IS 50V)" : "", P.src === "isor" ? "ÍSOR's name (the seabed map)" : "",
    P.name_source && P.name_source !== P.name ? "the source spells it " + P.name_source : "", P.name_basis ? "name: " + P.name_basis : "",
    P.synonyms ? "also called " + P.synonyms : "",
    P.thing ? "the thing at " + P.thing + (+P.pk === 1 ? ", a dot" : "") : "",
    P.lmi ? "LMÍ: " + P.lmi : "", P.isor ? "ÍSOR: " + P.isor : "",
    P.lmi_source ? (P.src === "isor" ? "ÍSOR's source: " : "LMÍ's source (heimild): ") + P.lmi_source + (P.lmi_source_kind ? " [" + P.lmi_source_kind + "]" : "") : "",
    P.report ? "ÍSOR's report of 2008 for Orkustofnun: " + P.report + (P.coined === "yes" ? ", a name coined there" : P.coined === "no" ? ", a name it took as it found it" : "") +
      (P.name_en ? "; English: " + P.name_en : "") + (P.report_entry ? ". " + P.report_entry : "") : "",
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
  showProposal({ name_id: +P.feature }, false).catch(() => {});
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
  marker?.remove(); marker = null; pinM?.remove(); pinM = null; sel = null; base = null;
  setOwn("lets", EMPTY); setOwn("links", EMPTY); setOwn("lmiext", EMPTY);
  og.filter(NAMES, "sel", null);
  $(".nm-sel").hidden = true;
}
let lastNameClick = 0;
og.on("click", NAMES, async ({ row }) => {
  lastNameClick = Date.now();
  const r = await row(); if (!r) return;                    // clicked again meanwhile
  const id = r.find(c => c.name === "feature")?.value;
  if (id != null) select(+id).catch(err => { $(".nm-status").textContent = "Not shown: " + err.message; });
});
// A click on ÍSOR's crater: with a name chosen, offer to link the name to it
const onMound = async ({ row }) => {
  lastCraterClick = Date.now();
  if (!sel) return;
  const r = await row(); if (!r || !sel) return;
  const get = k => r.find(c => c.name === k)?.value;
  pendingLink = { id: get("seabed_id"), label: get("label"), kind: get("kind") };
  $(".nm-link").disabled = false; $(".nm-link").textContent = `Link to ${pendingLink.label}`;
  $(".nm-status").textContent = `Link ${sel.P.name} to ÍSOR's ${pendingLink.kind} ${pendingLink.label}? Its thing moves there.`;
};
for (const L of ["isor_craters", "isor_guyots"]) og.on("click", L, onMound);
// A click on Trackwell's candidate: Accept makes it a name at the next build, Reject keeps it out (rows `accept`, `reject`)
let cand = null;
og.on("click", "tw_candidates", async ({ row }) => {
  lastCraterClick = Date.now();
  const r = await row(); if (!r) return;
  const get = k => r.find(c => c.name === k)?.value;
  cand = { key: get("key"), name: get("name") };
  $(".nm-cand").hidden = false; $(".nm-cand-name").textContent = cand.name;
  $(".nm-cand-info").innerHTML = [`Trackwell's name: ${get("tows")} tows by ${get("vessels")} vessels here (${Math.round(100 * get("share"))} % of all its tows)`,
    get("spellings") ? "spelled " + get("spellings") : "", get("place_basis"), get("verdict") ? "verdict: " + get("verdict") : ""].filter(Boolean).map(esc).join("<br>");
  $(".nm-cand-status").textContent = "";
});
async function verdict(action) {
  if (!cand) return;
  try { const j = await post({ action, link_to: cand.key, name: cand.name });
    $(".nm-cand-status").textContent = `${j.verdict} ${j.at}` + (action === "accept" ? "; a name at the next build." : ".");
  } catch (err) { $(".nm-cand-status").textContent = "Not saved: " + err.message; }
}
$(".nm-accept").addEventListener("click", () => verdict("accept"));
$(".nm-reject").addEventListener("click", () => verdict("reject"));
$(".nm-cand-close").addEventListener("click", () => { cand = null; $(".nm-cand").hidden = true; });

// A click on an area chooses its name, unless the click was on a name or a crater
for (const L of ["isor_areas", "lmi_areas"]) og.on("click", L, async ({ row }) => {
  await new Promise(r => setTimeout(r, 150)); if (Date.now() - lastNameClick < 500 || Date.now() - lastCraterClick < 500) return;
  const r = await row(); if (!r) return;
  const id = r.find(c => c.name === "feature")?.value;
  if (id != null) select(+id).catch(err => { $(".nm-status").textContent = "Not shown: " + err.message; });
});
map.on("zoom", () => { if (marker && sel) marker.getElement().style.fontSize = labelPx(sel.P) + "px"; });

// Claude's proposals (plan 081): a proposal with its evidence, each witness on each candidate trough; Accept and Reject are
// rows `accept proposal` and `reject proposal` (the proposal's key in `link_to`); the queue walks them, the flagged first
let prop = null, queue = null;
const OUTCOL = o => /^agrees/.test(o) ? "#1a9850" : /^disagrees/.test(o) ? "#d73027" : "#7a7a7a";
async function showProposal(args, fly = true) {
  const r = await call("proposal", args);
  if (!r || !r.p) { if (!fly) { prop = null; $(".nm-prop").hidden = true; setOwn("prop", EMPTY); } return; }
  const p = r.p; prop = p;
  $(".nm-prop").hidden = false; $(".nm-prop-name").textContent = p.name;
  $(".nm-prop-q").textContent = r.q ? `(${r.q} of ${r.n} in the queue)` : "";
  const where = p.class === "bank" ? (p.kind === "bank" ? `its outline the east's piece ${p.piece}` + (p.shared_with ? ` (shared with ${p.shared_with})` : "") : p.whole ? `a part of ${p.whole}` : "no whole found")
    : p.class === "moraine" ? (p.moraine === "none" ? "no ÍSOR moraine proposed" : `on ÍSOR's moraine ${p.moraine}`)
    : p.trough === "none" ? "no ÍSOR trough proposed" : `on ÍSOR's trough ${p.trough}` + (p.part ? `, its part ${p.part}` : "");
  const what = p.class === "bank" ? (p.kind === "bank" ? "a bank" : `a ${p.kind} (a part of a bank)`) : p.class === "moraine" ? "a " + p.kind + " name" : "a deep";
  $(".nm-prop-info").innerHTML = [`${what} (step ${p.step})`, where,
    p.place_basis, p.extent_basis ? "its extent: " + p.extent_basis : "",
    `witnesses agreeing: ${p.n_agree ? p.n_agree + " (" + p.agree + ")" : "none"}` + (p.against ? `; against: ${p.against}` : ""),
    p.flags ? "to look at: " + p.flags : "", p.forms ? "forms: " + p.forms : "", p.verdict ? "verdict: " + p.verdict : "", p.key]
    .filter(Boolean).map(esc).join("<br>");
  const tb = $(".nm-ev tbody"); tb.innerHTML = "";
  // a candidate is a trough, or a part of a shared trough (by its shape, decision 338); in step 2 a moraine
  const cand = e => e.candidate ? e.candidate : e.moraine ? (e.moraine === "none" ? "none" : "moraine " + e.moraine) : e.trough + (e.part ? " · " + e.part : ""), mine = cand(p);
  const ev = (r.ev || []).slice().sort((a, b) => (cand(a) === mine ? 0 : 1) - (cand(b) === mine ? 0 : 1) || cand(a).localeCompare(cand(b)));
  for (const e of ev) {
    const tr = document.createElement("tr"); if (cand(e) === mine) tr.className = "nm-ev-chosen";
    tr.innerHTML = `<td>${esc(cand(e))}</td><td>${esc(e.group)}<div class="nm-muted">${esc(e.member)}</div></td>` +
      `<td style="color:${OUTCOL(e.outcome)}">${esc(e.outcome)}</td><td class="nm-muted">${esc([e.value, e.detail].filter(Boolean).join(" · "))}</td>`;
    tb.append(tr);
  }
  $(".nm-prop-status").textContent = ""; $(".nm-prop-why").value = "";
  const g0 = await call("proposal_shape", { key: p.key }), g = typeof g0 === "string" ? JSON.parse(g0) : g0;   // as the route `extent` is read
  g.features = (g.features || []).concat([{ type: "Feature", properties: { what: "thing" }, geometry: { type: "Point", coordinates: [+p.lon, +p.lat] } }]);
  setOwn("prop", g);
  if (fly) map.easeTo({ center: [+p.lon, +p.lat], zoom: Math.max(map.getZoom(), 7.5) });
}
async function step(d) {
  queue ??= await call("proposal_queue");
  if (!queue.length) return;
  const i = prop ? queue.findIndex(q => q.key === prop.key) : -1;
  const j = i < 0 ? 0 : (i + d + queue.length) % queue.length;
  await showProposal({ key: queue[j].key });
}
$(".nm-review").addEventListener("click", () => step(1).catch(err => { $(".nm-review-txt").textContent = "No proposals: " + err.message; }));
$(".nm-prop-next").addEventListener("click", () => step(1));
$(".nm-prop-prev").addEventListener("click", () => step(-1));
$(".nm-prop-close").addEventListener("click", () => { prop = null; $(".nm-prop").hidden = true; setOwn("prop", EMPTY); });
async function propVerdict(action) {
  if (!prop) return;
  try { const j = await post({ action, link_to: prop.key, name: prop.name, why: $(".nm-prop-why").value.trim() });
    prop.verdict = j.verdict; if (queue) { const q = queue.find(x => x.key === prop.key); if (q) q.status = action === "accept proposal" ? "accepted" : "rejected"; }
    $(".nm-prop-status").textContent = j.verdict + (action === "accept proposal" ? "; its thing and extent at the next build." : ".");
  } catch (err) { $(".nm-prop-status").textContent = "Not saved: " + err.message; }
}
$(".nm-prop-accept").addEventListener("click", () => propVerdict("accept proposal"));
$(".nm-prop-reject").addEventListener("click", () => propVerdict("reject proposal"));
for (const L of ["proposals", "prop_extents", "prop_moraines"]) og.on("click", L, async ({ row }) => {
  lastCraterClick = Date.now();
  const r = await row(); if (!r) return;
  const key = r.find(c => c.name === "key")?.value;
  if (key) showProposal({ key }, false).catch(err => { $(".nm-prop-status").textContent = "Not shown: " + err.message; });
});

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
    await changeFeature(row, f => { f.geometry.coordinates = [+P.comp_lon, +P.comp_lat]; f.properties.turn = -(+P.comp_rot || 0); f.properties.og_off = offKey(upOf(back), oxOf(back));
      if (!P.zoom_by) f.properties.hand = "computed"; });
    await select(+P.feature);
    $(".nm-status").textContent = "Back at the computed place and angle (its zoom as it was).";
  } catch (err) { $(".nm-status").textContent = "Not reverted: " + err.message; }
});
// Where the thing is: a row `pin` (or `unpin`), the dot moved with it; a point kind's name follows unless moved by hand --------
async function dotsTo(j, P) {
  const lngLat = [+j.lon, +j.lat];
  if (j.dots_row) {
    const d = await map.getSource(og.layer("name_dots").source).getData(), f = d.features.find(x => x.properties.og_row === +j.dots_row);
    if (f) { f.geometry.coordinates = lngLat; og.setData("name_dots", d); }
  } else {                                                  // pinned now, a dot of its own until the page starts again
    const feats = own.pinned.features.filter(x => x.properties.feature !== +P.feature);
    if (j.pinned !== false) feats.push({ type: "Feature", properties: { feature: +P.feature }, geometry: { type: "Point", coordinates: lngLat } });
    setOwn("pinned", { type: "FeatureCollection", features: feats });
  }
  if (j.follow) { P.lon = j.lon; P.lat = j.lat; marker?.setLngLat(drawnAt(P, lngLat));
    await changeFeature(sel.row, f => { f.geometry.coordinates = lngLat; }); }
}
$(".nm-savepin").addEventListener("click", async () => {
  if (!sel || !pinM || !pinMoved) return;
  const P = sel.P, p = pinM.getLngLat();
  try {
    const j = await post({ feature: +P.feature, name: P.name, action: "pin", lon: p.lng, lat: p.lat });
    P.thing_lon = j.lon; P.thing_lat = j.lat; P.pinned = j.at; pinMoved = false; $(".nm-savepin").disabled = true;
    await dotsTo(j, P);
    $(".nm-status").textContent = "The point saved " + j.at + (j.follow ? "; its name follows it." : "; its name stays where it is.");
  } catch (err) { $(".nm-status").textContent = "The point not saved: " + err.message; }
});
$(".nm-unpin").addEventListener("click", async () => {
  if (!sel) return;
  const P = sel.P;
  try {
    const j = await post({ feature: +P.feature, name: P.name, action: "unpin" });
    P.thing_lon = j.lon; P.thing_lat = j.lat; P.pinned = ""; pinM?.setLngLat([+j.lon, +j.lat]); pinMoved = false; $(".nm-savepin").disabled = true;
    await dotsTo({ ...j, pinned: +P.pk === 1 ? undefined : false }, P);
    $(".nm-status").textContent = "The point back at the rule's place.";
  } catch (err) { $(".nm-status").textContent = "Not put back: " + err.message; }
});

// Link to this mound, and Unlink: rows `link` and `unlink`; the thing moves to the crater ------------------------------------
$(".nm-link").addEventListener("click", async () => {
  if (!sel || !pendingLink) return;
  const P = sel.P, L = pendingLink;
  try {
    const j = await post({ feature: +P.feature, name: P.name, action: "link", link_to: L.id });
    P.thing_lon = j.lon; P.thing_lat = j.lat; P.seabed = j.seabed; pinM?.setLngLat([+j.lon, +j.lat]);
    await dotsTo({ ...j, pinned: +P.pk === 1 ? undefined : false }, P);
    pendingLink = null; $(".nm-link").disabled = true; $(".nm-link").textContent = "Link to this mound";
    $(".nm-mound").textContent = "Its mound: " + j.seabed + ".";
    $(".nm-status").textContent = "Linked " + j.at + "; the thing at the crater" + (j.follow ? ", its name beside it." : ".");
  } catch (err) { $(".nm-status").textContent = "Not linked: " + err.message; }
});
$(".nm-unlink").addEventListener("click", async () => {
  if (!sel) return;
  const P = sel.P;
  try {
    const j = await post({ feature: +P.feature, name: P.name, action: "unlink" });
    P.seabed = j.seabed; $(".nm-mound").textContent = "Its mound: none (" + j.seabed + ").";
    $(".nm-status").textContent = "Unlinked " + j.at + ".";
  } catch (err) { $(".nm-status").textContent = "Not unlinked: " + err.message; }
});

// Rename: the name used from now on, a row of the ledger; the source's spelling is kept by the build ------------------------
$(".nm-rename").addEventListener("click", async () => {
  if (!sel) return;
  const P = sel.P, mine = sel, to = $(".nm-newname").value.trim(), why = $(".nm-why").value.trim();
  if (!to || to === P.name) { $(".nm-status").textContent = "Type a new name first."; return; }
  try {
    const j = await post({ feature: +P.feature, name: P.name, action: "rename", new_name: to, why });
    P.name = j.name;
    await changeFeature(mine.row, f => { f.properties.name = j.name; f.properties.hand = "by hand"; });
    if (sel === mine) { $(".nm-name").textContent = j.name; marker.getElement().textContent = j.name; $(".nm-newname").value = "";
      $(".nm-status").textContent = "Renamed " + j.at + "; the build keeps the source's spelling beside it."; }
  } catch (err) { $(".nm-status").textContent = "Not renamed: " + err.message; }
});

// Add as a synonym: another name of the feature, a row of the ledger; the name used unchanged ------------------------------
$(".nm-synonym").addEventListener("click", async () => {
  if (!sel) return;
  const P = sel.P, to = $(".nm-newname").value.trim(), why = $(".nm-why").value.trim();
  if (!to || to === P.name) { $(".nm-status").textContent = "Type the other name first."; return; }
  try {
    const j = await post({ feature: +P.feature, name: P.name, action: "synonym", new_name: to, why });
    P.synonyms = j.synonyms; $(".nm-newname").value = "";
    $(".nm-status").textContent = "Added as a synonym " + j.at + ": also called " + j.synonyms + ".";
  } catch (err) { $(".nm-status").textContent = "Not added: " + err.message; }
});

document.addEventListener("keydown", e => {
  if (e.target.tagName === "INPUT" && (e.target.type === "search" || e.target.type === "text")) {
    if (e.key === "Enter" && (e.target.classList.contains("nm-newname") || e.target.classList.contains("nm-why"))) { e.preventDefault(); $(".nm-rename").click(); }
    return;
  }
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
