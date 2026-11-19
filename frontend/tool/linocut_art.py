"""Turn a cut-paper picture into a five-ink linocut print."""
import sys, numpy as np
from PIL import Image, ImageFilter
INKS = np.array([(0x17,0x13,0x0f),(0x14,0x18,0x3a),(0xf3,0xe8,0xd3),(0xc8,0x45,0x2f),(0xe3,0xa1,0x3a)], float)
def lino(src, dst, seed=7):
    im = Image.open(src).convert('RGB')
    # flatten paper grain, keep shapes
    for _ in range(3): im = im.filter(ImageFilter.MedianFilter(7))
    a = np.asarray(im, float)
    # stretch contrast so mid-tones commit to an ink
    lo, hi = np.percentile(a, 2), np.percentile(a, 98)
    a = np.clip((a - lo) / (hi - lo), 0, 1) * 255
    # nearest ink, weighting hue so reds/ambers survive
    d = ((a[:, :, None, :] - INKS[None, None]) ** 2 * np.array([1.0, 1.2, 0.9])).sum(-1)
    idx = d.argmin(-1)
    # tidy speckle: majority filter on the ink map
    m = Image.fromarray(idx.astype('uint8')).filter(ImageFilter.ModeFilter(9)).filter(ImageFilter.ModeFilter(5))
    idx = np.asarray(m)
    out = INKS[idx]
    # carved edges: ink line where regions meet
    e = np.zeros(idx.shape, bool)
    e[1:, :] |= idx[1:, :] != idx[:-1, :]; e[:, 1:] |= idx[:, 1:] != idx[:, :-1]
    e = np.asarray(Image.fromarray((e * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0
    out[e] = INKS[0]
    # print texture: missed ink specks in flat areas
    rng = np.random.default_rng(seed)
    n = np.asarray(Image.fromarray((rng.random(idx.shape) * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(1.2)), float)
    speck = (n > 168) & ~e & (idx != 2)
    out[speck] = out[speck] * 0.55 + INKS[2] * 0.45
    Image.fromarray(out.astype('uint8')).save(dst)
if __name__ == '__main__': lino(sys.argv[1], sys.argv[2])
