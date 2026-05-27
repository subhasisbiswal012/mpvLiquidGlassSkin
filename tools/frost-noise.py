"""Generate a tiling perlin-style noise texture for the frost layer.

Output: portable_config/scripts/uosc/assets/frost-noise.png (256x256, grayscale).
"""
import os
import numpy as np
from PIL import Image

SIZE = 256
OCTAVES = 4
SEED = 42

def value_noise(size, scale, rng):
    """Cheap lattice noise: random grid, bilinearly upsampled."""
    grid = rng.random((size // scale + 2, size // scale + 2)).astype(np.float32)
    img = Image.fromarray((grid * 255).astype(np.uint8), mode='L')
    img = img.resize((size + scale * 2, size + scale * 2), Image.BILINEAR)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return arr[:size, :size]

def make_tiling(size, octaves, seed):
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), dtype=np.float32)
    amplitude = 1.0
    for octave in range(octaves):
        scale = max(2, size // (2 ** (octave + 1)))
        out += value_noise(size, scale, rng) * amplitude
        amplitude *= 0.5
    # Normalize to 0..1
    out -= out.min()
    out /= out.max()
    # Soft-center the distribution so it's mostly mid-gray (additive blend won't blow out)
    out = 0.45 + (out - 0.5) * 0.35
    return np.clip(out, 0, 1)

def main():
    arr = make_tiling(SIZE, OCTAVES, SEED)
    img = Image.fromarray((arr * 255).astype(np.uint8), mode='L')
    out_dir = os.path.join('portable_config', 'scripts', 'uosc', 'assets')
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'frost-noise.png')
    img.save(out_path, optimize=True)
    print(f'Wrote {out_path} ({os.path.getsize(out_path)} bytes)')

if __name__ == '__main__':
    main()
