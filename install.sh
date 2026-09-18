#!/usr/bin/env bash
#
# CotMate installer
# Wires up the server, launcher, watcher, launchd agent and CotEditor hook.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- destinations -----------------------------------------------------------

BIN_DIR="$HOME/.local/bin"
APPS_SCRIPTS="$HOME/Library/Application Scripts/com.coteditor.CotEditor"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
SUPPORT_DIR="$HOME/Library/Application Support/CotMate"

PLIST_LABEL="com.radekkozak.cotmate.watcher"
PLIST_SRC="$REPO_DIR/launchd/${PLIST_LABEL}.plist"
PLIST_DEST="$LAUNCH_AGENTS/${PLIST_LABEL}.plist"

INSTALL_LAUNCHD=1
if [[ "${1:-}" == "--no-launchd" ]]; then
    INSTALL_LAUNCHD=0
fi

# --- preflight --------------------------------------------------------------

echo "CotMate installer"
echo "─────────────────"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "error: CotMate is macOS-only." >&2
    exit 1
fi

# --- Python 3.9+ check ------------------------------------------------------

PYTHON_BIN="$(command -v python3 2>/dev/null || true)"

if [[ -z "$PYTHON_BIN" ]]; then
    echo "error: python3 not found on PATH." >&2
    echo "" >&2
    echo "       macOS provides Python 3.9 via the Xcode Command Line Tools." >&2
    echo "       Install them with:" >&2
    echo "" >&2
    echo "           xcode-select --install" >&2
    echo "" >&2
    exit 1
fi

PYVER="$("$PYTHON_BIN" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])')"

if ! "$PYTHON_BIN" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
    echo "error: CotMate requires Python 3.9 or newer." >&2
    echo "       Found: $PYVER at $PYTHON_BIN" >&2
    echo "" >&2
    echo "       The system Python shipped with macOS Monterey and later" >&2
    echo "       is 3.9.6, which is sufficient.  Install the Command Line" >&2
    echo "       Tools with:" >&2
    echo "" >&2
    echo "           xcode-select --install" >&2
    echo "" >&2
    exit 1
fi

echo "→ python3: $PYTHON_BIN ($PYVER)"

# Also verify the *system* Python (what launchd will resolve to).
if [[ -x /usr/bin/python3 ]]; then
    if ! /usr/bin/python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
        echo "warning: /usr/bin/python3 is older than 3.9." >&2
        echo "         launchd will use it.  You may need to edit the" >&2
        echo "         launcher to point at a newer Python." >&2
    fi
fi

if ! command -v cot >/dev/null 2>&1; then
    COT_FALLBACK="/Applications/CotEditor.app/Contents/SharedSupport/bin/cot"
    if [[ ! -x "$COT_FALLBACK" ]]; then
        echo "warning: 'cot' CLI not found." >&2
        echo "         CotMate needs it. In CotEditor, run:" >&2
        echo "         Help → Install Command Line Tool" >&2
        read -r -p "Continue anyway? [y/N] " reply
        [[ "${reply,,}" == "y" ]] || exit 1
    fi
fi

# --- directories ------------------------------------------------------------

mkdir -p "$BIN_DIR" "$APPS_SCRIPTS" "$LAUNCH_AGENTS" "$SUPPORT_DIR"

# --- server -----------------------------------------------------------------

echo "→ installing server to $BIN_DIR/cotmate"
install -m 0755 "$REPO_DIR/bin/cotmate" "$BIN_DIR/cotmate"

# --- launcher + watcher -----------------------------------------------------

echo "→ installing launcher + watcher"
install -m 0755 "$REPO_DIR/scripts/cotmate-launcher.sh" \
    "$APPS_SCRIPTS/cotmate-launcher.sh"

if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
    install -m 0755 "$REPO_DIR/scripts/cotmate-watcher.sh" \
        "$APPS_SCRIPTS/cotmate-watcher.sh"
fi

# --- hook (always installed) ------------------------------------------------

HOOK_DEST="$APPS_SCRIPTS/CotMateHook.scptd"
if [[ -d "$HOOK_DEST" ]]; then
    echo "→ hook already present, refreshing"
    rm -rf "$HOOK_DEST"
fi
echo "→ installing CotEditor hook"
cp -R "$REPO_DIR/hooks/CotMateHook.scptd" "$HOOK_DEST"

# --- launchd ----------------------------------------------------------------

if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
    echo "→ installing launchd agent"
    sed "s|__HOME__|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"

    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    launchctl load   "$PLIST_DEST"
fi

# --- done -------------------------------------------------------------------

cat <<EOF

────────────────────────────────────────────────────────────
CotMate installed.

  server    $BIN_DIR/cotmate
  launcher  $APPS_SCRIPTS/cotmate-launcher.sh
  hook      $HOOK_DEST
$(
    if [[ $INSTALL_LAUNCHD -eq 1 ]]; then
        echo "  agent     $PLIST_DEST"
    else
        echo "  agent     (skipped — minimal install)"
    fi
)

Quit CotEditor completely, then reopen it. Open any file and check the log:

  tail -f "$SUPPORT_DIR/cotmate.log"

Then from a remote host:

  scp bin/rmate user@server:~/.local/bin/
  ssh user@server 'chmod +x ~/.local/bin/rmate'
  rmate /tmp/test.txt
────────────────────────────────────────────────────────────
EOF