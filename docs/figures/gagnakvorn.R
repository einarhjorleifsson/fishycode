# Gagnakvörn, the fishydata edition: Hammer's 1996 data grinder, adapted for fishydata with his permission
# (maintainer, 2026-10-23). His labels are replaced in place by fishydata's, in a hand like his; the inflow
# arrow becomes a small-scale boat (the stakeholder) with the register, logbooks, landings and AIS thrown in
# after it; the sign is redrawn larger. The new marks are given the scan's resolution, ink tone and speckle.
#
# Input:  $FISHYDATA/raw/image/gagnakvorn.png (the scan, 715 x 493)
# Output: $FISHYDATA/exports/gagnakvorn/gagnakvorn.png (3x the scan, with a strip on top and a credit line below)
#
# Run from the repository root:  Rscript docs/figures/gagnakvorn.R
#
# AI use: the labels, the boat, the sacks, the sign and this script were drafted by Claude (Anthropic) with the
# maintainer, 2026-10-23, who chose every label. The drawing is Hammer's. The versions on the way are in
# $FISHYDATA/exports/gagnakvorn/versions/, v01 (labels struck through, new ones in the margins) to v09 (this
# script's output). Images live under $FISHYDATA, never in this repo.
#
# Coordinates are the scan's pixels (x = column, y = row, from the top left); the strip on top has y < 0.

source("R/paths.R")
invisible(Sys.setlocale("LC_CTYPE", "en_US.UTF-8"))
src <- fd_raw("image", "gagnakvorn.png")
out <- fd_path("exports", "gagnakvorn", "gagnakvorn.png")
dir.create(dirname(out), recursive = TRUE, showWarnings = FALSE)
s <- 3                                       # output pixels per scan pixel
set.seed(1996)
ink <- "#3b3b3b"                             # the scan's strokes are grey, not black

# Upscale ----------------------------------------------------------------------
orig <- magick::image_read(src)
w0 <- magick::image_info(orig)$width; h0 <- magick::image_info(orig)$height
tmp <- tempfile(fileext = ".png")
magick::image_write(magick::image_resize(orig, sprintf("%dx%d!", w0 * s, h0 * s), filter = "Mitchell"), tmp)
im <- png::readPNG(tmp)[, , 1:3]
H <- dim(im)[1]
paper <- c(253, 253, 253) / 255

# Erase ------------------------------------------------------------------------
in_poly <- function(px, py, x, y) {
  inside <- logical(length(px)); j <- length(x)
  for (i in seq_along(x)) {
    hit <- ((y[i] > py) != (y[j] > py)) & (px < (x[j] - x[i]) * (py - y[i]) / (y[j] - y[i]) + x[i])
    inside <- xor(inside, hit); j <- i
  }
  inside
}
box <- function(m, r) {                      # sum over a (2r + 1)^2 window
  n <- nrow(m); p <- ncol(m)
  cs <- rbind(0, apply(m, 2, cumsum))
  v <- cs[pmin(n, 1:n + r) + 1, , drop = FALSE] - cs[pmax(1, 1:n - r), , drop = FALSE]
  cs <- cbind(0, t(apply(v, 1, cumsum)))
  cs[, pmin(p, 1:p + r) + 1, drop = FALSE] - cs[, pmax(1, 1:p - r), drop = FALSE]
}
# The erased pixels take the paper and shading around them: each copies a random nearby pixel
# that is not erased, hatching included so the tone matches, and the copies are softened
fill <- function(im, rows, cols, kill, r = 6 * s, floor = 0) {
  if (!any(kill)) return(im)
  reg <- im[rows, cols, , drop = FALSE]
  lum <- (reg[, , 1] + reg[, , 2] + reg[, , 3]) / 3
  cand <- !kill & lum >= floor               # floor > 0 keeps a dark neighbour out of a light patch
  n <- nrow(kill); p <- ncol(kill)
  at <- which(kill, arr.ind = TRUE); src <- matrix(NA_integer_, nrow(at), 2)
  for (k in 1:40) {
    todo <- which(is.na(src[, 1])); if (!length(todo)) break
    ii <- at[todo, 1] + sample(-r:r, length(todo), TRUE)
    jj <- at[todo, 2] + sample(-r:r, length(todo), TRUE)
    ok <- ii >= 1 & ii <= n & jj >= 1 & jj <= p
    ok[ok] <- cand[cbind(ii[ok], jj[ok])]
    src[todo[ok], ] <- cbind(ii[ok], jj[ok])
  }
  for (ch in 1:3) {
    v <- reg[, , ch]
    v[at] <- ifelse(is.na(src[, 1]), paper[ch], v[src])
    soft <- box(v, 1) / box(matrix(1, n, p), 1)
    v[at] <- soft[at]
    reg[, , ch] <- v
  }
  im[rows, cols, ] <- reg
  im
}

