# cotmate

_**rmate-compatible** remote editing for CotEditor_

`cotmate` lets you open files on remote servers in your local
[CotEditor](https://coteditor.com/) — the same way TextMate users have used
`rmate` for over a decade. Point `rmate` at a file over SSH, edit it
locally, save, and the changes go straight back to the remote host.

- **No Ruby.** `cotmate` is pure Python, [rmate](vendor/rmate/rmate) is pure Bash.
- **No sudo.** everything runs as your normal user.
- **No daemons.** `cotmate` starts when CotEditor launches and stops
  when you quit it.
  
> [!TIP]
> **You can still use TextMate with rmate as before** - essentialy you can joggle whichever editor you fancy at particular moment

> [!IMPORTANT]
> It is recommended that only one editor at a time is opened for the same remote file (`52698` port is used).
> If both TextMate and CotEditor are editing the same remote file, last editor that saves it wins ;)

---

## The _why_ behing the `cotmate`

TextMate has built-in support for `rmate` — a tiny protocol that lets a
remote shell tell your local editor to open a file. CotEditor has no such
support. `cotmate` bridges that gap: it listens on the standard `rmate` port
(52698), materialises remote files as local mirrors, opens them in
CotEditor, and streams your saves back to the remote host over the same
SSH connection that `rmate` opened.

```
  remote shell                  local Mac
  ────────────                  ─────────
  rmate /tmp/foo.txt  ──ssh──▶  cotmate :52698
                                      │
                                      ▼
                                ~/Library/.../mirrors/…
                                      │
                                      ▼
                                  CotEditor
                                      │
                                      ▼  (on save)
                                   cotmate
                                      │
                                      ▼
  /tmp/foo.txt  ◀──────────────  save command
```

---

## Requirements

- macOS 12 (Monterey) or later
- [CotEditor 4.x](https://coteditor.com/) (tested with CotEditor 4.5.9)
- Python 3.9+ (usually provided via Xcode Command Line Tools but you can install via `mise` or some other tools)
- The CotEditor CLI (`cot`). Enable it once via
  **CotEditor → Help → Install Command Line Tool**, or symlink
  `/Applications/CotEditor.app/Contents/SharedSupport/bin/cot`
  into a directory on your `$PATH`. See official website for [cot](https://coteditor.com/cot)

---

## Install

```sh
git clone https://github.com/radekkozak/cotmate.git
cd cotmate
./install.sh
```

The installer:

1. Copies `cotmate` to `~/.local/bin/cotmate`.
2. Copies the launcher and watcher scripts into
   `~/Library/Application Scripts/com.coteditor.CotEditor/`.
3. Installs a launchd agent at
   `~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist`.
4. Installs the optional CotEditor hook bundle.
5. Loads the agent.

Then **quit and relaunch CotEditor** and you're done.

### Minimal install (no launchd agent)

> [!TIP]
> Not recommended if you care about simplicity.

If you'd rather not have a background agent then run:

```sh
./install.sh --no-launchd
```

`cotmate` will then start the first time you open any non-empty document in
CotEditor, and stop when CotEditor quits

---

## Remote setup

`cotmate` ships with a pure-Bash `rmate` client so you don't need Ruby on
your server:

```sh
scp bin/rmate user@server:~/.local/bin/
ssh user@server 'chmod +x ~/.local/bin/rmate'
```

Make sure `~/.local/bin` is on your remote `$PATH`. Now, from anywhere on
the remote host:

```sh
rmate test-file.txt
```

The file opens in CotEditor on your Mac. Save, and the remote file is
updated. Close the CotEditor window to end the session.

If you prefer to use the official Ruby `rmate`, that should work too — `cotmate`
speaks essentialy the same protocol

---

## How it works

- **cotmate** (`bin/cotmate`): a small Python TCP server listening on
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

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

The three commands to run first:

```sh
lsof -iTCP:52698 -sTCP:LISTEN # is anything listening?
cat ~/Library/Application\ Support/CotMate/cotmate.pid
tail -50 ~/Library/Application\ Support/CotMate/cotmate.log
```

---

## Uninstall

```sh
./uninstall.sh
```

Removes every file `cotmate` installed and unloads the launchd agent. Your
CotEditor install is untouched.

---

## Credits

- The `rmate` protocol and the bundled Bash client come from
  [aurora/rmate](https://github.com/aurora/rmate) by [Harald Lapp](https://github.com/aurora).
- [CotEditor](https://github.com/coteditor/) is by [1024jp](https://github.com/1024jp).

## License

`cotmate` is released under the MIT License — see [`LICENSE`](LICENSE).
The bundled `bin/rmate` is licensed under the GNU GPL v3 by its original
author; see [`vendor/rmate/rmate.LICENSE`](vendor/rmate/rmate.LICENSE) for details.