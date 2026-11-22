"""Smooth sky model for 04 (cubic polynomial of the clean sky), used to segment & fill."""

import numpy as np
from lib import *

I = load(WORK + "night-village.jpg")
H, W, _ = I.shape
cx, cy, r = np.load(WORK + "moon_circle.npy")
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
valid = yy < 250
for x0, y0, x1, y1 in [
    (0, 60, 270, 190),
    (0, 160, 330, 262),
    (405, 160, 575, 230),
    (570, 135, 768, 275),
    (570, 245, 768, 380),
]:
    valid[y0:y1, x0:x1] = False
valid &= np.hypot(xx - cx, yy - cy) > r + 40
# drop spire & tree tops
valid[:, 360:460] &= yy[:, 360:460] < 240
Ls = gauss(I.mean(2), 2.0)
valid &= (Ls > 30) & (Ls < 60)
print("valid px", valid.sum())
u = (xx / W - 0.5) * 2
v = (yy / 250 - 0.5) * 2


def basis(u, v):
    return np.stack(
        [np.ones_like(u), u, v, u * u, u * v, v * v, u**3, u * u * v, u * v * v, v**3],
        -1,
    )


B = basis(u, v)
model = np.zeros_like(I)
for c in range(3):
    A = B[valid]
    y = I[..., c][valid]
    coef = np.linalg.lstsq(A, y, rcond=None)[0]
    model[..., c] = B @ coef
    res = y - A @ coef
    print("ch", c, "resid std", res.std().round(2))
np.save(WORK + "sky_model04.npy", model.astype(np.float32))
for p in [
    (10, 10),
    (384, 20),
    (700, 20),
    (700, 120),
    (300, 250),
    (20, 120),
    (384, 400),
]:
    print(p, model[p[1], p[0]].round(1))
