"""04 v2: paper layers carry no shadow. Shadows are their own black layers:
clouds_*_shadow  (cast on the sky, drawn UNDER the moon, drift with their cloud)
moon_shadow_*    (cast on the moon, computed from the cloud's shape, drawn OVER the moon clipped to it)
"""

import itertools

exec(open("s04_build.py").read())

OUT = WORK + "out/"
import os

os.makedirs(OUT, exist_ok=True)
P = plate_final.astype(np.float32)

# the dark tip over the moon (kept as a cut with its own colour): polygon only used to flag the zone
tip_zone = dil(extra_rc.astype(bool), 2)

# ---------------------------------------------------------------- moon (as before)
occ_body = dil(body["rc"] | body["cc1"], 3)
occ_hole = dil((occ_body | (s_ext > 0.40)) & disc_hard, 1)
moon_lift = I / np.maximum(1 - s_ext, 0.03)[..., None]
moon_valid_px = ero(disc_hard, 2) & ~occ_hole
moon_base = pushpull(
    gauss(moon_lift, 2), moon_valid_px & ~dil(occ_hole, 2), (4, 8, 16, 32, 64, 128)
)
donor_m = ero(disc_hard, 8) & ~dil(occ_hole, 12)
grain_m = grain_field(moon_lift, donor_m, (H, W), rng, sigma_low=9.0, patch=44, step=22)
moon_fill = moon_base + grain_m
fm = np.maximum(gauss(occ_hole.astype(np.float32), 0.8), occ_hole)
moon_rgb_in = moon_lift * (1 - fm[..., None]) + moon_fill * fm[..., None]
inner_m = ero(disc_hard, 2)
F_m = pushpull(moon_rgb_in, inner_m, (1.5, 3, 6))
ring_m = (dist_c > r - 2.5) & (dist_c < r + 2.5)
s_m_own = np.where((owner == names.index("moon")) & ~inner_m, s_ext, 0).astype(
    np.float32
)
Bs_m = P * (1 - s_m_own)[..., None]
d_m = F_m - Bs_m
a_proj_m = np.clip(
    (((I - Bs_m) * d_m).sum(2)) / np.maximum((d_m * d_m).sum(2), 1), 0, 1
)
near_cloud = dil(occ_body, 4)
a_ring_m = np.where(near_cloud, disc, a_proj_m)
a_moon = np.where(dist_c <= r - 2.5, 1.0, np.where(ring_m, a_ring_m, 0.0)).astype(
    np.float32
)
Fl_m = np.clip(
    (I - ((1 - a_moon) * (1 - s_m_own))[..., None] * P)
    / np.maximum(a_moon, 1e-3)[..., None],
    0,
    255,
)
use_I = ring_m & (a_moon > 0.04) & ~near_cloud
moon_rgb = np.where(
    use_I[..., None], Fl_m, np.where((dist_c > r - 2.5)[..., None], F_m, moon_rgb_in)
)
s_moon = np.where(a_moon >= 0.999, 0, s_m_own).astype(np.float32)
alpha_moon = a_moon + (1 - a_moon) * s_moon
rgb_moon = moon_rgb * (a_moon / np.maximum(alpha_moon, 1e-4))[..., None]


# ---------------------------------------------------------------- shadow models
def shifted(a, dx, dy):
    M = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(a, M, (W, H), flags=cv2.INTER_LINEAR)


def fit_terms(cast, valid, target, soft_grid, hard_grid):
    """s = 1 - (1 - k1*P1)(1 - k2*P2); soft term first, then a hard contact term on the residual."""
    tv = target[valid]
    best = None
    for dx, dy, sg in soft_grid:
        p = gauss(shifted(cast, dx, dy), sg)[valid]
        k = max((p * tv).sum() / max((p * p).sum(), 1e-6), 0)
        e = ((k * p - tv) ** 2).mean()
        if best is None or e < best[0]:
            best = (e, dx, dy, sg, k)
    _, dx1, dy1, sg1, k1 = best
    S1 = np.clip(k1 * gauss(shifted(cast, dx1, dy1), sg1), 0, 0.97)
    res = np.clip(1 - (1 - target) / np.maximum(1 - S1, 1e-3), 0, 1)[valid]
    best2 = None
    for dx, dy, sg in hard_grid:
        p = gauss(shifted(cast, dx, dy), sg)[valid]
        k = max((p * res).sum() / max((p * p).sum(), 1e-6), 0)
        e = ((k * p - res) ** 2).mean()
        if best2 is None or e < best2[0]:
            best2 = (e, dx, dy, sg, k)
    return (dx1, dy1, sg1, k1), best2[1:], best[0], best2[0]


def model(cast, p1, p2):
    S1 = np.clip(p1[3] * gauss(shifted(cast, p1[0], p1[1]), p1[2]), 0, 0.97)
    S2 = np.clip(p2[3] * gauss(shifted(cast, p2[0], p2[1]), p2[2]), 0, 0.97)
    return 1 - (1 - S1) * (1 - S2)


