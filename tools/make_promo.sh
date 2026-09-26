#!/bin/bash
# 宣伝動画（縦 720x1280・約36秒）を作る。各場面を Movie Maker で録って、字幕をのせてつなぐ。
# 使い方: bash tools/make_promo.sh
set -e
cd "$(dirname "$0")/.."
OUT=promo
TMP=promo/tmp
mkdir -p $TMP
FONT=assets/fonts/ZenMaruGothic-Black.ttf
FF=/opt/homebrew/bin/ffmpeg

rec() { # 場面 秒
  local scene=$1 sec=$2
  local frames=$((sec * 30 + 15))
  OBAKE_DEMO=$scene godot --path . --resolution 720x1280 --write-movie $TMP/$scene.avi --fixed-fps 30 --quit-after $frames >/dev/null 2>&1 || true
}

if [ "$1" != "--no-rec" ]; then
rec rush 7
rec boss 15
rec room 4
rec scoop 6
rec hatch 6
rec crew 5
fi

python3 tools/promo_cards.py

# 字幕の PNG を重ねる。$1=場面 $2=切り出し開始秒 $3=長さ
cap() {
  local scene=$1 ss=$2 dur=$3
  $FF -y -loglevel error -ss $ss -t $dur -i $TMP/$scene.avi -i $TMP/cap_$scene.png \
    -filter_complex "[0:v]scale=720:1280[v];[v][1:v]overlay=0:0,fade=t=in:st=0:d=0.15[o]" -map "[o]" -map 0:a? \
    -af "apad" -t $dur -r 30 -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 $TMP/c_$scene.mp4
}

cap rush 0.5 6
cap boss 0.4 13.5
cap room 0.3 3.5
cap scoop 0.3 5.5
cap hatch 0.3 5.5
cap crew 0.3 4.5

# しめのカード
$FF -y -loglevel error -loop 1 -framerate 30 -t 4.5 -i $TMP/end.png -f lavfi -t 4.5 -i "anullsrc=r=44100:cl=stereo" \
  -vf "fade=t=in:st=0:d=0.3" -c:v libx264 -pix_fmt yuv420p -c:a aac -ar 44100 -ac 2 -shortest $TMP/c_end.mp4

printf "file 'c_%s.mp4'\n" rush boss room scoop hatch crew end > $TMP/list.txt
$FF -y -loglevel error -f concat -safe 0 -i $TMP/list.txt -c:v libx264 -pix_fmt yuv420p -r 30 -c:a aac -b:a 160k $OUT/promo.mp4
echo "wrote $OUT/promo.mp4"
