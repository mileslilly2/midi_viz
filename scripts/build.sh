#!/bin/bash
set -e
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$BASE_DIR/lib/core.jar" ]]; then
  echo "ERROR: lib/core.jar not found. Run ./install_midi_visualizer.sh first."
  exit 1
fi

mkdir -p "$BASE_DIR/out" "$BASE_DIR/frames"

javac -cp "$BASE_DIR/lib/core.jar" -d "$BASE_DIR/out" "$BASE_DIR"/src/*.java

echo "Build complete. Classes in out/"
