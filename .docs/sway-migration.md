# i3 to Sway migration

Status: planning document, nothing implemented yet.
Last reviewed 2026-10-12 against Sway 1.12 (wlroots 0.20) and the Arch repositories of that date.
Scope: this repository (`~/dotfiles`), branch `master`
plus the machine branches `origin/dracaena` and `origin/piceoideae`.

Line numbers refer to `master` at the time of review and drift quickly.
For `i3/.config/i3/config`, rules and bindings are referenced by content instead.

## 1. Summary

The window manager config itself is the easy part.
Sway parses i3 config syntax,
so `i3/.config/i3/config` ports almost verbatim:
`bindsym`, `for_window`, `mode`, `client.*` colors, `hide_edge_borders`,
`floating_modifier`, `focus_on_window_activation`, `mouse_warping`,
workspace and resize bindings all carry over unchanged.

The work is everywhere else.
This repo has 48 stow packages,
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
| Input method | `fcitx` (fcitx **4**, no longer in the Arch repos) | Port to fcitx5 |
| Color temperature | `redshift` (`adjustment-method=randr`) | Replace with `gammastep`/`wlsunset` |
| Launcher | `rofi` | Nothing to do, rofi 2.0 ships a native Wayland backend |

Roughly 25 of the 48 packages need no changes at all
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
- Media key bindings (`pactl`, `brightnessctl`) and the mpris bindings.
- Notification bindings (`dunstctl`).

Sway-only replacements for i3-isms inside that file:

| i3 | Sway |
| --- | --- |
| `i3-nagbar` (`$mod+Shift+e` exit confirmation) | `swaynag` |
| `i3-sensible-terminal` (`$mod+Return`, launcher `r`) | `$term` variable set to `alacritty`. The script ships with the `i3-wm` package, so it only keeps working while i3 stays installed. |
| `i3-msg exit` | `swaymsg exit` |
| `exec --no-startup-id` | `exec`. Sway accepts the flag but only logs that it is ignored. Sway tracks launches itself (via xdg-activation and the pid), so windows still open on the workspace they were launched from. |

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
| `exec sway` from `zsh/.profile` on tty1 (already stubbed at lines 41-44) | Simplest, matches the current startx pattern. Arch's `sway` package ships `/etc/sway/config.d/50-systemd-user.conf`, which imports `WAYLAND_DISPLAY`, `SWAYSOCK`, `DISPLAY` and `XDG_CURRENT_DESKTOP=sway` into systemd and D-Bus, but only if the ported config keeps `include /etc/sway/config.d/*` (the default config has it, the i3 config does not). `graphical-session.target` is still never reached, so `.system/smgood/smgood.service:4 (After=graphical-session.target)` and `redshift-gtk.service.d/override.conf (WantedBy=graphical-session.target)` stay unsatisfied. |
| `uwsm start sway` (recommended, `extra/uwsm`) | Puts the session under a proper systemd user scope, gets `graphical-session.target` and `wayland-session@sway.target` for free, propagates `XDG_CURRENT_DESKTOP=sway` correctly to portals, gives clean shutdown ordering. Extra dependency, and autostarts move from `exec` lines to systemd units (or `uwsm app -- <cmd>`). |
| Display manager (greetd + `tuigreet`) | Nice if you want a login prompt. Additional moving part you do not currently have (there is no DM config anywhere in this repo today). |

Recommendation: `uwsm`,
because two of your units already declare `graphical-session.target` ordering
and neither is actually satisfied under the current xinit setup.

`xbindkeys` (`b:8`/`b:9` mouse buttons to Page Up/Down via `xdotool`)
needs a new home.
Sway can *bind* those buttons (`bindsym --whole-window button8/button9`),
but it has no built-in way to *synthesize* a Page Up keypress.
Options:

- Remap the mouse buttons below the compositor with a `udev` hwdb entry
  (`KEYBOARD_KEY_<scancode>=pageup`), so every application sees the key directly.
  Cleanest, also works under i3 and on the console.
