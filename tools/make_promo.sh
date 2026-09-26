#!/bin/zsh
# 広告動画をつくる：自動デモを Movie Maker で録って、字幕とタイトルを重ねる。
# ./tools/make_promo.sh  → promo/promo.mp4（720x1280, 30fps, H.264）
set -e
cd "$(dirname "$0")/.."
mkdir -p promo
FF=/opt/homebrew/bin/ffmpeg
if [[ "$1" != "--no-record" ]]; then
  OBAKE_DEMO=promo godot --path . --resolution 720x1280 --write-movie promo/raw.avi --fixed-fps 30 --quit-after 1320 >/dev/null 2>&1 || true
fi
# 字幕とタイトルはゲームの中で描く（scripts/demo.gd）。ここでは書き出すだけ
$FF -loglevel error -y -i promo/raw.avi -t 43.3 -vf "scale=720:1280" -af "loudnorm=I=-16:TP=-1.5:LRA=11" -ar 44100 -r 30 -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -c:a aac -b:a 160k -movflags +faststart promo/promo.mp4
echo "wrote promo/promo.mp4"
