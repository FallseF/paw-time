#!/bin/zsh
# Exploration renders for the variant sheet: ./render_variants.sh <out_dir>
set -e
HERE=${0:A:h}; REPO=${HERE:h:h:h}; OUT=${1:?out dir}
mkdir -p $OUT
for v in A B C D; do
  blender --background --factory-startup --python $HERE/paw_logo.py -- \
    --variant $v --width 1200 --samples 64 --out $OUT/variant_$v.png | grep WROTE
done
python3 $HERE/post.py sheet $OUT/variants_sheet.png $OUT/variant_{A,B,C,D}.png
