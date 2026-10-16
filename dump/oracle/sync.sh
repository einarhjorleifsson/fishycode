#!/bin/sh
# sync.sh - copy each schema of a dump to another disk as soon as it is finished (decision 109).
#
# Input:  FROM, the dump's raw/oracle/ as this machine sees it (the server's, over the SMB share)
# Output: TO, a copy of it, schema by schema, with the logs; its own log in TO/_sync.log
#
# On the Mac, from the fishycode folder, while the server dumps:
#   nohup sh dump/oracle/sync.sh /Volumes/einarhj/stasi/fishydata/raw/oracle ~/stasi/fishydata/raw/oracle_server > /dev/null 2>&1 &
#
# A schema counts as finished when its _logs/ holds a .exit file, the exit code its run writes last; it is then
# copied once. A new file is the signal because the macOS SMB client can show a file the server keeps appending to
# without its newest lines (the run's _all.log, 2026-10-16), while a new file appears at once. The schemas are those
# with a script beside this one. It stops when all are copied, or after one whose run failed as a whole (the dump
# stops there too). Made for a fresh run: after a --resume, run it again once the dump is done. Run it again any
# time: rsync copies only what changed. Every minute by default; SYNC_EVERY=<seconds> changes that.

FROM=${1:?"usage: sh dump/oracle/sync.sh FROM TO"}
TO=${2:?"usage: sh dump/oracle/sync.sh FROM TO"}
EVERY=${SYNC_EVERY:-60}
HERE=$(cd "$(dirname "$0")" && pwd)
SCHEMAS=$(cd "$HERE" && ls *.R | sed 's/[.]R$//' | grep -v '^all$')
mkdir -p "$TO"
LOG="$TO/_sync.log"
say() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG"; }

say "sync of $(echo $SCHEMAS | wc -w | tr -d ' ') schemas from $FROM to $TO, every $EVERY s"
copied=""
while :; do
  for s in $SCHEMAS; do
    case " $copied " in *" $s "*) continue ;; esac
    x=$(ls "$FROM/$s/_logs/"*.exit 2>/dev/null | tail -1)
    [ -n "$x" ] || continue
    if rsync -a "$FROM/$s" "$TO/"; then
      copied="$copied $s"
      code=$(cat "$x")
      say "$s copied (its run exited $code; $(du -sh "$TO/$s" | cut -f1))"
      if [ "$code" != 0 ]; then
        rsync -a "$FROM/_logs" "$TO/"
        say "$s failed as a whole, so the dump stopped there; so does this sync"
        exit 1
      fi
    else
      say "$s: rsync failed (network?); trying again in $EVERY s"
    fi
  done
  rsync -a "$FROM/_logs" "$TO/" 2>/dev/null
  if [ "$(echo $copied | wc -w)" -ge "$(echo $SCHEMAS | wc -w)" ]; then
    say "all schemas copied"
    exit 0
  fi
  sleep "$EVERY"
done
