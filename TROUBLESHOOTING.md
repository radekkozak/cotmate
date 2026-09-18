# Troubleshooting

Almost every `cotmate` problem falls into one of five categories. Work
through them in order.

---

## 1. Ground truth: three commands to run first

Before anything else, run these three commands on your Mac. Their
output tells you exactly where the problem is.

    # Is anything actually listening on the rmate port?
    lsof -iTCP:52698 -sTCP:LISTEN

    # What PID did the server record?
    cat ~/Library/Application\ Support/CotMate/cotmate.pid

    # What has the server been doing?
    tail -50 ~/Library/Application\ Support/CotMate/cotmate.log

Interpretation:

| What you see | What it means | Go to |
|---|---|---|
| `lsof` shows nothing | Server isn't running | §2 |
| `lsof` shows a listener, but pidfile is missing or points elsewhere | Orphan server from an earlier run | §3 |
| `lsof` shows a listener, pidfile matches, log looks healthy | Server is fine; problem is remote-side | §4 |
| `lsof` shows a listener on a *different* port | Something else grabbed 52698 | §5 |

---

## 2. Server isn't running

### Check the launchd watcher is loaded

    launchctl list | grep cotmate

You should see a line containing `com.radekkozak.cotmate.watcher`. If
you don't:

    launchctl load ~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist

### Check the watcher is actually running

    ps aux | grep cotmate-watcher | grep -v grep

If the process isn't there but the plist is loaded and `KeepAlive` is
`true`, launchd should respawn it within a few seconds. Wait, then
re-check.

### Check CotEditor itself is running

    pgrep -x CotEditor

If CotEditor is running and the watcher is loaded, the server should be
running within ~2 seconds. If it isn't, tail the watcher's launchd
logs:

    tail -50 ~/Library/Logs/cotmate-watcher.log
    tail -50 ~/Library/Logs/cotmate-watcher.err

### Force a manual start

    ~/Library/Application\ Scripts/com.coteditor.CotEditor/cotmate-launcher.sh

Then run the three ground-truth commands again. If this starts the
server but launchd doesn't, the plist is the problem — re-run
`./install.sh`.

---

## 3. Orphan server (listener exists, pidfile doesn't match)

This is the most common `cotmate` support case. It happens when an
earlier version of the server was left running — usually because a
previous launcher, or a manual invocation, started a server that the
current watchdog doesn't know about.

Symptom: `lsof -iTCP:52698 -sTCP:LISTEN` shows a live process, but
`cat cotmate.pid` either fails (no file) or shows a PID that isn't the
one `lsof` reported.

Fix:

    # Kill whatever is bound to the port, no matter its name.
    kill $(lsof -tiTCP:52698 -sTCP:LISTEN)

    # Remove any stale pidfile.
    rm -f ~/Library/Application\ Support/CotMate/cotmate.pid

    # Reload the agent so a fresh server starts on next launch.
    launchctl unload ~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist
    launchctl load  ~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist

Then quit and relaunch CotEditor.

> Why `kill $(lsof …)` instead of `pkill cotmate`? Because a process
> started via a different command line (a manual `python3 …`, an old
> script, a stale launchd job) won't match `pkill cotmate`. `lsof` is
> the only reliable way to find who is actually bound to the port.

---

## 4. Remote-side problems

The server is fine; `rmate` on the remote host can't reach it, or opens
but doesn't save.

### `rmate` says "Unable to connect to TextMate on localhost:52698"

`rmate` connects to `localhost:52698` **on the remote host**, which
must be forwarded back to your Mac over SSH. Two ways to set that up:

**Option A — reverse tunnel on connect.** In your `~/.ssh/config`:

    Host myserver
        RemoteForward 52698 127.0.0.1:52698
        ExitOnForwardFailure yes

Then just `ssh myserver`. Every session gets the tunnel.

**Option B — one-off.** On the command line:

    ssh -R 52698:localhost:52698 user@server

Verify the tunnel is up (from the remote host):

    nc -z localhost 52698 && echo "tunnel ok"

### `rmate` opens the file, but saves don't reach the remote

Check `rmate` is running in **wait mode**:

    rmate -w /tmp/test.txt

