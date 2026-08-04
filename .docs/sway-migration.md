# i3 to Sway migration

Status: planning document, nothing implemented yet.
Scope: this repository (`~/dotfiles`), branch `master`
plus the machine branches `origin/dracaena` and `origin/piceoideae`.

## 1. Summary

The window manager config itself is the easy part.
Sway parses i3 config syntax,
so `i3/.config/i3/config` ports almost verbatim:
`bindsym`, `for_window`, `mode`, `client.*` colors, `hide_edge_borders`,
`floating_modifier`, `focus_on_window_activation`, `mouse_warping`,
workspace and resize bindings all carry over unchanged.

The work is everywhere else.
This repo has 42 stow packages,
and the X11 coupling is concentrated in a few clusters:

| Cluster | Packages | Verdict |
| --- | --- | --- |
| Session bootstrap | `xinit`, `xbindkeys` | Delete entirely, replace with a Sway session |
| Bar and tray | `polybar` | Rewrite for Waybar (polybar has no Wayland support) |
| Screen capture and sharing | `teiler`, `bin/shot`, `bin/i3lock-shot`, `xdg-desktop-portal` | Full retooling |
| Clipboard | `parcellite`, plus 8 `xsel`/`xclip` call sites | Swap to `wl-clipboard` + `cliphist` |
| Display management | `autorandr` (on `dracaena`), `mons`, `arandr`, `~/.screenlayout/*.sh` | Replace with `kanshi` |
| Image viewing and wallpaper | `feh` | Replace with `imv`/`swayimg` + `swaybg` |
| Compositing | `picom` | Delete, Sway composites natively |
| Input method | `fcitx` (fcitx **4**) | Port to fcitx5 |
| Color temperature | `redshift` (`adjustment-method=randr`) | Replace with `gammastep`/`wlsunset` |
| Launcher | `rofi` | Rebuild against `rofi-wayland`, or swap to `fuzzel` |

Roughly 25 of the 42 packages need no changes at all
(`beets`, `btop`, `cmus`, `git` except one script, `helix`, `htop`, `lftp`,
`mpd`, `noisetorch`, `pulse`, `readline`, `tools`, `youtube-dl`, and so on).

Two things are already in your favour:

- `zsh/.profile:41-44` already has a commented-out `exec sway` block,
  so the session entry point is half-designed.
- `bin/toggle-dark-mode` already uses `gsettings`/portals rather than anything X-specific.

## 2. What ports unchanged

From `i3/.config/i3/config`, no edits needed:

- All layout, focus, move, split, resize, fullscreen and floating bindings.
- Workspace switching and `move container to workspace`.
- `mode` blocks, including `$mode_system`, `$mode_focus`, `$mode_launcher`, `resize`.
- Color scheme (`client.focused` etc.), `font pango:...`, border settings, gaps.
- `bindsym --release button2 kill` and `bindsym --whole-window $mod+button2 floating toggle`.
- Media key bindings (`pactl`, `brightnessctl`) and the mpris bindings,
  though `mpris-rofi` itself depends on rofi.
- Notification bindings (`dunstctl`).

Sway-only replacements for i3-isms inside that file:

| i3 | Sway |
| --- | --- |
| `i3-nagbar` (exit confirmation, line 155) | `swaynag` |
| `i3-sensible-terminal` (lines 331, 384) | `$term` variable set to `alacritty`, or keep, it still works |
| `i3-msg exit` | `swaymsg exit` |
| `exec --no-startup-id` | `exec` (Sway ignores startup notification, the flag is accepted but meaningless) |

## 3. Replacement decisions, with alternatives and tradeoffs

### 3.1 Session bootstrap

Delete `xinit/` (`.xinitrc`, `.xprofile`, `.xserverrc`) and `xbindkeys/`.

`~/.xinitrc` currently does five things that need new homes:

1. `xrdb -merge` of `.Xresources` (lines 9-19).
   No Wayland equivalent.
   `Xft.dpi` needs to move to Sway `output ... scale` plus `fontconfig`,
   and to `xrdb` inside the Sway config only if XWayland clients still need it.
2. `xmodmap` (lines 13-23).
   Replace with `input type:keyboard { xkb_layout de; xkb_variant neo_qwertz }`
   (values taken from `fcitx/.config/fcitx/data/layout_override`).
   Anything that was a genuine `xmodmap` hack has to become a custom XKB variant,
   Sway has no runtime remapping equivalent.
3. Input method exports (lines 26-28), see 3.8.
4. Sourcing `/etc/X11/xinit/xinitrc.d/*.sh` (lines 35-40).
   This is what currently imports `DISPLAY` into the systemd user manager on Arch.
   Losing it is the single most under-appreciated breakage,
   see the note on session targets below.
5. `exec i3` (line 43).

**Options for launching Sway:**

