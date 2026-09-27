"""タイトルのロゴ（緑 #00FF00 のクロマキー）を透過 PNG にする。縁は砂色の輪郭に揃えて、緑のにじみを残さない。
  uv run --with pillow --with numpy python tools/key_title_logo.py logo_b.png assets/title/logo.png check.png
"""
import sys, numpy as np
from PIL import Image
src, dst, prev = sys.argv[1], sys.argv[2], sys.argv[3]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
R, G, B = im[..., 0], im[..., 1], im[..., 2]
# green excess: 255 on pure key, <=0 on navy / cream / sand
gex = G - np.maximum(R, B)
# foreground colors have gex <= ~0; map (lo..hi) -> alpha (1..0)
lo, hi = -31.0, 250.0  # sand outline (#D8B99B) has green excess -31: linear unmix against it
a = 1.0 - np.clip((gex - lo) / (hi - lo), 0.0, 1.0)
# painted colors (navy, cream, sand) all have gex <= 0: those pixels are untouched by the key
a[gex <= 0.0] = 1.0
# pixels within 4 px of the key are outline antialiasing (spill can make them yellow while gex <= 0)
key = gex > 40.0
near = key.copy()
for dy in range(-4, 5):
    for dx in range(-4, 5):
        near |= np.roll(np.roll(key, dy, 0), dx, 1)
rim = near & (gex > -48.0)  # the 1-px spill band just inside the outline reads about -33
a[rim] = np.clip((hi - gex[rim]) / (hi - lo), 0.0, 1.0)
# unmix the key color from partially covered pixels
K = np.array([0.0, 255.0, 0.0])
aa = np.maximum(a, 1e-3)[..., None]
F = (im - (1.0 - a)[..., None] * K) / aa
F = np.clip(F, 0, 255)
# despill: every key-adjacent pixel lies on the warm-sand outline, so partially covered pixels take the
# pure sand color (alpha carries the antialiasing); fully covered pixels keep their painted color
SAND = np.array([0xD8, 0xB9, 0x9B], dtype=np.float32)
edge = rim | (gex > 0.0)
F[edge] = SAND
# the painted outline band has brighter orange speckles; flatten warm pixels within 8 px of the key to sand
band = key.copy()
for dy in range(-8, 9):
    for dx in range(-8, 9):
        band |= np.roll(np.roll(key, dy, 0), dx, 1)
warm = band & (R > 180) & (R >= G) & (G >= B) & ((G - B) > 20)
F[warm] = SAND
a[~edge] = 1.0
# drop isolated faint specks
a[a < 0.02] = 0.0
out = np.dstack([F, a * 255.0]).round().astype(np.uint8)
img = Image.fromarray(out, "RGBA")
bbox = img.getchannel("A").point(lambda v: 255 if v > 3 else 0).getbbox()
pad = 12
x0, y0, x1, y1 = bbox
img = img.crop((max(0, x0 - pad), max(0, y0 - pad), min(img.width, x1 + pad), min(img.height, y1 + pad)))
img.save(dst)
print("trimmed", img.size, "from bbox", bbox)
# preview: 2x zoom crops on dark / light / sky backgrounds
W, H = img.size
crop = img.crop((0, 0, W // 3, H // 2)).resize((W // 3 * 2, H // 2 * 2), Image.NEAREST)
tiles = []
for bg in [(20, 20, 30), (255, 255, 255), (247, 187, 164), (147, 157, 203)]:
    t = Image.new("RGBA", crop.size, bg + (255,))
    t.alpha_composite(crop)
    tiles.append(t)
sheet = Image.new("RGBA", (crop.width * 2, crop.height * 2))
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % 2) * crop.width, (i // 2) * crop.height))
sheet.convert("RGB").save(prev)
