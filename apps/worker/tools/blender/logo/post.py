"""Post steps for the Paw Time 3D logo (system python3 + Pillow).

  python3 tools/blender/logo/post.py glow   <logo_main.png> <out_dir>
  python3 tools/blender/logo/post.py shadow <logo_shadow.png>          (in place)
  python3 tools/blender/logo/post.py sheet <out.png> A.png B.png C.png D.png
  python3 tools/blender/logo/post.py phone <logo.png> <out.png> [shadow.png]
"""
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
SKY = os.path.join(REPO, "assets", "title", "sky.png")
FONT = os.path.join(REPO, "assets", "fonts", "ZenMaruGothic-Bold.ttf")
GLOW = (255, 206, 128)


def glow(src, out_dir):
    im = Image.open(src).convert("RGBA")
    w = im.width
    a = im.getchannel("A")
    a = a.filter(ImageFilter.MaxFilter(9))
    soft = a.filter(ImageFilter.GaussianBlur(w * 0.018))
    wide = a.filter(ImageFilter.GaussianBlur(w * 0.045))
    g = ImageChops.add(soft.point(lambda v: int(v * 0.7)), wide.point(lambda v: int(v * 0.45)))
    layer = Image.new("RGBA", im.size, GLOW + (0,))
    layer.putalpha(g)
    layer.save(os.path.join(out_dir, "logo_glow.png"))
    comp = layer.copy()
    comp.alpha_composite(im)
    comp.save(os.path.join(out_dir, "logo_main_glow.png"))


def edge_fade(a, frac=0.06):
    """Ramp alpha to 0 at the canvas border so the drop-shadow tail never ends in a hard edge."""
    w, h = a.size
    m = int(min(w, h) * frac)
    ramp = lambda i, n: min(1.0, min(i, n - 1 - i) / m)
    col = Image.new("L", (w, 1))
    col.putdata([int(255 * ramp(x, w)) for x in range(w)])
    row = Image.new("L", (1, h))
    row.putdata([int(255 * ramp(y, h)) for y in range(h)])
    mask = ImageChops.multiply(col.resize((w, h)), row.resize((w, h)))
    return ImageChops.multiply(a, mask)


def shadow(src, opacity=0.5):
    """Cap the shadow-catcher layer to a gentle opacity and soften it (in place)."""
    im = Image.open(src).convert("RGBA")
    a = im.getchannel("A").point(lambda v: int(v * opacity))
    a = a.filter(ImageFilter.GaussianBlur(im.width * 0.004))
    a = edge_fade(a)
    out = Image.new("RGBA", im.size, (20, 18, 40, 0))
    out.putalpha(a)
    out.save(src)


def sky_crop(size):
    sky = Image.open(SKY).convert("RGBA")
    w, h = size
    s = max(w / sky.width, h / sky.height)
    sky = sky.resize((int(sky.width * s) + 1, int(sky.height * s) + 1), Image.LANCZOS)
    top = min(int(sky.height * 0.08), sky.height - h)
    return sky.crop((0, top, w, top + h))


def sheet(out, paths):
    cw, ch = 1200, 640
    labels = ["A  cream enamel / navy", "B  peach / plum", "C  white vinyl / gold trim", "D  stacked / cat-ear P"]
    canvas = Image.new("RGBA", (cw * 2, ch * 2), (20, 20, 30, 255))
    font = ImageFont.truetype(FONT, 34)
    for i, p in enumerate(paths):
        cell = sky_crop((cw, ch))
        logo = Image.open(p).convert("RGBA")
        k = min((cw * 0.9) / logo.width, (ch * 0.8) / logo.height)
        logo = logo.resize((int(logo.width * k), int(logo.height * k)), Image.LANCZOS)
        cell.alpha_composite(logo, ((cw - logo.width) // 2, (ch - logo.height) // 2 + 20))
        d = ImageDraw.Draw(cell)
        d.rounded_rectangle((18, 16, 18 + 22 * len(labels[i]) + 20, 66), 14, fill=(0, 0, 0, 120))
        d.text((32, 20), labels[i], font=font, fill=(255, 255, 255, 255))
        canvas.alpha_composite(cell, ((i % 2) * cw, (i // 2) * ch))
    canvas.convert("RGB").save(out)


def phone(src, out, shadow=None):
    """Title-screen check: 1080x1920 sky, logo at 80% width, then shrunk to a 390 px phone."""
    bg = sky_crop((1080, 1920))
    logo = Image.open(src).convert("RGBA")
    k = 1080 * 0.8 / (logo.width * 0.8)  # canvas has 10% margins -> wordmark ~80% wide
    size = (int(logo.width * k), int(logo.height * k))
    pos = ((1080 - size[0]) // 2, 230)
    if shadow:
        bg.alpha_composite(Image.open(shadow).convert("RGBA").resize(size, Image.LANCZOS), pos)
    bg.alpha_composite(logo.resize(size, Image.LANCZOS), pos)
    bg = bg.convert("RGB")
    bg.save(out.replace(".png", "_1080.png"))
    bg.resize((390, int(1920 * 390 / 1080)), Image.LANCZOS).save(out)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "glow":
        glow(sys.argv[2], sys.argv[3])
    elif cmd == "shadow":
        shadow(sys.argv[2])
    elif cmd == "sheet":
        sheet(sys.argv[2], sys.argv[3:])
    elif cmd == "phone":
        phone(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
