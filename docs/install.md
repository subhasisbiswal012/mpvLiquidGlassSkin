# Install

1. Locate your mpv config directory:
   - **Windows:** `%APPDATA%\mpv\`
   - **macOS:** `~/.config/mpv/`
   - **Linux:** `~/.config/mpv/`
2. Copy the **contents** of this repo's `portable_config/` into that directory.
3. Restart mpv.

Once running, **Ctrl+T** toggles between the dark and light Liquid Glass theme. See [docs/customization.md](customization.md) for more options.

## Updating
Re-copy `portable_config/` over your existing files.

## Uninstall
Delete `scripts/uosc/`, `fonts/Geist-*.ttf`, `fonts/LICENSE-Geist.txt`, `script-opts/uosc.conf`, and `script-opts/liquid-glass.conf` from your mpv config directory.

## Fonts
Geist (OFL-licensed) is bundled in `portable_config/fonts/`. mpv loads fonts from this directory automatically when it's part of your mpv config.
