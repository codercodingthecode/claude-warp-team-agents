# Contributing

This plugin currently supports **macOS only**. Contributions to bring it to Linux and Windows are very welcome.

## What needs to change per platform

The plugin has two platform-dependent pieces:

### 1. Pane splitting (`hooks/lib/pane.sh`)

Currently uses macOS AppleScript (`osascript`) to simulate Warp keyboard shortcuts (CMD+D, CMD+SHIFT+D). This is the hardest part — Warp has no programmatic pane API on any platform.

| Platform | Current approach | What's needed |
|----------|-----------------|---------------|
| macOS | AppleScript via `osascript` | Working |
| Linux | — | `xdotool` or `xdg-open` based approach. Warp on Linux uses the same keyboard shortcuts but needs X11/Wayland input simulation. |
| Windows | — | AutoHotkey, PowerShell `SendKeys`, or Win32 `SendInput`. Warp on Windows uses Ctrl+Shift+D / Ctrl+D for splits. |

### 2. Warp detection (`hooks/lib/warp.sh`)

Currently checks `TERM_PROGRAM=WarpTerminal`. This should work on all platforms — verify and adjust if Warp sets a different value on Linux/Windows.

### 3. Clipboard / typing

macOS uses `pbcopy`/`pbpaste`. The current approach types directly via AppleScript, but the retry loop may still touch the clipboard. Linux needs `xclip`/`xsel`, Windows needs `clip.exe`/PowerShell.

## Architecture

Everything platform-specific lives in `hooks/lib/pane.sh`. The rest of the plugin (payload parsing, model resolution, hook registration) is portable bash that works everywhere.

The cleanest approach for multi-platform: keep `pane.sh` as the macOS implementation, add `pane-linux.sh` and `pane-windows.sh`, and have the caller detect the OS and source the right one.

## How to contribute

1. Fork the repo
2. Create a branch (`git checkout -b linux-support`)
3. Implement the platform-specific pane splitting
4. Add tests (see `tests/` for examples)
5. Open a PR with a screen recording showing it working

## Known Warp limitations (all platforms)

- No programmatic pane split API (feature request: [#1550](https://github.com/warpdotdev/Warp/issues/1550), [#8741](https://github.com/warpdotdev/Warp/issues/8741))
- No AppleScript dictionary ([#3364](https://github.com/warpdotdev/Warp/issues/3364))
- `warp://` URI scheme cannot split panes or run commands in existing windows ([#9009](https://github.com/warpdotdev/Warp/issues/9009))
- Launch configurations open new windows, cannot split existing ones
- YAML workflows are interactive templates, not programmable

If Warp ships a proper pane API, the entire AppleScript approach can be replaced with a single API call. Watch the issues above.