- Remapping daemons such as `keyd` or `input-remapper`.
  Same effect as hwdb, configurable at runtime, extra service.
- Sway bindings calling `wtype -k Prior`.
  Sway implements the virtual-keyboard protocol, so this reaches every client,
  but each call uploads a temporary keymap, which some clients handle poorly.
  `ydotool` also works but needs a daemon with `/dev/uinput` access.

### 3.2 Bar and tray

Polybar is X11-only by upstream policy and will not be ported.
`polybar/.config/polybar/config.ini` is 500 lines and 27 modules.

Module-by-module port target:

| Polybar module | Waybar equivalent | Notes |
| --- | --- | --- |
| `i3` (line 132) | `sway/workspaces` | Direct. `pin-workspaces = true` maps to `all-outputs: false`. |
| `xwindow` (112) | `sway/window` | Direct. |
| `tray` (107) | `tray` | Polybar uses XEmbed, Waybar uses StatusNotifierItem. Apps that only do XEmbed (older `parcellite`) simply will not appear. |
| `filesystem`, `memory`, `cpu_usage`, `eth`, `battery`, `pulseaudio`, `backlight-acpi`, `mpd`, temperature modules | built-in Waybar modules | Straight port, all read `/proc`, sysfs, or D-Bus. |
| `date`, `wttr`, `updates`, `failed_units`, `kernel`, `cpu_load`, `gpu_usage`, `pulsesinksource`, `mpris` | `custom/*` | Scripts port unchanged, but see 3.3 for their `click-left` popups. |
| `xbacklight` (218) | delete | Only kept as the `inherit` base of `backlight-acpi`; fold its settings into that. |
| `picom` (454) | delete | Meaningless under Sway. |

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
The hardcoded output names `HDMI-A-0` and `DVI-I-1` (config.ini:86, 99)
will **not** carry over as-is.
They are xf86-video-amdgpu's names, which count from 0 per connector type
(and spell DisplayPort as `DisplayPort-0`),
while Sway uses the kernel's DRM connector names, which count from 1
(`HDMI-A-1`, `DP-1`).
Take the real names from `ls /sys/class/drm` or `swaymsg -t get_outputs`,
or match on make/model/serial in Waybar's `output` key instead.
The same applies to every output name in kanshi profiles and Sway `output` blocks.

**Alternatives to Waybar:**

| Bar | Tradeoffs |
| --- | --- |
| Waybar | Most mature, closest module set to polybar, CSS styling. Config is JSON(C), so your `.ini` becomes a rewrite not a port. Recommended. |
| `eww` | Far more flexible, can do the yad-popup use case natively. Much bigger investment, custom Lisp-ish config. |
| `i3status`/i3status-rust + `swaybar` | Simplest, uses Sway's built-in bar. `origin/piceoideae` already maintains an `i3status` config, which works with `swaybar` unchanged. Weakest tray support and no per-module click popups. |
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
(`teiler/.config/teiler/config:75-76`).
Options:

1. **Extend `bin/shot`** to cover video too and drop `teiler` entirely.
   You already own `shot` and it already does the rofi menu / save / copy / upload / open flow.
   Swap `maim` for `grim`+`slurp`, `xclip` for `wl-copy`, `feh` for `imv`, add a `wf-recorder` branch.
   Recommended, since it removes a dependency rather than replacing it.
2. Use `grimshot` (Arch package `sway-contrib`, no longer part of `sway` itself) as the capture layer
   and keep a thin rofi/fuzzel menu on top.
3. Adopt `flameshot`. It has partial wlroots support but it is fiddly,
   and your i3 config already only uses it via `bin/shot`.

`teiler/.config/teiler/profiles/my-mp4-noaudio:1` contains `border="-show_region 1"`,
which is an `x11grab`-only ffmpeg option and must be dropped.

### 3.4 Screen sharing (portals)