# A stroke goes only if it lies mostly inside the label and ends near it: a line that runs on
# past the label (an outline, a shaft, hatching) is part of the drawing and stays
erase <- function(im, x, y, thr = 0.6, grow = 5, margin = 6, floor = 0) {
  if (length(x) == 2) { x <- x[c(1, 2, 2, 1)]; y <- y[c(1, 1, 2, 2)] }   # a box
  x <- (x - 1) * s + 1; y <- (y - 1) * s + 1
  cols <- max(1, floor(min(x)) - margin * s):min(dim(im)[2], ceiling(max(x)) + margin * s)
  rows <- max(1, floor(min(y)) - margin * s):min(H, ceiling(max(y)) + margin * s)
  g <- expand.grid(r = rows, c = cols)
  inside <- matrix(in_poly(g$c + 0.5, g$r + 0.5, x, y), length(rows))
  lum <- (im[rows, cols, 1] + im[rows, cols, 2] + im[rows, cols, 3]) / 3
  dark <- lum < thr
  lab <- matrix(terra::values(terra::patches(terra::rast(ifelse(dark, 1, NA)), directions = 8)),
                nrow(dark), byrow = TRUE)
  edge <- unique(c(lab[1, ], lab[nrow(lab), ], lab[, 1], lab[, ncol(lab)]))
  n_all <- table(lab); n_in <- table(lab[inside])
  frac <- setNames(rep(0, length(n_all)), names(n_all)); frac[names(n_in)] <- n_in / n_all[names(n_in)]
  gone <- setdiff(as.numeric(names(frac)[frac >= 0.5]), edge)
  kill <- matrix(lab %in% gone, nrow(lab))
  for (k in seq_len(grow)) {                 # take in the strokes' soft edges, never a kept stroke
    d <- kill
    d[-1, ] <- d[-1, ] | kill[-nrow(kill), ]; d[-nrow(d), ] <- d[-nrow(d), ] | kill[-1, ]
    d[, -1] <- d[, -1] | kill[, -ncol(kill)]; d[, -ncol(d)] <- d[, -ncol(d)] | kill[, -1]
    kill <- kill | (d & !dark)
  }
  fill(im, rows, cols, kill, floor = floor)
}

# Hammer's labels, word by word; a third value is the refill's floor (light paper only)
E <- list(
  inflow    = list(c(105, 220), c(19, 38), 0.85),
  entrance  = list(c(45, 123), c(46, 61)),
  grid      = list(c(85, 122), c(61, 76)),
  data_d    = list(c(24, 63), c(97, 114)),
  discard   = list(c(15, 74), c(116, 136)),
  data_c    = list(c(130, 168), c(132, 149)),
  chopper   = list(c(134, 198), c(148, 165)),
  data_g    = list(c(71, 108), c(199, 216)),
  grinder   = list(c(80, 141), c(212, 228)),
  data_f    = list(c(73, 111), c(258, 274)),
  flattener = list(c(74, 141), c(273, 289)),
  non       = list(c(44, 82), c(360, 380)),
  herring   = list(c(35, 102), c(381, 407)),
  or        = list(c(56, 80), c(410, 428)),
  acoustic1 = list(c(35, 102), c(424, 446)),
  data_m    = list(c(139, 182), c(406, 423)),
  mixer     = list(c(132, 191), c(423, 441)),
  big       = list(c(228, 257), c(282, 299)),
  blow      = list(c(228, 269), c(299, 313)),
  up        = list(c(236, 263), c(312, 327)),
  fresh     = list(c(319, 360), c(436, 456)),
  air       = list(c(323, 354), c(455, 477)),
  polish    = list(c(326, 462), c(47, 64)),
  high      = list(c(433, 470), c(133, 152)),
  freq      = list(c(470, 562), c(133, 157)),
  vib       = list(c(471, 490, 585, 585, 471), c(152, 152, 152, 172, 170)),
  mik       = list(c(357, 383), c(199, 217), 0.8),
  lpe       = list(c(387, 422), c(221, 241), 0.8),
  ibts      = list(c(436, 471), c(229, 246), 0.8),
  q1        = list(c(441, 463), c(245, 259), 0.8),
  mlai      = list(c(477, 513), c(249, 263), 0.8),
  sealed    = list(c(357, 372, 421, 421, 398, 357), c(270, 268, 284, 297, 297, 281)),
  can       = list(c(639, 639, 645, 652, 660, 665, 665, 658, 651, 648),
                   c(284, 272, 265, 260, 257.5, 257.5, 266, 272, 278, 285), 0.75),
  acoustic  = list(c(451, 562, 562, 542, 542, 494, 494, 451), c(398, 398, 419, 419, 417, 417, 419, 419)),
  ring      = list(c(533, 542), c(386, 398)),
  john      = list(c(499, 531), c(440, 452))
)
for (e in E) im <- erase(im, e[[1]], e[[2]], floor = if (length(e) > 2) e[[3]] else 0)

