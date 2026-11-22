"""08 step C: hills_far, birds, gallows layers (and the roof mask)."""

exec(open("s08_b.py").read())

OUT = WORK + "out/"
import os

os.makedirs(OUT, exist_ok=True)
Rr, Gg, Bb = I[..., 0], I[..., 1], I[..., 2]

# ---------- roofs, including their cream trims and amber windows ----------
warm = ((Rr - Bb) > 22) & (L1 > 70)
amber = (Rr > 180) & (Gg > 120) & (Bb < 110)
roof_only = roof_comp & ~post_reg
near_roof = dil(roof_only, 4)
near4 = (warm | amber) & near_roof
wa = (warm | amber)
_n, _lab, _st, _ = cv2.connectedComponentsWithStats(wa.astype(np.uint8), connectivity=8)
touch = np.unique(_lab[dil(roof_only, 3) & wa])
gal_touch = np.unique(_lab[gal_full & wa & (yy < 400)])
trim = np.zeros((H, W), bool)
for k in touch:
    if k == 0 or k in gal_touch or _st[k][4] < 25:
        continue
    trim |= _lab == k
trim |= near4
trim &= ~((xx >= 425) & (xx <= 715) & (yy < top_s[None, :] + 3) & (yy > 200))
roof_full = fill_holes(roof_only | trim)
roof_full = dil(roof_full, 1)
# the gallows' feet stand ON the roof: wood near the legs belongs to the gallows (drawn over the middle roofs)
win_feet = np.zeros((H, W), bool)
win_feet[380:452, 425:715] = True
feet = warm & win_feet & dil(gal_full & (yy < 400), 40)
feet = fill_holes(dil(feet, 1))
roof_full = roof_full & ~feet
# the gallows stands above the roof line; wood touching the roofs is their trim
gallows = gal_full & ~roof_full
gallows = gallows | (gal_full & post_reg & (yy < top_s[None, :] + 1))
gallows = fill_holes(gallows)
gal_core = gallows
roof_full = roof_full & ~ero(gallows, 1)
np.save(WORK + "s08_roof_full.npy", roof_full)
np.save(WORK + "s08_gallows_mask.npy", gallows)
np.save(WORK + "s08_birds_mask.npy", birds)


# ---------- helper: extract an object over a known background ----------
def extract(seed, Bg, ring=2, min_contrast=30, soft=None):
    inner = seed
    ringm = dil(seed, ring) & ~seed
    F = pushpull(I, inner, (1, 2, 4, 8))
    d = F - Bg
    den = np.maximum((d * d).sum(2), 1)
    a_proj = np.clip((((I - Bg) * d).sum(2)) / den, 0, 1)
    a_geo = smooth_mask_aa(seed, 0.6)
    w = smoothstep((np.sqrt(den) - min_contrast) / 25)
    a_ring = a_proj * w + a_geo * (1 - w)
    a = np.where(inner, 1.0, np.where(ringm, a_ring, 0.0)).astype(np.float32)
    Fl = (I - (1 - a)[..., None] * Bg) / np.maximum(a, 1e-3)[..., None]
    Fl = np.clip(Fl, 0, 255)
    Fl = np.where((a > 0.05)[..., None], Fl, F)
    Fl = np.where(inner[..., None], I, Fl)
    return a, Fl


# ---------- birds over the sky plate ----------
plate_s = plate.astype(np.float32)
a_birds, rgb_birds = extract(birds, plate_s, ring=2)
C_b = plate_s * (1 - a_birds[..., None]) + rgb_birds * a_birds[..., None]

# ---------- hills_far ----------
roof_d = dil(roof_full, 2)
gal_np = gallows & ~post_reg
gal_left = gal_np & (xx < 600)
gal_dd = dil(gal_np, 6) | dil(gallows & post_reg, 3) | (((Rr - Bb) > 12) & (L1 > 110) & dil(gal_left, 12) & ~roof_full) | (dil(gal_left, 14) & (L1 < 120) & (yy < top_s[None, :] - 3) & ~roof_full)
hills_zone = (yy >= yb_i[None, :]) & ~band & ~roof_d & ~gal_dd
hills_zone &= ~(((Rr - Bb) > 12) & (L1 > 80) & dil(gal_left, 18) & (yy >= yb_i[None, :]))
hills_zone &= ~dil(birds, 3)
# reach under the roofs and gallows: 16 px
under = dil(roof_full, 16) | gal_dd
Z_h = ((yy >= yb_i[None, :] - 0) & ~band & under) | hills_zone
Z_h &= yy < 560
Z_h = Z_h & ~(roof_full & ~dil(hills_zone, 16))
visible = hills_zone
hills_rgb = I.copy()
# fill holes in the hills layer: gallows by rows (keeps the ridges level), roofs by push-pull
hole_h = Z_h & ~visible
# row interpolation
rowfilled = np.zeros_like(I)
rowvalid = np.zeros((H, W), bool)
gal_hole = hole_h
for y in range(H):
    row = gal_hole[y]
    if not row.any():
        continue
    xs_ = np.nonzero(row)[0]
    # runs
    starts = [xs_[0]] + [xs_[i] for i in range(1, len(xs_)) if xs_[i] != xs_[i - 1] + 1]
    ends = [xs_[i - 1] for i in range(1, len(xs_)) if xs_[i] != xs_[i - 1] + 1] + [
        xs_[-1]
    ]
    for s0, e0 in zip(starts, ends):
        lm = visible[y, max(s0 - 6, 0):s0]
        rm = visible[y, e0 + 1:min(e0 + 7, W)]
        lv = I[y, max(s0 - 6, 0):s0][lm].mean(0) if lm.any() else None
        rv = I[y, e0 + 1:min(e0 + 7, W)][rm].mean(0) if rm.any() else None
        if lv is None and rv is None:
            continue
        if lv is None:
            lv = rv
        if rv is None:
            rv = lv
        xs_run = np.arange(s0, e0 + 1)
        t = (xs_run - s0 + 0.5) / (e0 - s0 + 1)
        # mirror each side into the hole (keeps the ridge lines and the real grain), blended across it
        lx = s0 - 1 - (xs_run - s0)
        rx = e0 + 1 + (e0 - xs_run)
        lval = np.tile(lv, (len(xs_run), 1)).astype(np.float32)
        rval = np.tile(rv, (len(xs_run), 1)).astype(np.float32)
        okl = (lx >= 0) & (lx < W)
        okr = (rx >= 0) & (rx < W)
        okl[okl] = visible[y, lx[okl]]
        okr[okr] = visible[y, rx[okr]]
        rowfilled[y, s0 : e0 + 1] = lval * (1 - t[:, None]) + rval * t[:, None]
        rowvalid[y, s0 : e0 + 1] = True