Two files need changing, and getting this wrong silently kills all screen sharing.

Arch's `sway` package already ships `/usr/share/xdg-desktop-portal/sway-portals.conf`
with exactly the routing Sway needs:
`default=gtk`, `ScreenCast` and `Screenshot` to `wlr`,
and `Inhibit=none` (so Firefox falls back to the idle-inhibit protocol).
Install `xdg-desktop-portal-wlr` and let that file do its job.
Two things in this repo currently prevent that:

- `xdg-desktop-portal/.config/xdg-desktop-portal/portals.conf` (`default=gtk`).
  `portals.conf(5)` searches `~/.config` before `/usr/share`,
  and within each directory falls back to the generic `portals.conf`
  before moving on to the next directory.
  The user-level `portals.conf` therefore **shadows** the shipped `sway-portals.conf`
  and routes screen casting to `gtk`, which cannot do it.
  Rename it to a desktop-specific file (see below) instead of editing its contents.
- `xdg-desktop-portal/.config/systemd/user/xdg-desktop-portal.service.d/override.conf`
  forces `XDG_CURRENT_DESKTOP=gtk` for the portal service.
  A unit's `Environment=` wins over the imported session environment,
  so under Sway this **clobbers** the correct value.
  It has to go, since it cannot be made conditional on the session.