# Letters that touch a line survive the stroke test; these boxes take what is left of them,
# drawn to stop short of the lines
erase_box <- function(im, x, y, thr = 0.5, grow = 4, margin = 6, floor = 0) {
  if (length(x) == 2) { x <- x[c(1, 2, 2, 1)]; y <- y[c(1, 1, 2, 2)] }
  x <- (x - 1) * s + 1; y <- (y - 1) * s + 1
  cols <- max(1, floor(min(x)) - margin * s):min(dim(im)[2], ceiling(max(x)) + margin * s)
  rows <- max(1, floor(min(y)) - margin * s):min(H, ceiling(max(y)) + margin * s)
  g <- expand.grid(r = rows, c = cols)
  inside <- matrix(in_poly(g$c + 0.5, g$r + 0.5, x, y), length(rows))
  lum <- (im[rows, cols, 1] + im[rows, cols, 2] + im[rows, cols, 3]) / 3
  dark <- lum < thr; kill <- dark & inside
  for (k in seq_len(grow)) {
    d <- kill
    d[-1, ] <- d[-1, ] | kill[-nrow(kill), ]; d[-nrow(d), ] <- d[-nrow(d), ] | kill[-1, ]
    d[, -1] <- d[, -1] | kill[, -ncol(kill)]; d[, -ncol(d)] <- d[, -ncol(d)] | kill[, -1]
    kill <- kill | (d & !dark & inside)
  }
  fill(im, rows, cols, kill, floor = floor)
}
B <- list(
  inflow    = list(c(104, 222), c(19, 38), 0.85),
  grinder   = list(c(71, 139), c(199, 228)),
  flattener = list(c(73, 139), c(258, 289)),
  barrel    = list(c(39, 99), c(380, 446)),
  mixer     = list(c(133, 188), c(423, 441)),
  air       = list(c(321, 358), c(436, 477)),
  air_f     = list(c(314, 324), c(436, 456)),
  lpe       = list(c(388, 421), c(222, 240), 0.8),
  ibts      = list(c(438, 469), c(229, 259), 0.8),
  mlai      = list(c(479, 512), c(249, 263), 0.8),
  acoustic  = list(c(492, 562, 562, 542, 542, 494, 494, 492), c(398, 398, 419, 419, 417, 417, 419, 419))
)
for (e in B) im <- erase_box(im, e[[1]], e[[2]], floor = if (length(e) > 2) e[[3]] else 0)

# The sign is too small for its new words: all of it goes, and a larger one is drawn below
im <- erase_box(im, c(562, 638, 638, 562), c(254, 211, 265, 310), thr = 0.8, grow = 3)

# The inflow arrow goes: the stakeholder's boat and the records go in instead
im <- erase_box(im, c(136, 222, 222, 186, 169, 136), c(0, 0, 44, 73, 73, 44), thr = 0.8, grow = 3, floor = 0.85)

