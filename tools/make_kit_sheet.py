"""島の置き物のカタログ一覧（assets/gen/island_kit/<id>.png を並べ、名前・値段・材料を添える）。
  python3 tools/make_kit_sheet.py  → ui_review/island_catalog.png
"""
import csv, os, re
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "assets", "gen", "island_kit")
names = {}
with open(os.path.join(ROOT, "translations", "island_kit.csv"), encoding="utf-8") as f:
    for row in csv.DictReader(f):
        names[row["keys"]] = (row["en"], row["ja"])
items = []
for line in open(os.path.join(ROOT, "scripts", "island_kit.gd"), encoding="utf-8"):
    m = re.match(r'\s*\{"id": "(\w+)", "cat": "(\w+)".*"price": (\d+), "mats": \{([^}]*)\}, "stage": (\d)', line)
    if m:
        yen = re.search(r'"yen": (\d+)', line)
        mats = ", ".join("%s%s" % (v, k) for k, v in re.findall(r'"(\w+)": (\d+)', m.group(4)))
        items.append(dict(id=m.group(1), cat=m.group(2), price=int(m.group(3)), mats=mats, stage=int(m.group(5)), yen=yen.group(1) if yen else None))
cols, cell, lab = 8, 220, 64
rows = (len(items) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cell, rows * (cell + lab)), (251, 246, 239))
d = ImageDraw.Draw(sheet)
fb = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/ZenMaruGothic-Black.ttf"), 17)
fs = ImageFont.truetype(os.path.join(ROOT, "assets/fonts/ZenMaruGothic-Bold.ttf"), 13)
for i, it in enumerate(items):
    x, y = (i % cols) * cell, (i // cols) * (cell + lab)
    bg = (255, 250, 242) if (i + i // cols) % 2 == 0 else (243, 236, 226)
    if it["yen"]:
        bg = (238, 232, 255)
    d.rectangle([x, y, x + cell, y + cell + lab], fill=bg)
    p = os.path.join(SRC, it["id"] + ".png")
    if os.path.exists(p):
        im = Image.open(p).convert("RGBA").resize((cell, cell), Image.LANCZOS)
        sheet.paste(im, (x, y), im)
    en, ja = names.get("KIT_" + it["id"], (it["id"], ""))
    d.text((x + 10, y + cell - 4), en, fill=(42, 34, 51), font=fb)
    d.text((x + 10, y + cell + 17), ja, fill=(106, 95, 112), font=fs)
    info = ("¥%s sample · looks only" % it["yen"]) if it["yen"] else ("%dc  %s  S%d" % (it["price"], it["mats"], it["stage"]))
    d.text((x + 10, y + cell + 36), info, fill=(138, 91, 214) if it["yen"] else (176, 100, 58), font=fs)
out = os.path.join(ROOT, "ui_review", "island_catalog.png")
sheet.save(out)
print(out, len(items), "items")
