# Contributing

## Project layout
- `portable_config/scripts/uosc/` — our fork of uosc. Patches live here.
- `portable_config/scripts/uosc/lib/liquid/{theme,motion,icons,glass}.lua` — our additions; safe to evolve freely. Sub-namespaced under `liquid/` to avoid collisions with upstream uosc's `lib/`.
- `portable_config/scripts/uosc/elements/Controls.lua` — patched to consume the glass primitive.
- `tests/` — busted unit tests for our libraries.
- `tools/` — one-shot scripts (icon converter, noise PNG generator).

## Rebasing onto upstream uosc
1. Track upstream tag in `portable_config/scripts/uosc/UPSTREAM.md`.
2. Our patches are isolated to `elements/Controls.lua` (and later milestones).
3. Three-way merge: clone the new upstream tag to a sibling directory, then `diff -ur` each patched file against ours and the upstream's new version. Hand-merge.
4. Run `busted tests/` and a manual smoke playback before committing the rebase.

## Adding a new library file
Drop it in `portable_config/scripts/uosc/lib/liquid/`, add tests in `tests/`, expose via `require('lib/liquid/<name>')`. (We use slash form to match upstream uosc's `require('lib/utils')` convention.)

## Licensing

Files under `portable_config/scripts/uosc/` (except for `lib/liquid/`, see below) are LGPL-2.1, inherited from upstream uosc. Modifications to those files — for example the `Controls.lua` patch in Task 11 — must remain LGPL-compatible.

Our additions live under `portable_config/scripts/uosc/lib/liquid/` (theme, motion, icons, glass). Those files are MIT-licensed (project's own license).

Our MIT libs may `require()` upstream LGPL modules — LGPL-2.1 §6 explicitly permits this dynamic-linking pattern. **Do not** copy upstream LGPL source code into our MIT files; depend on it via require, don't paste.

When in doubt: keep our code in `lib/liquid/`, leave upstream code where it is, and `require()` across the boundary.
