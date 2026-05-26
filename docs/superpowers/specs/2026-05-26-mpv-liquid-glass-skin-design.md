# mpv Liquid Glass Skin — Design Spec

**Date:** 2026-05-26
**Status:** Brainstorm → ready for implementation planning
**Author:** subha (with Claude)

---

## 1. Summary

A skin for the mpv media player that brings Apple's Liquid Glass design language to playback controls. Distributed as a fork of [uosc](https://github.com/tomasklaen/uosc) — the most mature OSC (on-screen controller) for mpv — with its rendering layer restyled while keeping its logic and feature set intact.

The skin ships as a drop-in folder users copy into their mpv config directory. No new binary, no native code, no build step for end users.

## 2. Goals

- Restyle every visible uosc surface to a single coherent Apple Liquid Glass aesthetic
- Ship as a pure Lua + ASS solution — no compiled components
- Stay rebase-able on top of upstream uosc so future uosc features come along for free
- Cross-platform support: Windows / macOS / Linux, all fully tested
- User-togglable light and dark themes
- Springy, liquid motion that matches the visual language
- Custom SF Symbols-style icons authored as ASS vectors (no PNG icons)

## 3. Non-goals

- Replicating Apple's true refractive backdrop-filter (libass cannot sample the video buffer)
- Adaptive theming based on video content
- Replacing uosc's event handling, menu logic, or state machines
- Native UI overlays (Qt/WinUI/etc.) on top of mpv
- Supporting non-uosc OSC scripts
- A GUI for configuration (we use `mpv.conf` / `script-opts/uosc.conf`)

## 4. Topology & Aesthetic Decisions (locked)

| Decision | Choice |
|---|---|
| Starting point | Fork uosc, restyle |
| Aesthetic intensity | Apple-style Liquid Glass (bright specular, prominent edge highlight) |
| Control-bar block topology | Three discrete pebbles (play / times / progress) |
| Scope | Everything uosc ships (full restyle, no surface left as default) |
| Theme | User-togglable light / dark |
| Platforms | Windows + macOS + Linux, fully supported |
| Motion | Springy / liquid (overshoot easing, soft settle) |
| Icons | Custom SF Symbols-style ASS vectors (~22 icons) |

## 5. Repo structure

```
mpv-liquid-glass/
├── README.md
├── LICENSE                           # MIT, inherits uosc's attribution
├── portable_config/                  # users copy this to %APPDATA%\mpv\ (or ~/.config/mpv/)
│   ├── scripts/
│   │   └── uosc/                     # the forked OSC
│   │       ├── main.lua              # entry point; mostly unchanged from upstream
│   │       ├── elements/             # ~30 component files; we restyle, don't rewrite
│   │       ├── lib/
│   │       │   ├── ass.lua           # uosc's ASS helpers (extended)
│   │       │   ├── glass.lua         # NEW — six-layer glass primitive
│   │       │   ├── theme.lua         # NEW — light/dark token tables
│   │       │   ├── motion.lua        # NEW — spring easings
│   │       │   └── icons.lua         # NEW — SF-style ASS vector paths
│   │       └── intl/                 # localizations, untouched
│   ├── fonts/
│   │   └── Geist-*.ttf               # bundled body font (sans, neutral, reads small)
│   └── script-opts/
│       └── uosc.conf                 # default config tuned for the skin
├── docs/
│   ├── install.md
│   ├── customization.md
│   └── screenshots/
├── tools/
│   ├── icon-forge.lua                # SVG → ASS path converter
│   ├── frost-noise.py                # one-time perlin-noise PNG generator
│   └── preview/                      # browser-based visual harness
│       ├── index.html
│       └── glass-mockup.css
└── docs/superpowers/specs/           # planning artifacts (this file lives here)
```

## 6. Core technique: the six-layer glass primitive

libass cannot do real backdrop-blur or SVG filter chains, so each glass pebble is a deterministic stack of six ASS layers, drawn in order:

| # | Layer | Recipe |
|---|---|---|
| 1 | Drop shadow | Soft black ellipse, 16px blur via `\blur`, 35% alpha (dark theme), offset y+8px |
| 2 | Glass body | Rounded rect, fill `rgba(255,255,255,9%)` dark / `rgba(255,255,255,55%)` light |
| 3 | Frost noise | Pre-baked 256×256 tiling perlin noise PNG, 6% alpha, additive blend |
| 4 | Top highlight | Linear gradient rect, white 30% → transparent across top 35% of pebble |
| 5 | Rim light | 1px rounded stroke on top edge only, white 55% |
| 6 | Border | 1px rounded stroke around full perimeter, white 22% |

Exposed as a single function in `lib/glass.lua`:

```lua
glass.draw(ass_builder, {
  x, y, w, h, r,           -- geometry, radius
  theme,                    -- 'dark' | 'light'  (default reads from theme.current)
  intensity,                -- 0.5–1.5 alpha multiplier (default 1.0)
})
```

The one binary asset in the repo: `frost-noise.png` (~8KB), generated once by `tools/frost-noise.py` and committed.

## 7. Theme system

