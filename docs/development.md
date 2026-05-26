# Development

## Test
```bash
busted
```
Runs all `_spec.lua` files under `tests/`.

## Manual smoke test
```bash
mpv --no-config --script=portable_config/scripts/uosc/main.lua <some_video.mp4>
```
The `--no-config` flag bypasses your normal mpv config so the skin renders against vanilla defaults.

## Regenerate the frost-noise PNG
```bash
python3 tools/frost-noise.py
```
(Only needed if you change the noise parameters.)
