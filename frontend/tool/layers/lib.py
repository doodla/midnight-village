"""Helpers for lifting the flat scenes into layers (numpy / cv2 / Pillow only)."""

import os

import cv2
import numpy as np
from PIL import Image

# The work folder: the flat pictures in, the stages' state and the layers out
# (`out/`). `run.sh` sets it; it ends with a slash.
WORK = os.environ["LAYERS_WORK"].rstrip("/") + "/"


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32)


def save_rgb(a, path):
    Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8)).save(path)


def save_rgba(rgb, alpha, path, **kw):
    out = np.dstack(
        [np.clip(rgb + 0.5, 0, 255), np.clip(alpha * 255 + 0.5, 0, 255)]
    ).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path, **kw)


def gauss(a, s):
    return cv2.GaussianBlur(a, (0, 0), s)


def pushpull(img, valid, sigmas=(2, 4, 8, 16, 32, 64, 128, 256)):
    """Smoothly fill pixels where valid==0 from the nearest valid data (normalised convolution ladder)."""
    img = img.astype(np.float32)
    v = valid.astype(np.float32)
    out = img.copy()
    done = valid.astype(bool).copy()
    for s in sigmas:
        if img.ndim == 3:
            num = np.dstack([gauss(img[..., c] * v, s) for c in range(img.shape[2])])
        else:
            num = gauss(img * v, s)
        den = gauss(v, s)
        ok = (den > 0.02) & ~done
        if img.ndim == 3:
            out[ok] = num[ok] / den[ok][:, None]
        else:
            out[ok] = num[ok] / den[ok]
        done |= ok
        if done.all():
            break
    return out


def smoothstep(x):
    x = np.clip(x, 0, 1)
    return x * x * (3 - 2 * x)


def grain_field(donor, donor_valid, shape, rng, sigma_low=5.0, patch=80, step=40):
    """Stationary grain: high-pass of donor, tiled from random donor patches, variance-preserving blend."""
    H, W = shape
    dv = donor_valid.astype(np.float32)
    low = np.dstack(
        [
            pushpull(donor[..., c], dv, (sigma_low,))
            if False
            else gauss(donor[..., c] * dv, sigma_low)
            / np.maximum(gauss(dv, sigma_low), 1e-3)
            for c in range(3)
        ]
    )
    hp = (donor - low) * dv[..., None]
    # candidate patch origins fully inside donor_valid
    er = cv2.erode(dv, np.ones((patch, patch), np.uint8), anchor=(0, 0), borderType=cv2.BORDER_CONSTANT, borderValue=0)
    er[-patch + 1:, :] = 0
    er[:, -patch + 1:] = 0
    ys, xs = np.nonzero(er > 0.5)
    assert len(ys) > 0, "donor region too small for patch size"
    win1 = np.sin(np.linspace(0, np.pi, patch + 2)[1:-1]) ** 2
    win = np.outer(win1, win1).astype(np.float32)
    acc = np.zeros((H, W, 3), np.float32)
    wsq = np.zeros((H, W), np.float32)
    for y0 in range(-patch // 2, H, step):
        for x0 in range(-patch // 2, W, step):
            k = rng.integers(len(ys))
            py, px = ys[k], xs[k]
            p = hp[py : py + patch, px : px + patch]
            # random flip for variety
            if rng.random() < 0.5:
                p = p[:, ::-1]
            if rng.random() < 0.5:
                p = p[::-1]
            ya, yb = max(y0, 0), min(y0 + patch, H)
            xa, xb = max(x0, 0), min(x0 + patch, W)
            if ya >= yb or xa >= xb:
                continue
            pw = win[ya - y0 : yb - y0, xa - x0 : xb - x0]
            pp = p[ya - y0 : yb - y0, xa - x0 : xb - x0]
            acc[ya:yb, xa:xb] += pp * pw[..., None]
            wsq[ya:yb, xa:xb] += pw**2
    return acc / np.sqrt(np.maximum(wsq, 1e-6))[..., None]


def largest_component(mask, min_area=0):
    n, lab, stats, _ = cv2.connectedComponentsWithStats(
        mask.astype(np.uint8), connectivity=8
    )
    if n <= 1:
        return np.zeros_like(mask, bool)
    k = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
    return lab == k


def fill_holes(mask):
    m = mask.astype(np.uint8)
    h, w = m.shape
    ff = m.copy()
    pad = np.zeros((h + 2, w + 2), np.uint8)
    cv2.floodFill(ff, pad, (0, 0), 1)
    return mask | (ff == 0)


def smooth_mask_aa(mask, sigma=1.0, ss=4):
    """Binary mask -> anti-aliased alpha with a smoothed contour (supersampled)."""
    h, w = mask.shape
    big = cv2.resize(
        mask.astype(np.float32), (w * ss, h * ss), interpolation=cv2.INTER_LINEAR
    )
    big = cv2.GaussianBlur(big, (0, 0), sigma * ss)
    big = (big > 0.5).astype(np.float32)
    return cv2.resize(big, (w, h), interpolation=cv2.INTER_AREA)


def crop_cover(img, out_w, out_h, focus=(0.5, 0.5)):
    """Flutter BoxFit.cover with alignment; returns the crop box in source px and the scale."""
    h, w = img.shape[:2]
    s = max(out_w / w, out_h / h)
    sw, sh = w * s, h * s
    ox = (sw - out_w) * focus[0]
    oy = (sh - out_h) * focus[1]
    return s, ox, oy