`lib/theme.lua` holds two flat token tables — `dark` and `light` — and a `current` reference. Token names map directly to layers of the glass recipe plus content colors (ink, accent, progress fill).

User control:

```ini
# script-opts/uosc.conf
liquid_glass_theme=dark            # dark | light
liquid_glass_intensity=1.0         # 0.5 = subtler, 1.5 = more pronounced
liquid_glass_accent=E8553A         # optional override of accent color
```

```
# input.conf
Ctrl+t script-message liquid-glass-toggle-theme
```

Switching themes is a single assignment + redraw — no per-element conditional code.

## 8. Motion system

`lib/motion.lua` adds three easing curves on top of uosc's existing tween engine:

| Easing | Use | Curve |
|---|---|---|
| `spring_out` | Element appearance | 8% overshoot, 280ms settle |
| `spring_settle` | State transitions (play↔pause) | cubic-bezier(0.2, 0.8, 0.2, 1), 200ms, no overshoot |
| `liquid_fade` | Menu open/close | Alpha fade + 0.96→1.0 scale, 320ms |

Hover states settle at 180ms. mpv's `--no-osc-animation` flag (or a `reduced_motion=yes` script-opt) routes everything to instant transitions.

## 9. Icon system

22 hand-authored icons in `lib/icons.lua`, all as ASS vector path data:

```
play · pause · prev · next · fwd-10 · back-10
volume-mute · volume-low · volume-mid · volume-high
fullscreen-enter · fullscreen-exit · pip
subtitle · audio-track · chapter-list · playlist
settings · close · minimize · expand-menu · eject · search
```

Design grid: 24×24, 1.5pt stroke weight, rounded caps. Each icon is ~10–30 lines of ASS path. `tools/icon-forge.lua` accepts SVG path `d` attributes and emits ASS draw commands, so iterating on icons doesn't require manual path-data rewriting.

## 10. Component restyle scope

All ~30 files under `elements/` get the glass primitive applied. Implementation order (logical grouping for incremental rollout):

1. **Core playback chrome** — control_bar, top_bar, timeline, volume
2. **Big surfaces** — menu (used for many things), playlist, settings
3. **Pickers** — audio_picker, subtitle_picker, chapter_picker
4. **State surfaces** — idle_screen, buffering_indicator, message overlay
5. **Polish** — mouse_cursor_indicator, hover tooltips, edge cases

uosc's layout logic stays untouched. We replace the drawing calls, not the positioning math.

## 11. Customization surface

Exposed via `script-opts/uosc.conf`:
- `liquid_glass_theme` — `dark` | `light`
- `liquid_glass_intensity` — `0.5` to `1.5`
- `liquid_glass_accent` — hex color (optional)
- `liquid_glass_corner_radius` — pixels (default scales with control-bar height)
- `liquid_glass_show_frost_noise` — `yes` | `no` (some users may want flatter glass)

Power users can edit `theme.lua` directly for full control. Both paths documented in `docs/customization.md`.

## 12. Cross-platform considerations

| Concern | Approach |
|---|---|
| Font rendering differences | Bundle Geist (OFL-licensed, redistributable) and avoid relying on system-specific font names. Numerics use Geist Mono for tabular alignment in the time readouts. |
| DPI scaling | Use uosc's existing DPI-aware sizing (it already handles this) |
| Path separators in config | Lua-side normalization, already in uosc |
| Theme toggle persistence | mpv config file — same path on all platforms relative to mpv's config dir |
| Linux Wayland vs X11 | Both supported by mpv directly; OSC rendering is buffer-agnostic |

The skin's pure-ASS approach is inherently portable. Cross-platform testing is mostly checking that fonts render at expected metrics on each platform, not platform-specific code.

## 13. Preview / testing harness

`tools/preview/index.html` is a browser-rendered mockup of all glass components at 1× and 2× scale. Uses real CSS `backdrop-filter` (so it looks *better* than the mpv result — the preview is aspirational reference, not regression baseline). Helps iterate on color/sizing decisions without restarting mpv. Graduated and tidied from the brainstorming-phase mockups under `.superpowers/brainstorm/`.

## 14. Open risks & mitigations

| Risk | Mitigation |
|---|---|
| ASS `\blur` performance on large surfaces (playlist, menu) | Cache blurred drop shadow as a single PNG generated at first paint; redraw only when geometry changes |
| Frost-noise PNG anti-aliases poorly at non-integer DPI scales | Use 2× source resolution + ASS's bilinear sampling |
| Upstream uosc refactors break our patches | Pin to a specific uosc tag; document the rebase process in `docs/contributing.md` |
| Light theme readability over bright video content | Document this in `customization.md`; users can switch to dark or lower intensity |
| 22 icons may not cover all uosc menu actions | Audit uosc's icon usage before locking the set; add missing ones |

## 15. What this spec does NOT cover

- Specific Lua/ASS implementation details (those belong in the implementation plan)
- Visual mockups beyond the brainstorming companion artifacts (those live in `.superpowers/brainstorm/` for now)
- Distribution / release process (out of scope; project is in design phase)
- Localization changes (we touch zero strings)

---

**Next step:** transition to `writing-plans` skill to produce a detailed task-by-task implementation plan against this spec.
