"""おばけの休憩室のドット絵を一括で描く。python3 tools/gen_art.py で assets/sprites に PNG を出す。

絵柄の決まり：
- パレットは下の PAL だけを使う
- キャラクターは 32x32、輪郭は 1px の INK、左上から光が当たる（右下が影）
- 背景は 180x320 で描き、ゲーム内で 2 倍にする
"""

from pathlib import Path
import math
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
OUT.mkdir(parents=True, exist_ok=True)

PAL = {
    "ink": (46, 34, 47),
    "ink2": (69, 41, 63),
    "white": (255, 246, 232),
    "cream": (246, 225, 196),
    "sand": (226, 196, 150),
    "wood": (186, 134, 88),
    "wood2": (138, 90, 58),
    "wood3": (94, 60, 44),
    "yellow": (255, 214, 102),
    "yellow2": (232, 168, 64),
    "orange": (240, 138, 78),
    "red": (214, 78, 72),
    "red2": (150, 48, 58),
    "pink": (246, 168, 170),
    "sky": (150, 206, 240),
    "sky2": (94, 150, 206),
    "blue": (60, 94, 160),
    "navy": (38, 46, 90),
    "navy2": (26, 30, 60),
    "lav": (196, 176, 240),
    "lav2": (140, 116, 200),
    "mint": (170, 226, 196),
    "green": (92, 150, 110),
    "green2": (54, 98, 78),
    "gray": (170, 160, 168),
    "gray2": (112, 104, 118),
    "gold": (255, 226, 120),
}


def rgba(name, a=255):
    return PAL[name] + (a,)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def outline(img, color="ink"):
    """不透明な画素の外側に 1px の輪郭を足す"""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] != 0:
                    dst[x, y] = rgba(color)
                    break
    return out


