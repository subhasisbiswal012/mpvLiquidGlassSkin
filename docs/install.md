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

## Cross-platform verification (Milestone 2)

After installing per the steps above, run through this checklist to confirm the skin renders correctly on your platform. Each item should look the same on Windows, macOS, and Linux — if it doesn't, file an issue with a screenshot.

### Visual smoke test

1. Launch mpv with any video file.
2. Move the mouse to the **top** of the window. Confirm:
   - A glass title bar fades in (no hard pop)
   - Close/minimize/maximize buttons render as three small glass pebbles
   - The file title sits inside a wide glass strip, left-aligned, in Geist
3. Move the mouse to the **bottom**. Confirm:
   - Three glass pebbles: play, time readout, progress
   - A slim glass timeline strip below the pebbles with an accent-colored progress fill
4. Move the mouse to the **right edge** (or `--volume=left` config side). Confirm:
   - A vertical glass capsule with accent fill matching the current volume level
   - A small glass pebble below it with the speaker icon
5. Hover the **play pebble**. It should scale up ~4% with a soft overshoot.
6. Press **Ctrl+T**. Both theme palettes should flip in one repaint.

### Font rendering

Tabular numerics in the time readout should align (`00:00 / 00:00` digits should sit at fixed widths). If they drift, mpv isn't picking up the bundled `GeistMono-Regular.ttf` — make sure `portable_config/fonts/` was copied into your mpv config directory.

### Known platform notes

- **Windows:** No known issues.
- **macOS:** Font subpixel rendering can make light theme text look softer. Switch to dark theme if that bothers you.
- **Linux/Wayland:** Same as X11; the skin doesn't touch windowing.
