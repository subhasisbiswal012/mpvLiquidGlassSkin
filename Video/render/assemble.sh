#!/usr/bin/env bash
# Assemble all video pieces. Run from Video/render/.
set -e
cd "$(dirname "$0")"
DEMO="../Demo.mp4"
OUT="out"
VENC="-c:v libx264 -pix_fmt yuv420p -r 30 -crf 18 -preset medium"
AENC="-c:a aac -b:a 192k -ar 48000 -ac 2"

echo "[1/6] placeholder PNGs"
node make_placeholders.js

echo "[2/6] hook.mp4  (Demo.mp4 + title overlay + VO)"
ffmpeg -y -loglevel error -i "$DEMO" -loop 1 -i "$OUT/hook_overlay.png" -i audio/voice_HOOK.wav \
  -filter_complex "[0:v]scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080,setsar=1,fps=30[bg];\
[1:v]format=rgba,fade=in:st=0:d=0.8:alpha=1[ov];[bg][ov]overlay=0:0[v]" \
  -map "[v]" -map 2:a -shortest $VENC $AENC "$OUT/hook.mp4"

echo "[3/6] segment_why.mp4  (slides 1-7)"
ffmpeg -y -loglevel error -i "$OUT/part_A.webm" -i audio/voice_A.wav \
  -map 0:v:0 -map 1:a:0 -shortest $VENC $AENC "$OUT/segment_why.mp4"

echo "[4/6] segment_features_outro.mp4  (slides 8-11)"
ffmpeg -y -loglevel error -i "$OUT/part_B.webm" -i audio/voice_B.wav \
  -map 0:v:0 -map 1:a:0 -shortest $VENC $AENC "$OUT/segment_features_outro.mp4"

echo "[5/6] placeholder clips (4s each, silent)"
for name in mpv skin; do
  ffmpeg -y -loglevel error -loop 1 -i "$OUT/ph_${name}.png" -f lavfi -i anullsrc=r=48000:cl=stereo \
    -t 4 $VENC $AENC -shortest "$OUT/placeholder_${name}.mp4"
done

echo "[6/6] preview_full.mp4  (hook -> why -> [install gaps] -> features/outro)"
printf "file '%s'\n" hook.mp4 segment_why.mp4 placeholder_mpv.mp4 placeholder_skin.mp4 segment_features_outro.mp4 > "$OUT/concat.txt"
ffmpeg -y -loglevel error -f concat -safe 0 -i "$OUT/concat.txt" -c copy "$OUT/preview_full.mp4" \
  || ffmpeg -y -loglevel error -f concat -safe 0 -i "$OUT/concat.txt" $VENC $AENC "$OUT/preview_full.mp4"

echo "=== done ==="
for f in hook segment_why placeholder_mpv placeholder_skin segment_features_outro preview_full; do
  d=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT/$f.mp4")
  printf "  %-26s %6.1fs\n" "$f.mp4" "$d"
done
