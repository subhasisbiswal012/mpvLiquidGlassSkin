# mpv Liquid Glass — YouTube Tutorial Script

**Format:** AI voiceover (ElevenLabs / Edge TTS) over screen recordings + Demo.mp4
**Target length:** ~3:30
**Footage you have:** `Demo.mp4`, Recording #1 (install mpv), Recording #2 (install skin)

> **How to use this file:** Each beat has the **VOICEOVER** line (paste straight into your TTS engine), the **VISUAL** (what's on screen), and **EDIT NOTES** (zooms, callouts, speed). Narration is written to land at the listed timecode at a normal speaking pace.

---

## 0. Cold-open hook — `0:00–0:18`

**VISUAL:** Best 3–4 moments from `Demo.mp4`, fast cuts — frosted glass control bar, elastic speedometer bobbing, theme toggle (Ctrl+T) dark→light, volume OSD popping up. No UI chrome, just the skin looking gorgeous.

**VOICEOVER:**
> "This is mpv — the media player — but it's never looked like this. Frosted glass controls, springy animations, Apple's Liquid Glass design, completely free. Let me show you how to get it running in under two minutes."

**EDIT NOTES:** Punchy music starts on frame one. Cut on the beat. End the hook on the theme-toggle moment — it's the most "wow."

---

## 1. What it is — `0:18–0:38`

**VISUAL:** Clean title card: **"mpv Liquid Glass"** over a slow, calm clip of the idle screen (Chill Cat) or the full control bar.

**VOICEOVER:**
> "It's called mpv Liquid Glass — a skin built on top of uosc. Pure Lua, no compiling, no extra software. If you can copy and paste a folder, you can install this. There are two parts: first we install mpv itself, then we drop the skin in. Let's go."

**EDIT NOTES:** Keep title card on screen ~3s. Lower-third text: "Restyled fork of uosc · MIT licensed".

---

## 2. Install mpv — `0:38–1:35`  *(Recording #1)*

**VISUAL:** Your mpv-install recording.

**VOICEOVER:**
> "First, mpv. If you already have it, skip ahead to the next chapter. Head to mpv.io and grab the build for your system. On Windows that's the latest release — download it, and unzip it somewhere you'll keep it, like your Program Files or a tools folder. That's it — mpv itself doesn't need an installer. Once you can open a video with mpv, you're ready for the fun part."

**EDIT NOTES:**
- Zoom + highlight the **download link** when the cursor reaches it.
- Speed-ramp the download progress bar to 3×–4× with a whoosh.
- Text callout on screen: **`mpv.io`**.
- Add a chapter marker here so viewers can skip.

---

## 3. Install the skin — `1:35–2:45`  *(Recording #2)*

**VISUAL:** Your skin-install recording, following the README's 3 steps.

**VOICEOVER:**
> "Now the skin. Go to the project's Releases page on GitHub and download the latest zip — it's about one megabyte. Unzip it, and you'll get a single 'mpv-liquid-glass' folder. Next, find your mpv config folder. On Windows, paste this into your address bar: percent-APPDATA-percent, backslash, mpv. If that folder doesn't exist yet, just create it. Now copy the *contents* of the unzipped folder — the scripts, fonts, and script-opts folders — straight into that mpv folder. That's the whole install. Restart mpv, open any video, and the Liquid Glass skin loads automatically."

**EDIT NOTES:**
- Zoom + highlight the **Releases "latest" button**.
- BIG text callout of the path: **`%APPDATA%\mpv\`** — hold it long enough to pause-and-copy.
- Highlight the three folders being copied: `scripts/`, `fonts/`, `script-opts/`.
- Speed-ramp the unzip/copy to 2×–3×.
- Optional callout: "No config switches needed — it just loads."

---

## 4. Quick feature tour — `2:45–3:20`  *(Demo.mp4, slower)*

**VISUAL:** Replay `Demo.mp4` at normal speed with on-screen labels as each feature appears.

**VOICEOVER:**
> "Here's what you just unlocked. A full-width glass progress bar with chapter markers. Scroll over the speed button and a speedometer springs to life. Scroll on the video to seek, scroll on the volume for a clean volume readout. There's a built-in stats overlay, playlist and subtitle controls, and a light theme — just hit Control-T to switch. It even reshapes itself for portrait and reels-sized windows."

**EDIT NOTES:** Sync each clause to its on-screen moment. Text labels: "Elastic Speedometer", "Seek OSD", "Volume OSD", "Ctrl+T — Theme Toggle", "Portrait-aware layout".

---

## 5. Outro — `3:20–end`

**VISUAL:** End card: GitHub repo URL, "Star ⭐ / Like / Subscribe", a final slow glamour shot of the control bar.

**VOICEOVER:**
> "That's it. Link to the repo is in the description — give it a star if you like it, and let me know in the comments what you'd want next. Thanks for watching."

**EDIT NOTES:** YouTube end-screen elements (subscribe + suggested video) over the last 10s.

---

## Production checklist

- [ ] **TTS voice:** pick one neutral, friendly voice (ElevenLabs "Adam/Rachel" or Edge TTS `en-US-GuyNeural` / `en-US-AriaNeural`). Generate each section separately so you can re-time.
- [ ] **Music:** one chill royalty-free track (YouTube Audio Library / Pixabay). Duck it −12 dB under voiceover.
- [ ] **Captions:** upload, let YouTube auto-caption, then clean up. Big for reach + works on mute.
- [ ] **Zoom/highlight** every click target (Releases button, the `%APPDATA%\mpv\` path).
- [ ] **Chapter markers** in the description: `0:00 Intro · 0:38 Install mpv · 1:35 Install the skin · 2:45 Features`.
- [ ] **Editor:** DaVinci Resolve (free) or CapCut (easiest).

## Description-box starter

```
mpv Liquid Glass — a free, glass-styled skin for the mpv media player. Frosted
glass controls, spring animations, and Apple's Liquid Glass look. No compiling,
no dependencies — just copy and play.

⭐ Repo & install: https://github.com/subhasisbiswal012/mpvLiquidGlassSkin
📦 Latest release: https://github.com/subhasisbiswal012/mpvLiquidGlassSkin/releases/latest

Chapters:
0:00 Intro
0:38 Install mpv
1:35 Install the skin
2:45 Feature tour

Built on uosc by tomasklaen · MIT licensed.
```
