# port_code.R — the landing system's port codes (hid) as it lists them, each with its class (harbours.R until plan 014).
# Side: preprocessing (ports). See plan 014.
#
# Input:  raw/oracle/agf/aflagrunnur.parquet      every hid an agf landing uses
#         raw/oracle/kvoti/lods_slaegt.parquet    every hid a LODS landing uses, as its port (hofn) or as an export's
#                                                 origin port (upprunahofn)
#         raw/oracle/ask/londunarstadir.parquet   the landing system's port list: each hid's name and new code (id)
#         raw/oracle/fs_afladagbok/ws_veidiferd.parquet  every new code (id) a logbook trip names as its departure or
#                                                 landing port (upphafshofn, londunarhofn; TODO 196)
#         raw/oracle/kvoti/stadur.parquet         Fiskistofa's place list: the names londunarstadir lacks (159's)
#         curated/reference/port.parquet          the pid of each hid with a harbour polygon
#         reference/ports/port_code_class.yml     the class of every other code (decision 208 e), reviewed by hand
# Output: curated/reference/port_code.parquet   one row per code: hid, hid_new (hafnarnumer_id), port (name), pid,
#                                               class (harbour, disposition, abroad, transfer, placeholder)
#
# The raw list; reference/ports/harbour_codes.R joins it to the standard harbour key. The tables, not the view
# aflagrunnur_v, whose party and vessel joins drop code 168 (decision 175). A code with a pid is a harbour; any other
# code must be in the class table, or the build stops: the landings' disposition reads the class (curate/landing.R).

con <- duckdbfs::cached_connection()
pq <- function(f) sprintf("read_parquet('%s')", f)
decl <- yaml::read_yaml("reference/ports/port_code_class.yml")$codes
cls <- data.frame(hid = vapply(decl, \(x) as.integer(x$hid), 1L),
                  class = vapply(decl, \(x) x$class, ""))
stopifnot(!anyDuplicated(cls$hid),
          all(cls$class %in% c("harbour", "disposition", "abroad", "transfer", "placeholder")))
duckdb::duckdb_register(con, "port_code_class", cls, overwrite = TRUE)

codes <- DBI::dbGetQuery(con, sprintf(r"[
  WITH used AS (SELECT DISTINCT hafnarnumer AS hid FROM %s
                UNION SELECT DISTINCT hofn FROM %s
                UNION SELECT DISTINCT upprunahofn FROM %s
                UNION SELECT l.hafnarnumer FROM %s l
                      WHERE l.id IN (SELECT upphafshofn FROM %s UNION SELECT londunarhofn FROM %s))
  SELECT u.hid, l.id AS hid_new, coalesce(l.heiti, trim(s.heiti)) AS port, p.pid, k.class AS class_declared
  FROM used u
  LEFT JOIN %s l ON l.hafnarnumer = u.hid
  LEFT JOIN (SELECT stad_nr, any_value(heiti) AS heiti FROM %s GROUP BY 1) s ON s.stad_nr = u.hid
  LEFT JOIN (SELECT hid, any_value(pid) AS pid FROM %s GROUP BY 1) p ON p.hid = u.hid
  LEFT JOIN port_code_class k ON k.hid = u.hid
  WHERE u.hid IS NOT NULL ORDER BY u.hid]",
  pq(fd_raw("oracle", "agf", "aflagrunnur.parquet")), pq(fd_raw("oracle", "kvoti", "lods_slaegt.parquet")),
  pq(fd_raw("oracle", "kvoti", "lods_slaegt.parquet")), pq(fd_raw("oracle", "ask", "londunarstadir.parquet")),
  pq(fd_raw("oracle", "fs_afladagbok", "ws_veidiferd.parquet")),
  pq(fd_raw("oracle", "fs_afladagbok", "ws_veidiferd.parquet")),
  pq(fd_raw("oracle", "ask", "londunarstadir.parquet")),
  pq(fd_raw("oracle", "kvoti", "stadur.parquet")), pq(fd_curated("reference", "port.parquet"))))
duckdb::duckdb_unregister(con, "port_code_class")

both <- codes$hid[!is.na(codes$pid) & !is.na(codes$class_declared)]
none <- codes[is.na(codes$pid) & is.na(codes$class_declared), c("hid", "port")]
if (length(both)) stop("port_code: a code with a pid is also in the class table: ", toString(both))
if (nrow(none)) stop("port_code: a code with no pid and no class; class it in reference/ports/port_code_class.yml: ",
                     paste(none$hid, none$port, collapse = ", "))
codes$class <- ifelse(is.na(codes$pid), codes$class_declared, "harbour")
codes$class_declared <- NULL
print(table(codes$class))

write_curated(codes, fd_curated("reference", "port_code.parquet"),
              inputs = c(fd_raw("oracle", "agf", "aflagrunnur.parquet"), fd_raw("oracle", "kvoti", "lods_slaegt.parquet"),
                         fd_raw("oracle", "ask", "londunarstadir.parquet"), fd_raw("oracle", "kvoti", "stadur.parquet"),
                         fd_raw("oracle", "fs_afladagbok", "ws_veidiferd.parquet"),
                         fd_curated("reference", "port.parquet"), "reference/ports/port_code_class.yml"))
