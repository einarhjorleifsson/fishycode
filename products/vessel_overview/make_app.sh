#!/bin/sh
# Makes "Vessel overview.app" in ~/Applications, to start the vessel overview with a click (plan 030). A click starts
# the server if it is not running and opens the page. While it runs, a click asks whether to open the page, restart
# the server (after a change to api.R) or stop it. The work is done by start.sh beside this script.
#
# The app holds the path of this checkout's start.sh, so make it again from the checkout you want it to run: after a
# merge, from main.
#
#   products/vessel_overview/make_app.sh

set -eu
launcher="$(cd "$(dirname "$0")" && pwd)/start.sh"
app="$HOME/Applications/Vessel overview.app"
src=$(mktemp -t vessel_overview).applescript
cat > "$src" <<APPLESCRIPT
property launcher : "$launcher"
on run
	try
		set cmd to quoted form of launcher
		set state to do shell script cmd & " status"
		if state is "running, older than the code" then
			display notification "The server is older than its code: restarting." with title "Vessel overview"
			do shell script cmd & " restart"
		else if state is "running" then
			set r to button returned of (display dialog "The vessel overview is running." buttons {"Stop", "Restart", "Open"} default button "Open" with title "Vessel overview")
			if r is "Stop" then
				do shell script cmd & " stop"
				display notification "Stopped." with title "Vessel overview"
			else if r is "Restart" then
				display notification "Restarting: a few seconds." with title "Vessel overview"
				do shell script cmd & " restart"
			else
				do shell script cmd & " open"
			end if
		else
			display notification "Starting: a few seconds." with title "Vessel overview"
			do shell script cmd & " open"
		end if
	on error msg
		display dialog msg buttons {"OK"} default button "OK" with title "Vessel overview" with icon caution
	end try
end run
APPLESCRIPT
mkdir -p "$HOME/Applications"
rm -rf "$app"
osacompile -o "$app" "$src"
rm -f "$src"
echo "made $app, running $launcher"