Without `-w`, the client backgrounds itself and can be killed by SIGHUP
when the SSH session ends.

### Second `rmate` on the same file is rejected

This is intentional. `cotmate` refuses to open the same remote path twice
concurrently, because two CotEditor windows writing back to one remote
file is last-writer-wins. Look for this line in the log:

    [cotmate] rejected duplicate open of host:/path/to/file (already open)

Close the first window, then re-run `rmate`.

### `rmate` is not installed on the remote host

The remote needs `rmate`. `cotmate` vendors a pure-Bash version that
needs no Ruby:

    scp vendor/rmate/rmate user@server:~/.local/bin/
    ssh user@server 'chmod +x ~/.local/bin/rmate'

Make sure `~/.local/bin` is on the remote `$PATH`:

    ssh user@server 'echo $PATH | tr ":" "\n" | grep local'

### `rmate` is Bash-based but the remote shell isn't Bash

The vendored `rmate` requires Bash. On remote hosts where `/bin/sh` is
`dash` (Debian/Ubuntu) or `ash` (Alpine), invoke it explicitly:

    bash ~/.local/bin/rmate /tmp/test.txt

or make sure its shebang line (`#!/usr/bin/env bash`) is being honored,
which requires `bash` to be installed. It usually is; if not:

    # Debian/Ubuntu
    sudo apt install bash

    # Alpine
    sudo apk add bash

---

## 5. Port 52698 is taken by something else

Check what's bound:

    lsof -iTCP:52698 -sTCP:LISTEN

Common culprits:

- **TextMate itself.** If you have TextMate running with its built-in
  rmate listener on the same port, only one server can bind. Quit
  TextMate, or run `cotmate` on a different port (`cotmate --port 52699`
  and matching `rmate -p 52699`).
- **A stale `cotmate` from a previous version.** Kill it (§3) and reload
  the agent.

---

## 6. "The operation couldn't be completed" in Console

This is a **scripting hook** error, not a server error. It means
CotEditor failed to compile `CotMateHook.scptd`.

Check:

    ls -la ~/Library/Application\ Scripts/com.coteditor.CotEditor/CotMateHook.scptd/Contents/Resources/Scripts/

The path must contain a `main.scpt` file. If it's missing or malformed,
re-run `./install.sh` — the installer refreshes the bundle
unconditionally.

If the error persists, the bundle's `Info.plist` may be missing the
`CotEditorHandlers` key, or the `main.scpt` file may contain JXA code
that CotEditor tried to compile as AppleScript. The hook must be
written in AppleScript, not JavaScript, for CotEditor 4.5.x on
Monterey.

---

## 7. "python3 not found" or version errors

`cotmate` needs Python 3.9 or newer. On every macOS from Monterey onward,
this is provided by the Xcode Command Line Tools. If you don't have
them:

    xcode-select --install

To check which interpreter launchd will use:

    /usr/bin/python3 --version

This should print `Python 3.9.6` or newer. If it doesn't, install the
CLT first.

To force a specific interpreter (e.g. Homebrew's Python), export
`COTMATE_PYTHON` before launching CotEditor:

    export COTMATE_PYTHON=/opt/homebrew/bin/python3.12

Then reload the launchd agent so the watcher inherits the variable, or
edit `EnvironmentVariables` in the plist directly.

---

## 8. Starting over

If you want to reset everything to a clean state without uninstalling:

    # Stop everything related to cotmate.
    launchctl unload ~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist
    pkill -f cotmate-watcher
    kill $(lsof -tiTCP:52698 -sTCP:LISTEN) 2>/dev/null

    # Wipe runtime state.
    rm -rf ~/Library/Application\ Support/CotMate

    # Reload.
    launchctl load ~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist

Then quit and relaunch CotEditor. A fresh `cotmate.log` and
`cotmate.pid` will appear within a couple of seconds.

---

## 9. Reporting a bug

If none of the above applies, open an issue with:

1. The output of the three ground-truth commands from §1.
2. Your macOS version (`sw_vers`).
3. Your CotEditor version (CotEditor → About CotEditor).
4. The last 50 lines of `~/Library/Application Support/CotMate/cotmate.log`.

The log almost always contains the answer. If it doesn't, the three
ground-truth commands will.