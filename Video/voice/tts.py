"""Kokoro-82M TTS for the mpv Liquid Glass YouTube video.

Usage:
    python tts.py --text "..." --voice am_michael --out out.wav
    python tts.py --sample          # generate voice-comparison samples
"""
import argparse
import os
import sys

import numpy as np
import soundfile as sf
from kokoro import KPipeline

SR = 24000
SAMPLE_TEXT = (
    "But push them. A ten gigabyte movie, an eighteen gigabyte remux, "
    "and they start to lag and hang. In my experience, MPV just, didn't. "
    "It stayed buttery smooth, every time."
)


def synth(pipeline: KPipeline, text: str, voice: str, speed: float = 1.0) -> np.ndarray:
    """Return one concatenated waveform for the whole text."""
    chunks = []
    for _gs, _ps, audio in pipeline(text, voice=voice, speed=speed):
        chunks.append(audio)
    if not chunks:
        raise RuntimeError("Kokoro produced no audio")
    return np.concatenate(chunks)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--text", default=SAMPLE_TEXT)
    ap.add_argument("--voice", default="am_michael")
    ap.add_argument("--speed", type=float, default=1.0)
    ap.add_argument("--out", default="out.wav")
    ap.add_argument("--sample", action="store_true", help="render comparison samples")
    args = ap.parse_args()

    here = os.path.dirname(os.path.abspath(__file__))
    pipeline = KPipeline(lang_code="a")  # American English

    if args.sample:
        for voice in ("am_michael", "af_heart", "am_fenrir", "bf_emma"):
            wav = synth(pipeline, SAMPLE_TEXT, voice)
            path = os.path.join(here, f"sample_{voice}.wav")
            sf.write(path, wav, SR)
            print(f"wrote {path}  ({len(wav)/SR:.1f}s)")
        return 0

    wav = synth(pipeline, args.text, args.voice, args.speed)
    out = args.out if os.path.isabs(args.out) else os.path.join(here, args.out)
    sf.write(out, wav, SR)
    print(f"wrote {out}  ({len(wav)/SR:.1f}s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