| Option | Tradeoffs |
| --- | --- |
| `exec sway` from `zsh/.profile` on tty1 (already stubbed at lines 41-44) | Simplest, matches the current startx pattern. You must do `dbus-update-activation-environment` / `systemctl --user import-environment` yourself, and `graphical-session.target` is never reached, so `.system/smgood/smgood.service:4 (After=graphical-session.target)` and `redshift-gtk.service.d/override.conf (WantedBy=graphical-session.target)` stay unsatisfied. |
| `uwsm start sway` (recommended) | Puts the session under a proper systemd user scope, gets `graphical-session.target` and `sway-session.target` for free, propagates `XDG_CURRENT_DESKTOP=sway` correctly to portals, gives clean shutdown ordering. Extra dependency, and autostarts move from `exec` lines to systemd units. |
| Display manager (greetd + `tuigreet`) | Nice if you want a login prompt. Additional moving part you do not currently have (there is no DM config anywhere in this repo today). |

Recommendation: `uwsm`,
because two of your units already declare `graphical-session.target` ordering
and neither is actually satisfied under the current xinit setup.

`xbindkeys` (`b:8`/`b:9` mouse buttons to Page Up/Down via `xdotool`)
becomes native Sway bindings on `BTN_SIDE`/`BTN_EXTRA`,
but note the caveat: Sway can *bind* those buttons,
it cannot *synthesize* a Page Up keypress into a native Wayland client.
Options:

- Rebind the mouse buttons at the hardware/kernel level with `udev` hwdb
  or `input <id> map_...` so applications see the keys directly. Cleanest.
- Use `wtype` (works only for clients supporting virtual-keyboard protocol) or `ydotool`
  (needs a root daemon and `/dev/uinput` access). Both are worse than the hwdb route.

### 3.2 Bar and tray

Polybar is X11-only by upstream policy and will not be ported.
`polybar/.config/polybar/config.ini` is 500 lines and 27 modules.

Module-by-module port target:

| Polybar module | Waybar equivalent | Notes |
| --- | --- | --- |
| `i3` (line 133) | `sway/workspaces` | Direct. `pin-workspaces = true` maps to `all-outputs: false`. |
| `xwindow` (113) | `sway/window` | Direct. |
| `tray` (108) | `tray` | Polybar uses XEmbed, Waybar uses StatusNotifierItem. Apps that only do XEmbed (older `parcellite`) simply will not appear. |
| `filesystem`, `memory`, `cpu_usage`, `eth`, `battery`, `pulseaudio`, `backlight-acpi`, `mpd`, temperature modules | built-in Waybar modules | Straight port, all read `/proc`, sysfs, or D-Bus. |
| `date`, `wttr`, `updates`, `failed_units`, `kernel`, `cpu_load`, `gpu_usage`, `pulsesinksource`, `mpris` | `custom/*` | Scripts port unchanged, but see 3.3 for their `click-left` popups. |
| `xbacklight` (219) | delete | Already superseded by `backlight-acpi`. |
| `picom` (455) | delete | Meaningless under Sway. |

Scripts under `polybar/.config/polybar/scripts/`:

- `pulse-sink-source`, `systemd-units`: portable as-is.
- `wttr.py`: logic portable, but the `%{T5}` font-index and `%{F#...}` color tags
  are polybar syntax and need rewriting to Waybar's Pango markup.
- `polyyad.py` and `polyyadfile`: **not portable**.
  The script queries the pointer with `xdotool getmouselocation`,
  reads window geometry with `xdotool getwindowgeometry`,
  parses `xrandr -q` for screen size,
  and positions a `yad` dialog with absolute `--posx/--posy`.
  Wayland clients cannot position themselves, full stop.
  Options:
  1. Drop the popup and use Waybar tooltips instead (`tooltip-format`). Least work, least capable.
  2. Replace with `swaynag`, which the compositor positions. Text only, no scrolling.
  3. Replace with a `fuzzel --dmenu` / `rofi -dmenu` read-only list.
  4. Keep `yad` but let Sway place it via `for_window [app_id="yad"] floating enable, move position cursor`.
     Sway does have `move position cursor`, so this is actually viable
     and preserves the most behaviour.

`launch.sh` currently enumerates monitors with `polybar --list-all-monitors`
and passes `POLY_MONITOR` per output.
Waybar handles multi-output itself via the `output` key per bar,
so the whole launcher script disappears.
Hardcoded output names `HDMI-A-0` and `DVI-I-1` (config.ini:87, 100)
stay valid, Sway uses the same DRM connector names.

**Alternatives to Waybar:**

| Bar | Tradeoffs |
| --- | --- |
| Waybar | Most mature, closest module set to polybar, CSS styling. Config is JSON(C), so your `.ini` becomes a rewrite not a port. Recommended. |
| `eww` | Far more flexible, can do the yad-popup use case natively. Much bigger investment, custom Lisp-ish config. |
| i3status-rust + `swaybar` | Simplest, uses Sway's built-in bar. Weakest tray support and no per-module click popups. |
| `yambar` | Lightweight, YAML config. Smaller module set, no tray. |

### 3.3 Screen capture, recording, upload

This is the largest single cluster of breakage.

Current chain:
`teiler` (rofi frontend)
-> `maim` + `slop` + `xininfo` + `xrandr` + `ffmpeg -f x11grab`
-> `teiler/bin/teiler_helper` -> `xclip`.
Plus `bin/shot` (its own `maim` + `xclip` + `feh` tool)
and `zsh/zshrc/aliases.zsh:225-240 ffmpeg_grab()`.