# A strip of paper on top, for what is thrown in and for the title: the scan's own top rows,
# mirrored so the grain runs on across the join, with their ink taken out
T <- 72
strip <- im[(T * s):1, , , drop = FALSE]
lum <- (strip[, , 1] + strip[, , 2] + strip[, , 3]) / 3
ink_px <- lum < 0.9 | strip[, , 1] - strip[, , 3] > 0.012      # ink, and the coffee stain
ink_px <- box(ink_px * 1, 3) > 0                                  # with its soft edge
w <- (!ink_px) * 1; nw <- box(w, 15)
for (k in 1:3) {
  v <- strip[, , k]
  v[ink_px] <- ifelse(nw[ink_px] > 0, (box(v * w, 15) / pmax(nw, 1e-9))[ink_px], paper[k])
  strip[, , k] <- v
}
im <- array(c(rbind(strip[, , 1], im[, , 1]), rbind(strip[, , 2], im[, , 2]), rbind(strip[, , 3], im[, , 3])),
            c(T * s + H, dim(im)[2], 3))
png::writePNG(im, tmp)
base <- magick::image_read(tmp)

# Pen --------------------------------------------------------------------------
# Letters one at a time, each a little off its line, size and angle, as a pen does
fam <- "Noteworthy"
hand <- function(lab, x, y, h, w = Inf, srt = 0, adj = 0.5, seed = 1, font = 2, col = ink) {
  set.seed(seed)
  par(family = fam, font = font)
  ch <- strsplit(lab, "")[[1]]
  cex <- h / abs(strheight("H", cex = 1))
  track <- 0.06 * h
  wid <- function(cex, track) sum(strwidth(ch, cex = cex)) + track * (length(ch) - 1)
  if (wid(cex, track) > w) { k <- w / wid(cex, track); cex <- cex * k; track <- track * k }
  tot <- wid(cex, track)
  th <- srt * pi / 180
  ux <- cos(th); uy <- -sin(th)                       # along the line (y grows downwards)
  vx <- sin(th); vy <- cos(th)                        # across the line
  d <- -adj * tot
  for (i in seq_along(ch)) {
    j <- rnorm(3, 0, c(0.05 * h, 0.035, 2.2))         # offset across the line, size, angle
    px <- x + d * ux + j[1] * vx; py <- y + d * uy + j[1] * vy
    if (ch[i] != " ") text(px, py, ch[i], adj = c(0, 0.5), srt = srt + j[3], cex = cex * (1 + j[2]), col = col)
    d <- d + strwidth(ch[i], cex = cex) + track
  }
}
pen <- function(x, y, lwd = 1.5) lines(x, y, col = ink, lwd = lwd * s / 2)
# A line as a hand draws it: a little off straight
sketch <- function(x, y, lwd = 1.5, wob = 0.35, seed = 1) {
  set.seed(seed)
  n <- 12 * (length(x) - 1); u <- seq(0, length(x) - 1, length.out = n)
  xs <- approx(seq_along(x) - 1, x, u)$y; ys <- approx(seq_along(y) - 1, y, u)$y
  e <- as.numeric(stats::filter(rnorm(n, 0, wob), rep(1 / 3, 3), circular = TRUE))
  pen(xs + e, ys + rev(e), lwd = lwd)
}
paper_col <- "#fcfcfc"
bez <- function(p0, p1, p2, n = 30) {                   # a quadratic curve as points
  u <- seq(0, 1, length.out = n)
  cbind((1 - u)^2 * p0[1] + 2 * u * (1 - u) * p1[1] + u^2 * p2[1],
        (1 - u)^2 * p0[2] + 2 * u * (1 - u) * p1[2] + u^2 * p2[2])
}
circ <- function(x, y, rx, ry = rx, a0 = 0, a1 = 2 * pi, n = 24) {
  a <- seq(a0, a1, length.out = n); cbind(x + rx * cos(a), y + ry * sin(a))
}
blank <- function(p) polygon(p[, 1], p[, 2], col = paper_col, border = NA)
outline <- function(p, close = TRUE, ...) {
  if (close) p <- rbind(p, p[1, ])
  sketch(p[, 1], p[, 2], ...)
}
# Pen hatching clipped to a shape, as Hammer shades
hatch <- function(p, angle = 60, gap = 2, lwd = 0.6, seed = 1) {
  poly <- sf::st_polygon(list(rbind(p, p[1, ])))
  cx <- mean(range(p[, 1])); cy <- mean(range(p[, 2])); L <- diff(range(p[, 1])) + diff(range(p[, 2]))
  th <- angle * pi / 180; d <- c(cos(th), -sin(th)); nrm <- c(sin(th), cos(th))
  k <- 0
  for (o in seq(-L, L, by = gap)) {
    a <- c(cx, cy) + o * nrm - L * d; b <- c(cx, cy) + o * nrm + L * d
    seg <- sf::st_intersection(sf::st_linestring(rbind(a, b)), poly)
    if (sf::st_is_empty(seg)) next
    for (g in if (inherits(seg, "MULTILINESTRING")) unclass(seg) else list(unclass(seg))) {
      k <- k + 1; sketch(g[, 1], g[, 2], lwd = lwd, wob = 0.12, seed = seed * 100 + k)
    }
  }
}
rot <- function(u, v, cx, cy, a) {                      # a in degrees, anticlockwise on the page
  th <- a * pi / 180; cbind(cx + u * cos(th) + v * sin(th), cy - u * sin(th) + v * cos(th))
}
edge <- function(x0, y0, x1, y1, over = 1.5, ...) {     # pen strokes run past the corners
  d <- sqrt((x1 - x0)^2 + (y1 - y0)^2); ux <- (x1 - x0) / d; uy <- (y1 - y0) / d
  sketch(c(x0 - over * ux, x1 + over * ux), c(y0 - over * uy, y1 + over * uy), ...)
}

