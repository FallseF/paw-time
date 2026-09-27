#!/bin/zsh
# Re-render the title logo (variant A, one line) into assets/title/logo3d/.
#   tools/blender/logo/render_all.sh [variant]   (default A, the chosen title logo)
# ~35 min on an M5 (the SDF bodies are CPU work). Renders into a temp dir, then crop_a.py trims
# the canvas to the letters (+ shadow/glow room) and writes the shipped PNGs (main, glow, shadow, 12 turntable frames).
set -e
HERE=${0:A:h}; REPO=${HERE:h:h:h}
V=${1:-A}
OUT=$REPO/assets/title/logo3d
TMP=$(mktemp -d)
mkdir -p $OUT
run() { blender --background --factory-startup --python $HERE/paw_logo.py -- --variant $V "$@" | grep WROTE; }

run --mode main   --width 1600 --samples 256 --out $TMP/logo_main.png
run --mode shadow --width 1600 --samples 128 --out $TMP/logo_shadow.png
run --mode turntable --width 900 --samples 128 --out "$TMP/logo_turntable_{}.png"
python3 $HERE/post.py glow $TMP/logo_main.png $TMP
python3 $HERE/post.py shadow $TMP/logo_shadow.png
python3 $HERE/crop_a.py $TMP $OUT
