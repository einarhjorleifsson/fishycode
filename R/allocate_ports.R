# allocate_ports.R — the port ledger: which number (pid) each port has, given once and never moved (plan 075 §2.3).
#
# Input:  curated/reference/port_ledger/ (the ledger, one stamped parquet per allocation),
#         curated/reference/port_layer.parquet and port_feature.parquet (reference/ports/port_layer.R),
#         staging/ports/ports_all.gpkg (the old build's acronyms, read for the alias where it still exists)
# Output: read_port_ledger() the ledger as one table; port_ledger_files() its files, for targets and write_curated();
#         allocate_ports() a new batch file in the ledger
#
# A port is known to the ledger by its anchor's key, `<source>:<feature_key>` (einar:IS-REY, gfw_dock:<s2id>, gisco:NLRTM). The
# layer reads the ledger as an input, as the vessel crosswalk reads the vid ledger: which port a feature anchors follows
# from the lists and is rebuilt with them, but which number a port has depends on earlier builds, and a target cannot
# read its own output. So the numbering lives outside the graph, and allocate_ports() - run by hand, as allocate_vids()
# is - extends it. Until then a new port's pid is NA, and nothing stops.
#
# The numbers (the maintainer, 2026-11-14): an Icelandic harbour's pid is its landing code as given (`hid`, Fiskistofa's
# stad_nr), basis `given`; 1-999 is kept for those codes. Every other port is numbered from 1000 up, basis `new`: in the
# first batch einar's harbours with no code first (Iceland, then the Faroes, by name), then the rest by country, name and
# key. A number carries no meaning beyond that.
#
# Evidence changes, and a port's anchor with it: a list is refreshed or a better one added. A new key whose port holds,
# among its members' keys, exactly one key that has a number no current port holds takes that number, basis `inherited`,
# with the old key in `from_key`. A number whose port is gone is retired, never reused.
#
# Append-only, at the file level: each allocation writes a new file and no file is ever rewritten.

port_ledger_dir <- function() fd_path("curated", "reference", "port_ledger")

port_ledger_files <- function(dir = port_ledger_dir())
  sort(list.files(dir, "^batch_.*[.]parquet$", full.names = TRUE), method = "radix")

# The ledger as one table. Stops if the files contradict each other: a key on two numbers, or a number given twice.
read_port_ledger <- function(dir = port_ledger_dir()) {
  files <- port_ledger_files(dir)
  empty <- data.frame(pid = integer(), port_key = character(), pid_acronym = character(), basis = character(),
                      from_key = character(), name = character(), iso = character(), allocated = as.Date(character()),
                      batch = character())
  if (!length(files)) return(empty)
  led <- do.call(rbind, lapply(files, function(f) {
    d <- as.data.frame(nanoparquet::read_parquet(f))[names(empty)]
    d$allocated <- as.Date(d$allocated)
    d
  }))
  if (anyDuplicated(led$port_key)) stop("port ledger: a key on two rows: ", paste(head(led$port_key[duplicated(led$port_key)]), collapse = ", "))
  first <- led[led$basis != "inherited", ]
  if (anyDuplicated(first$pid)) stop("port ledger: a number allocated twice: ", paste(head(first$pid[duplicated(first$pid)]), collapse = ", "))
  led
}

