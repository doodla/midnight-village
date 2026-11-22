"""08 step D: split the roofs into near and mid, fill the mid under the seams."""

exec(open("s08_c.py").read())

# ---- polygons (source px), read off the picture: the seams where a nearer roof overlaps a farther one ----
poly_left = [
    (0, 0),
    (262, 0),
    (263, 250),
    (266, 262),
    (262, 300),
    (256, 370),
    (266, 370),
    (263, 395),
    (268, 398),
    (402, 722),
    (412, 768),
    (0, 768),
]
poly_right = [
    (1024, 0),
    (866, 0),
    (866, 358),
    (855, 400),
    (795, 512),
    (763, 572),
    (743, 630),
    (719, 680),
    (726, 768),
    (1024, 768),
]


def poly_aa(pts, ss=4):
    m = np.zeros((H * ss, W * ss), np.uint8)
    cv2.fillPoly(m, [np.array([(x * ss, y * ss) for x, y in pts], np.int32)], 1)
    return cv2.resize(m.astype(np.float32), (W, H), interpolation=cv2.INTER_AREA)


pl = poly_aa(poly_left)
pr = poly_aa(poly_right)
near_poly = np.clip(pl + pr, 0, 1)
# a cream trim strip is one paper strip: it goes wholly to the layer most of it falls in
_n, _l, _st, _ = cv2.connectedComponentsWithStats(trim.astype(np.uint8), connectivity=8)
for k in range(1, _n):
    if _st[k][4] < 8:
        continue
    comp = _l == k
    frac = near_poly[comp].mean()
    if 0.02 < frac < 0.98:
        near_poly[dil(comp, 1)] = 1.0 if frac > 0.5 else 0.0
a_near = a_roof * near_poly
a_mid_vis = a_roof * (1 - near_poly)

# mid roofs: continue under the near roofs for 14 px past each seam
mid_vis_hard = a_mid_vis > 0.5
under_near = (near_poly > 0.02) & (a_roof > 0.5)
band_under = under_near & dil(mid_vis_hard, 14)
# content: smooth continuation of the dark paper + grain from clean roof paper
rdon = mid_vis_hard & ~dil(~mid_vis_hard, 6) & (yy > 450)
rdon_f = ero(rdon, 2)
grain_r = grain_field(I, rdon_f, (H, W), rng, sigma_low=3.0, patch=48, step=24)
base_r = pushpull(rgb_roof, mid_vis_hard & ~dil(~roof_full, 1) & ~dil(L1 > 95, 2), (2, 4, 8, 16, 32))
fill_r = base_r + grain_r
# keep the seam straight: fill only within the band
a_mid = np.maximum(a_mid_vis, band_under.astype(np.float32) * 1.0)
rgb_mid = np.where((band_under & (near_poly > 0.5))[..., None], fill_r, rgb_roof)
# near layer straight colours are those of the roof
rgb_near = rgb_roof

# composite check at rest
C_mid = C_gb * (1 - a_mid[..., None]) + rgb_mid * a_mid[..., None]
C_rest = C_mid * (1 - a_near[..., None]) + rgb_near * a_near[..., None]
C_rest = C_rest * (1 - a_gal[..., None]) + rgb_gal * a_gal[..., None]
dd = np.abs(C_rest - I)
print("08 split rest diff max %.1f mean %.3f" % (dd.max(), dd.mean()))
np.savez_compressed(
    WORK + "s08_d_state.npz",
    a_near=a_near,
    rgb_near=rgb_near,
    a_mid=a_mid,
    rgb_mid=rgb_mid,
)
save_rgb(C_rest, WORK + "s08_rest_raw2.png")
# near / mid review image: near tinted
vis = I.copy()
vis[near_poly > 0.5] = vis[near_poly > 0.5] * 0.5 + np.array([255, 120, 0]) * 0.5
for pts in (poly_left, poly_right):
    cv2.polylines(vis, [np.array(pts, np.int32)], True, (0, 255, 0), 1)
save_rgb(vis, WORK + "s08_split_overlay.png")
