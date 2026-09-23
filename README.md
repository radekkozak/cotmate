<div id="toc">
  <ul align="center" style="list-style: none">
    <summary>
      	<h1>cotmate</h1><br/>
		<h2>remote editing for CotEditor</h2>
	</summary>
  </ul>
</div>
<p align="center">
	<img alt="GitHub Actions Workflow Status" src="https://img.shields.io/github/actions/workflow/status/radekkozak/cotmate/tests.yml?branch=main&style=flat-square">
	<img alt="GitHub License" src="https://img.shields.io/github/license/radekkozak/cotmate?style=flat-square">
	<img alt="GitHub Release" src="https://img.shields.io/github/v/release/radekkozak/cotmate?style=flat-square">
</p><br/>

## About

`cotmate` is CotEditor's best mate. It lets you open and edit files on remote servers via SSH session in
[CotEditor](https://coteditor.com/) — the same way TextMate users have used
`rmate` for over a decade. `cotmate` is ***rmate-compatible*** which means you can point 
`rmate` at a file over SSH, edit it locally, save, and the changes 
go straight back to the remote host.

- **No Ruby.** `cotmate` is pure Python, [rmate](vendor/rmate/rmate) is pure Bash.
- **No sudo.** everything runs as your normal user.
- **No daemons.** `cotmate` starts when CotEditor launches and stops
  when you quit it.

<br/>

> [!TIP]
> **You can still use TextMate with rmate as before** - essentialy you can juggle whichever editor you fancy.
>
> If you prefer to use the official Ruby version of `rmate` that should work too — `cotmate`
> speaks essentialy the same protocol

<br/>

> [!IMPORTANT]
> It is recommended that only one editor at a time is opened for the same remote file (`52698` port is used).
>
> If both TextMate and CotEditor are editing the same remote file, last editor that saves the file wins ;)

<br/>

## The _why_ behind the `cotmate`

TextMate has built-in support for `rmate` — a tiny protocol that lets a
remote shell tell your local editor to open a file. CotEditor has no such
support. `cotmate` bridges that gap: it listens on the standard `rmate` port
(52698), materialises remote files as local mirrors, opens them in
CotEditor, and streams your saves back to the remote host over the same
SSH connection that `rmate` opened.<br/>

