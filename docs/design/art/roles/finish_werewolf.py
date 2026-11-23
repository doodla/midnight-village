"""raw/<id>.png (1200x1600) -> werewolf-<letter>.jpg (576x768): grade, grain. Deterministic."""
import sys, zlib
import numpy as np
from PIL import Image
from matplotlib.colors import rgb_to_hsv, hsv_to_rgb
from scipy.ndimage import gaussian_filter

def finish(src, dst, seed):
    im = Image.open(src).convert("RGB").resize((576, 768), Image.LANCZOS)
    a = np.asarray(im).astype(np.float64) / 255
    hsv = rgb_to_hsv(a)
    h, s, v = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    # blues (190-265 deg) toward the violet-leaning indigo: hue +14, saturation -18%
    blue = np.clip(1 - np.abs(h - 228) / 40, 0, 1) * np.clip(s * 6, 0, 1)
    h = h + 14 * blue
    s = s * (1 - 0.18 * blue)
    # bone (bright, low saturation): lifted a little and warmed
    bone = np.clip((v - 0.55) / 0.25, 0, 1) * np.clip(1 - s / 0.30, 0, 1)
    v = np.clip(v * (1 + 0.04 * bone), 0, 1)
    # darks lifted a little (gamma 0.9) so the figure does not sink into the indigo
    v = v ** 0.9
    out = hsv_to_rgb(np.stack([(h % 360) / 360, np.clip(s, 0, 1), v], -1))
    warm = np.array([1.025, 1.0, 0.955])
    out = out * (1 - bone[..., None]) + np.clip(out * warm, 0, 1) * bone[..., None]
    # paper grain: fine soft noise, ~2.5% of range, mostly in the mid tones
    rng = np.random.default_rng(seed)
    n = gaussian_filter(rng.standard_normal((768, 576)), 0.7)
    n = n / n.std() * 0.025
    lum = out.mean(-1)
    mid = 4 * lum * (1 - lum)
    out = np.clip(out + (n * (0.4 + 0.6 * mid))[..., None], 0, 1)
    Image.fromarray((out * 255 + 0.5).astype(np.uint8)).save(dst, quality=92, subsampling=0)

if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    finish(src, dst, zlib.crc32(dst.split("/")[-1].encode()))
