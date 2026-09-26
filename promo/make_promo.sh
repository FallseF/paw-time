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
  OBAKE_NOSAVE=1 OBAKE_WINDOW=720x1280 OBAKE_DEMO=promo godot --path . --resolution 720x1280 --write-movie promo/raw.avi --fixed-fps 30 --quit-after 2400 | grep "\[promo\]" > promo/marks.txt || true
  rm -f override.cfg
fi
python3 promo/captions.py
# 区切り（demo.gd の _mark が出すフレーム番号）から、字幕の時刻を決める
MARKS=$(grep -o '\[promo\] [0-9]) frame=[0-9]*' promo/marks.txt | sed -E 's/.*\] ([0-9])\) frame=([0-9]+)/\1 \2/')
t() { echo "$MARKS" | awk -v k=$1 -v off=${2:-0} '$1==k{printf "%.2f", $2/30+off}'; }
END=$(python3 -c "import subprocess;print(float(subprocess.check_output(['/opt/homebrew/bin/ffprobe','-v','error','-show_entries','format=duration','-of','csv=p=0','promo/raw.avi']).decode().strip()))")
# (字幕, 開始, 終了, 高さ割合)
CAPS=(
  "hook $(t 0 0.1) $(t 1 -0.1) 0.40"
  "scoop $(t 1 0.3) $(t 2 -0.1) 0.78"
  "sleep $(t 2 0.2) $(t 3 -0.1) 0.36"
  "dream $(t 3 0.2) $(t 4 -0.1) 0.72"
  "hatch $(t 4 0.2) $(t 5 -0.1) 0.36"
  "garden $(t 5 0.2) $(t 6 -0.1) 0.13"
  "moon $(t 6 0.2) $(t 7 -0.1) 0.80"
  "deco $(t 7 0.2) $(t 8 -0.1) 0.08"
  "zukan $(t 8 0.2) $(t 9 -0.1) 0.60"
  "tag1 $(t 9 0.2) $END 0.54"
  "tag2 $(t 9 1.0) $END 0.61"
)
FADE=$(python3 -c "print($END-0.8)")
IN=(-i promo/raw.avi)
G="[0:v]fade=t=in:st=0:d=0.3[v0]"
k=0
for c in $CAPS; do
  parts=(${=c})
  IN+=(-i promo/caps/${parts[1]}.png)
  k=$((k+1))
  G="$G;[v$((k-1))][$k:v]overlay=x=(W-w)/2:y=H*${parts[4]}:enable='between(t,${parts[2]},${parts[3]})'[v$k]"
done
G="$G;[v$k]fade=t=out:st=$FADE:d=0.8[vout]"
$FF -y -v error $IN -filter_complex "$G" -map "[vout]" -map 0:a -af "volume=1.3,afade=t=out:st=$FADE:d=0.8" -c:v libx264 -pix_fmt yuv420p -r 30 -crf 20 -preset medium -c:a aac -b:a 160k -shortest promo/promo.mp4
echo "wrote promo/promo.mp4"