sack <- function(cx, cy, w, h, a, label, go, seed, pings = FALSE) {
  u <- c(-0.11, -0.36, -0.50, -0.34, 0.34, 0.50, 0.36, 0.11) * w
  v <- c(-0.36, -0.12, 0.18, 0.47, 0.47, 0.18, -0.12, -0.36) * h
  sp <- xspline(u, v, shape = -0.6, open = FALSE, draw = FALSE)
  body <- rot(sp$x, sp$y, cx, cy, a)
  go <- go / sqrt(sum(go^2)); side <- c(-go[2], go[1])  # streaks behind it, the way it came
  for (i in -1:1) {
    st <- c(cx, cy) - go * (0.45 * w + 3) + side * i * 0.22 * h
    sketch(c(st[1], st[1] - go[1] * (10 + 4 * abs(i - 1))), c(st[2], st[2] - go[2] * (10 + 4 * abs(i - 1))),
           lwd = 0.9, seed = seed + 10 + i)
  }
  blank(body)
  outline(body, lwd = 1.3, wob = 0.3, seed = seed)
  # the shaded side, the tie and the ears
  sh <- rot(c(0.22, 0.44, 0.50, 0.34, 0.20) * w, c(-0.12, 0.05, 0.20, 0.46, 0.44) * h, cx, cy, a)
  hatch(rbind(sh, rot(0.18 * w, 0.0, cx, cy, a)), angle = a + 70, gap = 1.6, lwd = 0.55, seed = seed + 1)
  outline(rot(c(-0.12, 0.12, 0.12, -0.12) * w, c(-0.43, -0.43, -0.36, -0.36) * h, cx, cy, a), lwd = 1.1, seed = seed + 2)
  outline(rot(c(-0.10, -0.24, -0.02) * w, c(-0.43, -0.58, -0.45) * h, cx, cy, a), lwd = 1, seed = seed + 3)
  outline(rot(c(0.02, 0.22, 0.10) * w, c(-0.45, -0.60, -0.43) * h, cx, cy, a), lwd = 1, seed = seed + 4)
  for (i in c(-1, 1)) {                                  # creases from the neck
    cr <- rot(c(0.06 * i, 0.12 * i) * w, c(-0.32, -0.16) * h, cx, cy, a)
    sketch(cr[, 1], cr[, 2], lwd = 0.7, seed = seed + 5 + i)
  }
  lab <- rot(0, 0.14 * h, cx, cy, a)
  hand(label, lab[1], lab[2], 0.2 * h, w = 0.8 * w, srt = a, seed = seed + 6)
  if (pings) for (r in c(0.62, 0.76, 0.90) * w) {        # AIS pings
    arc <- circ(cx, cy, r, r, -0.45, 0.45, 12)
    arc <- rot(arc[, 1] - cx, arc[, 2] - cy, cx, cy, a)
    sketch(arc[, 1], arc[, 2], lwd = 0.9, seed = seed + round(r))
  }
}

