# CotMate

> rmate-compatible remote editing for CotEditor.

CotMate lets you open files on remote servers in your local
[CotEditor](https://coteditor.com/) — the same way TextMate users have used
`rmate` for over a decade. Point `rmate` at a file over SSH, edit it
locally, save, and the changes go straight back to the remote host.

- **No Ruby.** Pure Python server, pure Bash client.
- **No sudo.** Everything runs as your normal user.
- **No daemons.** The server starts when CotEditor launches and stops
  when you quit it.

---

## Why

TextMate has built-in support for `rmate` — a tiny protocol that lets a
remote shell tell your local editor to open a file. CotEditor has no such
support. CotMate bridges that gap: it listens on the standard `rmate` port
(52698), materialises remote files as local mirrors, opens them in
CotEditor, and streams your saves back to the remote host over the same
SSH connection that `rmate` opened.

```
  remote shell                  local Mac
  ────────────                  ─────────
  rmate /tmp/foo.txt  ──ssh──▶  CotMate :52698
                                      │
                                      ▼
                                ~/Library/.../mirrors/…
                                      │
                                      ▼
                                  CotEditor
                                      │
                                      ▼  (on save)
                                   CotMate
                                      │
                                      ▼
  /tmp/foo.txt  ◀──────────────  save command
```

---

## Requirements

- macOS 12 (Monterey) or later
- [CotEditor 4.x](https://coteditor.com/)
- Python 3.8+ (the system Python 3 on Monterey is fine)
- The CotEditor CLI (`cot`). Enable it once via
  **CotEditor → Help → Install Command Line Tool**, or symlink
  `/Applications/CotEditor.app/Contents/SharedSupport/bin/cot`
  into a directory on your `$PATH`.

---

## Install

```sh
git clone https://github.com/<you>/cotmate.git
cd cotmate
./install.sh
```

The installer:

1. Copies the server to `~/.local/bin/cotmate`.
2. Copies the launcher and watcher scripts into
   `~/Library/Application Scripts/com.coteditor.CotEditor/`.
3. Installs a launchd agent at
   `~/Library/LaunchAgents/com.cotmate.watcher.plist`.
4. Installs the optional CotEditor hook bundle.
5. Loads the agent.

Then **quit and relaunch CotEditor** and you're done.

### Minimal install (no launchd agent)

If you'd rather not have a background agent, run:

```sh
./install.sh --no-launchd
```

CotMate will then start the first time you open any document in
CotEditor, and stop when CotEditor quits.

---

## Remote setup

CotMate ships with a pure-Bash `rmate` client so you don't need Ruby on
your servers:

```sh
scp bin/rmate user@server:~/.local/bin/
ssh user@server 'chmod +x ~/.local/bin/rmate'
```

Make sure `~/.local/bin` is on your remote `$PATH`. Now, from anywhere on
the remote host:

```sh
rmate /tmp/notes.txt
```

The file opens in CotEditor on your Mac. Save, and the remote file is
updated. Close the CotEditor window to end the session.

If you prefer to use the official Ruby `rmate`, that works too — CotMate
speaks the same protocol.

---

## How it works

- **Server** (`bin/cotmate`): a small Python TCP server listening on
  `127.0.0.1:52698`. It receives `open`, `save`, and `close` commands
  from `rmate`, writes each remote file into
  `~/Library/Application Support/CotMate/mirrors/<host>/…`, and opens it
  in CotEditor via the `cot` CLI. A polling thread watches each mirror
  for changes and sends `save` commands back over the originating
  connection.
- **Launcher** (`scripts/cotmate-launcher.sh`): starts the server if it
  isn't already running, and spawns a watchdog that kills it when
  CotEditor quits.
- **Watcher** (`scripts/cotmate-watcher.sh`): a tiny launchd-managed
  script that notices whenever CotEditor is launched and calls the
  launcher.
- **Hook** (`hooks/CotMateHook.scptd`): fires on `document opened` as a
  secondary trigger, useful when the watcher isn't installed.

---

## Usage notes

- **Same file twice.** If two `rmate` sessions try to open the same
  remote path, the second one is politely rejected and logged. This
  matches how most editors handle duplicate opens and prevents
  last-writer-wins data loss.
- **Mirror files.** Local mirrors live under
  `~/Library/Application Support/CotMate/mirrors/` and are wiped at each
  server start. They are not meant to be edited directly.
- **Log.** `~/Library/Application Support/CotMate/cotmate.log`. Rotated
  automatically by the launcher at 1000 lines.
- **Port.** 52698 (the standard `rmate` port). If you need a different
  one, pass `--port` to `cotmate`.

---

## Troubleshooting

See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).

The three commands to run first:

```sh
lsof -iTCP:52698 -sTCP:LISTEN                 # is anything listening?
cat ~/Library/Application\ Support/CotMate/cotmate.pid
tail -50 ~/Library/Application\ Support/CotMate/cotmate.log
```

---

## Uninstall

```sh
./uninstall.sh
```

Removes every file CotMate installed and unloads the launchd agent. Your
CotEditor install is untouched.

---

## Credits

- The `rmate` protocol and the bundled Bash client come from
  [aurora/rmate](https://github.com/aurora/rmate) by Harald Lapp.
- CotEditor is by 1024jp.

## License

CotMate is released under the MIT License — see [`LICENSE`](LICENSE).
The bundled `bin/rmate` is licensed under the GNU GPL v3 by its original
author; see [`bin/rmate.LICENSE`](bin/rmate.LICENSE) for details.