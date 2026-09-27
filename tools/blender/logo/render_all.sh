#!/bin/zsh
# Re-render every Paw Time logo deliverable into assets/title/logo3d/.
#   tools/blender/logo/render_all.sh [variant]   (default: the chosen main variant)
# Takes ~30-40 min on an M5 (the SDF bodies are CPU work; Cycles runs on Metal).
set -e
HERE=${0:A:h}; REPO=${HERE:h:h:h}
V=${1:-D}
OUT=$REPO/assets/title/logo3d
mkdir -p $OUT
run() { blender --background --factory-startup --python $HERE/paw_logo.py -- --variant $V "$@" | grep WROTE; }

run --mode main   --width 2400 --samples 256 --out $OUT/logo_main.png
run --mode shadow --width 2400 --samples 128 --out $OUT/logo_shadow.png
run --mode ja     --width 2400 --samples 256 --out $OUT/logo_ja.png
run --mode turntable --width 1200 --samples 128 --out "$OUT/logo_turntable_{}.png"
python3 $HERE/post.py glow $OUT/logo_main.png $OUT
python3 $HERE/post.py shadow $OUT/logo_shadow.png