fisher <- function(x, yf, h = 24, seed = 1) {
  r <- 0.085 * h; hy <- yf - 0.80 * h
  # the waving arm first, so the coat sits over its shoulder
  arm <- rbind(c(x + 0.10 * h, yf - 0.60 * h), c(x + 0.26 * h, yf - 0.76 * h), c(x + 0.24 * h, yf - 1.00 * h))
  sketch(arm[, 1], arm[, 2], lwd = 1.6, seed = seed)
  outline(circ(arm[3, 1], arm[3, 2] - 1, 1.3), lwd = 1, seed = seed + 1)
  for (k in 1:2) {                                       # the wave
    w <- circ(arm[3, 1], arm[3, 2], 3 + 2 * k, 3 + 2 * k, -2.4, -1.5, 8)
    sketch(w[, 1] + 2, w[, 2] + 1, lwd = 0.8, seed = seed + 1 + k)
  }
  coat <- rbind(c(x - 0.12 * h, yf - 0.66 * h), c(x + 0.12 * h, yf - 0.66 * h),
                c(x + 0.17 * h, yf - 0.12 * h), c(x - 0.17 * h, yf - 0.12 * h))
  blank(coat); hatch(coat, angle = 75, gap = 1.5, lwd = 0.55, seed = seed + 4); outline(coat, lwd = 1.3, seed = seed + 5)
  other <- rbind(c(x - 0.11 * h, yf - 0.60 * h), c(x - 0.19 * h, yf - 0.40 * h), c(x - 0.17 * h, yf - 0.28 * h))
  sketch(other[, 1], other[, 2], lwd = 1.5, seed = seed + 6)
  head <- circ(x, hy, r); blank(head); outline(head, lwd = 1.2, seed = seed + 7)
  sketch(c(x + 0.2 * r, x + 0.9 * r), c(hy + 0.45 * r, hy + 0.35 * r), lwd = 0.7, seed = seed + 8)   # a grin
  brim <- circ(x - 0.3 * r, hy - 0.45 * r, 1.9 * r, 0.55 * r); blank(brim); outline(brim, lwd = 1.1, seed = seed + 9)
  crown <- rbind(circ(x - 0.2 * r, hy - 0.6 * r, 1.0 * r, 1.0 * r, pi, 2 * pi, 12))
  blank(crown); outline(crown, lwd = 1.1, seed = seed + 10)
}

tmp2 <- tempfile(fileext = ".png")
ragg::agg_png(tmp2, width = w0 * s, height = (h0 + T) * s, res = 72 * s, background = "transparent")
par(mar = c(0, 0, 0, 0))
plot.new(); plot.window(xlim = c(1, w0 + 1), ylim = c(h0 + 1, 1 - T), xaxs = "i", yaxs = "i")

# The stakeholder --------------------------------------------------------------
# A small coastal boat with one fisherman, bow to the right, sitting on the entrance grid. It is
# drawn in its own coordinates and enlarged about its keel, so pen widths stay Hammer's
zoom <- function(k, cx = 0, cy = 0) plot.window(xlim = cx + (c(1, w0 + 1) - cx) / k,
                                                 ylim = cy + (c(h0 + 1, 1 - T) - cy) / k, xaxs = "i", yaxs = "i")
zoom(1.3, 176, 95)
sheer <- bez(c(134, 72), c(176, 78), c(219, 61))
stem  <- bez(c(219, 61), c(217, 84), c(204, 93), 16)
keel  <- bez(c(204, 93), c(172, 96), c(142, 94), 20)
trans <- bez(c(142, 94), c(136, 86), c(134, 72), 12)
hull <- rbind(sheer, stem[-1, ], keel[-1, ], trans[-c(1, 12), ])

# mast, AIS whip and the wheelhouse behind the man
sketch(c(161, 161), c(54, 30), lwd = 1.3, seed = 201)
outline(rbind(c(161, 30.5), c(170, 33), c(161, 35.5)), lwd = 0.9, seed = 202)        # a pennant
sketch(c(155, 154.5), c(54, 39), lwd = 0.8, seed = 204)
house <- rbind(c(149, 76), c(149, 55), c(173, 53), c(177, 74))
blank(house)
hatch(rbind(c(149, 76), c(149, 55), c(156, 55), c(156, 76)), angle = 80, gap = 1.6, lwd = 0.55, seed = 205)
outline(house, lwd = 1.4, seed = 206)
sketch(c(147.5, 175), c(55.5, 52.5), lwd = 1.6, seed = 207)              # the roof's overhang
outline(rbind(c(159, 59), c(169, 58.5), c(169.5, 65.5), c(159.5, 66)), lwd = 1, wob = 0.15, seed = 208)   # window
outline(rbind(c(173.5, 57), c(175, 56.5), c(176.5, 66), c(174.8, 66.2)), lwd = 0.9, seed = 209)

