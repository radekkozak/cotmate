#!/bin/bash
# cotmate-watcher.sh
# Runs forever. Whenever CotEditor appears, calls the launcher to
# start CotMate. Whenever CotEditor quits, the launcher's own
# watchdog already handles killing the server.

LAUNCHER="$HOME/Library/Application Scripts/com.coteditor.CotEditor/cotmate-launcher.sh"

was_running=0

while true; do
    if pgrep -x "CotEditor" >/dev/null; then
        if [ "$was_running" -eq 0 ]; then
            # CotEditor just appeared — start CotMate.
            "$LAUNCHER"
            was_running=1
        fi
    else
        if [ "$was_running" -eq 1 ]; then
            # CotEditor just quit — next appearance should re-launch.
            was_running=0
        fi
    fi
    sleep 2
done