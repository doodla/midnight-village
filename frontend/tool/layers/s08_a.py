"""08 step A: classify; birds, gallows, sky/hill boundary, band zone."""

import cv2
import numpy as np
from lib import *

I = load(WORK + "dawn-gallows.jpg")
H, W, _ = I.shape
L = I.mean(2)
L1 = gauss(L, 0.8)
R, G, B = I[..., 0], I[..., 1], I[..., 2]
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)


def dil(m, n):
    return cv2.dilate(
        m.astype(np.uint8),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * n + 1, 2 * n + 1)),
    ).astype(bool)


def ero(m, n):
    return cv2.erode(
        m.astype(np.uint8),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * n + 1, 2 * n + 1)),
    ).astype(bool)


def cc(mask):
    n, lab, st, cen = cv2.connectedComponentsWithStats(
        mask.astype(np.uint8), connectivity=8
    )
    return n, lab, st, cen


dark = gauss(L, 0.7) < 85
n, lab, st, cen = cc(dark)
big = 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])
roof_comp = lab == big
birds = np.zeros((H, W), bool)
for k in range(1, n):
    if k == big:
        continue
    x, y, w, h, a = st[k]
    if a > 150 and y + h < 262:
        birds |= lab == k
print(
    "birds comps:",
    [
        (int(st[k][0]), int(st[k][1]), int(st[k][4]))
        for k in range(1, n)
        if k != big and st[k][4] > 150 and st[k][1] + st[k][3] < 262
    ],
)

# gallows
win = np.zeros((H, W), bool)
win[195:452, 425:715] = True
wood = ((R - B) > 26) & (L1 > 70) & (L1 < 190) & win
red = (R > 1.6 * G) & (R > 70) & (L1 < 140) & win
post = dark & (xx >= 655) & (xx <= 708) & (yy >= 212) & (yy < 438)
gal = wood | red | post
gal = cv2.morphologyEx(
    gal.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)
).astype(bool)
n2, lab2, st2, _ = cc(gal)
keep = np.zeros((H, W), bool)
for k in range(1, n2):
    if st2[k][4] > 120:
        keep |= lab2 == k
gal = keep
# the gallows' own dark outlines (edge lines darker than sky): include dark pixels hugging the gallows, above the roofs
edge_dark = dil(gal, 3) & (gauss(L, 0.7) < 120) & (yy < 440) & win
gal_full = gal | edge_dark
gal_full = fill_holes(gal_full)
print("gallows px", gal_full.sum())
np.savez_compressed(
    WORK + "s08_a.npz", birds=birds, gal=gal_full, dark=dark, roof_comp=roof_comp
)
vis = I.copy()
vis[gal_full] = vis[gal_full] * 0.5 + np.array([0, 255, 0]) * 0.5
vis[birds] = vis[birds] * 0.5 + np.array([255, 0, 255]) * 0.5
save_rgb(vis, WORK + "s08_a_overlay.png")