```
  remote shell                  local Mac
  ────────────                  ─────────
  rmate /tmp/foo.txt  ──ssh──▶  cotmate :52698
                                      │
                                      ▼
                                ~/Library/.../CotMate/mirrors/…
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

## Requirements

- macOS 12 (Monterey) or later
	- **Maintainer-tested:** macOS 12.7.6 (Monterey) — yes, this is still my daily driver in 2026 - brilliant macOS version in my opinion (and it works amazingly great even on my maxed-out, rusty but trusty, MBP Pro Mid 2012). Compatibility with this release is verified by hand before each release.
	- **CI-tested:** macOS 26 (Tahoe), arm64. GitHub retired all runners
	  older than macOS 14, so Monterey compatibility rests on the code's
	  conservative design (stdlib only, Python 3.9.6 syntax) plus manual
	  testing - not on automated CI.
- CotEditor 4.5.9 or later — tested with 4.5.9 (575), the last release supporting macOS 12 Monterey
- Python 3.9+ (usually provided via Xcode Command Line Tools but you can install via `mise` or some other tools)
- The CotEditor CLI (`cot`). See official website for [how to install cot cli](https://coteditor.com/cot)

## Install

```sh
git clone https://github.com/radekkozak/cotmate.git
cd cotmate
./install.sh
```

> [!IMPORTANT]
> If `./install.sh` fails with "permission denied", it probably means the executable bit
> didn't survive the checkout. Run `chmod +x install.sh uninstall.sh scripts/*.sh`
> and retry, or invoke it as `bash install.sh`.

<br/>

After that you should be up and running. Just **quit and relaunch CotEditor** and you're done.

What does the installer do:

1. Copies `cotmate` to `~/Library/Application Support/CotMate/bin/cotmate`.
2. Copies the launcher and watcher scripts into
   `~/Library/Application Scripts/com.coteditor.CotEditor/`.
3. Installs a launchd agent at
   `~/Library/LaunchAgents/com.radekkozak.cotmate.watcher.plist`.
4. Installs the optional CotEditor hook bundle.
5. Loads the agent.

### Minimal install (no launchd agent)

If you'd rather not have a background agent then run:

```sh
./install.sh --no-launchd
```

> [!TIP]
> **Not recommended if you care about simplicity**
>
> In this scenario `cotmate` will start and listen for a remote connection from `rmate`
> **only when you open any non-empty document** in CotEditor and stop when CotEditor quits.
> The "non-empty document" is required because CotEditor doesn't offer a hook into its
> own lifecycle (namely we cannot hook into when CotEditor is launched) - only into
> `document opened` and `document saved` events. 

## Remote setup

`cotmate` ships with a pure-Bash `rmate` client so you don't need Ruby on
your server:

```sh
scp vendor/rmate/rmate user@server:~/.local/bin/
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

## How it works

- **cotmate** (`bin/cotmate`, installed to
  `~/Library/Application Support/CotMate/bin/cotmate)`: a small Python TCP server
  listening on `127.0.0.1:52698`. It receives `open`, `save`, and `close` commands
  from `rmate`, writes each remote file into
  `~/Library/Application Support/CotMate/mirrors/<host>/…`, and opens it
  in CotEditor via the `cot` CLI. A polling thread watches each mirror
  for changes and sends `save` commands back over the originating
  connection.
- **launcher** (`scripts/cotmate-launcher.sh`): starts the server if it
  isn't already running, and spawns a watchdog that kills it when
  CotEditor quits.
- **watcher** (`scripts/cotmate-watcher.sh`): a tiny launchd-managed
  script that notices whenever CotEditor is launched and calls the
  launcher.
- **CotEditor hook** (`hooks/CotMateHook.scptd`): fires on `document opened` as a
  secondary trigger, useful when the watcher isn't installed.

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
- **Port.** 52698 (the standard `rmate` port)

## Troubleshooting

See [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).

The three commands to run first:

```sh
lsof -iTCP:52698 -sTCP:LISTEN # is anything listening?
cat ~/Library/Application\ Support/CotMate/cotmate.pid
tail -50 ~/Library/Application\ Support/CotMate/cotmate.log
```

## Uninstall

```sh
./uninstall.sh
```

Removes every file `cotmate` installed and unloads the launchd agent. Your
CotEditor install is untouched.

## Contributing

If you happen to use [CotEditor](https://coteditor.com/) daily on your macOS and be so nice and willing to test `cotmate` in real-life scenarios on your machine it would be greatly appreciated. I cannot own every MacBook machine out there (duh) and have every macOS system installed to be 100% sure, and CI testing on Github can offer certainty only to a point of running some unit tests and checks. 

If you find any problem do not hesitate to open an [ISSUE](https://github.com/radekkozak/cotmate/issues/new). 

If you would like to contribute code you can do so through GitHub by forking the repository and sending a pull request.

When submitting code, please make every effort to follow existing conventions and style in order to keep the code as readable as possible. Please also make sure your code compiles and passes all tests by running `python3 -m unittest discover -s tests -v` locally before submitting. 

## Credits

- The `rmate` protocol and the bundled Bash client come from
  [aurora/rmate](https://github.com/aurora/rmate) by [Harald Lapp](https://github.com/aurora).
- [CotEditor](https://github.com/coteditor/) is by [1024jp](https://github.com/1024jp).

## License

`cotmate` is released under the MIT License — see [`LICENSE`](LICENSE).

The bundled `rmate` is licensed under the GNU GPL v3 by its original
author - see [`rmate.LICENSE`](vendor/rmate/rmate.LICENSE).
