"""Build the paper-edged sun sprite from the bone paper of 04's moon. Light comes from the upper right (08)."""

import cv2
import numpy as np
from lib import *
from PIL import Image

WORKD = WORK
moon = np.asarray(Image.open(WORKD + "out/04_moon.png").convert("RGBA")).astype(
    np.float32
)
R = 50.0
S = 150  # sprite canvas
c = S / 2
# bone-paper texture from the moon's clean interior, 1:1 scale (same grain size as the art)
cx0, cy0 = 607, 148
tex = moon[cy0 - 75 : cy0 + 75, cx0 - 75 : cx0 + 75, :3].copy()
tex_l = gauss(tex, 6.0)
# lift to a touch brighter/warmer than the sky, keep the mottle (high-pass) at full strength
target = np.array([234, 222, 206], np.float32)
body = target[None, None, :] + (tex - tex_l) * 1.1 + (tex_l - tex_l.mean((0, 1))) * 0.8

yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
d = np.hypot(xx + 0.5 - c, yy + 0.5 - c)
# the light is upper-right: unit vector toward the light
lx, ly = 0.62, -0.78
nx = (xx + 0.5 - c) / np.maximum(d, 1e-3)
ny = (yy + 0.5 - c) / np.maximum(d, 1e-3)
facing = nx * lx + ny * ly  # +1 toward the light
# a cut-paper edge: the radius wobbles a little all round (scissor-cut, not compass-drawn), with two small nicks
_rng = np.random.default_rng(7)
th = np.arctan2(yy + 0.5 - c, xx + 0.5 - c)
_n = 720
_ang = np.linspace(-np.pi, np.pi, _n, endpoint=False)
def _pn(sig):
    z = _rng.standard_normal(_n * 3).astype(np.float32)
    z = cv2.GaussianBlur(z.reshape(1, -1), (0, 0), sig).ravel()[_n:2 * _n]
    return z / z.std()
rad = R + 0.36 * _pn(14) + 0.26 * _pn(5) + 0.14 * _pn(1.5)
for a0, w, depth in ((2.3, 0.05, 1.1), (-0.9, 0.04, 0.9)):
    rad -= depth * np.exp(-0.5 * ((np.angle(np.exp(1j * (_ang - a0)))) / w) ** 2)
rr = np.interp(th, np.r_[_ang, np.pi], np.r_[rad, rad[0]])
disc = np.clip(rr + 0.5 - d, 0, 1)
# paper edge: a lit lip on the light side, a dark cut line on the far side
edge_in = np.clip(1 - (rr - d) / 2.2, 0, 1) * (d < rr)
lip = edge_in * np.clip(facing, 0, 1) * 14
shade = edge_in * np.clip(-facing, 0, 1) * -22
outline = np.clip(1 - (rr - d) / 1.1, 0, 1) * (d < rr)
rgb = body + (lip + shade - 9 * outline)[..., None]
# a hair of curl: the paper is not flat; darken very slightly away from the light
rgb = (
    rgb * (1 - 0.035 * (1 - np.clip((facing + 1) / 2, 0, 1)) * (d / R) ** 2)[..., None]
)


# hard shadow cast down and to the left (light from upper right)
def shifted(a, dx, dy):
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(a, M, (S, S), flags=cv2.INTER_LINEAR)


sh_hard = gauss(shifted(disc, -4.0, 5.0), 1.0) * 0.5
sh_soft = gauss(shifted(disc, -7.0, 9.0), 4.5) * 0.20
sh = 1 - (1 - sh_hard) * (1 - sh_soft)
sh = sh * (1 - disc)  # only outside the disc; the disc covers its own shadow
alpha = disc + (1 - disc) * sh
rgb_out = rgb * (disc / np.maximum(alpha, 1e-4))[..., None]
sprite = np.dstack(
    [np.clip(rgb_out + 0.5, 0, 255), np.clip(alpha * 255 + 0.5, 0, 255)]
).astype(np.uint8)
sprite[..., :3] = np.where(sprite[..., 3:4] > 0, sprite[..., :3], 0)
Image.fromarray(sprite, "RGBA").save(WORKD + "out/08_sun.png", optimize=True)
Image.fromarray(sprite, "RGBA").save(WORKD + "out/08_sun.webp", quality=82, method=6)
print("sun sprite", sprite.shape)