None of `maim`, `slop`, `xininfo`, `x11grab` work on Wayland.

Replacements:

| Function | Replacement | Alternatives / tradeoffs |
| --- | --- | --- |
| Screenshot capture | `grim` | Only sane option on wlroots. Pairs with `slurp` for region selection. |
| Region selection | `slurp` | Direct `slop` replacement, same idea, same ergonomics. |
| Annotation | `swappy` | Reads from stdin (`grim -g "$(slurp)" - \| swappy -f -`). `satty` is a newer alternative with a nicer UI. |
| Screen recording | `wf-recorder` | Simplest, close to the `ffmpeg -f x11grab` model, takes `-g "$(slurp)"`. `wl-screenrec` is faster (hardware encode via VAAPI) but fewer options. OBS via the PipeWire portal is the heavyweight option. |
| Active window capture | `grim -g "$(swaymsg -t get_tree \| jq -r '...rect')"` | No direct `maim -i $(xdotool getactivewindow)` equivalent, you go through `swaymsg` IPC. |
| Screenshot to clipboard | `wl-copy --type image/png` | Direct `xclip -t image/png` replacement. |
| Screenshot viewer | `imv` or `swayimg` | Replaces the `feh` call at `bin/shot:168`. |

For `teiler` specifically:
there is no Wayland port.
The config file even documents an `~/.Xresources` dependency
(`teiler/.config/teiler/config:74-77`).
Options:

1. **Extend `bin/shot`** to cover video too and drop `teiler` entirely.
   You already own `shot` and it already does the rofi menu / save / copy / upload / open flow.
   Swap `maim` for `grim`+`slurp`, `xclip` for `wl-copy`, `feh` for `imv`, add a `wf-recorder` branch.
   Recommended, since it removes a dependency rather than replacing it.
2. Use `sway-contrib/grimshot` (ships with Sway) as the capture layer
   and keep a thin rofi/fuzzel menu on top.
3. Adopt `flameshot`. It has partial wlroots support but it is fiddly,
   and your i3 config already only uses it via `bin/shot`.

`teiler/.config/teiler/profiles/my-mp4-noaudio:1` contains `border="-show_region 1"`,
which is an `x11grab`-only ffmpeg option and must be dropped.

### 3.4 Screen sharing (portals)

Two files need changing, and getting this wrong silently kills all screen sharing:

- `xdg-desktop-portal/.config/xdg-desktop-portal/portals.conf` currently says `default=gtk`.
  It needs `org.freedesktop.impl.portal.ScreenCast` and `.Screenshot` routed to `wlr`
  (install `xdg-desktop-portal-wlr`), keeping `gtk` as the default for file chooser and settings.
- `xdg-desktop-portal/.config/systemd/user/xdg-desktop-portal.service.d/override.conf`
  forces `XDG_CURRENT_DESKTOP=gtk` to make backend matching work under i3.
  Under Sway this **clobbers** the correct value and breaks `-wlr` selection.
  Delete the drop-in, or change the value to `sway`.

Good news: `vesktop` is already installed with `WebScreenShareFixes` enabled
(`vesktop/.config/vesktop/settings/settings.json:600-603`),
which is the Wayland/PipeWire screenshare path.

### 3.5 Clipboard

`parcellite` is unportable:
it owns X selections, uses XTest to synthesize Ctrl+V (`automatic_paste=true`, line 12),
sits in an XEmbed tray (line 37), and installs X key grabs (lines 39-41).

Replacement: `wl-clipboard` (`wl-copy`/`wl-paste`)
plus `cliphist` or `clipman` for history.

| History tool | Tradeoffs |
| --- | --- |
| `cliphist` | Most popular, stores images too, pairs with `rofi`/`fuzzel` dmenu. No automatic paste. |
| `clipman` | Simpler, integrates with `wofi`. Text-focused. |
| `copyq` | Full GUI, closest to parcellite in features including a tray icon. Heavier, Qt. |

Note: nothing on Wayland can reproduce `automatic_paste=true`.
Selecting a history entry puts it on the clipboard,
you press Ctrl+V yourself.
The `<Super>Y` / `<Super><Shift>Y` / `<Super><Shift>A` global grabs
become normal Sway `bindsym` lines.

**Call sites that need `xsel`/`xclip` -> `wl-copy`/`wl-paste`:**

| File | Line | Current |
| --- | --- | --- |
| `zsh/zshrc/aliases.zsh` | 4, 5 | `alias ci='xsel -ib'`, `alias co='xsel -ob'` |
| `zsh/zshrc/aliases.zsh` | 252, 260 | `tee >(xsel -ib)` in `hologra()`, `staco()` |
| `zsh/zshrc/aliases.zsh` | 399-400 | `xsel -b`, `xclip-copyfile` in `copympd()` |
| `bin/bin/share_clip` | 5, 7, 10, 25 | `xclip -t TARGETS -o`, `xsel -ob`, `xsel -ib` |
| `bin/bin/share` | 15 | `xsel -ib` |
| `bin/bin/shot` | 54, 150 | `xclip -selection clipboard` (text and `image/png`) |
| `bin/bin/xclipargs` | 2 | `$@ $(xsel -ob)` |
| `git/bin/git-copy-commit-url` | 13 | `xsel -ib` |
| `teiler/bin/teiler_helper` | 11 | `xclip -selection clipboard` |
| `ranger/.config/ranger/rc.conf` | 51 | `map yc shell xsel -ib < %f` |
| `i3/.config/i3/config` | 349-351 | `xsel -ob` in the openurl / mpv / playlist bindings |

