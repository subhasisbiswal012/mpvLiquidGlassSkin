# mpv Liquid Glass

A modern, glass-styled skin for [mpv](https://mpv.io/) media player. Built as a restyled fork of [uosc](https://github.com/tomasklaen/uosc) with Apple's Liquid Glass design language — frosted glass controls, smooth spring animations, and a clean YouTube-style layout.

Pure Lua + ASS rendering. No compiled components, no native code, no build step. Just copy and play.

![Controls and Progress Bar](screenshots/Progress%20Bar%20and%20Other%20Controls%20SS.png)

## Features

### Glass Controls
- **Full-width progress bar** with frosted glass effect, chapter markers, and click-to-seek + drag scrubbing
- **YouTube-style button row**: Play/Pause, Skip Previous/Next, Speed, Quality, Time + Progress %, Volume with horizontal slider + %, and right-side utility buttons
- All controls wrapped in frosted glass pebbles with soft drop shadows and blur

### Smart Scroll Behavior
- **Scroll on volume block** = adjust volume
- **Scroll anywhere else on video** = seek forward/backward 5 seconds
- No accidental volume changes while browsing the timeline

### macOS-Style Centered OSD
When you scroll to adjust volume or seek, a large centered glass overlay appears (like macOS volume HUD):

![Volume OSD](screenshots/All%20The%20Controls%20and%20Column%20OSD.png)

- **Volume OSD**: Big speaker icon + volume percentage, centered on screen
- **Seek OSD**: Video camera icon + progress percentage, centered on screen
- Only one OSD shows at a time, auto-hides after 2 seconds

### Playback Controls
- **Speed button**: Click to choose playback speed (0.25x to 3x)
- **Quality indicator**: Shows current video resolution (1080p, 720p, 4K, etc.). For streaming URLs, click to switch quality.
- **Playlist button**: Opens the playlist picker
- **Audio track button**: Switch between audio tracks
- **Subtitle (CC) button**: Load or switch subtitles
- **Settings button**: Opens the full settings menu (chapters, navigation, utilities, etc.)
- **Fullscreen button**: Toggle fullscreen

![All Controls](screenshots/All%20The%20Controls%20With%20Video%20OSD%20Visual.png)

### Motion & Animation
- **Spring hover-scale** on the Play button (soft overshoot on hover)
- **Spring-eased fade** on the top bar visibility
- `reduced_motion` option for users who prefer no animation

### Theme Support
- **Dark theme** (default) — glass tinted for dark video backgrounds
- **Light theme** — lighter glass with dark text
- Toggle with **Ctrl+T** during playback

## Install

1. **Download** this repo (Code > Download ZIP, or `git clone`).
2. **Locate your mpv config directory:**
   - **Windows:** `%APPDATA%\mpv\`
   - **macOS:** `~/.config/mpv/`
   - **Linux:** `~/.config/mpv/`
3. **Copy** the contents of `portable_config/` into your mpv config directory.
4. **Restart mpv.** The Liquid Glass skin will load automatically.

### Quick Test (without modifying your config)

```bash
mpv --config-dir=portable_config <your-video-file>
```

This runs mpv with the skin's config in isolation — your existing mpv setup is untouched.

## Customize

Edit `script-opts/liquid-glass.conf` in your mpv config directory:

| Option | Values | Default | What it does |
|---|---|---|---|
| `liquid_glass_theme` | `dark`, `light` | `dark` | Glass tint and text color |
| `liquid_glass_intensity` | `0.5` to `1.5` | `1.0` | Multiplier on all glass alpha values |
| `liquid_glass_accent` | hex color | `E8553A` | Accent color for progress fill |
| `liquid_glass_show_frost_noise` | `yes`, `no` | `yes` | Toggle the noise texture layer |
| `reduced_motion` | `yes`, `no` | `no` | Skip spring animations |

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `Ctrl+T` | Toggle dark/light theme |

## How It Works

The skin is built on four core libraries under `scripts/uosc/lib/liquid/`:

- **glass.lua** — Six-layer rendering primitive (drop shadow, glass body, frost noise, top highlight, rim light, border)
- **theme.lua** — Dark/light token tables with intensity multiplier
- **motion.lua** — Spring easing curves (overshoot, settle, liquid fade)
- **icons.lua** — 24+ hand-crafted ASS vector icons

These libraries are consumed by patched uosc element files (`Controls.lua`, `TopBar.lua`, `Timeline.lua`, `Volume.lua`) which replace the stock rendering with glass-styled equivalents.

## Requirements

- **mpv** (any recent version)
- No additional dependencies for end users

### For Development

- Lua 5.1+ and [busted](https://github.com/lunarmodules/busted) for running tests
- Run `busted` from the project root (29 tests)

## Credits

- Built on [uosc](https://github.com/tomasklaen/uosc) by [tomasklaen](https://github.com/tomasklaen) (LGPL-2.1)
- [Geist](https://vercel.com/font) font by Vercel (OFL)
- [Material Icons](https://fonts.google.com/icons) by Google (Apache 2.0)
- Inspired by Apple's Liquid Glass design language

## License

MIT (own code). Vendors uosc (LGPL-2.1) and Material Icons (Apache 2.0). See `portable_config/scripts/uosc/LICENSE.LGPL` for uosc attribution.
