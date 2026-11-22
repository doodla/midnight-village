import cv2
import numpy as np
from lib import *

I = load(WORK + "night-village.jpg")
H, W, _ = I.shape
L = I.mean(2)
L1 = gauss(L, 1.2)

# ---- moon disc: fit a circle to the boundary where bright meets sky ----
bright = L1 > 140
bright[300:] = False
bright = largest_component(bright)
edge = bright & ~cv2.erode(bright.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(
    bool
)
ys, xs = np.nonzero(edge)
# rough circle, then iterate rejecting points not on it (cloud overlaps)
pts = np.c_[xs, ys].astype(np.float64)


def fit(p):
    A = np.c_[2 * p[:, 0], 2 * p[:, 1], np.ones(len(p))]
    b = (p**2).sum(1)
    c = np.linalg.lstsq(A, b, rcond=None)[0]
    return c[0], c[1], np.sqrt(c[2] + c[0] ** 2 + c[1] ** 2)


rng = np.random.default_rng(1)
best = (0, None)
for _ in range(4000):
    p = pts[rng.choice(len(pts), 3, replace=False)]
    try:
        c = fit(p)
    except Exception:
        continue
    if not (90 < c[2] < 120):
        continue
    d = np.abs(np.hypot(pts[:, 0] - c[0], pts[:, 1] - c[1]) - c[2])
    n = (d < 1.5).sum()
    if n > best[0]:
        best = (n, c)
cx, cy, r = best[1]
for it in range(8):
    d = np.abs(np.hypot(pts[:, 0] - cx, pts[:, 1] - cy) - r)
    keep = d < 2.5
    cx, cy, r = fit(pts[keep])
print("moon circle", cx, cy, r, keep.sum(), len(pts))
np.save(WORK + "moon_circle.npy", np.array([cx, cy, r]))
