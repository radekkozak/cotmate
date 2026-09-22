#!/usr/bin/env bash
#
# cotmate installer
# Wires up the server, launcher, watcher, launchd agent and CotEditor hook.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# --- destinations -----------------------------------------------------------

APPS_SCRIPTS="$HOME/Library/Application Scripts/com.coteditor.CotEditor"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
SUPPORT_DIR="$HOME/Library/Application Support/CotMate"
SUPPORT_BIN="$SUPPORT_DIR/bin"
LEGACY_BIN="$HOME/.local/bin/cotmate"

PLIST_LABEL="com.radekkozak.cotmate.watcher"
PLIST_SRC="$REPO_DIR/launchd/${PLIST_LABEL}.plist"
PLIST_DEST="$LAUNCH_AGENTS/${PLIST_LABEL}.plist"

INSTALL_LAUNCHD=1
if [[ "${1:-}" == "--no-launchd" ]]; then
    INSTALL_LAUNCHD=0
fi

# --- output helpers ---------------------------------------------------------

info()    { printf '%s🔄%s %s\n' "$BLUE" "$RESET" "$*"; }
success() { printf '%s✅%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s⚠️%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error()   { printf '%s🚫%s %s\n' "$RED" "$RESET" "$*" >&2; }

# --- banner -----------------------------------------------------------------

printf '\n%s cotmate installer %s\n\n' "$BOLD" "$RESET"

# --- preflight --------------------------------------------------------------

if [[ "$(uname -s)" != "Darwin" ]]; then
    error "cotmate is macOS-only."
    exit 1
fi
success "macOS detected"

# --- Python 3.9+ check ------------------------------------------------------

PYTHON_BIN="$(command -v python3 2>/dev/null || true)"
if [[ -z "$PYTHON_BIN" ]]; then
    error "python3 not found on PATH."
    echo
    echo "  macOS provides Python 3.9 via the Xcode Command Line Tools."
    echo "  Install them with:"
    echo
    echo "      ${BOLD}xcode-select --install${RESET}"
    echo
    exit 1
fi

PYVER="$("$PYTHON_BIN" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"
if ! "$PYTHON_BIN" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
    error "Python 3.9+ required (found $PYVER at $PYTHON_BIN)."
    exit 1
fi
success "Python $PYVER"

# --- cot CLI check ----------------------------------------------------------

# --- CotEditor / cot CLI check ----------------------------------------------

COT_APP="/Applications/CotEditor.app/Contents/SharedSupport/bin/cot"

# CotEditor must be installed and ship the cot binary.
if [[ ! -x "$COT_APP" ]]; then
    error "CotEditor not found at /Applications/CotEditor.app"
    echo
    echo "  cotmate requires CotEditor to be installed."
    echo "  Download it from:"
    echo
    echo "      https://coteditor.com/"
    echo
    exit 1
fi
success "CotEditor.app found"

# Is cot CLI already on PATH?
COT_BIN="$(command -v cot 2>/dev/null || true)"
if [[ -n "$COT_BIN" ]]; then
    success "cot CLI at $COT_BIN"
else
    # Try to symlink cot CLI into /usr/local/bin.
    if [[ -w /usr/local/bin ]]; then
        ln -sf "$COT_APP" /usr/local/bin/cot
        success "cot CLI linked to /usr/local/bin/cot"
    else
        warn "cot CLI is not on PATH and /usr/local/bin is not writable."
        echo
        echo "  Create the symlink manually with sudo:"
        echo
        echo "      sudo ln -s $COT_APP /usr/local/bin/cot"
        echo
    fi
fi

# --- legacy cleanup ---------------------------------------------------------

if [[ -f "$LEGACY_BIN" ]]; then
    info "Removing legacy server binary at $LEGACY_BIN"
    rm -f "$LEGACY_BIN"
fi

# --- directories ------------------------------------------------------------

mkdir -p "$APPS_SCRIPTS" "$LAUNCH_AGENTS" "$SUPPORT_BIN"

# --- cotmate -----------------------------------------------------------------

#info "Installing cotmate to $SUPPORT_BIN/cotmate"
install -m 0755 "$REPO_DIR/bin/cotmate" "$SUPPORT_BIN/cotmate"
success "cotmate installed"

# --- launcher + watcher -----------------------------------------------------

install -m 0755 "$REPO_DIR/scripts/cotmate-launcher.sh" \
    "$APPS_SCRIPTS/cotmate-launcher.sh"

if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
    install -m 0755 "$REPO_DIR/scripts/cotmate-watcher.sh" \
        "$APPS_SCRIPTS/cotmate-watcher.sh"
    success "Launcher and watcher installed"
else
    success "Launcher installed"
fi

# --- hook -------------------------------------------------------------------

HOOK_DEST="$APPS_SCRIPTS/CotMateHook.scptd"
if [[ -d "$HOOK_DEST" ]]; then
    #info "Refreshing existing CotEditor hook"
    rm -rf "$HOOK_DEST"
fi
#info "Installing CotEditor hook"
cp -R "$REPO_DIR/hooks/CotMateHook.scptd" "$HOOK_DEST"
success "CotEditor hook installed"

# --- launchd ----------------------------------------------------------------

if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
    #info "Installing launchd agent"
    sed "s|__HOME__|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    launchctl load   "$PLIST_DEST"
    success "Agent installed and loaded"
fi

# --- done -------------------------------------------------------------------

printf '\n%s────────────────────────────────────────────────────────────%s\n' "$DIM" "$RESET"
printf '%s cotmate installed successfully %s\n' "$BOLD$GREEN" "$RESET"
printf '%s────────────────────────────────────────────────────────────%s\n\n' "$DIM" "$RESET"

printf '  %scotmate%s     %s\n' "$BOLD" "$RESET" "$SUPPORT_BIN/cotmate"
printf '  %slauncher%s   %s\n' "$BOLD" "$RESET" "$APPS_SCRIPTS/cotmate-launcher.sh"
printf '  %shook%s       %s\n' "$BOLD" "$RESET" "$HOOK_DEST"

if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
    printf '  %swatcher%s    %s\n' "$BOLD" "$RESET" "$APPS_SCRIPTS/cotmate-watcher.sh"
    printf '  %sagent%s      %s\n' "$BOLD" "$RESET" "$PLIST_DEST"
else
    printf '  %swatcher%s    %s(not installed — minimal install)%s\n' "$BOLD" "$RESET" "$DIM" "$RESET"
    printf '  %sagent%s      %s(not installed — minimal install)%s\n' "$BOLD" "$RESET" "$DIM" "$RESET"
fi

echo

if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
    echo "  Quit CotEditor completely, then reopen it."
    printf '\n%s  cotmate will start automatically whenever CotEditor is running. %s\n\n' "$BOLD" "$RESET"
else
    echo "  Quit CotEditor completely, then reopen it."
    printf '\n%s  cotmate will start the first time you open a non-empty document. %s\n\n' "$BOLD" "$RESET"
fi

echo "  To monitor the log:"
echo
printf '      tail -f "%s/cotmate.log"\n' "$SUPPORT_DIR"
echo
echo "  Then on remote host where you want to remote edit files on, copy rmate and edit some file, for example:"
echo
echo "      scp vendor/rmate/rmate user@server:~/.local/bin/"
echo "      ssh user@server 'chmod +x ~/.local/bin/rmate'"
echo "      rmate your-file.txt"
echo