base_h = pushpull(I, visible, (2, 4, 8, 16, 32))
hdonor = visible & (yy > 330) & ~dil(roof_full, 8)
hdonor &= (xx > 440) & (xx < 900)
hdonor = np.zeros((H, W), bool)
hdonor[420:445, 700:860] = False
# grain donor: clean hills block
cand = visible & ~dil(~visible, 10)
cand &= (yy > 300) & (yy < 440)
grain_h = grain_field(I, cand, (H, W), rng, sigma_low=4.0, patch=24, step=12)
hole_vals = np.where(rowvalid[..., None], rowfilled, base_h + grain_h)
# soften the mirrored fill along x so no seam shows where the two mirrored sides meet
_tmp = np.where(visible[..., None], I, hole_vals)
_sm = cv2.GaussianBlur(_tmp.astype(np.float32), (0, 0), sigmaX=2.5, sigmaY=0.6)
hole_vals = np.where(rowvalid[..., None], _sm + grain_h * 0.7, hole_vals)
hills_rgb = np.where(visible[..., None], I, hole_vals)
# alpha for hills_far (projection over the plate at the ring)
a_h, rgb_h = extract(Z_h & (visible | hole_h), plate_s, ring=2, min_contrast=25)
# the extract() colours for hole pixels must be the filled ones
rgb_h = np.where(Z_h[..., None] & ~visible[..., None], hills_rgb, rgb_h)
C_h = C_b * (1 - a_h[..., None]) + rgb_h * a_h[..., None]
# (birds are above the hills, so composite order is plate, hills, birds -- recompute properly below)
print("hills px", Z_h.sum(), "visible", visible.sum())
np.savez_compressed(
    WORK + "s08_c_state.npz",
    a_h=a_h,
    rgb_h=rgb_h,
    a_birds=a_birds,
    rgb_birds=rgb_birds,
    Z_h=Z_h,
    visible=visible,
)
save_rgb(
    plate_s * (1 - a_h[..., None]) + rgb_h * a_h[..., None],
    WORK + "s08_hills_over_plate.png",
)

# ---------- order: plate, hills, birds, roofs, then the gallows over the middle roofs ----------
C_h2 = plate_s * (1 - a_h[..., None]) + rgb_h * a_h[..., None]
C_hb = C_h2 * (1 - a_birds[..., None]) + rgb_birds * a_birds[..., None]
feet_zone = dil(feet, 4) & (yy >= top_s[None, :] - 2)
roof_seed = roof_full | feet_zone
a_roof, rgb_roof = extract(roof_seed, C_hb, ring=2, min_contrast=25)
# under the feet the roof is hidden dark paper: continue it
rv = roof_full & ~dil(feet_zone, 3) & ~dil(L1 > 95, 2)
base_f = pushpull(rgb_roof, rv, (2, 4, 8, 16))
rdon_ = ero(roof_full & (yy > 450), 3)
grain_f = grain_field(I, rdon_, (H, W), rng, sigma_low=3.0, patch=32, step=16)
rgb_roof = np.where(feet_zone[..., None], base_f + grain_f, rgb_roof)
a_roof = np.where(feet_zone, 1.0, a_roof).astype(np.float32)
C_roofs = C_hb * (1 - a_roof[..., None]) + rgb_roof * a_roof[..., None]
a_gal, rgb_gal = extract(gallows, C_roofs, ring=2, min_contrast=25)
C_all = C_roofs * (1 - a_gal[..., None]) + rgb_gal * a_gal[..., None]
C_gb = C_hb
dd = np.abs(C_all - I)
print('08 rest diff (float, before 8-bit) max %.1f mean %.3f' % (dd.max(), dd.mean()))
np.savez_compressed(WORK + 's08_c2_state.npz', a_gal=a_gal, rgb_gal=rgb_gal, a_roof=a_roof, rgb_roof=rgb_roof, C_all=C_all)
save_rgb(C_all, WORK + 's08_rest_raw.png')
save_rgb(np.clip(dd * 8, 0, 255), WORK + 's08_diff_x8.png')