def ghost_mask(w=22, h=24, wave=3):
    """おばけの体：丸い頭と、波打つ裾"""
    m = new(32, 32)
    d = ImageDraw.Draw(m)
    ox, oy = (32 - w) // 2, 4
    d.ellipse([ox, oy, ox + w - 1, oy + w - 1], fill=(255, 255, 255, 255))
    d.rectangle([ox, oy + w // 2, ox + w - 1, oy + h - 4], fill=(255, 255, 255, 255))
    # 裾の波
    for i in range(w):
        x = ox + i
        dy = int(round(math.sin(i / w * math.pi * wave) * 1.6))
        d.line([x, oy + h - 4, x, oy + h - 2 + dy], fill=(255, 255, 255, 255))
    return m


def paint_body(mask, base, shade, light):
    img = new(32, 32)
    mp = mask.load()
    ip = img.load()
    xs = [x for x in range(32) for y in range(32) if mp[x, y][3]]
    ys = [y for x in range(32) for y in range(32) if mp[x, y][3]]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    for y in range(32):
        for x in range(32):
            if not mp[x, y][3]:
                continue
            # 右下ほど影、左上に光
            t = (x - cx) * 0.6 + (y - cy) * 0.8
            if t > 6:
                ip[x, y] = rgba(shade)
            elif t < -9 and (x + y) % 2 == 0:
                ip[x, y] = rgba(light)
            elif t < -11:
                ip[x, y] = rgba(light)
            else:
                ip[x, y] = rgba(base)
    return img


def face(img, eye="ink", blink=False, mood="smile", y0=13):
    d = ImageDraw.Draw(img)
    lx, rx = 12, 19
    if blink:
        d.line([lx - 1, y0 + 1, lx + 1, y0 + 1], fill=rgba(eye))
        d.line([rx - 1, y0 + 1, rx + 1, y0 + 1], fill=rgba(eye))
    else:
        d.rectangle([lx, y0, lx + 1, y0 + 2], fill=rgba(eye))
        d.rectangle([rx, y0, rx + 1, y0 + 2], fill=rgba(eye))
        d.point([lx, y0], fill=rgba("white"))
        d.point([rx, y0], fill=rgba("white"))
    d.point([lx - 2, y0 + 4], fill=rgba("pink"))
    d.point([lx - 1, y0 + 4], fill=rgba("pink"))
    d.point([rx + 2, y0 + 4], fill=rgba("pink"))
    d.point([rx + 3, y0 + 4], fill=rgba("pink"))
    if mood == "smile":
        d.line([15, y0 + 4, 16, y0 + 4], fill=rgba(eye))
        d.point([14, y0 + 3], fill=rgba(eye))
        d.point([17, y0 + 3], fill=rgba(eye))
    elif mood == "o":
        d.rectangle([15, y0 + 3, 16, y0 + 5], fill=rgba(eye))
    elif mood == "angry":
        d.line([lx - 1, y0 - 2, lx + 2, y0 - 1], fill=rgba(eye))
        d.line([rx - 1, y0 - 1, rx + 2, y0 - 2], fill=rgba(eye))
        d.line([14, y0 + 5, 17, y0 + 5], fill=rgba(eye))
    elif mood == "sleep":
        pass


def save(img, name, scale=1):
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(OUT / f"{name}.png")


# ---------- 野生のおばけ（網で捕まえる） ----------

def obake(name, base, shade, light, prop=None, eye="ink", mood="smile"):
    frames = []
    for blink in (False, True):
        body = paint_body(ghost_mask(), base, shade, light)
        if prop:
            prop(body)
        face(body, eye=eye, blink=blink, mood=mood)
        frames.append(outline(body))
    sheet = new(64, 32)
    sheet.paste(frames[0], (0, 0))
    sheet.paste(frames[1], (32, 0))
    save(sheet, f"obake_{name}")


def p_receipt(img):
    d = ImageDraw.Draw(img)
    d.polygon([(24, 22), (29, 27), (27, 29), (22, 24)], fill=rgba("white"))
    d.line([(24, 24), (26, 26)], fill=rgba("gray"))


def p_bubbles(img):
    d = ImageDraw.Draw(img)
    for (x, y, r) in ((10, 3, 2), (15, 1, 1), (20, 3, 3), (25, 7, 1)):
        d.ellipse([x - r, y - r, x + r, y + r], fill=rgba("white"), outline=rgba("sky2"))


def p_tray(img):
    d = ImageDraw.Draw(img)
    d.rectangle([13, 0, 14, 3], fill=rgba("sky"))
    d.rectangle([17, 1, 18, 3], fill=rgba("yellow2"))
    d.line([(7, 4), (24, 4)], fill=rgba("gray"))
    d.line([(8, 5), (23, 5)], fill=rgba("gray2"))


def p_pan(img):
    d = ImageDraw.Draw(img)
    d.ellipse([22, 15, 29, 20], fill=rgba("gray2"))
    d.ellipse([24, 16, 27, 18], fill=rgba("yellow"))
    d.line([(28, 15), (31, 12)], fill=rgba("wood2"))


def p_box(img):
    d = ImageDraw.Draw(img)
    d.rectangle([4, 20, 27, 29], fill=rgba("sand"))
    d.rectangle([4, 20, 27, 21], fill=rgba("wood"))
    d.line([(13, 23), (18, 23)], fill=rgba("wood2"))
    d.line([(4, 29), (27, 29)], fill=rgba("wood2"))


def p_lantern(img):
    d = ImageDraw.Draw(img)
    d.line([(26, 8), (26, 12)], fill=rgba("ink2"))
    d.rectangle([24, 12, 28, 18], fill=rgba("orange"))
    d.point([26, 14], fill=rgba("yellow"))
    d.point([26, 15], fill=rgba("yellow"))


def p_crown(img):
    d = ImageDraw.Draw(img)
    d.polygon([(10, 5), (12, 1), (14, 4), (16, 0), (18, 4), (20, 1), (22, 5)], fill=rgba("gold"))
    d.line([(10, 5), (22, 5)], fill=rgba("yellow2"))


def p_nightcap(img):
    d = ImageDraw.Draw(img)
    d.polygon([(8, 7), (16, 1), (25, 6), (27, 10), (23, 8)], fill=rgba("blue"))
    d.ellipse([26, 9, 28, 11], fill=rgba("white"))


# ---------- 困りごと（協力バトルの相手、48x48） ----------

def trouble(name, draw):
    img = new(48, 48)
    draw(img)
    save(outline(img), f"trouble_{name}")


def t_line(img):
    # 行列：小さい影のおばけが連なる
    d = ImageDraw.Draw(img)
    for i, x in enumerate((4, 16, 28)):
        y = 18 + (i % 2) * 2
        d.ellipse([x, y, x + 13, y + 13], fill=rgba("gray2"))
        d.rectangle([x, y + 7, x + 13, y + 20], fill=rgba("gray2"))
        d.rectangle([x + 3, y + 5, x + 4, y + 7], fill=rgba("white"))
        d.rectangle([x + 8, y + 5, x + 9, y + 7], fill=rgba("white"))
    d.rectangle([40, 8, 44, 20], fill=rgba("red"))
    d.text((40, 6), "", fill=rgba("white"))


def t_angry(img):
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(16):
        a = i / 16 * math.tau
        r = 20 if i % 2 == 0 else 15
        pts.append((24 + r * math.cos(a), 24 + r * math.sin(a)))
    d.polygon(pts, fill=rgba("red"))
    d.ellipse([12, 12, 36, 36], fill=rgba("orange"))
    d.line([(16, 18), (21, 21)], fill=rgba("ink"), width=2)
    d.line([(32, 18), (27, 21)], fill=rgba("ink"), width=2)
    d.rectangle([17, 22, 19, 25], fill=rgba("ink"))
    d.rectangle([29, 22, 31, 25], fill=rgba("ink"))
    d.line([(19, 31), (29, 31)], fill=rgba("ink"), width=2)


def t_empty(img):
    # 品切れ：からっぽの棚にとりついたおばけ
    d = ImageDraw.Draw(img)
    d.rectangle([6, 8, 41, 44], fill=rgba("wood2"))
    d.rectangle([9, 11, 38, 41], fill=rgba("navy2"))
    for y in (20, 31):
        d.rectangle([9, y, 38, y + 1], fill=rgba("wood"))
    d.ellipse([15, 13, 32, 30], fill=rgba("lav"))
    d.rectangle([15, 21, 32, 34], fill=rgba("lav"))
    d.rectangle([19, 19, 20, 21], fill=rgba("ink"))
    d.rectangle([27, 19, 28, 21], fill=rgba("ink"))
    d.rectangle([22, 25, 25, 26], fill=rgba("ink"))


# ---------- 網（16x16 のアイコン） ----------

def net(name, rim, mesh):
    img = new(16, 16)
    d = ImageDraw.Draw(img)
    d.line([(2, 14), (7, 9)], fill=rgba("wood2"), width=2)
    d.ellipse([6, 1, 14, 9], outline=rgba(rim))
    for i in range(7, 14, 2):
        d.line([(i, 2), (i, 8)], fill=rgba(mesh, 180))
    for j in range(3, 9, 2):
        d.line([(7, j), (13, j)], fill=rgba(mesh, 180))
    save(outline(img), f"net_{name}")


# ---------- 背景（180x320） ----------

def dither_rect(d, box, c1, c2):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d.point([x, y], fill=rgba(c1 if (x + y) % 2 else c2))


def bg_room():
    img = Image.new("RGBA", (180, 320), rgba("cream"))
    d = ImageDraw.Draw(img)
    # 壁と腰板
    d.rectangle([0, 0, 179, 200], fill=rgba("cream"))
    for x in range(0, 180, 12):
        d.line([(x, 0), (x, 200)], fill=rgba("sand"))
    d.rectangle([0, 170, 179, 200], fill=rgba("wood"))
    d.line([(0, 170), (179, 170)], fill=rgba("wood2"))
    # 窓（夜）
    d.rectangle([20, 30, 80, 90], fill=rgba("navy"))
    dither_rect(d, (21, 70, 79, 89), "navy", "navy2")
    d.ellipse([60, 38, 70, 48], fill=rgba("yellow"))
    d.ellipse([63, 37, 72, 46], fill=rgba("navy"))
    for (x, y) in ((28, 40), (40, 52), (50, 36), (34, 62), (72, 60)):
        d.point([x, y], fill=rgba("white"))
    d.rectangle([20, 30, 80, 90], outline=rgba("wood3"))
    d.line([(50, 30), (50, 90)], fill=rgba("wood3"))
    d.line([(20, 60), (80, 60)], fill=rgba("wood3"))
    # シフト表
    d.rectangle([100, 34, 150, 84], fill=rgba("white"), outline=rgba("wood3"))
    for y in range(42, 82, 8):
        d.line([(104, y), (146, y)], fill=rgba("sand"))
    for (x, y, c) in ((110, 44, "orange"), (124, 52, "sky2"), (134, 60, "green"), (116, 68, "lav2"), (140, 76, "orange")):
        d.rectangle([x, y, x + 6, y + 3], fill=rgba(c))
    d.rectangle([123, 31, 127, 35], fill=rgba("red"))
    # ロッカー
    d.rectangle([140, 110, 175, 200], fill=rgba("sky2"), outline=rgba("ink2"))
    d.line([(157, 110), (157, 200)], fill=rgba("ink2"))
    for x in (146, 163):
        d.rectangle([x, 120, x + 6, 122], fill=rgba("navy"))
        d.rectangle([x + 5, 150, x + 6, 158], fill=rgba("gray"))
    # 床
    d.rectangle([0, 201, 179, 319], fill=rgba("wood"))
    for y in range(206, 320, 14):
        d.line([(0, y), (179, y)], fill=rgba("wood2"))
        off = (y // 14) % 2 * 20
        for x in range(off, 180, 40):
            d.line([(x, y), (x, y + 13)], fill=rgba("wood2"))
    # テーブルとやかん
    d.rectangle([30, 214, 120, 222], fill=rgba("wood3"))
    d.rectangle([34, 222, 38, 250], fill=rgba("wood3"))
    d.rectangle([112, 222, 116, 250], fill=rgba("wood3"))
    d.ellipse([46, 202, 62, 216], fill=rgba("gray"), outline=rgba("ink2"))
    d.line([(62, 206), (68, 202)], fill=rgba("ink2"))
    d.rectangle([80, 206, 88, 214], fill=rgba("white"), outline=rgba("ink2"))
    d.rectangle([94, 208, 101, 214], fill=rgba("orange"), outline=rgba("ink2"))
    # 座布団
    d.rectangle([128, 250, 160, 262], fill=rgba("red2"))
    d.rectangle([128, 250, 160, 252], fill=rgba("red"))
    save(img, "bg_room")


def bg_catch():
    img = Image.new("RGBA", (180, 320), rgba("navy"))
    d = ImageDraw.Draw(img)
    # 夜空のグラデーション（ディザ）
    bands = [("navy2", 0, 60), ("navy", 60, 150), ("blue", 150, 210)]
    for c, y0, y1 in bands:
        d.rectangle([0, y0, 179, y1], fill=rgba(c))
    dither_rect(d, (0, 55, 179, 65), "navy2", "navy")
    dither_rect(d, (0, 145, 179, 155), "navy", "blue")
    for (x, y) in ((12, 14), (40, 30), (70, 10), (120, 24), (150, 40), (164, 12), (96, 46), (24, 70)):
        d.point([x, y], fill=rgba("white"))
    # 街の影
    for (x, w, h) in ((0, 30, 70), (28, 22, 50), (48, 34, 90), (80, 26, 60), (104, 40, 80), (142, 38, 66)):
        d.rectangle([x, 230 - h, x + w, 230], fill=rgba("navy2"))
        for wy in range(230 - h + 6, 226, 10):
            for wx in range(x + 4, x + w - 4, 8):
                if (wx * 7 + wy * 3) % 5 < 2:
                    d.rectangle([wx, wy, wx + 2, wy + 3], fill=rgba("yellow2"))
    # 帰り道
    d.rectangle([0, 231, 179, 319], fill=rgba("ink2"))
    dither_rect(d, (0, 231, 179, 236), "ink2", "navy2")
    for x in range(10, 180, 36):
        d.rectangle([x, 270, x + 16, 272], fill=rgba("gray2"))
    # 街灯
    d.rectangle([150, 150, 152, 300], fill=rgba("ink"))
    d.rectangle([140, 146, 158, 150], fill=rgba("ink"))
    d.ellipse([136, 150, 148, 158], fill=rgba("yellow"))
    save(img, "bg_catch")


def bg_battle():
    img = Image.new("RGBA", (180, 320), rgba("cream"))
    d = ImageDraw.Draw(img)
    # 店のカウンター越し
    d.rectangle([0, 0, 179, 150], fill=rgba("sand"))
    for x in range(0, 180, 20):
        d.rectangle([x, 20, x + 16, 60], fill=rgba("white"), outline=rgba("wood2"))
        d.rectangle([x + 3, 26, x + 13, 30], fill=rgba("orange"))
        d.rectangle([x + 3, 34, x + 10, 36], fill=rgba("wood2"))
    d.rectangle([0, 70, 179, 76], fill=rgba("red"))
    d.rectangle([0, 150, 179, 170], fill=rgba("wood2"))
    d.rectangle([0, 150, 179, 153], fill=rgba("wood"))
    d.rectangle([0, 171, 179, 319], fill=rgba("cream"))
    for y in range(180, 320, 16):
        for x in range((y // 16) % 2 * 16, 180, 32):
            d.rectangle([x, y, x + 15, y + 15], fill=rgba("sand"))
    save(img, "bg_battle")


def ui_panel():
    img = new(24, 24)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 23, 23], fill=rgba("white"), outline=rgba("ink"))
    d.rectangle([1, 20, 22, 22], fill=rgba("cream"))
    d.point([0, 0], fill=(0, 0, 0, 0))
    d.point([23, 0], fill=(0, 0, 0, 0))
    d.point([0, 23], fill=(0, 0, 0, 0))
    d.point([23, 23], fill=(0, 0, 0, 0))
    save(img, "ui_panel")


def main():
    obake("receipt", "yellow", "yellow2", "white", p_receipt)
    obake("bubble", "sky", "sky2", "white", p_bubbles)
    obake("tray", "lav", "lav2", "white", p_tray)
    obake("pan", "orange", "red2", "yellow", p_pan)
    obake("box", "cream", "sand", "white", p_box)
    obake("lantern", "navy", "navy2", "blue", p_lantern, eye="white")
    obake("kirari", "gold", "yellow2", "white", p_crown)
    obake("nemuri", "lav", "lav2", "white", p_nightcap, mood="sleep")
    trouble("line", t_line)
    trouble("angry", t_angry)
    trouble("empty", t_empty)
    net("receipt", "white", "gray")
    net("bubble", "sky", "white")
    net("tray", "gray", "lav")
    net("pan", "orange", "yellow")
    net("box", "sand", "wood")
    net("kira", "gold", "yellow")
    bg_room()
    bg_catch()
    bg_battle()
    ui_panel()
    print("wrote", len(list(OUT.glob("*.png"))), "sprites to", OUT)


if __name__ == "__main__":
    main()
