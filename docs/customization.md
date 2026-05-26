# Customize

Edit `script-opts/liquid-glass.conf` for Liquid Glass options, or `script-opts/uosc.conf` for uosc upstream options. Restart mpv.

## Knobs
| Option | Values | Default | What it does |
|---|---|---|---|
| `theme` | `dark`, `light` | `dark` | Glass tint and content color |
| `intensity` | `0.5`–`1.5` | `1.0` | Multiplier on all alpha values |
| `accent` | hex color | `E8553A` | Accent color (progress fill, selection) |
| `show_frost_noise` | `yes`, `no` | `yes` | Toggle the noise texture layer |

## Power users
Edit `scripts/uosc/lib/theme.lua` directly to change individual token values.