soft_grid = list(itertools.product(range(-3, 6), range(2, 16), (3, 4, 5, 6, 8)))
hard_grid = list(itertools.product(range(-2, 4), range(0, 6), (0.8, 1.2, 1.8, 2.5)))
cast_dark = (body["rc"] | extra_rc.astype(bool)).astype(np.float32)
cast_cream = body["cc1"].astype(np.float32)
cast_all = np.maximum(cast_dark, cast_cream)

# on the moon (cloud-owned pixels inside the disc, away from the bodies and the rim)
valid_moon = ero(disc_hard, 6) & ~dil(cast_all > 0, 2)
pm1, pm2, e1, e2 = fit_terms(cast_all, valid_moon, s_ext, soft_grid, hard_grid)
print(
    "moon shadow model",
    pm1,
    pm2,
    "mse",
    e1,
    e2,
    "zero-shadow mse",
    (s_ext[valid_moon] ** 2).mean(),
)
_dc = cv2.distanceTransform((cast_cream <= 0).astype(np.uint8), cv2.DIST_L2, 3)
_dd = cv2.distanceTransform((cast_dark <= 0).astype(np.uint8), cv2.DIST_L2, 3)
valid_cream = valid_moon & (_dc < 22) & (_dd > 40)
pc1, pc2, e1c, e2c = fit_terms(cast_cream, valid_cream, s_ext, soft_grid, hard_grid)
print('cream-only shadow model', pc1, pc2, e1c, e2c, valid_cream.sum())
S_moon_dark = model(cast_dark, pm1, pm2).astype(np.float32)
S_moon_cream = model(cast_cream, pc1, pc2).astype(np.float32)
# a shadow on dark sky is stronger than the same shadow on the pale moon: measured ratio ~ (1-s)^2.4
S_skyfill_dark = (1 - (1 - S_moon_dark) ** 2.4).astype(np.float32)
S_skyfill_cream = (1 - (1 - S_moon_cream) ** 2.4).astype(np.float32)

# sky shadow layers: measured outside the disc, modelled inside it (where the moon will cover it)
w_in = smoothstep((r + 7 - dist_c) / 7)  # 1 inside the disc, 0 beyond rim+7
own_dark = np.zeros((H, W), bool)
for k in dark_names:
    own_dark |= owner == names.index(k)
own_cream = np.zeros((H, W), bool)
for k in cream_names:
    own_cream |= owner == names.index(k)


def sky_shadow(own, S_fill, cast_bodies):
    meas = np.where(own, s_ext, 0)
    s = meas * (1 - w_in) + np.maximum(meas, S_fill) * w_in
    s = np.where(own | (dist_c < r + 7), s, 0)
    s = np.where(cast_bodies, 0, s)  # under the paper itself: nothing needed
    return np.clip(s, 0, 0.97).astype(np.float32)


bodies_dark = np.zeros((H, W), bool)
for k in dark_names:
    bodies_dark |= dil(body[k], 1)
bodies_cream = np.zeros((H, W), bool)
for k in cream_names:
    bodies_cream |= dil(body[k], 1)
SS_dark = sky_shadow(own_dark, S_skyfill_dark, np.zeros((H, W), bool))
SS_cream = sky_shadow(own_cream, S_skyfill_cream, np.zeros((H, W), bool))

# ---------------------------------------------------------------- composite chain (rest)
C0 = P * (1 - SS_dark[..., None]) * (1 - SS_cream[..., None])
C1 = C0 * (1 - alpha_moon[..., None]) + rgb_moon * alpha_moon[..., None]
SM = 1 - (1 - S_moon_dark) * (1 - S_moon_cream)
C2 = C1 * (1 - (SM * a_moon)[..., None])


def make_paper(names_in, C_below, force_tip=False):
    b = np.zeros((H, W), bool)
    for k in names_in:
        b |= body[k]
    inner = ero(b, 2)
    ring = dil(b, 2) & ~inner
    F = pushpull(I, inner, (1.5, 3, 6, 12))
    Bs = C_below
    d = F - Bs
    den = np.maximum((d * d).sum(2), 1)
    a_proj = np.clip((((I - Bs) * d).sum(2)) / den, 0, 1)
    contrast = np.sqrt(den)
    a_aa = smooth_mask_aa(b, 0.7)
    wproj = smoothstep((contrast - 40) / 25)
    a_ring = a_proj * wproj + a_aa * (1 - wproj)
    a = np.where(inner, 1.0, np.where(ring, a_ring, 0.0)).astype(np.float32)
    Fl = np.clip(
        (I - (1 - a)[..., None] * C_below) / np.maximum(a, 1e-3)[..., None], 0, 255
    )
    Fl = np.where((a > 0.04)[..., None], Fl, F)
    Fl = np.where(inner[..., None], I, Fl)
    if force_tip and tip_zone.any():
        clean = ero(body["rc"], 4) & ~dil(disc_hard, 6)
        Fc = np.median(I[clean], axis=0)
        # sliver: dark paper on cream, contrast is huge, so the picture's own alpha is reliable
        dt = Fc[None, None, :] - Bs
        dent = np.maximum((dt * dt).sum(2), 1)
        at = np.clip((((I - Bs) * dt).sum(2)) / dent, 0, 1)
        at = np.where(dil(body["rc"] & tip_zone, 1) | tip_zone, at, 0)
        a = np.where(
            tip_zone, np.where(inner, np.maximum(at, 1.0 * (a >= 0.999)), at), a
        ).astype(np.float32)
        lum = I.mean(2)
        Fl = np.where(
            tip_zone[..., None],
            np.broadcast_to(Fc[None, None, :], I.shape),
            Fl,
        )
    comp = C_below * (1 - a[..., None]) + Fl * a[..., None]
    return a, Fl, comp


