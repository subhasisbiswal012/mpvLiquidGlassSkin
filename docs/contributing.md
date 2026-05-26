# Contributing

## Project layout
- `portable_config/scripts/uosc/` — our fork of uosc. Patches live here.
- `portable_config/scripts/uosc/lib/{theme,motion,icons,glass}.lua` — our additions; safe to evolve freely.
- `portable_config/scripts/uosc/elements/Controls.lua` — patched to consume the glass primitive.
- `tests/` — busted unit tests for our libraries.
- `tools/` — one-shot scripts (icon converter, noise PNG generator).

## Rebasing onto upstream uosc
1. Track upstream tag in `portable_config/scripts/uosc/UPSTREAM.md`.
2. Our patches are isolated to `elements/Controls.lua` (and later milestones).
3. Three-way merge: clone the new upstream tag to a sibling directory, then `diff -ur` each patched file against ours and the upstream's new version. Hand-merge.
4. Run `busted tests/` and a manual smoke playback before committing the rebase.

## Adding a new library file
Drop it in `portable_config/scripts/uosc/lib/`, add tests in `tests/`, expose via `require('lib.<name>')`.
