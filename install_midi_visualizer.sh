#!/bin/bash
set -e

echo "========================================="
echo "  MIDI VISUALIZER INSTALLER (LUBUNTU)"
echo "========================================="

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$BASE_DIR/lib"
PROC_TGZ="$BASE_DIR/processing.tgz"

echo ""
echo "Step 1: Installing required packages..."
sudo apt update
sudo apt install -y default-jdk ffmpeg fluidsynth wget tar

echo ""
echo "Java installed:"
java -version || true

mkdir -p "$LIB_DIR"
mkdir -p "$BASE_DIR/out"
mkdir -p "$BASE_DIR/frames"
mkdir -p "$BASE_DIR/data"

echo ""
echo "Step 2: Downloading Processing 4.3 (official build)..."
wget -O "$PROC_TGZ" https://download.processing.org/processing-4.3-linux-x64.tgz

echo ""
echo "Step 3: Extracting core.jar..."
tar -xvf "$PROC_TGZ" -C "$BASE_DIR"

PROCESSING_DIR=$(find "$BASE_DIR" -maxdepth 1 -type d -name "processing-4*" | head -n 1)

if [[ -z "$PROCESSING_DIR" ]]; then
    echo "ERROR: Could not extract Processing. Aborting."
    exit 1
fi

cp "$PROCESSING_DIR/core/library/core.jar" "$LIB_DIR/core.jar"

echo ""
echo "core.jar saved to: $LIB_DIR/core.jar"
echo "Cleaning up Processing tarball..."
rm -rf "$PROC_TGZ" "$PROCESSING_DIR"

echo ""
echo "Step 4: Building Java renderer..."
bash "$BASE_DIR/scripts/build.sh"

echo ""
echo "Step 5: Running a test render check (if JSON exists)..."
if [[ -f "$BASE_DIR/data/everyday_fixed.json" ]]; then
    echo "Test JSON found. Running renderer..."
    java -cp "$LIB_DIR/core.jar:$BASE_DIR/out" FallingNotesRenderer "$BASE_DIR/data/everyday_fixed.json" || true
    echo "Renderer test complete."
else
    echo "No JSON found at data/everyday_fixed.json; skipping test."
fi

echo ""
echo "========================================="
echo "   INSTALL COMPLETE"
echo "You can now run:"
echo "   python render_midi.py --midi your.mid --soundfont your.sf2"
echo "========================================="
