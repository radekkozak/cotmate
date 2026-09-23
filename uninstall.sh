#!/usr/bin/env bash
#
# cotmate uninstaller
# Removes everything install.sh added. CotEditor itself is untouched.
#
set -uo pipefail

APPS_SCRIPTS="$HOME/Library/Application Scripts/com.coteditor.CotEditor"
COTMATE_DIR="$APPS_SCRIPTS/CotMate"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_LABEL="com.radekkozak.cotmate.watcher"
PLIST_DEST="$LAUNCH_AGENTS/${PLIST_LABEL}.plist"
SUPPORT_DIR="$HOME/Library/Application Support/CotMate"
SUPPORT_BIN="$SUPPORT_DIR/bin"
LOG_DIR="$HOME/Library/Logs"
LEGACY_BIN="$HOME/.local/bin/cotmate"
LOCKDIR="/tmp/cotmate-launcher.lock"

# --- color handling ---------------------------------------------------------

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    BOLD="$(tput bold)"
    DIM="$(tput dim)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    RESET="$(tput sgr0)"
else
    BOLD="" DIM="" RED="" GREEN="" YELLOW="" BLUE="" RESET=""
fi

info()    { printf '%s🔄%s %s\n' "$BLUE" "$RESET" "$*"; }
success() { printf '%s✅%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s⚠️%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }

# --- banner -----------------------------------------------------------------

printf '\n%s cotmate uninstaller %s\n\n' "$BOLD" "$RESET"

# --- 1. unload launchd agent ------------------------------------------------

if [[ -f "$PLIST_DEST" ]]; then
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    rm -f "$PLIST_DEST"
    success "Removed launchd agent"
fi

# --- 2. kill stray watcher --------------------------------------------------

pkill -f "cotmate-watcher.sh" 2>/dev/null || true

# --- 3. stop server via pidfile ---------------------------------------------

if [[ -f "$SUPPORT_DIR/cotmate.pid" ]]; then
    COTMATE_PID="$(cat "$SUPPORT_DIR/cotmate.pid" 2>/dev/null || true)"
    if [[ -n "$COTMATE_PID" ]] && kill -0 "$COTMATE_PID" 2>/dev/null; then
        kill "$COTMATE_PID" 2>/dev/null || true
        for _ in 1 2 3 4 5; do
            kill -0 "$COTMATE_PID" 2>/dev/null || break
            sleep 0.2
        done
        kill -9 "$COTMATE_PID" 2>/dev/null || true
        success "Stopped cotmate (PID $COTMATE_PID)"
    fi
fi

# --- 4. kill orphans on port 52698 ------------------------------------------

if command -v lsof >/dev/null 2>&1; then
    ORPHANS=()
    while IFS= read -r pid; do
        [[ -n "$pid" ]] && ORPHANS+=("$pid")
    done < <(lsof -tiTCP:52698 -sTCP:LISTEN 2>/dev/null || true)
    if (( ${#ORPHANS[@]} )); then
        kill "${ORPHANS[@]}" 2>/dev/null || true
        success "Killed orphan listener(s): ${ORPHANS[*]}"
    fi
fi

# --- 5. remove scripts and hook ---------------------------------------------

# Current (foldered) install
rm -rf "$COTMATE_DIR"

# Legacy (flat) install
rm -f  "$APPS_SCRIPTS/cotmate-launcher.sh"
rm -f  "$APPS_SCRIPTS/cotmate-watcher.sh"
rm -rf "$APPS_SCRIPTS/CotMateHook.scptd"

success "Removed scripts and hook"

# --- 6. remove server binary ------------------------------------------------

if [[ -f "$SUPPORT_BIN/cotmate" ]]; then
    rm -f "$SUPPORT_BIN/cotmate"
    success "Removed cotmate binary"
fi

# --- 7. legacy cleanup ------------------------------------------------------

if [[ -f "$LEGACY_BIN" ]]; then
    rm -f "$LEGACY_BIN"
    success "Removed legacy binary from ~/.local/bin"
fi

# --- 8. remove runtime state ------------------------------------------------

rm -rf "$SUPPORT_DIR"
success "Removed runtime state"

# --- 9. remove watcher logs -------------------------------------------------

rm -f "$LOG_DIR/cotmate-watcher.log" "$LOG_DIR/cotmate-watcher.err"
success "Removed watcher logs"

# --- 10. clear lock ---------------------------------------------------------

rmdir "$LOCKDIR" 2>/dev/null || true

# --- done -------------------------------------------------------------------

printf '\n%s────────────────────────────────────────────────────────────%s\n' "$DIM" "$RESET"
printf '%s cotmate uninstalled %s\n' "$BOLD$GREEN" "$RESET"
printf '%s────────────────────────────────────────────────────────────%s\n\n' "$DIM" "$RESET"

echo "  CotEditor is untouched."
echo
echo "  Note: nothing was uninstalled on your remote hosts."
echo "  If you copied rmate to a server and want to remove it, run:"
echo
echo "      ssh user@server 'rm ~/.local/bin/rmate'"
echo