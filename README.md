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
**Milestone 2 complete:** Top bar, timeline, and volume slider all restyled as Liquid Glass. Icon set expanded from 4 to 22. Spring motion library wired into TopBar visibility fade and play-pebble hover. 29 busted tests passing.

To verify: `mpv --config-dir=portable_config <some-video>`.

**Next milestone:** menus, playlist, settings, pickers.