a_dark, rgb_dark, C3 = make_paper(dark_names, C2, force_tip=True)
a_cream, rgb_cream, C4 = make_paper(cream_names, C3)

# ------------------------------------------------------------------ tips with the body's own paper
import tips as _t
_rng = np.random.default_rng(2026)
# --- dark tip: grain and tone from the dark cloud's body
_dbody = ero(body['rc'], 3) & ~dil(disc_hard, 4)
_hp = I - gauss(I, 3.0)
_don = _dbody
_grain_d = grain_field(I, _don, (H, W), _rng, sigma_low=3.0, patch=12, step=6)
_Fd = np.median(I[_dbody], axis=0)
_pts = _t.rough_polygon([(594.5, 242.3), (606, 239.6), (614, 237.2), (622, 234.3), (632, 230.6)],
                        [(594.5, 242.3), (606, 241.7), (614, 242.3), (622, 242.6), (632, 240.4)],
                        _rng, amp_c=0.5, amp_f=0.2, taper_l=7, taper_r=10)
_ta = _t.aa_poly(_pts, (H, W)).astype(np.float32)
_zone = (xx >= 588) & (xx <= 640) & (yy >= 226) & (yy <= 248)
_wx = smoothstep((640 - xx) / 14)            # 1 left of ~648, 0 at 662: blend into the body's own pixels
_synth = _Fd[None, None, :] + _grain_d * 1.0
_lip = _t.lit_edges(_ta, 85.0, -14.0)
_synth = _synth + _lip[..., None]
_a_old = a_dark
_a_new = np.where(xx <= 620, _ta, np.maximum(_a_old * smoothstep((xx - 620) / 6) + _ta * (1 - smoothstep((xx - 620) / 6)), _ta))
a_dark = np.where(_zone, _a_new, a_dark).astype(np.float32)
_col = _synth * _wx[..., None] + rgb_dark * (1 - _wx[..., None])
rgb_dark = np.where(_zone[..., None] & (_ta > 0.003)[..., None], _col, rgb_dark)
# --- cream tail: grain and tone from the cream cloud's body
_cbody = ero(body['cc1'] & (xx < 497) & (xx > 440), 1)
_hpc = grain_field(I, _cbody, (H, W), _rng, sigma_low=3.0, patch=8, step=4)
_base = pushpull(gauss(I, 2.0), _cbody, (3, 6, 12, 24))
_ptsc = _t.rough_polygon([(477, 181.5), (480, 180), (483, 179), (486, 178), (489, 177.3), (492, 178), (495, 180), (498, 181), (502, 182), (515, 186), (530, 190.2), (545, 195), (555, 197.6)],
                         [(477, 199), (480, 198), (483, 197), (486, 196), (489, 195), (492, 196), (495, 197), (498, 197.2), (503, 198), (515, 197.5), (526, 196.6), (536, 196.4), (546, 197.8), (555, 197.6)],
                         _rng, amp_c=0.55, amp_f=0.25, taper_l=24, taper_r=6)
_tc = _t.aa_poly(_ptsc, (H, W)).astype(np.float32)
_zc = (xx >= 481) & (xx <= 562) & (yy >= 172) & (yy <= 203)
_wc = smoothstep((xx - 483) / 8)
_lipc = _t.lit_edges(_tc, 16.0, -26.0)
_syn = _base + _hpc * 1.0 + _lipc[..., None]
a_cream = np.where(_zc, _tc, a_cream).astype(np.float32)
_colc = _syn * _wc[..., None] + rgb_cream * (1 - _wc[..., None])
rgb_cream = np.where(_zc[..., None] & (_tc > 0.003)[..., None], _colc, rgb_cream)
C3 = C2 * (1 - a_dark[..., None]) + rgb_dark * a_dark[..., None]
C4 = C3 * (1 - a_cream[..., None]) + rgb_cream * a_cream[..., None]
diff = np.abs(C4 - I)
print("rest diff max %.1f mean %.3f" % (diff.max(), diff.mean()))
save_rgb(C4, WORK + "rest04_raw.png")
save_rgb(np.clip(diff * 8, 0, 255), WORK + "diff04_x8.png")
