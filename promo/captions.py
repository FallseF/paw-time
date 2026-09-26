"""宣伝動画の字幕を PNG に描く（ffmpeg に drawtext が無いので）。python3 promo/captions.py"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
FONT = str(ROOT.parent / "assets/fonts/ZenMaruGothic-Black.ttf")
OUT = ROOT / "caps"
OUT.mkdir(exist_ok=True)

# (名前, 文字, 大きさ)
CAPS = [
    ("hook", "眠るほど、庭が育つ。", 66),
    ("scoop", "じっと待つと、ゆめの泡が浮かぶ", 50),
    ("sleep", "いつもの時刻に、おやすみ", 52),
    ("dream", "よく眠れた夜は、夢を見る", 52),
    ("hatch", "朝、光る玉がかえる", 54),
    ("garden", "リズムが整うと、庭が育つ", 52),
    ("moon", "日曜は、満月の夜", 54),
    ("deco", "働いた日は、店の飾りが届く", 50),
    ("zukan", "レアおばけ 30体", 56),
    ("tag1", "働いた日は、ポイが増える。", 46),
    ("tag2", "よく寝た朝は、玉がかえる。", 46),
]

for name, text, size in CAPS:
    font = ImageFont.truetype(FONT, size)
    d0 = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    x0, y0, x1, y1 = d0.textbbox((0, 0), text, font=font, stroke_width=6)
    w, h = x1 - x0, y1 - y0
    pad = 26
    im = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, im.width - 1, im.height - 1), radius=(h + pad * 2) // 2, fill=(42, 34, 51, 150))
    d.text((pad - x0, pad - y0), text, font=font, fill=(255, 250, 240, 255), stroke_width=6, stroke_fill=(42, 34, 51, 255))
    im.save(OUT / f"{name}.png")
print("wrote", len(CAPS), "captions")
