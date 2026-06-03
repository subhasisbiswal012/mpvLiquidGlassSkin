# Chapter & Playlist Navigation — Design Spec

**Date:** 2026-06-03
**Branch:** `feature/chapter-navigation`
**Status:** Approved, ready for planning

## Summary

Add YouTube-style section navigation to the Liquid Glass skin (built on uosc):

1. Hovering the progress bar shows the **chapter title** of the section under the cursor.
2. The **hovered chapter's full span glows** on the progress bar.
3. A conditional floating **pill** offers a one-click **jump to the next chapter**.
4. Near the end of a video, that same pill switches to a **"Next video"** card when a playlist item is queued.

All four read uosc's existing chapter and playlist state — no new state plumbing.

## Context

- The skin is upstream **uosc** plus a custom `liquid-glass` theme and a customized `Timeline.lua`.
- `Timeline.lua` already renders chapter ticks (`Timeline.lua:226`) and a hover tooltip that currently shows only `HH:MM:SS` (`Timeline.lua:255`).
- Available state (maintained by uosc, no changes needed):
  - `state.chapters` — array of `{time, title, index, lowercase_title}`
  - `state.current_chapter` — current chapter object (has `.index`)
  - `state.has_playlist`, `state.playlist_count`, `state.playlist_pos` (1-based)
  - `state.duration`, `state.time`
- Next playlist video title: read on demand from mpv property `playlist/<pos>/title`, fallback to `playlist/<pos>/filename` basename.

## Components

### 1. Chapter-aware hover tooltip — *edit `Timeline.lua`*

- On hover, find the chapter whose span contains `hover_time` (the last chapter with `time <= hover_time`).
- Render **only the chapter title** above the timeline — no timestamp.
- Fallbacks:
  - Untitled chapter → `"Chapter N"` (N = 1-based index).
  - Hover before the first chapter's start time → **no tooltip**.
  - File has no chapters → no tooltip (current time-only behavior is removed).
- Long titles truncate with `…` to a sensible max width.

### 2. Hovered-chapter glow — *edit `Timeline.lua`*

- Replaces today's thin cursor line.
- When hovered, compute the hovered chapter's span: `[chapter.time, next_chapter.time)`, clamped to `[0, duration]` (last chapter's end = `duration`).
- Draw a soft accent glow band over that x-range on the progress strip, using the `liquid_glass_accent` color and ASS `\blur`.
- No chapters / hover in pre-first-chapter gap → no glow.

### 3. Floating skip pill — *new element `SkipPill.lua`*

A single uosc element anchored above the **right** end of the timeline. Resolves to exactly **one** of three states per frame:

| State | Condition | Label | Click action |
|---|---|---|---|
| **Jump** | `next_chapter` exists AND uosc controls are visible | `Jump: <next chapter title> ⏭` | `add chapter 1` |
| **Next video** | `duration - time <= next_video_threshold` AND a next playlist item exists | `Next: <next video title> ⏭` | `playlist-next` |
| **Hidden** | neither | — | — |

- **Priority:** Next-video state wins if both are somehow true (only realistic in the last chapter near the end). In practice they are mutually exclusive: the Jump state needs a next chapter, which the last chapter lacks.
- **Next-video visibility** is automatic in the threshold window (does not require controls to be visible) — it is the end-of-video CTA. The **Jump** state requires controls visible (it is a navigation affordance, not a CTA).
- Styled as a glass pill consistent with the skin: accent-tinted, rounded, with the existing glass treatment. Title truncates with `…`.
- Implemented as its own element (not folded into `Timeline.lua`) so it owns its render + click-zone and keeps the already-large `Timeline.lua` from growing.

### Configuration — `script-opts/liquid-glass.conf`

- `next_video_threshold=120` — seconds remaining at/below which the Next-video pill appears.

## Data Flow

```
mpv properties ──► uosc state (chapters, current_chapter, playlist_*, time, duration)
                        │
        ┌───────────────┼────────────────────────────┐
        ▼               ▼                             ▼
  Timeline tooltip  Timeline glow              SkipPill element
  (chapter at        (hovered chapter           (next_chapter / next
   cursor)            span → glow band)           playlist item → pill)
```

No new observers or state setters. The pill recomputes its mode each render from existing state; the next-video title is fetched lazily from `playlist/<pos>/title` and cached until `playlist_pos` changes.

## Error / Edge Handling

- No chapters → no ticks (existing), no glow, no tooltip, no Jump pill.
- Single video / no playlist → no Next-video pill.
- Last playlist video → no Next-video pill.
- Last chapter → no Jump pill.
- Untitled chapter / missing playlist title → graceful fallbacks (`Chapter N`, filename basename).
- Long titles → ellipsis truncation.
- Portrait / small windows → pill scales with uosc and respects existing min-size floors so it never overlaps controls.

## Testing

Pure-logic helpers extracted so they are unit-testable with busted (alongside existing `tests/`):

- `chapter_at_time(chapters, t)` → chapter or nil
- `next_chapter(chapters, current_index)` → chapter or nil
- `chapter_span(chapters, index, duration)` → `{start, stop}`
- `should_show_next_video(time, duration, threshold, has_next)` → bool
- `next_playlist_title(...)` → string

Visual behavior (glow band, pill render/click, threshold trigger) verified manually against a chaptered file and a 2-item playlist.

## Out of Scope

- Keybinds for next/prev chapter (one-line `input.conf` add anytime later).
- Chapter list menu (uosc already provides `script-binding uosc/chapters`).
