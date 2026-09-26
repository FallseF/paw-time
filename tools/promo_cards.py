"""宣伝動画の字幕と、しめのカードを PNG で作る（ffmpeg に drawtext が無いので）。python3 tools/promo_cards.py"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
TMP = ROOT / "promo" / "tmp"
TMP.mkdir(parents=True, exist_ok=True)
FONT = str(ROOT / "assets" / "fonts" / "ZenMaruGothic-Black.ttf")
INK = (42, 34, 51)

CAPS = {
    "rush": ("金曜の夜、店がパンク寸前", "おばけで守れ！"),
    "boss": ("困りごとの大ピーク、来た。", "チャイムで押し返せ"),
    "room": ("働いた日は", "その店で、おばけが強くなる"),
    "scoop": ("夜は川べりで", "仲間をすくう"),
    "hatch": ("よく寝た朝は", "玉がかえる"),
    "crew": ("レア30体", "それぞれ、変な技"),
}


def center(d, y, text, font, fill, stroke=0, stroke_fill=INK):
    w = d.textlength(text, font=font)
    d.text(((720 - w) / 2, y), text, font=font, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)


for key, (top, bottom) in CAPS.items():
    im = Image.new("RGBA", (720, 1280), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 720, 150], fill=INK + (215,))
    center(d, 42, top, ImageFont.truetype(FONT, 54), (255, 255, 255))
    center(d, 168, bottom, ImageFont.truetype(FONT, 58), (255, 210, 63), stroke=8)
    im.save(TMP / f"cap_{key}.png")

im = Image.new("RGB", (720, 1280), (255, 248, 239))
d = ImageDraw.Draw(im)
center(d, 400, "おばけの休憩室", ImageFont.truetype(FONT, 76), INK)
center(d, 500, "大ピーク防衛", ImageFont.truetype(FONT, 100), (255, 107, 91))
center(d, 720, "働いた日は、店で強くなる。", ImageFont.truetype(FONT, 42), (106, 95, 112))
center(d, 790, "よく寝た朝は、玉がかえる。", ImageFont.truetype(FONT, 42), (106, 95, 112))
try:
    g = Image.open(ROOT / "assets" / "gen" / "rares" / "hyakki.png").convert("RGBA")
    g.thumbnail((300, 300))
    im.paste(g, ((720 - g.width) // 2, 900), g)
except Exception as e:
    print("no hyakki art", e, file=sys.stderr)
im.save(TMP / "end.png")
print("cards ok")
