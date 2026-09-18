# rmate (vendored)

This directory contains a copy of the `rmate` client from
[aurora/rmate](https://github.com/aurora/rmate) by Harald Lapp.

CotMate vendors this file so that users have a working, dependency-free
`rmate` client to copy to their remote servers.  It is a pure Bash
script — no Ruby, no Python, no extra packages required on the remote
host.

## Provenance

- **Upstream:** https://github.com/aurora/rmate
- **File:** `rmate`
- **Version:** 1.0.2 (2019-04-08)
- **Status:** included unmodified

If you find a bug in `rmate` itself (as opposed to CotMate's server
side), please report it upstream:

    https://github.com/aurora/rmate/issues

If you want to fix a bug in `rmate`, submit the patch upstream.  Do not
patch the vendored copy in this repository — keeping it byte-identical
to upstream is deliberate, and it keeps the licensing story clean.

## License

`rmate` is licensed under the **GNU General Public License, version 3**.
The full license text is in `rmate.LICENSE` in this directory.

This means:

- You may use, modify, and redistribute `rmate` under the terms of
  the GPL v3.
- If you redistribute a modified version, you must also provide the
  modified source under the GPL v3.
- The GPL v3 does **not** affect the rest of CotMate, which lives in
  a separate directory tree and is licensed under the MIT License.

This arrangement — MIT project, GPL vendored file — is a standard
practice and is fully compatible with both licenses.  The two files
simply carry different licenses and are kept separate.

## Usage

Copy the `rmate` file to a `bin` directory on your remote host and make
it executable:

```sh
scp vendor/rmate/rmate user@server:~/.local/bin/
ssh user@server 'chmod +x ~/.local/bin/rmate'
```

Then, from a shell on the remote host:

```ssh
rmate /path/to/file
```

The file opens in CotEditor on your Mac. For full setup instructions, see the main README