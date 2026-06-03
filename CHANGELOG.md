# Changelog

All notable changes to mpv Liquid Glass are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] — 2026-06-03

YouTube-style chapter and playlist navigation on the progress bar.

### Added

- **Chapter title on hover** — hovering the progress bar shows the title of the section under the cursor, in a readable label just above the bar. Untitled chapters fall back to "Chapter N".
- **Jump-to-chapter pill** — a floating "Jump: \<next chapter\>" pill sits on the filename line, right-aligned, while the controls are visible; clicking it skips to the next chapter.
- **Next-video pill** — within the last `liquid_glass_next_video_threshold` seconds (default 120) of a file that has a queued playlist item, the pill becomes "Next: \<video title\>" and plays the next entry on click.
- **`liquid_glass_next_video_threshold`** option in `liquid-glass.conf` to tune when the Next-video pill appears.

### Changed

- **Chapter markers** on the progress bar are now thicker and alternate red/blue with a contrasting outline, so chapter boundaries are easy to spot over any video (previously thin and white).

## [1.1.0] — 2026-05-30

Full keyboard control, plus a YouTube-style centered play/pause OSD. Every
keyboard action surfaces the same frosted-glass OSD the scroll wheel uses, so
feedback shows even when the mouse is idle and the control bar is hidden.

### Added

- **Keyboard seek** — `←` / `→` (or `A` / `D`) jump the video ±5 s, with the centered Seek OSD. Hold the key to keep seeking.
- **Keyboard volume** — `↑` / `↓` (or `W` / `S`) change volume by 5, with the centered Volume OSD. Hold to ramp.
- **Jump to position** — number keys `0`–`9` and numpad `KP0`–`KP9` seek to that percentage of the file (`0` = start … `9` = 90%), scaling with the video's duration.
- **Right-click play/pause** — right-clicking the video toggles playback.
- **Play / Pause OSD** — a centered glyph flashes on every pause toggle (right-click, spacebar, or the on-screen button), showing the pause icon when paused and the play icon when resumed, then auto-hiding after ~1 s. Uses the same icons as the control-bar transport button.

### Changed

- The numpad (`KP0`–`KP9`) now seeks by percentage instead of mpv's built-in video-size behavior.
- Keyboard-triggered OSDs now render even while the control bar is hidden, without popping the full bar into view.

## [1.0.0] — 2026-05-28

Initial release.

### Added

- **Full-width glass control bar** — frosted progress bar with chapter markers and click-to-seek + drag scrubbing, plus a YouTube-style button row in blurred glass pebbles.
- **Elastic speedometer** — a circular gauge whose needle springs and overshoots like a real cluster, with gold tick flashes, on scroll over the speed pebble.
- **Volume & seek OSDs** — centered frosted HUDs on scroll: speaker + percentage for volume, a camera glyph with progress for ±5 s seeking.
- **Real SVG icon pipeline** — every glyph is an actual `.svg` parsed into ASS at startup (`lib/liquid/svg.lua` + `svg_loader.lua`); drop a file into `assets/icons/` to swap it.
- **Dark & light themes** — glass tuned for each, toggled live with `Ctrl+T`.
- **Small-window & portrait-aware layout** — the bar reshapes itself in narrow / reels-sized windows; the progress bar stays full-width.
- **Idle screen** — a friendly Chill Cat illustration and prompt when no file is loaded.
- **Hover glow** and an **info button** toggling mpv's built-in stats overlay.

[1.1.0]: https://github.com/subhasisbiswal012/mpvLiquidGlassSkin/releases/tag/v1.1.0
[1.0.0]: https://github.com/subhasisbiswal012/mpvLiquidGlassSkin/releases/tag/v1.0.0
