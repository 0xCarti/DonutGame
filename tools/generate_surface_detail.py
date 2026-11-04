"""Bake original, seamless 1024px physical surface maps and full-source relief.

Run with Python + NumPy + Pillow. No downloaded images, enlarged low-resolution
textures, or per-frame noise: the material detail is sampled at its native size.
Existing authored wood/paper color artwork is never modified.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "materials"
SIZE = 1024
RNG = np.random.default_rng(734121)


def noise(size, radius):
    """Band-limited, periodic noise; wrapping is also correct for normal maps."""
    field = RNG.normal(size=(size, size))
    freq = np.fft.fftfreq(size)
    kernel = np.exp(-2 * np.pi**2 * radius**2 * (freq[:, None] ** 2 + freq[None, :] ** 2))
    field = np.fft.ifft2(np.fft.fft2(field) * kernel).real
    return (field / max(float(field.std()), 1e-9)).astype(np.float32)


def save_gray(path, field):
    pixels = np.clip(field * 255, 0, 255).astype(np.uint8)
    Image.fromarray(pixels).convert("RGB").save(path, optimize=True)


def save_normal(path, field, strength):
    dx = (np.roll(field, -1, 1) - np.roll(field, 1, 1)) * strength
    dy = (np.roll(field, -1, 0) - np.roll(field, 1, 0)) * strength
    vector = np.stack((-dx, dy, np.ones_like(field)), axis=-1)
    vector /= np.linalg.norm(vector, axis=-1, keepdims=True)
    pixels = np.clip((vector * 0.5 + 0.5) * 255, 0, 255).astype(np.uint8)
    Image.fromarray(pixels).save(path, optimize=True)


def bake_detail(kind):
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
    fine = noise(SIZE, 0.6)
    medium = noise(SIZE, 5.0)
    broad = noise(SIZE, 46.0)
    if kind == "steel":
        # Many irregular parallel tool marks, broken by subtle hairline scratches.
        line = noise(SIZE, 1.2).mean(axis=1)
        line /= max(float(line.std()), 1e-9)
        streak = np.broadcast_to(line[:, None], (SIZE, SIZE))
        scratches = np.maximum(0, noise(SIZE, 2.0) - 1.7) * 0.4
        color = 0.91 + streak * 0.014 + broad * 0.006 + fine * 0.003
        height = streak * 0.035 + fine * 0.008 - scratches * 0.018
        rough = 0.76 + streak * 0.055 + medium * 0.008
        strength = 2.8
    elif kind == "dough":
        # Baked cake pores with softer rounded bumps and small toasted cavities.
        pores = np.maximum(0, noise(SIZE, 1.6) - 0.9) ** 1.6
        color = 0.91 + broad * 0.028 + medium * 0.023 - pores * 0.030
        height = medium * 0.045 + broad * 0.020 - pores * 0.050
        rough = 0.89 + fine * 0.017 + pores * 0.018
        strength = 3.5
    elif kind == "canvas":
        # Twill: continuous alternating thread ridges, not a low-res checkerboard.
        warp = np.cos(x * np.pi / 4.0)
        weft = np.cos(y * np.pi / 4.0)
        crossing = np.cos((x + y) * np.pi / 16.0)
        weave = (warp * (0.6 + crossing * 0.4) + weft * (0.6 - crossing * 0.4)) * 0.5
        color = 0.93 + broad * 0.012 + weave * 0.010 + fine * 0.003
        height = weave * 0.055 + fine * 0.007
        rough = 0.91 + weave * 0.016
        strength = 2.6
    elif kind == "paper":
        fibres = noise(SIZE, 1.0) * 0.5 + noise(SIZE, 3.0) * 0.5
        color = 0.96 + broad * 0.009 + fibres * 0.010
        height = fibres * 0.025 + broad * 0.013
        rough = 0.93 + fibres * 0.014
        strength = 2.6
    else:
        stones = np.maximum(0, noise(SIZE, 3.0) + 0.3)
        color = 0.75 + broad * 0.035 + medium * 0.035 + fine * 0.017
        height = stones * 0.10 + fine * 0.020
        rough = 0.93 + medium * 0.025
        strength = 4.0
    prefix = OUT / ("detail_" + kind)
    save_gray(str(prefix) + "_color.png", color)
    save_normal(str(prefix) + "_normal.png", height, strength)
    save_gray(str(prefix) + "_roughness.png", rough)


def bake_authored_relief(kind):
    # Recompute at the true source resolution, recovering image detail previously
    # discarded by the 512px relief bake. This does not enlarge the old maps.
    image = np.asarray(Image.open(OUT / f"{kind}_color.png").convert("RGB"), dtype=np.float32) / 255
    height = image[..., 0] * 0.2126 + image[..., 1] * 0.7152 + image[..., 2] * 0.0722
    strength = 3.5 if kind == "counter_wood" else 1.8
    rough_base = 0.61 if kind == "counter_wood" else 0.90
    save_normal(OUT / f"{kind}_normal.png", height, strength)
    save_gray(OUT / f"{kind}_roughness.png", rough_base + (height - 0.5) * 0.16)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ["steel", "dough", "canvas", "paper", "ground"]:
        bake_detail(kind)
    for kind in ["counter_wood", "kraft_paper"]:
        bake_authored_relief(kind)
    rows = []
    for path in sorted(OUT.glob("*.png")):
        rows.append({"file": path.name, "size": list(Image.open(path).size), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    print(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()
