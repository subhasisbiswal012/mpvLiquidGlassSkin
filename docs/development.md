# Development

## Setup

You need Lua + LuaRocks + busted available on your PATH to run tests.

**Windows (PowerShell):**
```powershell
winget install DEVCOM.Lua
winget install BrechtSanders.WinLibs.POSIX.UCRT  # gcc, required for busted's deps
luarocks install busted
# Ensure %APPDATA%\luarocks\bin is on PATH
```
busted on Windows installs as a Lua script without a `.bat` wrapper. If `busted` isn't directly invocable, create `%APPDATA%\luarocks\bin\busted.bat` that runs `lua "%APPDATA%\luarocks\bin\busted" %*`.

**macOS:**
```bash
brew install lua luarocks
luarocks install busted
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install lua5.1 luarocks
luarocks install busted
```

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

## Lua compatibility

Tests run under whatever Lua your `luarocks` installs (often 5.4 on Windows), but mpv ships LuaJIT (5.1-compatible) so production runs on **Lua 5.1 semantics**. Avoid 5.2+ features in `portable_config/scripts/uosc/lib/liquid/`:

- No `goto` statements / labels
- No integer-division operator `//` (use `math.floor(a/b)`)
- No native bitwise operators `& | ~ << >>` (use `bit.band`, `bit.bor`, etc. — LuaJIT ships `bit`)
- No `<const>` / `<close>` variable attributes
- No integer/float subtype assumptions — treat all numbers as Lua 5.1 floats

If a `lib/liquid/` test passes locally but mpv fails to load the script, version mismatch is the first thing to check.

## Regenerate the frost-noise PNG
```bash
python3 tools/frost-noise.py
```
(Only needed if you change the noise parameters.)