To keep both sessions working while they coexist:
export `XDG_CURRENT_DESKTOP=i3` in `.xinitrc`
and import it into systemd and D-Bus
(Arch's `xinitrc.d/50-systemd-user.sh` only imports `DISPLAY` and `XAUTHORITY`),
rename the user file to `i3-portals.conf`,
and delete the drop-in.
Sway then picks up the shipped `sway-portals.conf` without any file in this repo.
This is untested under i3; check `/usr/lib/xdg-desktop-portal -r -v` output
to confirm which config file each session loads.

Good news: `vesktop` is already installed with `WebScreenShareFixes` enabled
(`vesktop/.config/vesktop/settings/settings.json:600-603`),
which is the Wayland/PipeWire screenshare path.

### 3.5 Clipboard

`parcellite` is unportable:
it owns X selections, uses XTest to synthesize Ctrl+V (`automatic_paste=true`, line 13),
sits in an XEmbed tray, and installs X key grabs (lines 39-41).

Replacement: `wl-clipboard` (`wl-copy`/`wl-paste`)
plus `cliphist` or `clipman` for history.

| History tool | Tradeoffs |
| --- | --- |
| `cliphist` | Most popular, stores images too, pairs with `rofi`/`fuzzel` dmenu. No automatic paste. |
| `clipman` | Simpler, text-focused, picks entries via `wofi`/`rofi`/`dmenu`. Now maintained as the `chmouel/clipman` fork. |
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
| `i3/.config/i3/config` | 351-353 | `xsel -ob` in the openurl / mpv / playlist bindings |

`bin/follow_clip` uses `pyperclip`, which auto-detects `wl-clipboard` if installed,
so it only needs the package present.
`yazi` uses the `system-clipboard` plugin, which shells out to `cb` and therefore detects the session type.
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
- Nine bindings in `$mode_monitor` for profiles
  `common`, `horizontal`, `vertical`, `default`, `mobile`, `work`, `home`,
  plus `--change` and `--cycle`
- `exec --no-startup-id autorandr --change; picom` at startup

On `master` the same role is played by `mons` (the `$mode_monitor` bindings),
`~/.screenlayout/<hostname>.sh` (startup `exec`), `arandr` (launcher mode `a`),
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
| `kanshi` | Standard on Sway, actively maintained (1.9, January 2026), declarative. Matches outputs by connector name or make/model/serial, with wildcard patterns since 1.8 and a `...output` catch-all since 1.9, which makes identical-monitor setups less brittle. `kanshictl status` shows the active profile. No `--save`, no cycling. Recommended. |
| `shikane` | Kanshi-alike with a more expressive matching language (regex, priorities) and per-profile `exec`. Less widely used. |
| Sway `output` blocks in the config + `bindsym` to `swaymsg output ...` | Zero extra dependency, matches how the `$mode_monitor` bindings already feel. No hotplug automation, you switch manually. Good enough if you actually only have a handful of docked/undocked states. |
| `wdisplays` | GUI, the `arandr` replacement. Interactive only, does not persist. Useful as a companion to kanshi for figuring out coordinates. |
| `nwg-displays` | GUI that persists the current layout as Sway `output` lines to an includable file (`~/.config/sway/outputs`). It does **not** write kanshi profiles. Closest thing to `autorandr --save` for the single-layout case. |

Recommendation: `kanshi` for the profiles,
authored by hand from `swaymsg -t get_outputs` after arranging the outputs in `wdisplays` or `nwg-displays`,
and keep `$mode_monitor` in the Sway config
with `kanshictl switch <profile>` bound to the same letters
so muscle memory survives.
`bin/mons-primary` has no meaning on Wayland
(there is no "primary output" concept), delete it.
Its closest analogue is choosing which output Waybar's tray lives on.

### 3.7 Wallpaper and image viewing

`feh` is X11/Imlib2 only.
As an image *viewer* it keeps working under XWayland,
so those call sites can be migrated lazily.
Setting the wallpaper (`--bg-*`, `~/.fehbg`) breaks outright.
It appears in these places:

| File | Line | Role |
| --- | --- | --- |
| `i3/.config/i3/config` | startup `exec` | `~/.fehbg` at startup (wallpaper) |
| `origin/dracaena` `autorandr/postswitch` | 8 | `~/.fehbg` after display switch |
| `openurl/.config/openurl.conf` | 39 | image URL handler |
| `polybar/.config/polybar/config.ini` | 467, 479 | wttr popup image |
| `teiler/.config/teiler/config` | 11 | capture viewer |
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
or `swayimg` (despite the name a generic Wayland viewer, lighter).
`imv` is the better fit given you have a `keys` file with rotate/delete actions.
`nsxiv` is X11-only, so it is not an option despite being the usual `feh` alternative.

`ranger/rifle.conf:219-222` (the four `feh --bg-*` wallpaper actions) has no
direct replacement, they would become `swaybg`/`wpaperd` invocations.
The `X` condition in rifle (`$DISPLAY` is not empty) still evaluates true
under XWayland, so those rules will match and then fail.
Worth auditing rather than trusting.

### 3.8 Input method

`fcitx/` in this repo is **fcitx 4**, which has no Wayland text-input support at all
and has been dropped from the Arch repositories (only fcitx5 remains).
fcitx5 runs fine under i3 too,
so this port does not depend on the Sway switch and can happen in phase 0.
Full port to fcitx5 required:

- `~/.config/fcitx/` becomes `~/.config/fcitx5/` with different file syntax.
- `conf/fcitx-classic-ui.config` has no equivalent:
  the classic UI draws an override-redirect X window at absolute coordinates
  and uses an XEmbed tray. fcitx5 replaces it wholesale.
- `data/layout_override` (`default,de,neo_qwertz` / `mozc,de,neo_qwertz`)
  moves into the Sway config as
  `input type:keyboard { xkb_layout de; xkb_variant neo_qwertz }`.
  The `de(neo_qwertz)` variant is present in current `xkeyboard-config`.
- `data/QuickPhrase.mb` (64 text expansions) ports unchanged
  to `~/.local/share/fcitx5/data/quickphrase.d/*.mb`.
- Env vars from `.xinitrc:26-28`, per the fcitx5 Sway guidance:
  keep `XMODIFIERS=@im=fcitx` for XWayland clients,
  set `QT_IM_MODULE=fcitx` for Qt5
  and `QT_IM_MODULES="wayland;fcitx"` for Qt 6.8.2+,
  and leave `GTK_IM_MODULE` **unset** so GTK uses the Wayland text-input protocol.
  Sway draws the candidate popup for text-input-v3 clients since 1.10.

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

**rofi.** No longer a migration item.
rofi 2.0.0 (September 2025) merged lbonn's Wayland port upstream
and selects the backend at runtime (`rofi -info` shows which one).
Arch's `rofi` package is 2.0 and `replaces=rofi-wayland`,
so the installed binary already speaks Wayland.
`config.rasi`, the theme and `-dmenu` semantics are unchanged,
which keeps all call sites working:
`dunstrc:22` (`dmenu` for notification actions),
`feh/themes:3` (via `rofi-yesno`),
`teiler`, `bin/mpris-rofi`, `bin/mons-primary`, `bin/rofi-yesno`, `bin/shot`.
X11-only options such as `-normal-window` do not work on Wayland.

For `$mod+s` window switching:
`rofi -show window` uses the wlr foreign-toplevel protocol on Sway,
which should work but is worth testing early.
A `swaymsg -t get_tree | jq | rofi -dmenu | swaymsg` script
is the fallback and gives full control over the listing.

`fuzzel` (native, ini theming, no window mode) and `tofi` (dmenu only)
remain alternatives, but there is no longer a migration reason to switch.

**Screen lock.**
`i3lock` and `bin/i3lock-shot` (which uses `scrot` + imagemagick `convert`)
both die.
`i3/bin/i3lock-extra` is the older bash version of the same, also dead.

| Option | Tradeoffs |
| --- | --- |
| `swaylock` + a `grim`-based background script | Closest port. Rewrite `i3lock-shot` with `grim` instead of `scrot`, keep the imagemagick `convert` filter pipeline verbatim (it is display-agnostic). `swaylock` supports `--image` per output, so it is actually better than `i3lock --tiling`. Recommended. |
| `swaylock-effects` | Has built-in `--screenshots --effect-pixelate`/`--effect-blur`, which reproduces `--pixelize`/`--tint` without any script at all. But the maintained fork (`jirutka/swaylock-effects`) has had no commits since March 2024 and lags upstream `swaylock` (1.8.x), so not recommended. |
| `gtklock` | Modular, GTK-based, plugin system. Different look. |
| `waylock` | Minimal, no image support. |

Also needed: `swayidle` for the idle handling
that `xset -dpms && xset s off` (startup `exec` in the i3 config) currently disables.
Under Sway you either run no `swayidle` at all (equivalent to the current setup)
or configure explicit timeouts. The `xset` call itself just goes away.

**`swaynag`** replaces `i3-nagbar` in the `$mod+Shift+e` binding.

### 3.11 Compositing

Delete `picom/` entirely.
Sway composites natively, with `for_window ... opacity` for transparency.
Remove the `$mod+Ctrl+c` / `$mod+Ctrl+Shift+c` bindings,
the `picom` startup `exec` on `origin/dracaena`,
and polybar module `[module/picom]` (config.ini:454).
No replacement needed. `picom.conf` was only 4 active lines anyway.

### 3.12 Miscellaneous X11 tools

"X11 only" below still means "runs under XWayland" unless noted,
so most of these can be replaced lazily.
The exceptions are tools that need to observe or control *other* windows or input,
since XWayland clients only see other XWayland clients.

| Tool | Where | Status |
| --- | --- | --- |
| `screenkey` | `$mod+Ctrl+s` bindings | Runs under XWayland but only sees keys sent to XWayland clients, so effectively broken. `showmethekey` is the maintained replacement (libinput, needs a polkit-elevated helper). `wshowkeys` is unmaintained. |
| `key-mon` | `for_window` rule | Same problem, same replacement. |
| `dragon-drop` | `aliases.zsh:12`, `ranger/rc.conf:41-44` | No change needed. dragon is GTK3 and works natively on Wayland. `ripdrag` exists as an alternative. |
| `ueberzug` | `ranger/rc.conf:7` | X11 only (child window overlay). `ueberzugpp` supports Wayland (and Kitty/sixel). Or switch to yazi, which you already have configured and which handles previews natively. |
| ImageMagick `display` | `openurl.conf:38` (SVG handler) | Works under XWayland, but the comment already calls it terrible. Route SVG to `imv` (librsvg) or a browser. |
| `mupdf-x11` | `rifle.conf:155` | Works under XWayland. The preceding `mupdf` rule (line 154) already wins when plain `mupdf` is installed. `zathura` is the native alternative. |
| `xbacklight` | `i3/bin/backlightctl` | Nothing references `backlightctl` any more (the i3 config calls `brightnessctl` directly, and `origin/piceoideae` already deleted the script). Delete it. |
| `arandr` | launcher mode `a` | `wdisplays` or `nwg-displays`. |

### 3.13 Environment variables to add

There are currently **zero** Wayland or backend env vars anywhere in the repo,
so all of these are additions, not edits.
Best home is a new `sway/.config/environment.d/` or the Sway config,
not `zsh/.profile` (which is not sourced for graphical apps launched from the bar).

| Variable | Value | Why |
| --- | --- | --- |
| `QT_QPA_PLATFORM` | `wayland;xcb` | Qt5 apps native with X11 fallback. Qt6 already prefers Wayland, so this mainly matters for Qt5 apps (needs `qt5-wayland`). |
| `SDL_VIDEODRIVER` | `wayland` | Games. SDL3 already prefers Wayland, and some older SDL2 titles break with it, so set it per-app if at all. |
| `_JAVA_AWT_WM_NONREPARENTING` | `1` | Generic AWT/Swing apps running through XWayland. JetBrains IDEs run natively on Wayland by default since 2026.1 (`-Dawt.toolkit.name=auto`), so the `for_window [class="jetbrains-" title="win0"]` rule needs an `app_id` equivalent instead. |
| `XCURSOR_THEME` / `XCURSOR_SIZE` | `Adwaita` / `24` | `gtk-cursor-theme-size=0` in both GTK configs means "ask the X server", which fails under Sway and gives the default X cursor in XWayland. Also set `seat * xcursor_theme Adwaita 24` in the Sway config. |
| `XDG_CURRENT_DESKTOP` | `sway` | Portal backend selection. Set by uwsm or Arch's `50-systemd-user.conf`, but the portal drop-in currently overrides it, see 3.4. |

Not needed any more, despite appearing in many guides:

- `MOZ_ENABLE_WAYLAND=1`: Firefox runs natively on Wayland by default since 121.
- `ELECTRON_OZONE_PLATFORM_HINT`: deprecated since Electron 38,
  which defaults `--ozone-platform` to `auto` and picks Wayland when available (reliably since 38.2).
  Only apps bundling an older Electron need a per-app `--ozone-platform=wayland` flag.

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
| `[class="jetbrains-" title="win0"]` | Native on Wayland since 2026.1, needs an `app_id` rule (see 3.13). |
| The `$mode_focus` block (10 `[class=...] focus` bindings) | Each app needs checking individually: `firefox`, `Signal`, `TelegramDesktop`, `Thunderbird`, `vesktop`, `mpv` all have native Wayland modes and will report `app_id`. `Sublime_text`, `Sublime_merge`, `hexchat`, `Zeal`, `Spotify` stay XWayland and keep `class`. |

Practical approach: write rules as `[app_id="x"]` and `[class="X"]` pairs during transition,
and use `swaymsg -t get_tree` to confirm each one.
`for_window [shell="xwayland"]` is available if you want a blanket XWayland rule.

## 4. Per-package checklist

Legend: **DELETE** = package goes away, **REWRITE** = new config in a new tool,
**EDIT** = same tool, needs changes, **OK** = no change needed.

| Package | Action | Notes |
| --- | --- | --- |
| `i3` | REWRITE -> `sway` | Body ports 1:1, see 3.14 for window rules and 2 for i3-isms. `bin/backlightctl` and `bin/i3lock-extra` are unreferenced, delete. `bin/set-default-sink` OK. |
| `xinit` | DELETE | See 3.1. |
| `xbindkeys` | DELETE | See 3.1. |
| `picom` | DELETE | See 3.11. |
| `parcellite` | DELETE -> `cliphist` | See 3.5. |
| `feh` | DELETE -> `imv` | `keys` file has a real port target in imv's config. See 3.7. |
| `teiler` | DELETE | Fold into `bin/shot`. See 3.3. |
| `polybar` | REWRITE -> `waybar` | See 3.2. |
| `rofi` | OK | rofi 2.0 is Wayland-native, `config.rasi` unchanged. See 3.10. |
| `redshift` | REWRITE -> `gammastep` | Config format is compatible, file moves. See 3.9. |
| `fcitx` | REWRITE -> `fcitx5` | See 3.8. |
| `autorandr` (dracaena) | REWRITE -> `kanshi` | See 3.6. |
| `xdg-desktop-portal` | EDIT | Rename `portals.conf` to `i3-portals.conf`, delete the drop-in. This is the screen-sharing killer. See 3.4. |
| `dunst` | EDIT | Works on Wayland since 1.6. `dunstrc:19 monitor = 1` is an index and output ordering differs, re-verify. `origin/dracaena` uses `follow = keyboard` instead, which depends on the compositor reporting the focused output, so verify it there. The `dunstrc:22` rofi call keeps working. |
| `gtk` | EDIT | `gtk-cursor-theme-size=0` -> real size in both `.gtkrc-2.0:9` and `gtk-3.0/settings.ini:7`. `gtk-xft-*` no longer arrives via XSETTINGS. Also fix the hardcoded `/home/fichte` include at `.gtkrc-2.0:4`. |
| `fontconfig` | EDIT | Unchanged functionally, but this is now where DPI/hinting should live since `xrdb`/`Xft.dpi` disappears. |
| `zsh` | EDIT | `aliases.zsh` clipboard aliases (4, 5, 252, 260, 399-400), `ffmpeg_grab()` (225-240), `colorpicker()` (351-353). `.profile:36-44` uncomment the sway branch, add env vars. |
| `ranger` | EDIT | `rc.conf:7` ueberzug, `:51` xsel. `rifle.conf` feh wallpaper rules. Or migrate fully to `yazi`, which is already configured. |
| `bin` | EDIT | `shot`, `i3lock-shot`, `share_clip`, `share`, `xclipargs`, `mons-primary` (delete), `follow_clip` (needs `wl-clipboard` installed). `rofi-yesno` and `mpris-rofi` OK with rofi 2.0. Everything else OK. |
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
- [ ] Delete the unreferenced `i3/bin/backlightctl` and `i3/bin/i3lock-extra`.
- [ ] Add an explicit `pinentry-program` to a new `gpg/.gnupg/gpg-agent.conf`, plus `GPG_TTY`.
- [ ] Port `fcitx` to fcitx5 (section 3.8), since fcitx 4 is gone from the Arch repos anyway.
- [ ] Set `XDG_CURRENT_DESKTOP=i3` in the X session, rename `portals.conf` to `i3-portals.conf`
      and delete the portal drop-in (section 3.4). Verify screen sharing still works under i3.
- [ ] Decide ranger vs yazi. If yazi, the `ueberzug` problem disappears entirely.
- [ ] Delete the dead `termite` package.

**Phase 1, session skeleton:**

- [ ] New `sway/` stow package, port `i3/.config/i3/config` verbatim, fix the i3-isms from section 2,
      and keep `include /etc/sway/config.d/*` unless using uwsm.
- [ ] Add `input type:keyboard` with `de`/`neo_qwertz` from `fcitx/data/layout_override`.
- [ ] Add `output` blocks and `seat * xcursor_theme`.
- [ ] Set up `uwsm` (or the `zsh/.profile:41-44` `exec sway` branch) and verify
      `graphical-session.target` is reached.
- [ ] Verify it boots and you can open a terminal. Everything else can be broken at this point.

**Phase 2, make it usable:**

- [ ] Confirm `rofi -info` reports the Wayland backend and test `-show window`.
- [ ] Waybar with `sway/workspaces`, `sway/window`, `tray`, `clock`, and the trivial system modules.
- [ ] `swaybg` for wallpaper, `swaylock` + `swayidle` + `swaynag`.
- [ ] `wl-clipboard` call sites (the table in 3.5), `cliphist` with the three Super bindings.
- [ ] `grim` + `slurp` in `bin/shot`, `wl-copy` for the image path.
- [ ] `imv` for image viewing, update `openurl.conf` and `bin/shot`.

**Phase 3, fix the multi-monitor and sharing story:**

- [ ] `kanshi` profiles written from `swaymsg -t get_outputs`, `$mode_monitor` rebound to `kanshictl switch`.
- [ ] Install `xdg-desktop-portal-wlr` and confirm the shipped `sway-portals.conf` is picked up.
- [ ] Verify screen sharing in vesktop and Firefox before you delete the i3 session.
- [ ] `gammastep` replacing `redshift`.
- [ ] `wf-recorder` branch in `bin/shot`, then delete `teiler`.

**Phase 4, the long tail:**

- [ ] Port the remaining Waybar custom modules and decide on the `polyyad` popup replacement.
- [ ] Audit every `for_window` rule with `swaymsg -t get_tree` (section 3.14).
- [ ] Add the env vars from 3.13.
- [ ] `showmethekey` for `screenkey`/`key-mon`, if you still want them.
- [ ] Delete `xinit`, `xbindkeys`, `picom`, `parcellite`, `feh`, `teiler`, `polybar` packages.

## 6. Known unknowns and risks

- **The machine branches.** `origin/dracaena` and `origin/piceoideae`
  do not diverge from `master` on `xinit`, `xbindkeys`, `gtk`, `fcitx`, `xdg-desktop-portal` or `system`.
  They do carry machine-specific changes to X11-relevant packages
  (verified with `git diff master...origin/<branch>` on 2026-10-12):
  - `dracaena`: `autorandr` package, `$mode_monitor` rebound to autorandr,
    `autorandr --change; picom` at startup, polybar tweaks,
    `dunst` switched to `follow = keyboard`.
  - `piceoideae`: an `i3status` config (a ready-made `swaybar` option, see 3.2),
    `i3/bin/backlightctl` deleted, polybar and `dunst` tweaks.

  So the bulk of the work is still a master-branch job,
  but each machine branch needs its own pass over `i3`/`sway`, the bar and `dunst`,
  and the kanshi profiles are per-machine.
- **Untracked files that matter.**
  `~/.Xresources` and `~/.Xmodmap` are referenced by `.xinitrc` but not tracked here,
  so whatever `Xft.dpi` and keyboard remapping they contain
  needs to be recovered from the live machines before the X session goes away.
  Same for `~/.screenlayout/*.sh` and `~/.fehbg`.
- **`neo_qwertz`.** The variant exists in current `xkeyboard-config`.
  Still check whether the untracked `~/.Xmodmap` was adding anything on top of it.
- **Nvidia.** Not relevant if you are on AMD (`gpu_usage` module uses `radeontop`,
  and the `HDMI-A-0`/`DVI-I-1` output names follow xf86-video-amdgpu naming), but worth stating.
- **Games and SDL.** `SDL_VIDEODRIVER=wayland` globally breaks some older titles.
  Prefer per-launcher config over a global export.
- **XWayland scaling.** If any output ends up with a non-1 scale,
  XWayland clients (Sublime Text, Sublime Merge, Zeal, Spotify, Aegisub, Steam)
  will be blurry. Sway has no per-client scaling.
  If fractional scaling matters, evaluate that before committing.