allocate_ports <- function(layer = fd_curated("reference", "port_layer.parquet"),
                           features = fd_curated("reference", "port_feature.parquet"),
                           old = fd_staging("ports", "ports_all.gpkg"),
                           dir = port_ledger_dir(), first = 1000L, dry_run = TRUE) {
  led <- read_port_ledger(dir)
  ly <- as.data.frame(nanoparquet::read_parquet(layer))
  if (!all(c("port_key", "anchor_source", "hid", "iso", "name") %in% names(ly))) stop("not a port layer: ", layer)
  todo <- ly[!ly$port_key %in% led$port_key, ]
  if (!nrow(todo)) { message("allocate_ports: nothing unallocated"); return(invisible(led[0, ])) }

  # Inheritance: a new port whose members hold exactly one ledger key that no current port holds
  fe <- as.data.frame(nanoparquet::read_parquet(features))[, c("source", "feature_key", "port_key")]
  fe$key <- paste0(fe$source, ":", fe$feature_key)
  fe <- fe[fe$port_key %in% todo$port_key & fe$key %in% led$port_key & !fe$key %in% ly$port_key, ]
  one <- tapply(fe$key, fe$port_key, function(k) if (length(unique(k)) == 1) k[1] else NA_character_)
  inh_key <- unname(one[todo$port_key])
  inh_pid <- led$pid[match(inh_key, led$port_key)]
  dup <- duplicated(inh_pid) & !is.na(inh_pid)            # a number is inherited once: the first port in order keeps it
  inh_pid[dup] <- NA; inh_key[dup] <- NA

  # Iceland's codes as given: an einar harbour with a landing code
  given <- todo$anchor_source == "einar" & !is.na(todo$hid)
  if (any(todo$hid[given] >= first)) stop("allocate_ports: a landing code reaches ", first)
  used <- c(led$pid, todo$hid[given])
  if (anyDuplicated(todo$hid[given]) || any(todo$hid[given] %in% led$pid)) stop("allocate_ports: a landing code taken twice")

  # The rest from `first` up: einar's uncoded harbours first (Iceland, then the Faroes, by name), then by country and name
  rest <- which(!given & is.na(inh_pid))
  o <- order(todo$anchor_source[rest] != "einar", todo$iso[rest] != "IS", todo$iso[rest], todo$name[rest],
             todo$port_key[rest], method = "radix")
  nxt <- max(c(first - 1L, led$pid[led$pid >= first]))
  pid <- rep(NA_integer_, nrow(todo))
  pid[given] <- as.integer(todo$hid[given])
  pid[!is.na(inh_pid)] <- inh_pid[!is.na(inh_pid)]
  pid[rest[o]] <- nxt + seq_along(rest)
  basis <- ifelse(given, "given", ifelse(!is.na(inh_pid), "inherited", "new"))

  # The old build's acronym, as an alias: the canonical pid of the old group holding the anchor (within 300 m), where
  # the group maps to one new port and the port to one group. einar's pinned acronyms are the layer's own.
  acr <- rep(NA_character_, nrow(todo))
  if (file.exists(old) && file.exists(layer)) {
    s2 <- sf::sf_use_s2(FALSE); on.exit(sf::sf_use_s2(s2), add = TRUE)
    lg <- read_curated_sf(layer)
    lg <- lg[match(todo$port_key, lg$port_key), ]
    og <- sf::read_sf(old)
    og <- og[og$canonical, "pid"]
    hit <- sf::st_intersects(sf::st_buffer(sf::st_transform(lg, 3035), 300), sf::st_transform(og, 3035))
    single <- which(lengths(hit) == 1)
    cand <- data.frame(i = single, acr = og$pid[unlist(hit[single])])
    cand <- cand[!cand$acr %in% cand$acr[duplicated(cand$acr)], ]
    acr[cand$i] <- cand$acr
  }
  acr[todo$anchor_source == "einar"] <- NA

  stamp <- format(Sys.time(), "%Y%m%dT%H%M%S", tz = "UTC")
  add <- data.frame(pid = as.integer(pid), port_key = todo$port_key, pid_acronym = acr, basis = basis,
                    from_key = inh_key, name = todo$name, iso = todo$iso, allocated = Sys.Date(), batch = stamp)
  nv <- add$pid[add$basis == "new"]
  message(sprintf("allocate_ports: %s ports: %s given (Iceland's codes), %s new (%s), %s inherited, %s with an old acronym%s",
                  format(nrow(add), big.mark = ","), sum(add$basis == "given"), format(length(nv), big.mark = ","),
                  if (length(nv)) paste(range(nv), collapse = "-") else "none", sum(add$basis == "inherited"),
                  format(sum(!is.na(add$pid_acronym)), big.mark = ","), if (dry_run) " - dry run, nothing written" else ""))
  if (dry_run) return(invisible(add))

  f <- file.path(dir, paste0("batch_", stamp, ".parquet"))
  if (file.exists(f)) stop("ledger batch exists already: ", f)
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  write_curated(add, f, inputs = c(port_layer = layer, port_feature = features), script = "R/allocate_ports.R")
  read_port_ledger(dir)   # read back as one ledger, which checks the new file against the old ones
  invisible(add)
}
