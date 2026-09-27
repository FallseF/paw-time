"""Trim the rendered variant-A logo layers for the title: python3 crop_a.py <render_dir> <out_dir> (see render_all.sh)."""
# crop the variant-A logo layers to the letters (+ room for shadow/glow), same relative box for every layer
import sys, os, glob
sys.path.insert(0, "/Users/eiyuto/dev/paw-bgm/apps/worker/tools/blender/logo")
from PIL import Image
from post import edge_fade
BOX = (60/1600, 70/628, 1540/1600, 610/628)
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for f in sorted(glob.glob(os.path.join(src, "logo_*.png"))):
    n = os.path.basename(f)
    if n in ("logo_main_glow.png",): continue # the title uses the glow on its own
    im = Image.open(f).convert("RGBA"); w, h = im.size
    c = im.crop((round(BOX[0]*w), round(BOX[1]*h), round(BOX[2]*w), round(BOX[3]*h)))
    if n in ("logo_glow.png", "logo_shadow.png"):
        # glow / shadow: fade to 0 at the new edges so they never end in a hard line
        c.putalpha(edge_fade(c.getchannel("A"), 0.08))
    target_w = 1200 if "turntable" not in n else 720
    if c.width > target_w:
        c = c.resize((target_w, round(c.height * target_w / c.width)), Image.LANCZOS)
    c.save(os.path.join(dst, n), optimize=True)
    print(n, c.size, os.path.getsize(os.path.join(dst, n)))