fisher(192, 76, h = 29, seed = 300)

# a jigging reel on the rail, its line going down into the machine
sketch(c(209, 211), c(66, 57), lwd = 1.3, seed = 210)
outline(circ(211.5, 56, 2.6), lwd = 1.1, seed = 211)
sketch(c(214, 222, 223), c(55, 52, 96), lwd = 0.6, seed = 212)

blank(hull)
band <- bez(c(137, 84), c(177, 89), c(214, 78))                           # the waterline stripe
hatch(rbind(band, keel[-1, ], trans[1:6, ]), angle = 55, gap = 1.7, lwd = 0.6, seed = 213)
outline(hull, lwd = 1.6, wob = 0.3, seed = 214)
rail <- sheer; rail[, 2] <- rail[, 2] + 3
outline(rail[3:28, ], close = FALSE, lwd = 0.9, seed = 215)
outline(band, close = FALSE, lwd = 0.9, seed = 216)
hand("STAKEHOLDER", 176, 80.5, 5.6, w = 58, srt = 4, seed = 217)
for (sgn in c(-1, 1)) for (k in 1:2) {                                    # it has just landed
  x0 <- if (sgn < 0) 130 else 221; y0 <- 90 + 2 * k
  sketch(c(x0, x0 + sgn * (5 + 2 * k)), c(y0, y0 - 3 - k), lwd = 0.8, seed = 220 + 3 * k + sgn)
}
zoom(1)

# The records, thrown in after it
sack(46, -24, 46, 40, 14, "REGISTER", go = c(120, 100), seed = 400)
sack(112, -34, 46, 40, -6, "LOGBOOKS", go = c(60, 120), seed = 420)
sack(262, -32, 46, 40, -12, "LANDINGS", go = c(-80, 110), seed = 440)
sack(300, 4, 40, 36, -22, "AIS", go = c(-120, 70), seed = 460, pings = TRUE)

# The labels -------------------------------------------------------------------
hand("VESSEL ID", 78, 53, 11, w = 78, seed = 3)
hand("GRID", 97, 69, 11, seed = 4)
hand("PING", 43, 105, 13, seed = 5)
hand("FLAGGER", 45, 127, 13, w = 60, seed = 6)
hand("VOYAGE", 151, 140, 12, w = 50, seed = 7)
hand("CHOPPER", 166, 156, 12, w = 62, seed = 8)
hand("HAUL", 90, 207, 12, seed = 9)
hand("GRINDER", 110, 220, 12, w = 60, seed = 10)
hand("CANDIDATE", 106, 266, 12, w = 66, seed = 11)
hand("FLATTENER", 107, 281, 12, w = 66, seed = 12)
hand("INVALID", 68, 370, 13, w = 64, seed = 13)
hand("DUPLICATE", 68, 393, 13, w = 66, seed = 14)
hand("OR", 68, 416, 11, seed = 15)
hand("IMPOSSIBLE", 68, 435, 12, w = 66, seed = 16)
hand("LINK", 160, 414, 13, seed = 17)
hand("MIXER", 160, 432, 14, w = 56, seed = 18)
hand("BIG", 243, 290, 12, seed = 19)
hand("SPLIT", 247, 305, 11, w = 38, seed = 20)
hand("UP", 249, 319, 12, seed = 21)
hand("THIN", 340, 446, 14, w = 40, seed = 22)
hand("AIR", 339, 466, 15, seed = 23)
hand("CROSS-SOURCE POLISHING", 327, 56, 11, adj = 0, seed = 24)
hand("FILTER", 500, 153, 19, seed = 25)

# What the datacall drops off the filter
hand("HAULS", 368.5, 208, 10.5, w = 27, seed = 27)
hand("0.05°", 409, 231, 12.5, w = 27, seed = 28)
sketch(c(394, 388.5, 394), c(226.5, 231, 235.5), lwd = 1.7, wob = 0.15, seed = 28)   # the font's "<" is too small
hand("PORT", 454, 237, 10, w = 32, seed = 29)
hand("PINGS", 453, 251.5, 10, w = 33, seed = 30)
hand("OWN", 495, 250.5, 9.5, w = 30, seed = 31)
hand("MÉTIER", 494.5, 262, 9.5, w = 33, seed = 43)
hand("LOST IN", 358, 271, 8.5, srt = -17, adj = 0, seed = 32)
hand("AGGREGATION", 362, 285, 8.5, w = 72, srt = -17, adj = 0, seed = 44)

