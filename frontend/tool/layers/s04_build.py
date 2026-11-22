"""Build the 04 plate and shadow maps."""


import cv2
import numpy as np
from lib import *

I = load(WORK + "night-village.jpg")
H, W, _ = I.shape
rng = np.random.default_rng(404)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
cx, cy, r = np.load(WORK + "moon_circle.npy")
dist_c = np.hypot(xx - cx, yy - cy)
M = dict(np.load(WORK + "masks04.npz"))
model = np.load(WORK + "sky_model04.npy")


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


# manual: RC tip sliver over the moon
extra_rc = np.zeros((H, W), np.uint8)
cv2.fillPoly(
    extra_rc,
    [
        np.array(
            [
                [595, 242],
                [606, 239],
                [622, 236],
                [640, 234],
                [652, 232],
                [652, 236],
                [640, 238],
                [622, 241],
                [606, 243],
            ],
            np.int32,
        )
    ],
    1,
)
M["rc"] = M["rc"] | extra_rc.astype(bool)

# manual: the cream cloud's tail over the moon (cream on cream: no edge to threshold). Wedge from the disc edge to the tip.
poly = np.zeros((H, W), np.uint8)
cv2.fillPoly(poly, [np.array([[502, 182], [515, 186], [530, 190], [545, 195], [553, 197], [546, 198], [534, 195], [525, 196], [515, 197], [503, 198]], np.int32)], 1)
M['cc1'] = (M['cc1'] & (xx <= 502)) | poly.astype(bool)

disc_hard = dist_c <= r
disc = np.clip(r + 0.5 - dist_c, 0, 1)
body = {k: M[k] for k in ["lc1", "lc2", "rc", "cc1", "cc2"]}
dark_names = ["lc1", "lc2", "rc"]
cream_names = ["cc1", "cc2"]
casters = dict(body)
casters["moon"] = disc_hard
names = list(casters)

# distance to every caster, owner = nearest (on the moon only clouds)
D = np.stack(
    [
        cv2.distanceTransform((~casters[k]).astype(np.uint8), cv2.DIST_L2, 3)
        for k in names
    ],
    0,
)
Dm = D.copy()
Dm[names.index("moon")][disc_hard] = 1e9
owner = np.where(disc_hard, np.argmin(Dm, 0), np.argmin(D, 0))
dmin = np.min(D, 0)
reach = 75

hole_cloud = np.zeros((H, W), bool)
for k, v in body.items():
    hole_cloud |= dil(v, 3)
moon_ring = dil(disc_hard, 2) & ~ero(disc_hard, 2)  # unreliable: moon edge
hole_s = hole_cloud | moon_ring  # pixels not used to *measure* shadow
hole = hole_cloud | dil(disc_hard, 3)  # pixels removed from the plate

# ---------- sky reference (unshadowed) ----------
sky_far = (dmin >= reach) & (yy >= 150) & (yy < 440)
Lraw = gauss(I.mean(2), 1.5)
sky_far &= (Lraw > 22) & (Lraw < 50)
sky_far &= ~dil(Lraw > 52, 5)
sky_local = pushpull(I, sky_far, (4, 8, 16, 32, 64, 128))
wgt = smoothstep((yy - 230) / 25)[..., None]
sky_ref = model * (1 - wgt) + sky_local * wgt

# moon reference: smooth unshadowed cream from clean disc pixels
clouds_on_moon = dil(body["rc"] | body["cc1"], 16)
moon_valid = ero(disc_hard, 4) & ~clouds_on_moon
moon_ref = pushpull(gauss(I, 3), moon_valid, (6, 12, 24, 48, 96))
R = np.where(disc_hard[..., None], moon_ref, sky_ref)

# ---------- shadow measurement ----------
vA = (ero(disc_hard, 2) & ~hole_cloud).astype(np.float32)  # moon interior
vB = (~dil(disc_hard, 3) & ~hole_cloud).astype(np.float32)  # sky


def nconv(img, v, sg):
    return np.dstack(
        [gauss(img[..., c] * v, sg) / np.maximum(gauss(v, sg), 0.05) for c in range(3)]
    )


Is_c = np.where(disc_hard[..., None], nconv(I, vA, 1.8), nconv(I, vB, 1.8))
Is_f = np.where(disc_hard[..., None], nconv(I, vA, 0.8), nconv(I, vB, 0.8))
wf = smoothstep((14 - dmin) / 8)[..., None]
Is = Is_f * wf + Is_c * (1 - wf)
ratio = (Is / np.maximum(R, 1)).mean(2)
s_raw = np.clip(1 - ratio, 0, 0.97)
s = (
    s_raw
    * smoothstep((s_raw - 0.03) / 0.03)
    * (dmin < reach)
    * smoothstep((reach - dmin) / 15)
)
s[hole_s] = 0
s[(yy > 352) & (xx > 735)] = 0   # the right-hand chimney is not sky
# extend s into the unmeasured pixels, but only a few px (the AA rings)
meas = ~hole_s
dist_to_meas = cv2.distanceTransform((~meas).astype(np.uint8), cv2.DIST_L2, 3)
s_push_in = pushpull(s, meas & disc_hard, (1.5, 3, 6))
s_push_out = pushpull(s, meas & ~disc_hard, (1.5, 3, 6))
s_push = np.where(disc_hard, s_push_in, s_push_out)
s_ext = np.where(meas, s, np.where(dist_to_meas < 7, s_push, 0)).astype(np.float32)
s_ext = np.clip(s_ext, 0, 0.97)

# ---------- plate ----------
hole_plate = hole | dil((s_ext > 0.40) & ~disc_hard, 1)
unshadow = I / np.maximum(1 - s_ext, 0.03)[..., None]
plate = I.copy()
lift_zone = (s_ext > 0.003) & ~hole_plate & ~disc_hard
plate[lift_zone] = unshadow[lift_zone]

donor = np.zeros((H, W), bool)
donor[:250, 300:495] = True
donor[:60, :] = True
donor &= ~dil(hole_plate, 20) & ~dil(s_ext > 0.01, 6)
grain_sky = grain_field(I, donor, (H, W), rng, sigma_low=5.0, patch=64, step=32)
resid = pushpull(
    plate - sky_ref,
    ~dil(hole_plate, 4) & (s_ext < 0.02) & ~disc_hard,
    (6, 12, 24, 48, 96),
)
fill_sky = sky_ref + resid + grain_sky
fa = gauss(hole_plate.astype(np.float32), 0.8)
fa_in = np.maximum(fa, hole_plate)
plate_final = plate * (1 - fa_in[..., None]) + fill_sky * fa_in[..., None]
save_rgb(plate_final, WORK + "village_plate_raw.png")
print("plate done")