`bin/follow_clip` uses `pyperclip`, which auto-detects `wl-clipboard` if installed,
so it only needs the package present.
`yazi` uses the `system-clipboard` plugin which already detects the session type.
`helix` auto-detects too.
`zsh/zshrc/colors.zsh:22-23` uses `cb`, which is backend-agnostic already.

Consider a compatibility shim:
`bin/ci`/`bin/co` wrapper scripts that dispatch on `$WAYLAND_DISPLAY`.
That keeps the 11 call sites above working during a gradual migration
and lets you keep dual-booting i3 and Sway while you settle in.

### 3.6 Display management (autorandr, mons, arandr)

On `origin/dracaena` you have `autorandr/.config/autorandr/` with:

- `settings.ini`: `skip-options=gamma`
- `postswitch`: `notify-send`, then `~/.fehbg`, then `~/.config/polybar/launch.sh`
- Eight i3 bindings (config lines 180-188) for profiles
  `common`, `horizontal`, `vertical`, `default`, `mobile`, `work`, `home`,
  plus `--change` and `--cycle`
- `exec --no-startup-id autorandr --change` at startup (line 411)

On `master` the same role is played by `mons` (i3 config lines 182-188),
`~/.screenlayout/<hostname>.sh` (line 410), `arandr` (line 379),
and `bin/mons-primary`.
None of these work on Wayland: they are all `xrandr` wrappers.

**Replacement: `kanshi`.**

`kanshi` is the direct autorandr analogue for wlroots:
it watches for output hotplug and applies a matching profile.
Mapping:

| autorandr concept | kanshi equivalent |
| --- | --- |
| Profile directory with a saved `xrandr` state | `profile <name> { output ... }` block in `~/.config/kanshi/config` |
| `autorandr --change` (auto-detect) | Automatic, kanshi is a daemon that reacts to hotplug |
| `autorandr --load <profile>` | `kanshictl switch <profile>` |
| `autorandr --cycle` | No equivalent, you bind individual `kanshictl switch` calls |
| `postswitch` hook | `exec` line inside the profile block |
| `--save` to capture current layout | No equivalent. You write profiles by hand from `swaymsg -t get_outputs`. |

The `postswitch` script mostly disappears:
`~/.fehbg` becomes a `swaybg` invocation (or a Sway `output * bg` line),
and `polybar/launch.sh` disappears because Waybar handles outputs itself.
The `notify-send` line can move into the profile's `exec`.

**Alternatives:**

| Tool | Tradeoffs |
| --- | --- |
| `kanshi` | Standard on Sway, actively maintained, declarative. No `--save`, no cycling, profile matching is by output make/model/serial so it can be brittle with identical monitors. Recommended. |
| `shikane` | Kanshi-alike with a more expressive matching language (regex, priorities) and per-profile `exec`. Less widely used. |
| Sway `output` blocks in the config + `bindsym` to `swaymsg output ...` | Zero extra dependency, matches how the `$mode_monitor` bindings already feel. No hotplug automation, you switch manually. Good enough if you actually only have a handful of docked/undocked states. |
| `wdisplays` | GUI, the `arandr` replacement. Interactive only, does not persist. Useful as a companion to kanshi for figuring out coordinates. |
| `nwg-displays` | GUI that can *write* kanshi config files. Closest thing to `autorandr --save`. |

Recommendation: `kanshi` for the profiles, `nwg-displays` to author them,
and keep `$mode_monitor` in the Sway config
with `kanshictl switch <profile>` bound to the same letters
so muscle memory survives.
`bin/mons-primary` has no meaning on Wayland
(there is no "primary output" concept), delete it.
Its closest analogue is choosing which output Waybar's tray lives on.

### 3.7 Wallpaper and image viewing

`feh` is X11/Imlib2 only and appears in six places:

| File | Line | Role |
| --- | --- | --- |
| `i3/.config/i3/config` | 410 | `~/.fehbg` at startup (wallpaper) |
| `origin/dracaena` `autorandr/postswitch` | 8 | `~/.fehbg` after display switch |
| `openurl/.config/openurl.conf` | 39 | image URL handler |
| `polybar/.config/polybar/config.ini` | 468, 480 | wttr popup image |
| `teiler/.config/teiler/config` | 17 | capture viewer |
| `feh/.config/feh/keys`, `themes` | all | the config package itself |
| `ranger/.config/ranger/rifle.conf` | 181, 185, 219-222 | image opener and the four wallpaper actions |
| `bin/bin/shot` | 168 | open captured screenshot |

Wallpaper: `swaybg`, either as `output * bg <path> fill` in the Sway config
or as a standalone process.
Note there is no `.fehbg`-style "restore last wallpaper" file,
the path lives in the config.
If you want the randomised/per-output behaviour `.fehbg` gave you,
`wpaperd` (daemon with per-output playlists and intervals) is the closer match.

