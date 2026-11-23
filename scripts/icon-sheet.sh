#!/bin/sh
# Renders the four menu bar icons on a dark and a light strip into one PNG: icon-sheet.sh <output.png>
# Order, left to right: idle, recording, recording but silent, converting.
set -eu
output=$1
work=$(mktemp -d)
"$(dirname "$0")/../.build/debug/JamTap" --render-icons "$work"
inputs=""; filters=""; labels_dark=""; labels_light=""; index=0
for theme in dark light; do
  for kind in idle recording recordingSilent converting; do
    inputs="$inputs -i $work/icon-$kind-$theme.png"
    [ "$theme" = dark ] && colour=0x1f1f1f || colour=0xededed
    filters="$filters[$index]pad=344:240:0:0:color=$colour[p$index];"
    [ "$theme" = dark ] && labels_dark="$labels_dark[p$index]" || labels_light="$labels_light[p$index]"
    index=$((index + 1))
  done
done
ffmpeg -hide_banner -loglevel error -y $inputs -filter_complex \
  "$filters${labels_dark}hstack=4[top];${labels_light}hstack=4[bottom];[top][bottom]vstack" "$output"
rm -r "$work"
