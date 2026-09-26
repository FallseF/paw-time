#!/bin/bash
# はじめての人の流れを撮る：タイトル → 1-1 → 最初のすくい → 寝る → 孵化 → 地図
# 使い方: bash tools/ui_flow.sh ui_review/after
set -e
cd "$(dirname "$0")/.."
OUT=${1:-ui_review/after}
mkdir -p $OUT
S=user://obake_c_uiflow.json
shot() { # 名前 手順
  OBAKE_SAVE=$S OBAKE_SHOT="$2" OBAKE_SHOT_PATH=/tmp/uiflow_$1.png godot --path . --resolution 360x640 --quit-after 200000 >/dev/null 2>&1 || true
  [ -f /tmp/uiflow_$1.png ] && cp /tmp/uiflow_$1.png $OUT/$1.png
  for f in /tmp/uiflow_$1_*.png; do [ -f "$f" ] && cp "$f" $OUT/$(basename "$f" | sed 's/uiflow_//'); done
  rm -f /tmp/uiflow_$1*.png
}
rm -f "$HOME/Library/Application Support/Godot/app_userdata/おばけの休憩室/obake_c_uiflow.json"
# 1 タイトル、休憩室、地図の出撃シート、1-1 のはじめ・途中
OBAKE_FRESH=1 OBAKE_SAVE=$S OBAKE_SHOT="wait1.5,snap,title,wait0.5,morning,wait1.5,snap,map,wait1.5,snap,defense,wait2.5,snap,wait5,snap,call:demo_rush,wait42,snap" OBAKE_SHOT_PATH=/tmp/uiflow_a.png godot --path . --resolution 360x640 --quit-after 200000 >/dev/null 2>&1 || true
i=0; for n in 01_title 02_room 03_map 04_battle_start 05_battle_mid 06_result; do [ -f /tmp/uiflow_a_$i.png ] && cp /tmp/uiflow_a_$i.png $OUT/$n.png; i=$((i+1)); done
rm -f /tmp/uiflow_a*.png
# 2 そのセーブで、すくい → 寝る → 孵化 → 休憩室 → 地図
OBAKE_SAVE=$S OBAKE_SHOT="catch,wait1.5,snap,call:demo_hold,wait1,call:demo_lift,wait3,sleep,wait1,snap,call:_sleep,wait4,call:demo_open,wait4,snap,morning,wait1.5,snap,map,wait1.5,snap" OBAKE_SHOT_PATH=/tmp/uiflow_b.png godot --path . --resolution 360x640 --quit-after 200000 >/dev/null 2>&1 || true
i=0; for n in 07_scoop 08_sleep 09_hatch 10_room_day2 11_map_day2; do [ -f /tmp/uiflow_b_$i.png ] && cp /tmp/uiflow_b_$i.png $OUT/$n.png; i=$((i+1)); done
rm -f /tmp/uiflow_b*.png
rm -f "$HOME/Library/Application Support/Godot/app_userdata/おばけの休憩室/obake_c_uiflow.json"
python3 - "$OUT" <<'PY'
import sys, glob
from PIL import Image
out = sys.argv[1]
fs = sorted(glob.glob(out + "/[0-9]*.png"))
if fs:
    s = Image.new("RGB", (6 * 245, ((len(fs) + 5) // 6) * 430), (40, 40, 40))
    for i, f in enumerate(fs):
        im = Image.open(f).convert("RGB").resize((240, 427))
        s.paste(im, ((i % 6) * 245, (i // 6) * 430))
    s.save(out + "/_sheet.png")
PY
echo "wrote $OUT"
