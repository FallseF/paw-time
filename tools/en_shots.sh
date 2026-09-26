#!/bin/bash
# すべての画面を英語で撮る：bash tools/en_shots.sh ui_review/en
cd "$(dirname "$0")/.."
OUT=${1:-ui_review/en}
mkdir -p $OUT
S=user://obake_c_en.json
run() { OBAKE_SAVE=$S OBAKE_FRESH=1 OBAKE_SETUP=${3:-rich} OBAKE_START=$2 OBAKE_SHOT="$4" OBAKE_SHOT_PATH=$OUT/$1.png godot --path . --resolution 360x640 --quit-after 60000 >/dev/null 2>&1; }
run 01_title title "" wait2
run 02_room room rich wait2
run 03_map map rich wait1.5,call:demo_open_next,wait1.5
run 04_shift defense rich wait18
run 05_crew crew rich wait3
run 06_zukan zukan rich wait2
run 07_scoop catch rich wait2
run 08_sleep sleep rich wait1.5
OBAKE_SAVE=$S OBAKE_FRESH=1 OBAKE_START=hatch OBAKE_RARE=nemurin OBAKE_SHOT="wait1,call:demo_open,wait4" OBAKE_SHOT_PATH=$OUT/09_hatch.png godot --path . --resolution 360x640 --quit-after 60000 >/dev/null 2>&1
OBAKE_SAVE=$S OBAKE_FRESH=1 OBAKE_START=quiz OBAKE_QUIZ_AUTO=ABBABBAAABBA OBAKE_SHOT="wait6" OBAKE_SHOT_PATH=$OUT/10_quiz.png godot --path . --resolution 360x640 --quit-after 60000 >/dev/null 2>&1
OBAKE_SAVE=$S OBAKE_FRESH=1 OBAKE_SETUP=rich OBAKE_AUTO=1 OBAKE_SPEED=6 OBAKE_START=defense OBAKE_STAGE=0-0 OBAKE_SHOT="wait20" OBAKE_SHOT_PATH=$OUT/11_result.png godot --path . --resolution 360x640 --quit-after 60000 >/dev/null 2>&1
python3 - "$OUT" <<'PY'
import sys, glob
from PIL import Image
out = sys.argv[1]
fs = sorted(glob.glob(out + "/[0-9]*.png"))
s = Image.new("RGB", (6 * 245, ((len(fs) + 5) // 6) * 430), (40, 40, 40))
for i, f in enumerate(fs):
    s.paste(Image.open(f).convert("RGB").resize((240, 427)), ((i % 6) * 245, (i // 6) * 430))
s.save(out + "/_sheet.png")
PY
