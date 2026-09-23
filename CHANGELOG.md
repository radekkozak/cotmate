# Change Log

All notable changes to `cotmate` are documented here.

## 1.3.1

### Fixed

- `install.sh` / `uninstall.sh`: replaced deprecated `launchctl
  load`/`unload` with the modern `launchctl bootstrap`/`bootout`
  API. The legacy commands were removed in macOS Monterey 12.3 and
  could fail silently on newer systems.

## 1.3.0

### Changed

- CotEditor scripts are now installed into a dedicated `CotMate/`
  subfolder inside `~/Library/Application Scripts/com.coteditor.CotEditor/`,
  grouping them under a single **CotMate** submenu in CotEditor's
  Script menu (previously they appeared as three separate top-level entries).

### Added

- Installer now removes legacy flat-layout files from previous versions.

### Migration

- Re-run `./install.sh` then quit and reopen CotEditor.

## 1.2.2
--------------------------

### Fixed

- Reopening a remote file after closing its CotEditor window no
  longer fails with "rejected duplicate open". The newer `rmate`
  session now takes over from the older one: the previous client
  receives `close`, its mirror is unlinked, and a fresh session is
  started. This matches the behaviour of TextMate's rmate.

  The rejection path is retained as a fallback for the rare case
  where two sessions race within the same millisecond, so nothing
  regresses.

## 1.2.1

### Fixed

- a quirk around how official Ruby's version of `rmate` works (adding extra newline after a body)

## 1.2.0

### Refactored internal structure

- Split the server into five explicit classes: `Config`,
  `DocumentRegistry`, `RemoteDocument`, `Session`, `Server`. No
  behaviour change; the wire protocol is unchanged.
- Removed module-level globals in favour of constructor-injected
  dependencies, which is what makes the code testable.

### Added

- `--version` flag.
- Startup log now reports `cotmate` version, Python version, and macOS
  version, so a single log line reproduces most bug reports.
- 40+ unittest tests covering wire format, document lifecycle,
  registry semantics, and session dispatch.
- GitHub Actions CI, testing against system Python 3.9.6 and the
  latest stable Python on `macos-26`.
- `NOTICE` and `vendor/rmate/README.md` documenting third-party
  licensing.

### Changed

- `nc -z` health-check probes from the launcher no longer appear in
  `cotmate.log`; only real rmate sessions are logged.
- README documents how CotMate chooses a Python interpreter and how to
  override it with `COTMATE_PYTHON`.
- README includes a `chmod +x` fallback for the rare case where the
  executable bit doesn't survive a clone.

### Fixed

- `uninstall.sh`: replaced `kill $ORPHANS` with
  `kill "${ORPHANS[@]}"` (shellcheck SC2086).

## 1.1.0

### Bundled installation structure

- `cotmate` now installs to
  `~/Library/Application Support/CotMate/bin/cotmate` instead of
  `~/.local/bin/cotmate`, so every CotMate artifact lives under one
  folder.
- `install.sh` and `uninstall.sh` updated for the new layout, and both
  clean up the legacy `~/.local/bin/cotmate` on upgrade.

## 1.0.0

### First fully working version

- Uses pure-Bash `aurora/rmate` (final latest v1.0.2).
- Tested on macOS 12.7.6 (Monterey) with CotEditor v4.5.9 and official
  `cot` CLI v2.9.2.
