# yazi

Configuration for the [yazi][] file manager
and `ya-pkg-review` for reviewing plugin upgrades.

[yazi]: https://yazi-rs.github.io/


## Setup

```sh
stow yazi
ya pkg install
```

`ya pkg install` deploys the plugins from `package.toml`
at their pinned revisions.
The plugins in [Unmanaged plugins](#unmanaged-plugins)
need to be installed manually.


## System dependencies

| Plugin                    | Needs              |
| ------------------------- | ------------------ |
| `boydaihungst/mediainfo`  | `mediainfo`        |
| `kirasok/torrent-preview` | `transmission-cli` |
| `orhnk/system-clipboard`  | `clipboard` (AUR)  |
| `Rolv-Apneseth/starship`  | `starship`         |
| `ouch`                    | `ouch`             |


## Unmanaged plugins

These are referenced in the configuration
but not listed in `package.toml`.
Clone them into `~/.config/yazi/plugins/<name>.yazi` manually.

| Plugin         | Source | Used in       |
| -------------- | ------ | ------------- |
| `ouch`         | fork   | `yazi.toml`   |
| `goto-sibling` | own    | `keymap.toml` |

A plugin must not be both cloned manually and listed in `package.toml`,
see [Caveats](#caveats).


## Upgrading plugins

1. Run `ya-pkg-review`.
   It shows the pending commits of each package through the git pager,
   asks which upgrades to accept,
   and runs `ya pkg upgrade` for them after confirming a summary.
2. Commit `package.toml`.
3. On the other machines,
   pull the dotfiles and run `ya pkg install`.
   This deploys the reviewed revisions
   without having to review them again.


## Caveats

Notes on `ya pkg` behavior,
taken from the `yazi-cli/src/package/` sources.

- `ya pkg` rewrites `package.toml` on every `add`, `upgrade`, `delete`
  and after each package during `install`.
  Comments, formatting and unknown keys are lost,
  so document things here instead.
- A `rev` starting with `=` pins the package.
  `ya pkg upgrade` skips it,
  but `ya pkg install` still deploys the pinned revision.
- Packages can only come from GitHub.
  `owner/name` refers to the repository `owner/name.yazi`,
  and `owner/repo:name` to the directory `name.yazi` in `owner/repo`.
  Forks need to follow the same naming.
- The package repositories are cloned to
  `${XDG_CACHE_HOME:-~/.cache}/yazi/packages/<hash>`.
- Before overwriting a deployed plugin,
  `ya pkg` compares its files against the `hash` in `package.toml`
  and aborts on a mismatch,
  which also stops `ya pkg install` for all following packages.
  A manual clone in place of a listed package therefore fails,
  and `--discard` would overwrite the clone's files.
