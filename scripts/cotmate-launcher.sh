#!/bin/bash
# cotmate-launcher.sh
# Starts CotMate if not already running, and spawns a watchdog
# that kills it when CotEditor quits.

# Interpreter selection:
#   - default: whatever `python3` resolves to on PATH (fine for launchd,
#     which uses the minimal PATH and hits /usr/bin/python3 = 3.9.6)
#   - override: export COTMATE_PYTHON=/opt/homebrew/bin/python3.12
PYTHON="${COTMATE_PYTHON:-python3}"

COTMATE_PY="$HOME/Library/Application Support/CotMate/bin/cotmate"
PIDFILE="$HOME/Library/Application Support/CotMate/cotmate.pid"
LOG="$HOME/Library/Application Support/CotMate/cotmate.log"
LOCKDIR="/tmp/cotmate-launcher.lock"

# Rotate log if it grows too large (must come AFTER $LOG is set).
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt 1000 ]; then
    tail -n 500 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# --- Atomic mutex so two launchers can't race. -------------------------
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    # Another launcher is running; wait for it to finish, then bail.
    while [ -d "$LOCKDIR" ]; do sleep 0.1; done
    exit 0
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
# -----------------------------------------------------------------------

# Already running (and healthy)?
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null \
        && nc -z 127.0.0.1 52698 2>/dev/null; then
    exit 0
fi

# Stale pidfile? Clean it up before starting.
rm -f "$PIDFILE"

# Start the server.
mkdir -p "$(dirname "$PIDFILE")"
nohup "$PYTHON" "$COTMATE_PY" --pidfile "$PIDFILE" \
    >> "$LOG" 2>&1 &
disown

# Wait for the pidfile to appear (up to ~3 s).
for _ in 1 2 3 4 5 6; do
    [ -f "$PIDFILE" ] && break
    sleep 0.5
done

# Watchdog: kill the server when CotEditor quits.
(
    while pgrep -x "CotEditor" >/dev/null; do
        sleep 2
    done
    if [ -f "$PIDFILE" ]; then
        kill "$(cat "$PIDFILE")" 2>/dev/null
        rm -f "$PIDFILE"
    fi
) &
disown