Viewer: `imv` (feh-like, keyboard driven, config file with key bindings,
so `feh/.config/feh/keys` has a real port target)
or `swayimg` (Sway-specific, sixel/terminal support, lighter).
`imv` is the better fit given you have a `keys` file with rotate/delete actions.
`nsxiv` is X11-only, so it is not an option despite being the usual `feh` alternative.

`ranger/rifle.conf:219-222` (the four `feh --bg-*` wallpaper actions) has no
direct replacement, they would become `swaybg`/`wpaperd` invocations.
The `X` condition in rifle (`$DISPLAY` is not empty) still evaluates true
under XWayland, so those rules will match and then fail.
Worth auditing rather than trusting.

### 3.8 Input method

`fcitx/` in this repo is **fcitx 4**, which has no Wayland text-input support at all.
Full port to fcitx5 required:

- `~/.config/fcitx/` becomes `~/.config/fcitx5/` with different file syntax.
- `conf/fcitx-classic-ui.config` has no equivalent:
  the classic UI draws an override-redirect X window at absolute coordinates
  and uses an XEmbed tray. fcitx5 replaces it wholesale.
- `data/layout_override` (`default,de,neo_qwertz` / `mozc,de,neo_qwertz`)
  moves into the Sway config as
  `input type:keyboard { xkb_layout de; xkb_variant neo_qwertz }`.
  Verify `neo_qwertz` still exists in your `xkeyboard-config` version.
- `data/QuickPhrase.mb` (64 text expansions) ports unchanged
  to `~/.local/share/fcitx5/data/quickphrase.d/*.mb`.
- Env vars from `.xinitrc:26-28`: under fcitx5 on Wayland,
  keep `XMODIFIERS=@im=fcitx` for XWayland clients,
  set `QT_IM_MODULE=fcitx`,
  and leave `GTK_IM_MODULE` **unset** so GTK uses the Wayland text-input protocol.

Alternative: drop fcitx entirely if the only use is the Neo layout plus quickphrases.
The layout moves to Sway natively,
and quickphrases could be a `wtype`-based script or an editor snippet feature.
Worth asking whether `mozc` (Japanese) is still in use.

### 3.9 Color temperature

`redshift/.config/redshift.conf:5` uses `adjustment-method=randr`, which is X11 only.
Redshift's `drm` method bypasses the compositor and fights with it, do not use it.

| Replacement | Tradeoffs |
| --- | --- |
| `gammastep` | Direct redshift fork for wlroots, same config file format and same `temp-day`/`temp-night`/`location-provider=manual` keys. Your `redshift.conf` ports nearly verbatim to `~/.config/gammastep/config.ini`. Has `gammastep-indicator` (tray) matching `redshift-gtk`. Recommended. |
| `wlsunset` | Simpler, CLI flags only, no config file, no tray. Fewer moving parts if you drop the tray applet. |
| `sway` `output ... color_profile` | Not a scheduler, not a replacement. |

The `redshift/.config/systemd/user/redshift-gtk.service.d/override.conf` drop-in
(`WantedBy=graphical-session.target`) stays valid, just retarget it to `gammastep-indicator`.
Note the tray applet depends on Waybar's SNI tray existing.

### 3.10 Launcher, menus, screen lock

**rofi.** Upstream rofi is X11-only.
It is used in far more places than the launcher bindings:
`dunstrc:22` (`dmenu` for notification actions),
`feh/themes:3` (via `rofi-yesno`),
`teiler`, `bin/mpris-rofi`, `bin/mons-primary`, `bin/rofi-yesno`, `bin/shot`.

| Option | Tradeoffs |
| --- | --- |
| `rofi-wayland` (lbonn fork) | Everything keeps working including `config.rasi` and the Arc-Dark theme, and `-dmenu` semantics are identical, so all seven call sites are untouched. `-show window` works via the Wayland fork's compositor support. Lowest-effort by a wide margin. Fork lags upstream. |
| `fuzzel` | Native, fast, `-dmenu` compatible. Different theming (ini, not rasi), so `config.rasi` is thrown away. `-show window` has no equivalent. |
| `wofi` | GTK-based, CSS theming. Slower, less maintained. |
| `tofi` | Extremely fast, minimal. dmenu mode only. |

Recommendation: `rofi-wayland` first (it makes the migration far shorter),
then reconsider `fuzzel` later if the fork stalls.

For `$mod+s` window switching:
`rofi-wayland -show window` works,
but a `swaymsg -t get_tree | jq | fuzzel --dmenu | swaymsg` script
is the more idiomatic and more controllable route.

**Screen lock.**
`i3lock` and `bin/i3lock-shot` (which uses `scrot` + imagemagick `convert`)
both die.
`i3/bin/i3lock-extra` is the older bash version of the same, also dead.

