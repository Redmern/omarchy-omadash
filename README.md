# Omadash

A keyboard-first quick-settings dashboard for [Omarchy](https://omarchy.org/),
written in QML for [Quickshell](https://quickshell.org/). A single popup,
toggled by a Hyprland keybind, with tiles for Wi-Fi, Bluetooth, Audio,
Display, Power, and Apps — each one a real live-data screen, navigable
entirely with `hjkl`.

## How Omarchy plugins work

Omarchy's bar, notifications, OSD, and overlays all run inside one
long-running Quickshell process called `omarchy-shell`. A plugin is a
directory with a `manifest.json` (id, kinds, entry points) plus the QML
that implements it. User plugins live under `~/.config/omarchy/plugins/`
and hot-reload on save — no restart needed.

This plugin is a `panel` kind: a full-screen `PanelWindow` (Wayland
layer-shell surface) that's invisible until toggled open, with a small
card centered on it. The host (`omarchy-shell`) instantiates the plugin
once, injects `shell` and `manifest` properties into it, then drives it
through a small lifecycle contract:

- `open(payloadJson)` — called when the plugin is summoned/toggled open
- `close()` — called when the host hides it
- the plugin calls `shell.hide(id)` on itself (Esc / click-outside) so the
  host's bookkeeping of what's open stays correct

This mirrors every built-in panel plugin, e.g. the Wi-Fi QR share overlay
at `/usr/share/omarchy/shell/plugins/panels/wifiqr/Panel.qml` — read that
one for a richer example (payloads, subprocesses, theming via `qs.Commons`).

## Files

```
manifest.json   Plugin metadata: id, kind, entry point
Panel.qml       The popup itself
install.sh      Symlinks this repo into ~/.config/omarchy/plugins/
```

## Install

Quick install (clones into `~/.config/omarchy/plugins/`, no editing):

```bash
omarchy plugin add https://github.com/Redmern/omarchy-omadash.git --enable
```

Dev install (symlinks this repo instead, so edits here take effect live):

```bash
./install.sh
```

This symlinks the repo to `~/.config/omarchy/plugins/omadash/`, so
you keep editing files here and the running shell picks up changes live.

It also appends a default keybind to `~/.config/hypr/bindings.lua` (unless
a `red.omadash` bind is already there):

```lua
o.bind("SUPER + APOSTROPHE", "Omadash", "omarchy-shell shell toggle red.omadash")
```

Hyprland config hot-reloads on save. Press the bind — the popup should
appear; press it again (or Esc, or click outside) to close it.

To use a different combo, edit that line in `bindings.lua` directly, then
save (no reload command needed).

## Manual testing (no keybind needed)

```bash
omarchy-shell shell listPlugins          # confirm red.omadash is discovered
omarchy-shell shell toggle red.omadash
```

If edits to `Panel.qml` don't seem to apply, force a reload:

```bash
omarchy-shell shell rescanPlugins
```

## Next steps

- Swap the hardcoded colors for the shell's theme: `import qs.Commons` and
  use `Style.*` tokens, like the built-in plugins do.
- Take a JSON payload in `open(payloadJson)` to parameterize the popup
  (see `omarchy.menu`'s `Menu.qml` for a payload-driven example).
- Look through `/usr/share/omarchy/shell/plugins/` for more patterns:
  bar widgets (`kinds: ["bar-widget"]`), services, overlays.
