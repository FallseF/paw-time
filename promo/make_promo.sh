#!/bin/zsh
# 宣伝動画：自動操作で撮って、字幕をのせて promo/promo.mp4 にする
set -e
cd "$(dirname "$0")/.."
FF=/opt/homebrew/bin/ffmpeg
FONT=assets/fonts/ZenMaruGothic-Black.ttf
if [ -z "$SKIP_REC" ]; then
  rm -f promo/raw.avi
  # 撮影中だけ、ウィンドウを 720x1280 に（override.cfg は撮り終えたら消す）
  printf '[display]\n\nwindow/size/window_width_override=720\nwindow/size/window_height_override=1280\n' > override.cfg
  trap 'rm -f override.cfg' EXIT
  OBAKE_NOSAVE=1 OBAKE_WINDOW=720x1280 OBAKE_DEMO=promo godot --path . --resolution 720x1280 --write-movie promo/raw.avi --fixed-fps 30 --quit-after 2400 | grep "\[promo\]" || true
  rm -f override.cfg
fi
python3 promo/captions.py
# (字幕, 開始, 終了, 高さ割合)
CAPS=(
  "hook 0.1 2.6 0.30"
  "scoop 2.7 4.4 0.36"
  "sleep 4.6 8.8 0.36"
  "dream 9.0 14.3 0.36"
  "hatch 14.6 18.9 0.36"
  "garden 19.1 25.0 0.13"
  "moon 25.2 30.7 0.50"
  "deco 30.9 34.7 0.08"
  "zukan 34.9 39.2 0.60"
  "tag1 39.4 45 0.54"
  "tag2 40.2 45 0.61"
)
IN=(-i promo/raw.avi)
G="[0:v]fade=t=in:st=0:d=0.3[v0]"
k=0
for c in $CAPS; do
  parts=(${=c})
  IN+=(-i promo/caps/${parts[1]}.png)
  k=$((k+1))
  G="$G;[v$((k-1))][$k:v]overlay=x=(W-w)/2:y=H*${parts[4]}:enable='between(t,${parts[2]},${parts[3]})'[v$k]"
done
G="$G;[v$k]fade=t=out:st=41.6:d=0.8[vout]"
$FF -y -v error $IN -filter_complex "$G" -map "[vout]" -map 0:a -af "volume=1.6,afade=t=out:st=41.4:d=1.0" -c:v libx264 -pix_fmt yuv420p -r 30 -crf 20 -preset medium -c:a aac -b:a 160k -shortest promo/promo.mp4
echo "wrote promo/promo.mp4"
