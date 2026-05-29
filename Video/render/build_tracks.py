"""Rebuild concatenated voice tracks from existing clip_*.wav (no TTS).

Ranges (global slide indices):
    HOOK = [0]                slide 0 (composited over Demo.mp4)
    A    = [1..7]             why-mpv + intro
    B    = [8..11]            features + outro
"""
import json
import os

import numpy as np
import soundfile as sf

SR = 24000
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "audio")
RANGES = {"HOOK": [0], "A": [1, 2, 3, 4, 5, 6, 7], "B": [8, 9, 10, 11]}


def main():
    pad = json.load(open(os.path.join(OUT, "timings.json")))["pad"]
    silence = np.zeros(int(pad * SR), dtype=np.float32)
    for name, idxs in RANGES.items():
        track = []
        for k in idxs:
            wav, _ = sf.read(os.path.join(OUT, f"clip_{k:02d}.wav"), dtype="float32")
            track.append(wav)
            track.append(silence)
        full = np.concatenate(track)
        sf.write(os.path.join(OUT, f"voice_{name}.wav"), full, SR)
        print(f"voice_{name}.wav  {len(full)/SR:6.2f}s  slides {idxs}")


if __name__ == "__main__":
    main()