| Option | Tradeoffs |
| --- | --- |
| `swaylock` + a `grim`-based background script | Closest port. Rewrite `i3lock-shot` with `grim` instead of `scrot`, keep the imagemagick `convert` filter pipeline verbatim (it is display-agnostic). `swaylock` supports `--image` per output, so it is actually better than `i3lock --tiling`. Recommended. |
| `swaylock-effects` | Has built-in `--screenshots --effect-pixelate`/`--effect-blur`, which reproduces `--pixelize`/`--tint` without any script at all. Unmaintained fork, so check its status. |
| `gtklock` | Modular, GTK-based, plugin system. Different look. |
| `waylock` | Minimal, no image support. |

Also needed: `swayidle` for the idle handling
that `xset -dpms && xset s off` (i3 config line 406) currently disables.
Under Sway you either run no `swayidle` at all (equivalent to the current setup)
or configure explicit timeouts. The `xset` call itself just goes away.

**`swaynag`** replaces `i3-nagbar` in the `$mod+Shift+e` binding.

### 3.11 Compositing

Delete `picom/` entirely.
Sway composites natively, with `for_window ... opacity` for transparency.
Remove i3 config lines 361-362 (`$mod+Ctrl+c` / `$mod+Ctrl+Shift+c`)
and polybar module `[module/picom]` (config.ini:455-461).
No replacement needed. `picom.conf` was only 4 active lines anyway.

### 3.12 Miscellaneous X11 tools with no good replacement

| Tool | Where | Status |
| --- | --- | --- |
| `screenkey` | i3 config 364-365 | No Wayland port. `wshowkeys` is the closest (needs root or a wheel-group setuid), unmaintained. `showmethekey` is a maintained alternative using libinput. |
| `key-mon` | i3 config for_window rule | Same, X11 only. Same replacements. |
| `dragon-drop` | `aliases.zsh:12`, `ranger/rc.conf:41-44` | No direct port. `ripdrag` is a maintained Rust replacement with Wayland support. |
| `ueberzug` | `ranger/rc.conf:7` | X11 only (child window overlay). `ueberzugpp` supports Wayland (and Kitty/sixel). Or switch to yazi, which you already have configured and which handles previews natively. |
| ImageMagick `display` | `openurl.conf:38` (SVG handler) | X11 only. Route SVG to `imv` (which handles SVG via librsvg) or a browser. |
| `mupdf-x11` | `rifle.conf:155` | Use plain `mupdf` (which picks a backend) or `zathura`. |
| `xbacklight` | `i3/bin/backlightctl:9` | Replace with `brightnessctl`, which the i3 config already uses for the media keys. Trivial. |
| `arandr` | i3 config 379 | `wdisplays` or `nwg-displays`. |

### 3.13 Environment variables to add

There are currently **zero** Wayland or backend env vars anywhere in the repo,
so all of these are additions, not edits.
Best home is a new `sway/.config/environment.d/` or the Sway config,
not `zsh/.profile` (which is not sourced for graphical apps launched from the bar).

| Variable | Value | Why |
| --- | --- | --- |
| `MOZ_ENABLE_WAYLAND` | `1` | Firefox native Wayland. Default-on in recent Firefox but explicit is safer. |
| `QT_QPA_PLATFORM` | `wayland;xcb` | Qt apps (keepassxc, qpwgraph, QjackCtl, syncthingtray) native with X11 fallback. |
| `SDL_VIDEODRIVER` | `wayland` | Games. Be careful, some older SDL2 titles need `x11`, so consider setting per-app instead. |
| `_JAVA_AWT_WM_NONREPARENTING` | `1` | JetBrains and other AWT apps (you have a `for_window [class="jetbrains-"]` rule). |
| `XCURSOR_THEME` / `XCURSOR_SIZE` | `Adwaita` / `24` | `gtk-cursor-theme-size=0` in both GTK configs means "ask the X server", which fails under Sway and gives the default X cursor in XWayland. Also set `seat * xcursor_theme Adwaita 24` in the Sway config. |
| `XDG_CURRENT_DESKTOP` | `sway` | Portal backend selection. Set by Sway/uwsm, but the portal drop-in currently overrides it, see 3.4. |
| `ELECTRON_OZONE_PLATFORM_HINT` | `auto` | vesktop, discord, chromium, teams-for-linux. Alternative is per-app `--ozone-platform=wayland` flags in `.desktop` files, which is more surgical but more files. |

Also: `gpg/.gnupg/` has no `gpg-agent.conf` and no `pinentry-program`,
while `git/.gitconfig:10` sets `gpgSign = true`.
The system default pinentry is X11-first.
Set `pinentry-program /usr/bin/pinentry-gnome3` (portal-aware)
or `pinentry-qt`, and export `GPG_TTY` for terminal fallback.
Same class of problem for `SSH_ASKPASS` (`zsh/.profile:24-28`),
which points at `seahorse`/`ssh-askpass`, both X11-first.

### 3.14 Window matching rules

`for_window` criteria change meaning:

- `class=` and `instance=` only match **XWayland** clients under Sway.
- Native Wayland clients match on `app_id=` instead.
- `window_role=` does not exist for Wayland clients at all.
- `window_type=` only applies to XWayland.

Affected rules in `i3/.config/i3/config`:

| Rule | Migration |
| --- | --- |
| `[class="firefox" window_role="page-info"]` | Firefox on Wayland: `app_id="firefox"`, and the role is gone. Use `title` matching instead. |
| `[class="Thunderbird" window_role="EventDialog"]`, `[instance="Calendar"]` | Same problem. Thunderbird on Wayland needs `app_id` plus `title` matching. |
| `[window_type="notification"...]`, `[window_type="tooltip\|popup_menu\|..."]` | Only affects XWayland clients. Native Wayland popups are not separate windows and never needed these rules. Keep for XWayland, expect the native side to be a no-op. |
| `[class="^"]` (border pixel 2 catch-all) | Needs an `app_id`-based twin, or use `default_border pixel 2`. |
| The `$mode_focus` block (10 `[class=...] focus` bindings) | Each app needs checking individually: `firefox`, `Signal`, `TelegramDesktop`, `Thunderbird`, `vesktop`, `mpv` all have native Wayland modes and will report `app_id`. `Sublime_text`, `Sublime_merge`, `hexchat`, `Zeal`, `Spotify` stay XWayland and keep `class`. |

Practical approach: write rules as `[app_id="x"]` and `[class="X"]` pairs during transition,
and use `swaymsg -t get_tree` to confirm each one.
`for_window [shell="xwayland"]` is available if you want a blanket XWayland rule.

## 4. Per-package checklist

Legend: **DELETE** = package goes away, **REWRITE** = new config in a new tool,
**EDIT** = same tool, needs changes, **OK** = no change needed.

| Package | Action | Notes |
| --- | --- | --- |
| `i3` | REWRITE -> `sway` | Body ports 1:1, see 3.14 for window rules and 2 for i3-isms. `bin/backlightctl` -> `brightnessctl`. `bin/i3lock-extra` delete. `bin/set-default-sink` OK. |
| `xinit` | DELETE | See 3.1. |
| `xbindkeys` | DELETE | See 3.1. |
| `picom` | DELETE | See 3.11. |
| `parcellite` | DELETE -> `cliphist` | See 3.5. |
| `feh` | DELETE -> `imv` | `keys` file has a real port target in imv's config. See 3.7. |
| `teiler` | DELETE | Fold into `bin/shot`. See 3.3. |
| `polybar` | REWRITE -> `waybar` | See 3.2. |
| `rofi` | EDIT | `rofi-wayland` keeps `config.rasi` working. See 3.10. |
| `redshift` | REWRITE -> `gammastep` | Config format is compatible, file moves. See 3.9. |
| `fcitx` | REWRITE -> `fcitx5` | See 3.8. |
| `autorandr` (dracaena) | REWRITE -> `kanshi` | See 3.6. |
| `xdg-desktop-portal` | EDIT | Both files. This is the screen-sharing killer. See 3.4. |
| `dunst` | EDIT | Works on Wayland since 1.6. `dunstrc:19 monitor = 1` is an index and output ordering differs, re-verify. `dunstrc:22` rofi path. `dunstrc:20 follow = keyboard` is X11-only (already commented). |
| `gtk` | EDIT | `gtk-cursor-theme-size=0` -> real size in both `.gtkrc-2.0:9` and `gtk-3.0/settings.ini:7`. `gtk-xft-*` no longer arrives via XSETTINGS. Also fix the hardcoded `/home/fichte` include at `.gtkrc-2.0:4`. |
| `fontconfig` | EDIT | Unchanged functionally, but this is now where DPI/hinting should live since `xrdb`/`Xft.dpi` disappears. |
| `zsh` | EDIT | `aliases.zsh` clipboard aliases (4, 5, 252, 260, 399-400), `ffmpeg_grab()` (225-240), `colorpicker()` (351-353), `dragon-drop` alias (12). `.profile:36-44` uncomment the sway branch, add env vars. |
| `ranger` | EDIT | `rc.conf:7` ueberzug, `:51` xsel, `:41-44` dragon-drop. `rifle.conf` feh/mupdf-x11/wallpaper rules. Or migrate fully to `yazi`, which is already configured. |
| `bin` | EDIT | `shot`, `i3lock-shot`, `share_clip`, `share`, `xclipargs`, `mons-primary` (delete), `rofi-yesno`, `mpris-rofi`, `follow_clip`. Everything else OK. |
| `git` | EDIT | `bin/git-copy-commit-url:13` xsel only. |
| `gpg` | EDIT | Add `gpg-agent.conf` with an explicit `pinentry-program`. See 3.13. |
| `mpv` | EDIT | `mpv.conf:5 force-window-position=yes` is a no-op on Wayland, harmless but dead. `vo=gpu-next` + `gpu-api=vulkan` auto-select `waylandvk`, no change needed. |
| `system` | OK | `systembus-notify.service` is pure D-Bus. |
| `.system/smgood` | OK | `After=graphical-session.target` becomes *more* correct under uwsm. |
| `alacritty` | OK | Wayland-native. |
| `termite` | DELETE (already dead) | X11-only terminal, superseded by alacritty everywhere. Unrelated to this migration but worth cleaning up. |
| `yazi`, `helix`, `btop`, `htop`, `cmus`, `mpd`, `beets`, `noisetorch`, `pulse`, `readline`, `lftp`, `youtube-dl`, `lazydocker`, `tools`, `openurl` (script), `claude`, `opencode`, `bash`, `hexchat`, `sublime-text`, `sublime-merge`, `vesktop`, `BetterDiscord`, `aegisub`, `vimfx` | OK | No changes. `openurl/.config/openurl.conf:38-39` (feh, ImageMagick display) does need editing, but the script itself is fine. `hexchat.conf` has hardcoded window geometry that will be re-learned. `aegisub` config has absolute window coordinates that become meaningless, harmless. |

