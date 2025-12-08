#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$BASE_DIR/lib/core.jar" ]]; then
  echo "ERROR: lib/core.jar not found. Run ./install_midi_visualizer.sh first."
  exit 1
fi

mkdir -p "$BASE_DIR/frames"

JSON_PATH="$BASE_DIR/data/everyday_fixed.json"

if [[ ! -f "$JSON_PATH" ]]; then
  echo "WARNING: $JSON_PATH not found. Did you run fix_midi.py?"
  exit 1
fi

java -cp "$BASE_DIR/lib/core.jar:$BASE_DIR/out" FallingNotesRenderer "$JSON_PATH"
