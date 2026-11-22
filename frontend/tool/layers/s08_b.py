"""08 step B: sky plate, hills_far, birds, gallows (everything above the roofs)."""

import cv2
import numpy as np
from lib import *

I = load(WORK + "dawn-gallows.jpg")
H, W, _ = I.shape
L = I.mean(2)
L1 = gauss(L, 0.8)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
rng = np.random.default_rng(808)
A = np.load(WORK + "s08_a.npz")
birds, gal_full, dark, roof_comp = A["birds"], A["gal"], A["dark"], A["roof_comp"]


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


# ---------- roofs: the dark component without the gallows' own dark edges ----------
dark2 = dark & ~(gal_full & (yy < 405))
_n, _lab, _st, _ = cv2.connectedComponentsWithStats(dark2.astype(np.uint8), connectivity=8)
_big = 1 + np.argmax(_st[1:, cv2.CC_STAT_AREA])
roof_comp = _lab == _big
# ---------- roof top profile (roofs minus the gallows post) ----------
post_reg = (xx >= 650) & (xx <= 712) & (yy >= 205) & (yy < 440)
roof_only = roof_comp & ~post_reg
top = np.full(W, H - 1, np.int32)
for x in range(W):
    ys = np.nonzero(roof_only[200:, x])[0]
    if len(ys):
        top[x] = 200 + ys[0]
top_s = (
    cv2.medianBlur(top.astype(np.float32).reshape(1, -1), 5).ravel()
    if False
    else top.astype(np.float32)
)
roof_zone = yy >= top_s[None, :]
# gallows above the roof line only; wood below is roof trim
gallows = gal_full & ~roof_zone
gallows = gallows | (gal_full & (yy < top_s[None, :] + 1) & post_reg)

# ---------- sky / hills boundary: end of the sky run from the top ----------
skyish = (L1 > 195) | birds | dil(gallows, 2)
yb = np.zeros(W, np.float32)
for x in range(W):
    col = skyish[:, x]
    y = 235
    while y < H - 8 and (col[y] or col[y:y + 8].any()):
        y += 1
    yb[x] = y
# smooth/despike: median then interpolate over gallows columns
yb_m = cv2.medianBlur(yb.reshape(1, -1), 5).ravel()
gcols = gallows[255:420].sum(0) > 0
gcols = np.convolve(gcols.astype(float), np.ones(7), 'same') > 0
ok = ~gcols & (yb_m > 255)
xs = np.arange(W)
yb_i = np.interp(xs, xs[ok], yb_m[ok])
print("boundary at x=300,400,600,800,950:", yb_i[[300, 400, 600, 800, 950]].round(0))

# ---------- the pale band round the sun (kept in the sky plate) ----------
band = np.zeros((H, W), bool)
y_t = np.full(W, np.nan)
y_b = np.full(W, np.nan)
for x in range(600, W):
    col = L1[:, x] > 203
    if not col[330]:
        continue
    t = 330
    while t > 250 and col[t - 1]:
        t -= 1
    b = 330
    while b < H - 1 and col[b + 1]:
        b += 1
    y_t[x], y_b[x] = t, b + 1
okx = ~np.isnan(y_t)
print("band columns", okx.sum(), "x range", xs[okx].min(), xs[okx].max())
y_t_i = np.interp(xs[600:], xs[okx], y_t[okx])
y_b_i = np.interp(xs[600:], xs[okx], y_b[okx])
# the edges of the band are soft paper edges: smooth the per-column jitter
def _sm(v):
    from scipy.ndimage import median_filter
    v = median_filter(v.astype(np.float32), size=15, mode='nearest')
    return cv2.GaussianBlur(v.reshape(1, -1), (0, 0), 3).ravel()
y_t_i = _sm(y_t_i)
y_b_i = _sm(y_b_i)
for k, x in enumerate(range(600, W)):
    band[int(y_t_i[k]) : int(y_b_i[k]), x] = True
band = band & ~dil(gallows, 3)
np.save(WORK + "s08_band.npy", band)

# ---------- sun hole ----------
sx, sy, sr = 762.0, 354.0, 50.0
dsun = np.hypot(xx - sx, yy - sy)
sun_hole = (dsun < sr + 7) & band

# ---------- sky plate ----------
above = yy < yb_i[None, :]
bird_d = dil(birds, 3)
gal_d = dil(gallows & ~post_reg, 7) | dil(gallows & post_reg, 3) | (((I[..., 0] - I[..., 2]) > 12) & dil(gallows & ~post_reg & (xx < 600), 12))
above_in = yy < (yb_i[None, :] - 6)
band_in = cv2.erode(band.astype(np.uint8), np.ones((11, 1), np.uint8)).astype(bool)
valid_sky = (above_in | band_in) & ~bird_d & ~gal_d & ~roof_zone & ~sun_hole & ~dil(dark, 4)
valid_sky &= yy < 470
# row interpolation across narrow holes keeps the band's horizontal structure; smooth pushpull for the rest
plate_base = pushpull(I, valid_sky, (2, 4, 8, 16, 32, 64, 128, 256))
# grain donor: clean sky, plus clean band
donor = np.zeros((H, W), bool)
donor[8:195, 470:640] = True
donor &= ~dil(birds, 6)
grain_sky = grain_field(I, donor, (H, W), rng, sigma_low=5.0, patch=64, step=32)
band_donor = np.zeros((H, W), bool)
band_donor[300:345, 840:1010] = True
band_donor &= band
grain_band = grain_field(I, band_donor, (H, W), rng, sigma_low=4.0, patch=32, step=16)

fill = valid_sky
plate = I.copy()
holes_sky = ~valid_sky & (yy < 470)
gr = np.where((band & ~above)[..., None], grain_band, grain_sky)
plate = np.where(holes_sky[..., None], plate_base + gr, plate)
# below y=470 nothing is ever visible: flat continuation
low = yy >= 470
plate = np.where(low[..., None], pushpull(I, valid_sky, (64, 128, 256)), plate)
# feather the real/synthetic seam
fa = gauss(holes_sky.astype(np.float32), 0.8)
plate = (
    I * (1 - np.clip(fa, 0, 1))[..., None] * (valid_sky[..., None])
    + plate * np.where(valid_sky, np.clip(fa, 0, 1), 1)[..., None]
    if False
    else plate
)
save_rgb(plate, WORK + "s08_plate_raw.png")
np.savez_compressed(
    WORK + "s08_b_state.npz",
    plate=plate.astype(np.float32),
    yb=yb_i,
    valid_sky=valid_sky,
    gallows=gallows,
    roof_zone=roof_zone,
    band=band,
    sun_hole=sun_hole,
)
print("plate done")
