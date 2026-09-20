
library(chromote)
library(rvest)
library(tibble)
library(dplyr)
library(tidyr)
library(stringr)

scrape_mt_general <- function(url, wait_secs = 10, debug = FALSE) {
  # Set Chrome path if needed:
  # Sys.setenv(CHROMOTE_CHROME = "/Applications/Chromium.app/Contents/MacOS/Chromium")

  b <- ChromoteSession$new()
  on.exit(b$close(), add = TRUE)

  b$Page$navigate(url)
  Sys.sleep(wait_secs)

  html_raw <- b$Runtime$evaluate("document.documentElement.outerHTML")$result$value
  page <- read_html(html_raw)

  if (debug) {
    tmp <- tempfile(fileext = ".html")
    writeLines(html_raw, tmp)
    message("Raw HTML saved to: ", tmp)

    # Probe: find nodes whose text equals "General"
    nodes <- page |> html_elements("*")
    gen <- nodes[html_text(nodes, trim = TRUE) == "General"]
    message("Nodes with text 'General': ", length(gen))
    for (n in gen) {
      message("  <", html_name(n), "> class='", html_attr(n, "class"), "'")
    }
    return(invisible(page))
  }

  # ---------------------------------------------------------------------------
  # Extract General section
  # MarineTraffic renders vessel details as key-value pairs.
  # Selectors verified against shipid:9629012 — update below if MT redesigns.
  # ---------------------------------------------------------------------------

  # Find the "General" section container by locating its header, then walking
  # to the nearest ancestor that holds the key-value grid.
  general_header <- page |>
    html_elements("span, div, h2, h3, h4") |>
    keep(\(n) str_trim(html_text(n)) == "General") |>
    pluck(1)

  if (is.null(general_header)) {
    warning("Could not locate 'General' section header. Try debug = TRUE.")
    return(tibble())
  }

  # Walk up the DOM until we find a node that contains both label and value children
  # (chromote/rvest doesn't support parent traversal directly, so we scope
  #  the search using known MT class fragments instead)
  labels <- page |>
    html_elements("[class*='label'], [class*='Label'], dt") |>
    html_text(trim = TRUE)

  values <- page |>
    html_elements("[class*='value'], [class*='Value'], dd") |>
    html_text(trim = TRUE)

  if (length(labels) == 0 || length(values) == 0) {
    warning("Selectors returned no content. Try debug = TRUE to inspect the page.")
    return(tibble())
  }

  # Pair them up (trim to shorter of the two in case counts diverge)
  n <- min(length(labels), length(values))
  result <- tibble(label = labels[seq_len(n)], value = values[seq_len(n)]) |>
    filter(nchar(label) > 0, nchar(value) > 0) |>
    mutate(
      label = label |>
        str_to_lower() |>
        str_replace_all("[^a-z0-9]+", "_") |>
        str_remove("_$")
    ) |>
    pivot_wider(names_from = label, values_from = value, values_fn = first) |>
    mutate(source_url = url, .before = 1)

  result
}

Sys.setenv(CHROMOTE_CHROME = "/Applications/Chromium.app/Contents/MacOS/Chromium")
scrape_mt_general("https://www.marinetraffic.com/en/ais/details/ships/shipid:9629012", debug = TRUE)
