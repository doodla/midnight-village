"""Cloud tips with the cloud body's own paper: grain from the body, torn edge, lip on the lit (upper-left) side."""

import cv2
import numpy as np


def _rough(n, amp_c, amp_f, rng, step):
    """1-D torn-edge noise along an edge sampled every `step` px (n samples), ends tapered."""
    a = cv2.GaussianBlur(
        rng.standard_normal(n).astype(np.float32).reshape(1, -1), (0, 0), 2.2 / step
    ).ravel()
    b = cv2.GaussianBlur(
        rng.standard_normal(n).astype(np.float32).reshape(1, -1), (0, 0), 0.7 / step
    ).ravel()
    a /= max(a.std(), 1e-6)
    b /= max(b.std(), 1e-6)
    return amp_c * a + amp_f * b


def rough_polygon(
    upper, lower, rng, amp_c=0.45, amp_f=0.18, step=0.25, taper_l=0.0, taper_r=0.0
):
    """upper: list of (x,y) left to right; lower: list left to right. Returns closed point array."""

    def dense(p):
        p = np.array(p, np.float64)
        L = np.r_[0, np.cumsum(np.hypot(*np.diff(p, axis=0).T))]
        t = np.arange(0, L[-1], step)
        return np.c_[np.interp(t, L, p[:, 0]), np.interp(t, L, p[:, 1])], L[-1]

    up, Lu = dense(upper)
    lo, Ll = dense(lower)
    out = []
    for pts, L in ((up, Lu), (lo, Ll)):
        n = len(pts)
        nz = _rough(n, amp_c, amp_f, rng, step)
        u = np.linspace(0, 1, n)
        w = np.clip(
            np.minimum((u * L - taper_l) / max(L * 0.25, 1), 1) if taper_l else 1, 0, 1
        )
        w = np.where(
            taper_l > 0, np.clip(u * L / max(taper_l, 1e-3), 0, 1), 1.0
        ) * np.where(taper_r > 0, np.clip((1 - u) * L / max(taper_r, 1e-3), 0, 1), 1.0)
        pts = pts.copy()
        pts[:, 1] += nz * w
        out.append(pts)
    return np.vstack([out[0], out[1][::-1]])


def aa_poly(pts, shape, ss=8):
    H, W = shape
    big = np.zeros((H * ss, W * ss), np.uint8)
    cv2.fillPoly(big, [np.round(pts * ss + ss / 2 - 0.5 * 0).astype(np.int32)], 1)
    return cv2.resize(big.astype(np.float32), (W, H), interpolation=cv2.INTER_AREA)


def shifted(a, dx, dy):
    H, W = a.shape[:2]
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(a, M, (W, H), flags=cv2.INTER_LINEAR)


def lit_edges(alpha, lip_gain, shade_gain):
    """Light from the upper left: pixels with empty upper-left neighbours catch light; lower-right ones are in shade."""
    a_tl = shifted(alpha, 1.2, 1.2)
    a_br = shifted(alpha, -1.2, -1.2)
    lip = np.clip(alpha - a_tl, 0, 1) * alpha
    shade = np.clip(alpha - a_br, 0, 1) * alpha
    return lip * lip_gain + shade * shade_gain
