exec(open("s04_layers2.py").read())
from PIL import Image


def to_rgba(rgb, alpha):
    a = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    c = np.clip(rgb + 0.5, 0, 255).astype(np.uint8)
    c = np.where((a > 0)[..., None], c, 0).astype(np.uint8)
    return np.dstack([c, a])


def black(alpha):
    a = np.clip(alpha * 255 + 0.5, 0, 255).astype(np.uint8)
    return np.dstack([np.zeros_like(a)] * 3 + [a])


def bleed(rgba, n=16):
    left = rgba[:, 1 : n + 1][:, ::-1]
    right = rgba[:, -n - 1 : -1][:, ::-1]
    return np.concatenate([left, rgba, right], axis=1)


def save_pair(arr, name, mode="RGBA"):
    Image.fromarray(arr, mode).save(OUT + name + ".png", optimize=True)
    Image.fromarray(arr, mode).save(OUT + name + ".webp", quality=80, method=6)


for f in os.listdir(OUT):
    if f.startswith("04_"):
        os.remove(OUT + f)
save_pair(np.clip(P + 0.5, 0, 255).astype(np.uint8), "04_village_plate", "RGB")
save_pair(to_rgba(rgb_moon, alpha_moon), "04_moon")
save_pair(black(S_moon_dark), "04_moon_shadow_dark")
save_pair(black(S_moon_cream), "04_moon_shadow_cream")
drift = {
    "04_clouds_dark_shadow": black(SS_dark),
    "04_clouds_cream_shadow": black(SS_cream),
    "04_clouds_dark": to_rgba(rgb_dark, a_dark),
    "04_clouds_cream": to_rgba(rgb_cream, a_cream),
}
for k, v in drift.items():
    save_pair(v, k)
    save_pair(bleed(v), k + "_bleed16")
print("exported 04 v2")
