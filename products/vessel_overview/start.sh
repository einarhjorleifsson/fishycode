#!/bin/sh
# Starts, stops or restarts the vessel overview's server (plan 030), from a terminal or from the app that make_app.sh
# makes. The server runs in the background on 127.0.0.1, port VESSEL_OVERVIEW_PORT (8790), with its output in
# ~/Library/Logs/vessel_overview.log.
#
#   products/vessel_overview/start.sh          start it if it is not running, and open the page
#   products/vessel_overview/start.sh restart  stop it, start it again (after a change to api.R), and open the page
#   products/vessel_overview/start.sh start    start it if it is not running, without opening the page
#   products/vessel_overview/start.sh stop     stop it
#   products/vessel_overview/start.sh status   say "running" or "stopped"
#
# It stops only a vessel overview server: a port held by another program is reported, never freed.

set -u
cd "$(dirname "$0")/../.." || exit 1   # the checkout this script is in
PORT="${VESSEL_OVERVIEW_PORT:-8790}"
URL="http://127.0.0.1:$PORT/"
LOG="$HOME/Library/Logs/vessel_overview.log"
# a program started from the Finder has no locale, and R would then mangle the Icelandic letters
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 VESSEL_OVERVIEW_PORT="$PORT"
RSCRIPT=$(command -v Rscript || ls /usr/local/bin/Rscript /Library/Frameworks/R.framework/Resources/bin/Rscript 2>/dev/null | head -n 1)

pid() { lsof -nP -t -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | head -n 1; }
ours() { p=$(pid); [ -n "$p" ] && ps -o command= -p "$p" | grep -q "vessel_overview/server.R"; }
fail() { echo "$1" >&2; exit 1; }

stop() {
  ours || return 0
  kill "$(pid)"
  i=0; while [ -n "$(pid)" ] && [ $i -lt 20 ]; do sleep 0.5; i=$((i + 1)); done
  [ -z "$(pid)" ] || fail "The server on port $PORT did not stop."
}

start() {
  ours && return 0
  p=$(pid)
  [ -z "$p" ] || fail "Port $PORT is used by another program: $(ps -o command= -p "$p" | cut -c1-120)"
  [ -n "$RSCRIPT" ] || fail "Rscript was not found. Is R installed?"
  echo "--- $(date '+%Y-%m-%d %H:%M:%S') starting from $(pwd)" >> "$LOG"
  nohup "$RSCRIPT" products/vessel_overview/server.R >> "$LOG" 2>&1 < /dev/null &
  i=0   # the server reads the vessel list before it answers: a few seconds
  until curl -s -o /dev/null "$URL"; do
    sleep 0.5; i=$((i + 1))
    kill -0 $! 2>/dev/null || fail "The server stopped while starting. The end of $LOG:
$(tail -n 8 "$LOG")"
    [ $i -lt 120 ] || fail "The server did not answer within a minute. See $LOG."
  done
}

case "${1:-open}" in
  open)    start && open "$URL" ;;
  start)   start ;;
  restart) stop && start && open "$URL" ;;
  stop)    stop ;;
  status)  if ours; then echo running; else echo stopped; fi ;;
  *)       fail "usage: start.sh [open | start | restart | stop | status]" ;;
esac
