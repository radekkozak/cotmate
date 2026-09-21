# Change Log

All notable changes to `cotmate` are documented here.

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
