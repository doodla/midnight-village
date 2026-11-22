exec(open("s08_d.py").read())
from PIL import Image


def to_rgba(rgb, alpha):
    a = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    c = np.clip(rgb + 0.5, 0, 255).astype(np.uint8)
    c = np.where((a > 0)[..., None], c, 0).astype(np.uint8)
    return np.dstack([c, a])


def bleed(rgba, n=12):
    return np.pad(rgba, ((n, n), (n, n), (0, 0)), mode="reflect")


def save_pair(arr, name, mode="RGBA"):
    Image.fromarray(arr, mode).save(OUT + name + ".png", optimize=True)
    Image.fromarray(arr, mode).save(OUT + name + ".webp", quality=80, method=6)


# the sky plate: opaque
plate8 = np.clip(plate_s + 0.5, 0, 255).astype(np.uint8)
save_pair(plate8, "08_sky_plate", "RGB")
def despeckle(a, min_area=12, thr=0.02):
    m = (a > thr).astype(np.uint8)
    k, lab, st, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    kill = np.zeros(k, bool)
    kill[1:] = st[1:, cv2.CC_STAT_AREA] < min_area
    return np.where(kill[lab], 0, a).astype(np.float32)


a_h, a_birds, a_gal, a_mid, a_near = [despeckle(x) for x in (a_h, a_birds, a_gal, a_mid, a_near)]


def close_gaps(a, rgb, size=3, area=40):
    """Fill hairline gaps / pin holes inside a layer (alpha closed, colour pulled from the neighbours)."""
    solid = (a > 0.5).astype(np.uint8)
    closed = cv2.morphologyEx(solid, cv2.MORPH_CLOSE, np.ones((size, size), np.uint8))
    new = (closed > 0) & (solid == 0)
    k, lab, st, _ = cv2.connectedComponentsWithStats(new.astype(np.uint8), connectivity=8)
    keep = np.zeros(k, bool)
    keep[1:] = st[1:, cv2.CC_STAT_AREA] <= area
    new = keep[lab] & new
    col = pushpull(rgb, (a > 0.95) & ~new, (1.5, 3, 6))
    return np.where(new, 1.0, a).astype(np.float32), np.where(new[..., None], col, rgb)


# the hills' rim where a roof overlapped it carries dark roof paper: recolour it from the clean hills so a moving roof shows hills, not roof-coloured specks
_lum = rgb_h.mean(2)
_bad = (a_h > 0.02) & (_lum < 88) & dil(roof_full, 7)
_good = (a_h > 0.5) & ~dil(_bad, 1) & ~dil(roof_full, 2)
_fix = pushpull(rgb_h, _good, (2, 4, 8, 16))
rgb_h = np.where(_bad[..., None], _fix, rgb_h)
print('hills rim pixels recoloured:', int(_bad.sum()))
a_near, rgb_near = close_gaps(a_near, rgb_near)
a_mid, rgb_mid = close_gaps(a_mid, rgb_mid)
a_gal, rgb_gal = close_gaps(a_gal, rgb_gal)
layers = {
    "08_hills_far": to_rgba(rgb_h, a_h),
    "08_birds": to_rgba(rgb_birds, a_birds),
    "08_gallows": to_rgba(rgb_gal, a_gal),
    "08_roofs_mid": to_rgba(rgb_mid, a_mid),
    "08_roofs_near": to_rgba(rgb_near, a_near),
}
for k, v in layers.items():
    save_pair(v, k)
for k in ["08_roofs_mid", "08_roofs_near"]:
    save_pair(bleed(layers[k]), k + "_bleed12")
# flattened "hills_far plate with sky" (sun removed): the simple version for anyone who does not need the sun behind the hills
flat = plate_s * (1 - a_h[..., None]) + rgb_h * a_h[..., None]
save_pair(
    np.clip(flat + 0.5, 0, 255).astype(np.uint8), "08_hills_far_plate_with_sky", "RGB"
)
print("exported 08")
