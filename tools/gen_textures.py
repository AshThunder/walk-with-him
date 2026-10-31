#!/usr/bin/env python3
"""Self-generated seamless textures (CC0): sand, dry grass, plaster, flagstone, path, wood. numpy + Pillow."""
import numpy as np, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.makedirs(ROOT + "/art", exist_ok=True)
rng = np.random.default_rng(7); N = 256
def noise(scale):
    a = rng.normal(size=(N, N)); f = np.fft.fft2(a); fx = np.fft.fftfreq(N)[:, None]; fy = np.fft.fftfreq(N)[None, :]
    f *= np.exp(-(fx ** 2 + fy ** 2) * (scale ** 2) * 12); r = np.real(np.fft.ifft2(f)); r -= r.min(); return r / r.max()
def mix(base, hi, lo, parts):
    n = sum(w * noise(s) for s, w in parts) / sum(w for _, w in parts)
    c = np.array(lo)[None, None, :] + (np.array(hi) - np.array(lo))[None, None, :] * n[:, :, None]
    return c
def save(name, arr): Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(f"{ROOT}/art/{name}.png")
save("sand", mix(0, (226, 198, 150), (200, 168, 120), [(40, 1), (12, 0.6), (3, 0.3)]))
save("dry_grass", mix(0, (170, 164, 98), (132, 130, 72), [(30, 1), (8, 0.7), (2, 0.4)]))
save("plaster", mix(0, (230, 208, 168), (214, 190, 148), [(24, 1), (5, 0.5), (1.5, 0.25)]))
save("path", mix(0, (236, 214, 170), (216, 190, 142), [(18, 1), (4, 0.5), (1.2, 0.3)]))
# flagstone: voronoi-ish blocks
yy, xx = np.mgrid[0:N, 0:N]; pts = rng.uniform(0, N, (40, 2)); d = np.full((N, N), 1e9); idx = np.zeros((N, N), int); d2 = np.full((N, N), 1e9)
for i, (px, py) in enumerate(pts):
    dx = np.minimum(abs(xx - px), N - abs(xx - px)); dy = np.minimum(abs(yy - py), N - abs(yy - py)); dd = np.hypot(dx, dy)
    m = dd < d; d2 = np.where(m, d, np.minimum(d2, dd)); idx = np.where(m, i, idx); d = np.minimum(d, dd)
edge = np.clip((d2 - d) / 3.0, 0, 1); tone = rng.uniform(0.9, 1.05, 40)[idx]
base = np.array([208, 186, 150])[None, None, :] * tone[:, :, None] * (0.7 + 0.3 * edge[:, :, None]); save("flagstone", base + noise(6)[:, :, None] * 10)
# wood planks
pl = np.zeros((N, N, 3)); 
for i in range(8):
    t = rng.uniform(0.85, 1.05); pl[i * 32:(i + 1) * 32] = np.array([142, 98, 62]) * t; pl[i * 32:i * 32 + 2] *= 0.6
save("wood", pl + noise(2)[:, :, None] * 14)
print("textures done")
