# test_curated_list.R — the curated lists' shared machinery (R/curated_list.R) and the light characteristics
# (R/light_characteristic.R) on made-up records (plan 082).
#
# Input:  the functions in R/; no data, no $FISHYDATA
# Output: nothing kept
#
# Run from the repo root:  Rscript -e 'testthat::test_file("tests/test_curated_list.R")'
# Written by Claude (AI).

root <- normalizePath(getwd())
while (!file.exists(file.path(root, "AGENTS.md")) && dirname(root) != root) root <- dirname(root)
fd <- new.env()
sys.source(file.path(root, "R", "curated_list.R"), envir = fd)
sys.source(file.path(root, "R", "light_characteristic.R"), envir = fd)

test_that("a characteristic is read one way, from a list or a chart's read", {
  p <- fd$light_char_parse(c("Fl(3)WRG 20s", "FIG 3S", "Oc WRG 6s", "Mo(N)W 30s", "LFI W 10s", "Q(6)+LFl 15s", "Dir WRG", "28s", "", "xyz"))
  expect_equal(fd$light_char_text(p), c("Fl(3) WRG 20s", "Fl G 3s", "Oc WRG 6s", "Mo(N) W 30s", "LFl W 10s", "Q(6)+LFl 15s", "Dir WRG", "28s", NA, NA))
  expect_false(fd$light_char_parse("FIR 35")$has_s)                    # the charts' Fl R 3s, its s read as 5
})

test_that("two characteristics agree on rhythm, group, period and colours within each other", {
  a <- fd$light_char_agree
  expect_true(a("Fl(3)WRG 20s", "Fl(3) W 20s"))                          # one sector's colour within the light's
  expect_false(a("Fl W 15s", "Fl W 20s"))                                # Sauðanes: the periods differ
  expect_false(a("LFl WRG 5s", "Fl WRG 5s"))                             # the rhythms differ
  expect_true(a("FIR 35", "Fl R 3s"))                                    # a period read without its s is not compared
  expect_true(a("F WRG | Fl W 5s", "Fl W 5s"))                           # several: any one agreeing
  expect_true(a("Dir WRG", "Oc G 3s"))                                   # no rhythm given: the colours only
  expect_true(a("3s", "Fl G 3s")); expect_false(a("1S", "Q(3)W 10s"))    # a period alone: the period only
  expect_true(is.na(a(NA, "Fl W 5s")))
})

test_that("names agree across Icelandic cases, NGA's spelling and the -viti ending", {
  k <- fd$cl_name_keys(c("Arnarfjörður", "Langanes - Arnarfirði", "Aedhey", "Æðeyjarviti", "Dalatangaviti", "Dalatangi", "Reykjanes"), "viti")
  expect_true(fd$cl_names_agree(k[1], k[2])); expect_true(fd$cl_names_agree(k[3], k[4])); expect_true(fd$cl_names_agree(k[5], k[6]))
  expect_false(fd$cl_names_agree(k[6], k[7]))
})

test_that("records of two lists join when each is the other's nearest, and places are the connected sets", {
  xy <- cbind(c(0, 10, 50, 1000, 1005, 2000), 0)                        # list a at 0, 50, 1000; b at 10, 1005; c at 2000
  li <- c("a", "b", "a", "a", "b", "c")
  pr <- fd$cl_pairs(xy, li, rep(TRUE, 6), 500)
  expect_equal(nrow(pr), 3)                                              # within 500 m and of two lists: 0-10, 10-50, 1000-1005
  j <- fd$cl_mutual(pr, li, pr$dist_m <= 100)
  expect_equal(sum(j), 2)                                                # 0-10 and 1000-1005; 50 is not 10's nearest
  # the same records in another order: a record's nearest is judged over the pairs it is first and second in
  o <- c(2, 3, 1, 5, 4, 6); pr2 <- fd$cl_pairs(xy[o, ], li[o], rep(TRUE, 6), 500)
  j2 <- fd$cl_mutual(pr2, li[o], pr2$dist_m <= 100)
  expect_setequal(paste(o[pr2$i[j2]], o[pr2$j[j2]]) |> vapply(function(s) paste(sort(strsplit(s, " ")[[1]]), collapse = "-"), ""), c("1-2", "4-5"))
  pl <- fd$cl_places(6, pr, j, 1:6)
  expect_equal(pl, c(1, 1, 3, 4, 4, 6))
  expect_equal(fd$cl_best(1:3, c(NA, "x", "y"), li, c("b", "a")), c("x", "b"))
  expect_equal(fd$cl_best(1:3, c(NA, NA, NA), li, c("b", "a")), c(NA, "none"))
})

test_that("the best witness is one record, its other values taken with it", {
  li <- c("a", "b", "a", "b", "c"); v <- c(NA, 20, 30, 40, 50)               # a depth by list, its unit beside
  u <- c(NA, "fm", "m", "m", "m")
  expect_equal(fd$cl_best_which(1:5, v, li, c("b", "a")), 2)                 # b first; of b's two the first
  expect_equal(fd$cl_best_which(c(4, 2), v, li, c("b", "a")), 2)             # ties by record, not by the order of ix
  expect_equal(fd$cl_best_which(1:5, v, li, c("a", "b")), 3)                 # a's first record has no value
  k <- fd$cl_best_which(1:5, v, li, c("c")); expect_equal(c(v[k], u[k]), c("50", "m"))
  expect_true(is.na(fd$cl_best_which(1:5, v, li, c("d"))))                   # no list of the order: none
  expect_equal(fd$cl_best(1:5, v, li, c("b", "a")), c("20", "b"))
})

test_that("the digits of a position give its resolution", {
  expect_equal(fd$cl_digits_min(64 + 9.9 / 60, -(22 + 41.53 / 60)), 0.01)
  expect_equal(fd$cl_digits_min(64 + 9.9 / 60, -(22 + 41.5 / 60)), 0.1)
  expect_true(is.na(fd$cl_digits_min(64.1234567, -22.7654321)))
})
