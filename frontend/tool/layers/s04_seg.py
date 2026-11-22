"""Segment 04: moon disc, three dark clouds, two cream clouds (binary masks, then AA alpha)."""

import cv2
import numpy as np
from lib import *

I = load(WORK + "night-village.jpg")
H, W, _ = I.shape
L = I.mean(2)
L1 = gauss(L, 1.1)
model = np.load(WORK + 'sky_model04.npy')
Lm = model.mean(2)
D = L1 - Lm
BR = gauss(I[..., 2] - I[..., 0], 1.1)
cx, cy, r = np.load(WORK + "moon_circle.npy")
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
dist = np.hypot(xx - cx, yy - cy)

# the sky level (smooth), from clean sky
sky = np.zeros((H, W), bool)
sky[:250, 300:495] = True
skyL = L[sky].mean()
print("sky L", skyL)


def win(x0, y0, x1, y1):
    m = np.zeros((H, W), bool)
    m[y0:y1, x0:x1] = True
    return m


masks = {}
# dark clouds: lilac/indigo paper lighter than sky
for name, (x0, y0, x1, y1), thr in [
    ("lc1", (0, 70, 250, 175), 52),
    ("lc2", (0, 172, 310, 250), 52),
]:
    m = win(x0, y0, x1, y1) & (D > 9)
    m = cv2.morphologyEx(
        m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)
    ).astype(bool)
    m = cv2.morphologyEx(
        m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)
    ).astype(bool)
    m = fill_holes(largest_component(m))
    masks[name] = m

# right dark cloud: outside the moon it is lighter than sky; over the moon it is darker than the moon.
w = win(585, 145, 768, 255)
outside = w & (dist > r - 0.5) & (D > 9) & (L1 < 140)
over = w & (dist <= r - 0.5) & (L1 < 125) & (BR > 6)
m = outside | over
m = cv2.morphologyEx(
    m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)
).astype(bool)
m = cv2.morphologyEx(
    m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)
).astype(bool)
masks["rc"] = fill_holes(largest_component(m))

# cream clouds
w = win(415, 170, 560, 215)
outside = w & (dist > r - 0.5) & (L1 > 100)
inside = w & (dist <= r - 0.5) & (L1 < 207) & (xx < 570) & (yy > 178) & (yy < 210)
m = outside | inside
m = cv2.morphologyEx(
    m.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8)
).astype(bool)
masks["cc1"] = largest_component(m)

w = win(585, 255, 768, 365)
m = w & (L1 > 100) & (dist > r + 3)
m = cv2.morphologyEx(
    m.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)
).astype(bool)
masks["cc2"] = fill_holes(largest_component(m))

for k, v in masks.items():
    print(k, v.sum())
np.savez_compressed(WORK + "masks04.npz", **masks)

# overlay for review
vis = I.copy()
for k, v in masks.items():
    c, _ = cv2.findContours(
        v.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE
    )
    big = cv2.resize(vis, None, fx=3, fy=3, interpolation=cv2.INTER_NEAREST)
    vis = (
        cv2.resize(big, None, fx=1 / 3, fy=1 / 3, interpolation=cv2.INTER_AREA)
        if False
        else vis
    )
rgb = cv2.resize(vis[:380], None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
for k, v in masks.items():
    c, _ = cv2.findContours(
        v[:380].astype(np.uint8), cv2.RETR_LIST, cv2.CHAIN_APPROX_NONE
    )
    for cc in c:
        cv2.polylines(rgb, [(cc * 2).astype(np.int32)], True, (255, 0, 0), 1)
c = (int(cx * 2), int(cy * 2))
cv2.circle(rgb, c, int(r * 2), (0, 255, 0), 1)
save_rgb(rgb, WORK + "seg04_overlay.png")