## 5. Suggested migration order

Sway and i3 can coexist: you can build the Sway session while still booting into i3.
Doing the display-server-agnostic work first shortens the risky window.

**Phase 0, prep (works under i3, no risk):**

- [ ] Install `wl-clipboard` and add `bin/ci` / `bin/co` shim scripts that dispatch on `$WAYLAND_DISPLAY`.
- [ ] Replace `i3/bin/backlightctl` `xbacklight` call with `brightnessctl`.
- [ ] Add an explicit `pinentry-program` to a new `gpg/.gnupg/gpg-agent.conf`, plus `GPG_TTY`.
- [ ] Decide ranger vs yazi. If yazi, the `ueberzug` problem disappears entirely.
- [ ] Delete the dead `termite` package.

**Phase 1, session skeleton:**

- [ ] New `sway/` stow package, port `i3/.config/i3/config` verbatim, fix the i3-isms from section 2.
- [ ] Add `input type:keyboard` with `de`/`neo_qwertz` from `fcitx/data/layout_override`.
- [ ] Add `output` blocks and `seat * xcursor_theme`.
- [ ] Set up `uwsm` (or the `zsh/.profile:41-44` `exec sway` branch) and verify
      `graphical-session.target` is reached.
- [ ] Verify it boots and you can open a terminal. Everything else can be broken at this point.

**Phase 2, make it usable:**

- [ ] `rofi-wayland` (unblocks 7 call sites at once).
- [ ] Waybar with `sway/workspaces`, `sway/window`, `tray`, `clock`, and the trivial system modules.
- [ ] `swaybg` for wallpaper, `swaylock` + `swayidle` + `swaynag`.
- [ ] `wl-clipboard` call sites (the table in 3.5), `cliphist` with the three Super bindings.
- [ ] `grim` + `slurp` in `bin/shot`, `wl-copy` for the image path.
- [ ] `imv` for image viewing, update `openurl.conf` and `bin/shot`.

**Phase 3, fix the multi-monitor and sharing story:**

- [ ] `kanshi` profiles authored with `nwg-displays`, `$mode_monitor` rebound to `kanshictl switch`.
- [ ] `xdg-desktop-portal-wlr`, fix `portals.conf` and delete the `XDG_CURRENT_DESKTOP=gtk` drop-in.
- [ ] Verify screen sharing in vesktop and Firefox before you delete the i3 session.
- [ ] `gammastep` replacing `redshift`.
- [ ] `wf-recorder` branch in `bin/shot`, then delete `teiler`.

**Phase 4, the long tail:**

- [ ] `fcitx5` port (or drop fcitx if the layout is all you need).
- [ ] Port the remaining Waybar custom modules and decide on the `polyyad` popup replacement.
- [ ] Audit every `for_window` rule with `swaymsg -t get_tree` (section 3.14).
- [ ] Add the env vars from 3.13.
- [ ] `ripdrag` for `dragon-drop`, `showmethekey` for `screenkey`, if you still want them.
- [ ] Delete `xinit`, `xbindkeys`, `picom`, `parcellite`, `feh`, `teiler`, `polybar` packages.

## 6. Known unknowns and risks

- **The machine branches.** `origin/dracaena` and `origin/piceoideae` currently
  do not diverge on any of the X11 packages (verified: empty diffs against master
  for `xinit`, `xbindkeys`, `gtk`, `fcitx`, `xdg-desktop-portal`, `system`).
  Only `autorandr` is dracaena-only. So the migration is mostly a master-branch job,
  but the kanshi profiles will need to be per-machine.
- **Untracked files that matter.**
  `~/.Xresources` and `~/.Xmodmap` are referenced by `.xinitrc` but not tracked here,
  so whatever `Xft.dpi` and keyboard remapping they contain
  needs to be recovered from the live machines before the X session goes away.
  Same for `~/.screenlayout/*.sh` and `~/.fehbg`.
- **`neo_qwertz`.** Confirm the variant exists in the current `xkeyboard-config`
  before committing to a Sway-native layout, and check whether the untracked
  `~/.Xmodmap` was adding anything on top of it.
- **Nvidia.** Not relevant if you are on AMD (`gpu_usage` module uses `radeontop`,
  and the output names `HDMI-A-0`/`DVI-I-1` are AMDGPU-style), but worth stating.
- **Games and SDL.** `SDL_VIDEODRIVER=wayland` globally breaks some older titles.
  Prefer per-launcher config over a global export.
- **XWayland scaling.** If any output ends up with a non-1 scale,
  XWayland clients (Sublime Text, Sublime Merge, Zeal, Spotify, Aegisub, Steam)
  will be blurry. Sway has no per-client scaling.
  If fractional scaling matters, evaluate that before committing.
