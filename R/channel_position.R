# channel_position.R — channel's station positions in decimal degrees.
#
# Input:  the numbers as channel.station holds them (latitude, longitude, latitude_end, longitude_end)
# Output: none; decode_channel_position()
#
# Degrees and minutes to two decimals, times 100 (653000 = 65°30.00'), as geo::geoconvert.1() reads them; a value of
# three or four digits is degrees and minutes (6611 = 66°11'). NA where the minutes reach 60 or the value falls outside
# [lo, hi]: a longitude is given west-positive, so the caller turns its sign. Read by sources/ornefni/channel_name.R and
# tag_release.R.

decode_channel_position <- function(x, lo, hi) {
  x <- as.numeric(x)
  d <- ifelse(x >= 10000, x %/% 10000, x %/% 100)
  m <- ifelse(x >= 10000, (x %% 10000) / 100, x %% 100)
  v <- d + m / 60
  ifelse(!is.na(x) & x >= 100 & m < 60 & v >= lo & v <= hi, v, NA_real_)
}
