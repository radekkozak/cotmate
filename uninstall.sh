#!/usr/bin/env bash
#
# CotMate uninstaller
# Removes everything install.sh added.  CotEditor itself is untouched.
#
# No set -e: this is a cleanup script and should push through failures.
set -uo pipefail

APPS_SCRIPTS="$HOME/Library/Application Scripts/com.coteditor.CotEditor"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_LABEL="com.radekkozak.cotmate.watcher"
PLIST_DEST="$LAUNCH_AGENTS/${PLIST_LABEL}.plist"
SUPPORT_DIR="$HOME/Library/Application Support/CotMate"
SUPPORT_BIN="$SUPPORT_DIR/bin"
LOG_DIR="$HOME/Library/Logs"
LOCKDIR="/tmp/cotmate-launcher.lock"

echo "CotMate uninstaller"
echo "───────────────────"

# 1. Unload the launchd agent (this stops the watcher).
if [[ -f "$PLIST_DEST" ]]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm -f "$PLIST_DEST"
    echo "→ removed launchd agent"
fi

# 2. Kill any stray watcher (launchd KeepAlive can leave stragglers
#    if unload didn't finish before we removed the plist).
pkill -f "cotmate-watcher.sh" 2>/dev/null || true

# 3. Stop the running server gracefully via its pid file.
if [[ -f "$SUPPORT_DIR/cotmate.pid" ]]; then
    SERVER_PID="$(cat "$SUPPORT_DIR/cotmate.pid" 2>/dev/null || true)"
    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill "$SERVER_PID" 2>/dev/null || true
        for _ in 1 2 3 4 5; do
            kill -0 "$SERVER_PID" 2>/dev/null || break
            sleep 0.2
        done
        if kill -0 "$SERVER_PID" 2>/dev/null; then
            kill -9 "$SERVER_PID" 2>/dev/null || true
        fi
        echo "→ stopped server (PID $SERVER_PID)"
    fi
fi

# 4. Catch any orphan listening on the rmate port.  lsof is the only
#    reliable check here — pkill patterns miss processes whose argv
#    doesn't contain the script name.
if command -v lsof >/dev/null 2>&1; then
    ORPHANS="$(lsof -tiTCP:52698 -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "$ORPHANS" ]]; then
        kill $ORPHANS 2>/dev/null || true
        echo "→ killed orphan listener(s): $ORPHANS"
    fi
fi

# 5. Remove installed scripts and hook.
rm -f  "$APPS_SCRIPTS/cotmate-launcher.sh"
rm -f  "$APPS_SCRIPTS/cotmate-watcher.sh"
rm -rf "$APPS_SCRIPTS/CotMateHook.scptd"
echo "→ removed scripts and hook"

# 6. Remove the server binary from its application-support home.
if [[ -f "$SUPPORT_BIN/cotmate" ]]; then
    rm -f "$SUPPORT_BIN/cotmate"
    echo "→ removed server binary"
fi

# Legacy cleanup: older CotMate versions installed the server here.
# Safe to run even if the file doesn't exist.
if [[ -f "$HOME/.local/bin/cotmate" ]]; then
    rm -f "$HOME/.local/bin/cotmate"
    echo "→ removed legacy server binary from ~/.local/bin"
fi

# 7. Remove runtime state (pid, log, mirrors, bin/).
rm -rf "$SUPPORT_DIR"
echo "→ removed runtime state"

# 8. Remove watcher logs written by launchd.
rm -f "$LOG_DIR/cotmate-watcher.log" "$LOG_DIR/cotmate-watcher.err"
echo "→ removed watcher logs"

# 9. Clear the launcher lock directory if it was orphaned by a crash.
rmdir "$LOCKDIR" 2>/dev/null || true

echo ""
echo "Done.  CotEditor is untouched."
echo ""
echo "Note: nothing was installed on your remote hosts."
echo "      If you copied rmate to a server, remove it with:"
echo "          ssh user@server 'rm ~/.local/bin/rmate'"