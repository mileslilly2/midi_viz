#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$BASE_DIR"
if [[ ! -f "data/everyday.wav" ]]; then
  echo "WARNING: data/everyday.wav not found. Using silent video (no audio)."
  ffmpeg -y -framerate 60 -i frames/frame-%05d.png -c:v libx264 -pix_fmt yuv420p output.mp4
else
  ffmpeg -y -framerate 60 -i frames/frame-%05d.png \
    -i data/everyday.wav \
    -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
    output.mp4
fi
