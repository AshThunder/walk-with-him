#!/usr/bin/env python3
"""Recolors Kenney's Fantasy Town Kit colormap (CC0, modification allowed) from lavender/blue to warm sandstone/terracotta."""
import colorsys, sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGBA"); px = im.load()
for y in range(im.height):
    for x in range(im.width):
        r, g, b, a = px[x, y]; h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        d = h * 360
        if 190 <= d <= 340 and s > 0.08:   # blue / purple / pink -> sand / ochre / terracotta
            h2 = (34 if d < 260 else 22 if d < 300 else 14) / 360; s2 = min(0.55, s * 0.6 + 0.12); v2 = min(1.0, v * 0.95 + 0.05)
            r, g, b = [int(c * 255) for c in colorsys.hsv_to_rgb(h2, s2, v2)]
        elif s < 0.2 and 0.2 < v < 0.9:    # greys -> warm greys
            r, g, b = int(min(255, r * 1.06)), int(g * 0.98), int(g * 0.88)
        px[x, y] = (r, g, b, a)
im.save(sys.argv[2])
