# mpv Liquid Glass

A modern, glass-styled skin for [mpv](https://mpv.io/) media player. Built as a restyled fork of [uosc](https://github.com/tomasklaen/uosc) with Apple's Liquid Glass design language — frosted glass controls, smooth spring animations, and a clean YouTube-style layout.

Pure Lua + ASS rendering. No compiled components, no native code, no build step. Just copy and play.

## Demo

https://github.com/subhasisbiswal012/mpvLiquidGlassSkin/raw/main/Video/Demo.mp4

If the player above doesn't load in your browser, [download or watch Demo.mp4 directly](Video/Demo.mp4).

![Full controls bar — progress, playback row, OSC row](screenshots/2%20Rows%20of%20Control%20Showing.png)

---

<!-- ───────────────────────────── FEATURES ───────────────────────────── -->

# Features

> The skin restyles every part of mpv's on-screen UI as frosted glass pebbles with springy motion, real SVG icons, and adaptive layouts. Each subsection below pairs the feature with the screenshot that shows it.

### Full-Width Glass Control Bar

![Two-row control layout with full-width progress + button row](screenshots/2%20Rows%20of%20Control%20Showing.png)

- **Full-width progress bar** with frosted glass effect, chapter markers, click-to-seek + drag scrubbing
- **Filename label** above the progress bar — currently-playing media title in **Bahnschrift SemiBold** with a soft dark outline + drop shadow so it stays readable on bright video in both light and dark themes
- **Fixed-width time block** (`X:XX / Y:YY    Z %`) so the layout doesn't reflow as digits tick over
- **Fixed-width quality block** (`HD / 1080p / 4K / …`) — bigger, bolder, clickable to open the codec / fps / bitrate panel
- **YouTube-style button row**: play/pause, prev/next, speed, quality, time + progress %, volume slider + %, info, playlist, audio, subtitle, settings, fullscreen
- All controls wrapped in frosted glass pebbles with soft drop shadows and blur

### Small-Window & Portrait Aware

![Adaptive control layout in a portrait / reels-sized window](screenshots/Reels%20Aspect%20Ratio%20Controls%20Show.png)

When the player window is narrow (portrait aspect, reels-style preview, or a docked corner), the control bar reshapes itself instead of overflowing:

- Non-essential pebbles collapse first, essential transport stays anchored
- The button row stays single-line — no controls overlap the time block or the progress bar
- The progress bar continues to span the full window width regardless of how thin the window gets

### SVG Icon Pipeline

Every glyph the player draws is a real `.svg` file under [`assets/icons/`](portable_config/scripts/uosc/assets/icons/). At startup, [`lib/liquid/svg.lua`](portable_config/scripts/uosc/lib/liquid/svg.lua) parses each file into ASS drawing commands and `lib/liquid/svg_loader.lua` registers them into the icon registry.

- **Per-path fill / stroke modes** — stroke icons render with libass `\bord`, fills with `\1c`. Stroke width scales with icon size so a 1.5 px design stays proportional at any pebble.
- **Full SVG path syntax** — `M L H V C S A Z` plus their lowercase relative variants, smooth-cubic continuation, viewBox normalization.
- **Element support** — `<path>`, `<circle>`, `<line>`, `<rect rx ry>`, `<g opacity>`, `<g transform>` with affine matrix / translate / scale, `<defs>` / `<clipPath>` / `<mask>` correctly skipped instead of rendered as artwork.
- **Inline CSS** — `style="fill:#XXX;opacity:0.4"` (Adobe Illustrator's export style) reads alongside XML attributes.
- **Per-shape colours** for multi-colour illustrations. Monochrome icons stay tinted to the player's ink.

Drop any SVG into `assets/icons/<name>.svg` and the loader picks it up on next launch.

### Volume OSD

![Centered Volume OSD with speaker icon and percentage](screenshots/Showing%20Audio%20OSD.png)

Scroll the wheel over the volume block (or anywhere on the volume pebble) and a centred frosted-glass HUD pops up — large speaker SVG plus the current percentage. Same SVG as the inline volume control, just bigger. Auto-hides after the scroll burst ends.

### Seek OSD

![Centered Seek OSD with video camera icon and progress percent](screenshots/Showing%20Video%20OSD.png)

Scroll the wheel anywhere on the video itself and the player seeks ±5 s, surfacing a centred Seek HUD with a video-camera SVG and a clean progress %. The white background that ships with SVGRepo's `clipPath` is correctly stripped at parse time so only the camera silhouette shows.

### Play / Pause OSD

A YouTube-style centred HUD flashes the play/pause glyph in the middle of the player on **every** pause toggle — right-click, spacebar, or the on-screen play button. Shows the **pause** icon when you pause and the **play** icon when you resume (the same SVGs as the control-bar transport button), then auto-hides after ~1 s.

### Elastic Speedometer

![Speedometer OSD with elastic needle, tick flash, and gold glow](screenshots/Showing%20Speed%20OSD.png)

Scroll the wheel over the speed pebble and a big circular gauge pops up in the centre of the player. The needle springs to the new speed like a bike cluster — overshoots once, settles in ~0.6 s.

- **Semi-implicit Euler spring** with tunable stiffness / damping. Default 160 / 18 gives one visible overshoot bob.
- **Tick flash** — each tick mark briefly pulses gold (and the label flashes too) as the needle sweeps past it.
- **Optional tick sound** — drop a `tick.wav` into [`assets/sounds/`](portable_config/scripts/uosc/assets/sounds/) and a short PowerShell `Media.SoundPlayer` subprocess plays it on each scroll click (Windows; macOS / Linux fallback is silent).
- **Speed range** matches the existing speed picker (0.25× → 3.0× in 0.25 steps).
- OSD auto-hides 1.8 s after the last scroll.

### Idle Screen

![Idle screen with Chill Cat illustration and friendly prompt](screenshots/Player%20SS%20with%20Instruction%20to%20Put%20Video%20and%20URL%20when%20open%20app.png)

With no file loaded, the stock "Drop files or URLs here" indicator is replaced with a **Chill Cat illustration** and a friendlier prompt. Comes with a hand-picked font (Spell of Asia by default) and a fully-tunable layout — see Customise below.

### Hover Glow

A subtle warm-gold luminosity bleeds outward from whichever icon or text label the cursor is over. The glass pebble itself stays still — only the glyph lights up. Single colour, single thickness, one knob for the whole player.

- Stroked icons get a fat blurred halo around the silhouette (`\bord` + `\be`)
- Text labels get a blurred outline (`\bord` + `\3c` + `\be`)
- All driven by `icons.draw_glow_at()` so any icon you swap in inherits it for free

### Smart Scroll Behaviour

- **Scroll on the speed pebble** = elastic speedometer (above)
- **Scroll on the volume block** = adjust volume + Volume OSD (above)
- **Scroll anywhere else on the video** = seek ±5 s + Seek OSD (above)

### Keyboard & Controller Controls

Full keyboard control, with the same centred glass OSDs the scroll wheel uses — so feedback shows even when the mouse is idle and the control bar is hidden. Gamer-friendly `WASD` aliases are bound alongside the arrow keys.

- **Seek** — `←` / `→` or `A` / `D` jump ±5 s and surface the Seek OSD. Hold the key to keep seeking.
- **Volume** — `↑` / `↓` or `W` / `S` adjust volume ±5 and surface the Volume OSD. Hold to ramp.
- **Jump to position** — number keys `0`–`9` (top row **and** the numpad `KP0`–`KP9`) seek to that percentage of the file: `0` = start, `5` = 50%, `9` = 90%. Scales with the video's duration.
- **Play / Pause** — right-click the video to toggle, with the centred Play/Pause OSD (above).

### Info Button

Between the audio and playlist buttons on the right side. One click toggles mpv's built-in stats overlay (codec, fps, bitrate, dropped frames, …).

### Theme Support

- **Dark theme** (default) — glass tinted for dark video backgrounds
- **Light theme** — lighter glass with dark text
- Toggle with **Ctrl+T** during playback

---

<!-- ───────────────────────────── INSTALL ───────────────────────────── -->

# Install

> Three steps. No compile, no dependencies, no build tools. If you already have mpv installed, you're 30 seconds away from running the skin.

### 1. Download the release zip

Grab the latest **`mpv-liquid-glass-vX.Y.Z.zip`** from the [Releases page](https://github.com/subhasisbiswal012/mpvLiquidGlassSkin/releases/latest) (~1 MB — contains only what mpv needs to run the skin, no docs / tests / screenshots) and unzip it. You'll get a single `mpv-liquid-glass/` folder.

> **Prefer the full repo?** If you want tests, planning docs, and the asset sources too, `git clone https://github.com/subhasisbiswal012/mpvLiquidGlassSkin.git` instead — the skin lives under `portable_config/`.

### 2. Locate your mpv config directory

| OS | Path |
|---|---|
| **Windows** | `%APPDATA%\mpv\` |
| **macOS** | `~/.config/mpv/` |
| **Linux** | `~/.config/mpv/` |

If the folder doesn't exist yet, create it.

### 3. Copy the skin in

Copy the **contents** of the unzipped `mpv-liquid-glass/` folder (or this repo's `portable_config/` directory if you cloned) into your mpv config directory — the `scripts/`, `fonts/`, and `script-opts/` folders should land alongside any existing `mpv.conf` you have.

### 4. Restart mpv

The Liquid Glass skin loads automatically on next launch. No extra config switches required.

---

### Quick Test (without modifying your existing mpv config)

If you'd rather try the skin in isolation first — without touching your existing mpv setup — run mpv directly against this repo's bundled config:

```bash
mpv --config-dir=portable_config <your-video-file>
```

This runs mpv with the skin's config only. Your existing mpv setup is untouched. If you like what you see, do steps 1–4 above.

---

## Customise

### Theme & Animation
Edit `script-opts/liquid-glass.conf` in your mpv config directory:

| Option | Values | Default | What it does |
|---|---|---|---|
| `liquid_glass_theme` | `dark`, `light` | `dark` | Glass tint and text colour |
| `liquid_glass_intensity` | `0.5` to `1.5` | `1.0` | Multiplier on all glass alpha values |
| `liquid_glass_accent` | hex colour | `E8553A` | Accent colour (needle, hub, progress fill) |
| `liquid_glass_show_frost_noise` | `yes`, `no` | `yes` | Toggle the noise texture layer |
| `reduced_motion` | `yes`, `no` | `no` | Skip spring animations |

### Hover Glow (Controls.lua, ~line 499)
```lua
local LG_GLOW_COLOR      = 'FFD24C'   -- hex RRGGBB
local LG_GLOW_BLUR       = 6          -- libass \be iterations (1 tight … 10 cloud)
local LG_GLOW_ALPHA      = '&H80&'    -- &H00& solid → &HFF& invisible
local LG_ICON_GLOW_BORD  = 5          -- icon halo thickness in screen px
local LG_TEXT_GLOW_BORD  = 6          -- text outline thickness
```

### Per-Icon Sizes (Controls.lua, ~line 512)
Each value is a fraction of the pebble's height (default pebble = 42 px). Bump a number to enlarge that one glyph.
```lua
local LG_ICON_SCALES = {
    play = 0.50, pause = 0.50, prev = 0.50, ['next'] = 0.50,
    speed = 0.55, subtitle = 0.62, audio_track = 0.55,
    info = 0.55, playlist_play = 0.55, settings = 0.60,
    fullscreen_enter = 0.55, fullscreen_exit = 0.55,
    volume_up = 0.55, volume_down = 0.55,
    volume_mute = 0.55, volume_off = 0.55,
}
```

### Time + Quality Block (Controls.lua, ~line 612)
```lua
local TIME_BLOCK_FS_WIDE   = 28    -- font size
local TIME_BLOCK_W_WIDE    = 250   -- fixed pill width
local TIME_TEXT_GAP        = '    '  -- spacing between "X / Y" and "Z %"
local QUALITY_FS_WIDE      = 24
local QUALITY_W_WIDE       = 90
local VOL_PCT_FS           = 22
```

### Title Font (Controls.lua, ~line 643)
```lua
local FILENAME_FONT = 'Bahnschrift SemiBold'   -- any installed font family
local FILENAME_FS   = 30
local FILENAME_BORD = 2   -- outline px
local FILENAME_SHAD = 2   -- shadow px
```

### Speedometer (Controls.lua, ~line 415)
```lua
local LG_SPEED_STIFFNESS = 160   -- snappier ↑, looser ↓
local LG_SPEED_DAMPING   = 18    -- less overshoot ↑, more bobs ↓
local LG_SPEED_OSD_HOLD  = 1.8   -- seconds after last scroll
local LG_SPEED_FLASH_DUR = 0.22  -- gold tick flash duration
```
Try `110 / 7` for a sloppy carnival feel, `200 / 22` for a digital cluster look.

### Idle Screen (lib/utils.lua, ~line 920)
```lua
local IDLE_FONT     = 'Spell of Asia'
local IDLE_TEXT     = "What're ya lookin' at? Drop a file or URL already, will ya?"
local IDLE_FS       = 56
local IDLE_CAT_FRAC = 0.36   -- cat height as fraction of display height
local IDLE_CAT_MAX  = 420    -- pixel ceiling
local IDLE_TEXT_GAP = 32
```

### Custom Fonts
Drop any `.ttf` / `.otf` into [`portable_config/fonts/`](portable_config/fonts/) and mpv auto-loads it on startup. Then put the font's family name into `FILENAME_FONT` / `IDLE_FONT` / the speedo value text.

The repo ships with:
- **Geist** (Vercel, OFL) — body / time / quality
- **Bahnschrift SemiBold** (Windows system) — filename label
- **Spell of Asia** (user-installable) — idle prompt

### Custom Icons
Drop any 24 × 24 viewBox SVG into `assets/icons/<name>.svg` matching one of the registry names (`play`, `pause`, `next`, `prev`, `speed`, `subtitle`, `audio_track`, `info`, `playlist_play`, `settings`, `fullscreen_enter`, `fullscreen_exit`, `volume_up`, `volume_down`, `volume_mute`, `volume_off`, `video_camera`). The loader replaces the inline ASS path on next launch.

### Tick Sound
Drop a short `tick.wav` (16-bit PCM, 30–80 ms) into [`assets/sounds/`](portable_config/scripts/uosc/assets/sounds/). The speedometer plays it on each scroll click. Delete the file to disable audio (the gold visual flash still fires).

### Keyboard Shortcuts

| Key | Action |
|---|---|
| `←` / `→`, `A` / `D` | Seek ∓5 s (hold to repeat) + Seek OSD |
| `↑` / `↓`, `W` / `S` | Volume ±5 (hold to repeat) + Volume OSD |
| `0`–`9`, `KP0`–`KP9` | Jump to 0–90 % of the file + Seek OSD |
| `Right-click` | Toggle play/pause + centred Play/Pause OSD |
| `Ctrl+T` | Toggle dark/light theme |

All bindings live in [`portable_config/input.conf`](portable_config/input.conf) — edit or remap them there.

## How It Works

The skin is built on five core libraries under `scripts/uosc/lib/liquid/`:

- **glass.lua** — Layered rendering primitive (drop shadow, glass body, frost noise, top highlight, border)
- **theme.lua** — Dark/light token tables with intensity multiplier
- **motion.lua** — Spring easing curves (overshoot, settle, liquid fade)
- **icons.lua** — Icon registry + `draw_at` / `draw_glow_at` renderers (per-shape stroke/fill, per-shape colour, libass alpha + tag injection)
- **svg.lua** — SVG → ASS converter (path commands, transforms, viewBox normalization, `<defs>` skipping)
- **svg_loader.lua** — Walks `assets/icons/` at startup and registers each file into the icon registry

These libraries are consumed by patched uosc element files (`Controls.lua`, `TopBar.lua`, `Timeline.lua`, `Volume.lua`) which replace the stock rendering with glass-styled equivalents.

## Requirements

- **mpv** (any recent version)
- No additional dependencies for end users
- For the tick sound on Windows: PowerShell (ships with the OS). macOS / Linux currently silent — patch the `_lg_play_tick_sound` helper in `Controls.lua` with `afplay` / `paplay` if you want audio there.

### For Development

- Lua 5.1+ and [busted](https://github.com/lunarmodules/busted) for running tests
- Run `busted` from the project root

## Credits

- Built on [uosc](https://github.com/tomasklaen/uosc) by [tomasklaen](https://github.com/tomasklaen) (LGPL-2.1)
- [Geist](https://vercel.com/font) font by Vercel (OFL)
- Icon set adapted from [SVG Repo](https://www.svgrepo.com/) (CC0)
- Inspired by Apple's Liquid Glass design language

## License

MIT (own code). Vendors uosc (LGPL-2.1). See `portable_config/scripts/uosc/LICENSE.LGPL` for uosc attribution.
