# mpv Liquid Glass

A Liquid Glass skin for [mpv](https://mpv.io/), built as a restyled fork of [uosc](https://github.com/tomasklaen/uosc).

Apple's Liquid Glass design language, rendered with pure Lua + ASS — no compiled components, no native code, no build step for end users.

## Install
See [docs/install.md](docs/install.md).

## Customize
See [docs/customization.md](docs/customization.md).

## License
MIT (own code). Vendors uosc, which is LGPL-2.1; see `portable_config/scripts/uosc/LICENSE.LGPL` for attribution.

## Status
**Milestone 1 complete** (pre-alpha, awaiting visual smoke test).

Foundation libraries built and unit-tested (`theme`, `motion`, `icons`, `glass` in `portable_config/scripts/uosc/lib/liquid/`). uosc 5.9.2 vendored and patched to render the bottom control bar as three Liquid Glass pebbles (play / time / progress). 26 busted tests passing. mpv loads the skin without errors or warnings.

**Pending:** human visual confirmation that the pebbles render correctly on real video. To verify: `mpv --config-dir=portable_config <some-video>`.

**Next milestone:** restyle the top bar, timeline, volume popup, and menus.
