# MIDI Visualizer (Python + Java Processing)

End-to-end pipeline to turn a MIDI file into a falling-notes piano visualizer video:

1. **Python**: MIDI + SoundFont → WAV + JSON (timed notes)
2. **Java + Processing core.jar**: render PNG frames
3. **FFmpeg**: stitch PNG + WAV → MP4

Designed for **Lubuntu** with a graphical desktop.

## Quick Start

### 1. System dependencies

```bash
sudo apt update
sudo apt install -y default-jdk python3 python3-venv ffmpeg fluidsynth wget tar
```

### 2. Create virtualenv + install Python deps

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r midi_pipeline/requirements.txt
```

### 3. Download Processing core.jar

Use the installer script:

```bash
chmod +x install_midi_visualizer.sh
./install_midi_visualizer.sh
```

This will download Processing, extract `lib/core.jar`, build Java classes, and run a quick check.

### 4. Render a MIDI file in one command

From repo root:

```bash
source .venv/bin/activate
python render_midi.py \
  --midi /path/to/your.mid \
  --soundfont /path/to/your.sf2 \
  --output output.mp4
```

This will:

- Copy/render assets into `data/`
- Run FluidSynth → WAV
- Run `fix_midi.py` → JSON with scaled note timings
- Run Java/Processing renderer → PNG frames in `frames/`
- Run FFmpeg → MP4 video with audio

Default output is `output.mp4` in repo root.
