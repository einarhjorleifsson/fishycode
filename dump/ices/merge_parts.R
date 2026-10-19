# Usage: Rscript merge_parts.R <out.json> <part1.yml> [<part2.yml> ...]
# Merges a report's part maps: topics, code and vocabulary appended in part order; report-level lists (terms of
# reference, outputs) appended, scalar fields taken from the first part that has them; the data-call summaries joined.
a <- commandArgs(TRUE); out <- a[1]; parts <- lapply(a[-1], yaml::read_yaml, fileEncoding = "UTF-8")
first <- function(f) { for (p in parts) { v <- p$report[[f]]; if (!is.null(v) && !identical(v, "") && !identical(v, 0L)) return(v) }; "" }
rep <- list(id = first("id"), file = first("file"), title = first("title"), series = first("series"),
            year = first("year"), meeting = first("meeting"), set_out_to_do = first("set_out_to_do"),
            parts = vapply(parts, function(p) as.character(p$report$part %||% ""), ""),
            terms_of_reference = do.call(c, lapply(parts, function(p) p$report$terms_of_reference)),
            data_call = list(summary = paste(Filter(function(s) nzchar(s) && !grepl("^not described", s),
                               vapply(parts, function(p) as.character(p$report$data_call$summary %||% ""), "")), collapse = " "),
                             pages = paste(Filter(nzchar, vapply(parts, function(p) as.character(p$report$data_call$pages %||% ""), "")), collapse = ", ")),
            outputs = do.call(c, lapply(parts, function(p) p$report$outputs)))
m <- list(report = rep,
          topics = do.call(c, lapply(parts, `[[`, "topics")),
          code = do.call(c, lapply(parts, `[[`, "code")),
          vocabulary = do.call(c, lapply(parts, `[[`, "vocabulary")),
          notes = paste(vapply(parts, function(p) as.character(p$notes %||% ""), ""), collapse = " | "))
writeLines(jsonlite::toJSON(m, auto_unbox = TRUE, null = "null", na = "null"), out)
cat(rep$id, ":", length(m$topics), "topics,", length(m$code), "code,", length(m$vocabulary), "vocabulary\n")
