"""Generate per-slide Kokoro voiceover + timings + concatenated part tracks.

Outputs (in Video/render/audio/):
    clip_00.wav .. clip_11.wav   one per slide
    timings.json                 {durations:[per-slide seconds incl. pad], pad, parts}
    voice_A.wav                  slides in part A, concatenated with pad silence
    voice_B.wav                  slides in part B
"""
import json
import os

import numpy as np
import soundfile as sf
from kokoro import KPipeline

SR = 24000
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "audio")

# slide index ranges for each render part (install recordings go between A and B)
PARTS = {"A": list(range(0, 8)), "B": list(range(8, 12))}


def synth(pipeline, text, voice, speed):
    chunks = [a for _g, _p, a in pipeline(text, voice=voice, speed=speed)]
    return np.concatenate(chunks)


def main():
    os.makedirs(OUT, exist_ok=True)
    cfg = json.load(open(os.path.join(HERE, "script.json"), encoding="utf-8"))
    voice, speed, pad = cfg["voice"], cfg["speed"], cfg["pad"]
    lines = cfg["lines"]
    pad_samples = int(pad * SR)
    silence = np.zeros(pad_samples, dtype=np.float32)

    pipeline = KPipeline(lang_code="a")
    clips, durations = [], []
    for k, text in enumerate(lines):
        wav = synth(pipeline, text, voice, speed).astype(np.float32)
        sf.write(os.path.join(OUT, f"clip_{k:02d}.wav"), wav, SR)
        clips.append(wav)
        durations.append(round(len(wav) / SR + pad, 3))
        print(f"clip_{k:02d}  {len(wav)/SR:6.2f}s  (+{pad}s pad)  {text[:48]}...")

    json.dump(
        {"durations": durations, "pad": pad, "parts": PARTS, "voice": voice, "speed": speed},
        open(os.path.join(OUT, "timings.json"), "w", encoding="utf-8"),
        indent=2,
    )

    for name, idxs in PARTS.items():
        track = []
        for k in idxs:
            track.append(clips[k])
            track.append(silence)
        full = np.concatenate(track) if track else silence
        sf.write(os.path.join(OUT, f"voice_{name}.wav"), full, SR)
        print(f"voice_{name}.wav  {len(full)/SR:6.2f}s  (slides {idxs})")

    print("done")


if __name__ == "__main__":
    main()