# The sign: its face, the board's dark edge on the left, and a shiver beside it
edge(566, 256, 636, 216, lwd = 1.3, wob = 0.5, seed = 51)
edge(636, 216, 636, 264, lwd = 1.3, wob = 0.5, seed = 52)
edge(636, 264, 566, 306, lwd = 1.3, wob = 0.5, seed = 53)
edge(566, 306, 566, 256, lwd = 1.5, wob = 0.4, seed = 54)
edge(562.5, 309, 562.5, 258.5, over = 0.5, lwd = 1.5, wob = 0.4, seed = 55)
edge(562.5, 258.5, 566, 256, over = 0.5, lwd = 1.2, seed = 56)
edge(562.5, 309, 566, 306, over = 0.5, lwd = 1.2, seed = 57)
for (yy in seq(259, 305, by = 2)) sketch(c(562.5, 566), c(yy + 1.4, yy - 1), lwd = 0.9, wob = 0.15, seed = yy)
for (i in 0:3) sketch(c(642 + 2.5 * i, 642.5 + 2.5 * i), c(222 + 3 * i, 236 + 3 * i), lwd = 1, seed = 60 + i)
hand("Don't stop", 601, 247, 9, w = 66, srt = 30, seed = 33)
hand("if a table", 601, 261, 9, w = 66, srt = 30, seed = 34)
hand("is missing", 601, 275, 9, w = 66, srt = 30, seed = 35)

hand("V", 645, 276.5, 11, srt = 58, seed = 36)
hand("M", 653.5, 267.5, 11, srt = 42, seed = 37)
hand("S", 663, 261.5, 11, srt = 26, seed = 38)
hand("CURATED", 505, 409, 16, w = 106, seed = 39)
hand("ICES", 513, 446, 8.5, w = 26, seed = 40)
hand("GAGNAKVÖRN", 600, -48, 17, seed = 41)
hand("the fishydata edition", 600, -32, 8, seed = 42, font = 1)
invisible(dev.off())

# Grain ------------------------------------------------------------------------
# Hammer's grain is his scan's resolution: the new marks are taken down to it and enlarged the way
# the scan was, so they soften alike. The photocopier's speckle (sd 0.065 in the scan's ink) is
# added at that size too
tmp4 <- tempfile(fileext = ".png")
magick::image_write(magick::image_resize(magick::image_read(tmp2), sprintf("%dx%d!", w0, h0 + T), filter = "Box"),
                    tmp4, format = "png")
a <- png::readPNG(tmp4)
if (dim(a)[3] == 2) a <- a[, , c(1, 1, 1, 2)]                    # saved as grey and alpha
dk <- 1 - (a[, , 1] + a[, , 2] + a[, , 3]) / 3
n <- matrix(rnorm(length(dk), 0, 1), nrow(dk)) * (0.012 + 0.09 * dk)
for (k in 1:3) a[, , k] <- pmin(1, pmax(0, a[, , k] + n))
a[, , 4] <- pmin(1, pmax(0, a[, , 4] * (1 + rnorm(length(dk), 0, 0.06))))
png::writePNG(a, tmp4)
layer <- magick::image_resize(magick::image_read(tmp4), sprintf("%dx%d!", w0 * s, (h0 + T) * s), filter = "Mitchell")
fig <- magick::image_composite(base, layer)

# Credit -----------------------------------------------------------------------
tmp3 <- tempfile(fileext = ".png")
ragg::agg_png(tmp3, width = w0 * s, height = 16 * s, res = 72 * s)
par(mar = c(0, 0, 0, 0)); plot.new(); plot.window(xlim = c(0, w0), ylim = c(16, 0), xaxs = "i", yaxs = "i")
text(w0 - 6, 8, "Drawing: Hammer '96, adapted for fishydata with permission. New labels, sign, boat and sacks drawn with AI (Claude), 2026.",
     adj = c(1, 0.5), cex = 6.5 / 12, col = "grey35", family = "Helvetica")
invisible(dev.off())
fig <- magick::image_append(c(fig, magick::image_read(tmp3)), stack = TRUE)
magick::image_write(fig, out)
