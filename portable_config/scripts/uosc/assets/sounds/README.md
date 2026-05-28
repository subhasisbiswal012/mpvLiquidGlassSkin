# Sound effects

Drop a short audio file here named `tick.wav` and the speedometer OSD
will play it each time the needle crosses a tick mark while you're
scrolling on the speed pebble.

## Format

- File name: `tick.wav` (exact name; case-sensitive on some setups)
- Encoding: 16-bit PCM WAV
- Sample rate: 44.1 kHz or 48 kHz
- Duration: 30–80 ms is the sweet spot — a sharp clicky transient

If `tick.wav` is absent the OSD is silent (the gold tick flash still
fires either way), so removing the file is a safe way to disable
audio without touching code.

## Platform support

Playback is wired through `powershell -Command "(New-Object
Media.SoundPlayer '…').Play()"` on Windows. macOS / Linux users will
get the visual flash but no audio; add a platform branch in
`elements/Controls.lua` (`_lg_play_tick_sound`) using `afplay` /
`paplay` if you need it there.

## Throttling

The helper throttles to one tick per ~80 ms to keep rapid scrolls
from queueing dozens of subprocess spawns. If you raise the spring
oscillation count and want more ticks per second, lower the
`_lg_tick_last_play` gate in `Controls.lua`.
