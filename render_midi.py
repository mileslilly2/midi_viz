import argparse
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
DATA = BASE / "data"
FRAMES = BASE / "frames"

def run(cmd, **kwargs):
    print("\n[RUN]", " ".join(str(c) for c in cmd))
    subprocess.run(cmd, check=True, **kwargs)

def main():
    parser = argparse.ArgumentParser(description="End-to-end MIDI → visualizer video pipeline.")
    parser.add_argument("--midi", required=True, help="Path to input MIDI file.")
    parser.add_argument("--soundfont", required=True, help="Path to SoundFont (.sf2).")
    parser.add_argument("--output", default=str(BASE / "output.mp4"), help="Output MP4 path.")
    parser.add_argument("--fps", type=int, default=60, help="Frame rate for video.")
    args = parser.parse_args()

    midi_path = Path(args.midi).resolve()
    sf2_path = Path(args.soundfont).resolve()
    out_video = Path(args.output).resolve()

    if not midi_path.exists():
        raise SystemExit(f"MIDI file not found: {midi_path}")
    if not sf2_path.exists():
        raise SystemExit(f"SoundFont not found: {sf2_path}")

    DATA.mkdir(parents=True, exist_ok=True)
    FRAMES.mkdir(parents=True, exist_ok=True)

    midi_copy = DATA / "everyday.mid"
    wav_path = DATA / "everyday.wav"
    json_path = DATA / "everyday_fixed.json"

    if midi_copy != midi_path:
        midi_copy.write_bytes(midi_path.read_bytes())
        print(f"Copied MIDI to {midi_copy}")
    else:
        print(f"Using existing {midi_copy}")

    # 1) MIDI+SF2 → WAV via fluidsynth
    run([
        "fluidsynth",
        "-ni",
        str(sf2_path),
        str(midi_copy),
        "-F",
        str(wav_path),
        "-r",
        "44100",
    ])

    # 2) WAV+MIDI → JSON via fix_midi.py
    run([
        sys.executable,
        str(BASE / "midi_pipeline" / "fix_midi.py"),
        "--midi", str(midi_copy),
        "--wav", str(wav_path),
        "--out", str(json_path),
    ])

    # 3) Build Java (idempotent)
    run(["bash", str(BASE / "scripts" / "build.sh")])

    # 4) Java renderer → frames
    run([
        "java",
        "-cp",
        f"{BASE / 'lib' / 'core.jar'}:{BASE / 'out'}",
        "FallingNotesRenderer",
        str(json_path),
    ])

    # 5) FFmpeg → MP4
    ffmpeg_cmd = [
        "ffmpeg",
        "-y",
        "-framerate",
        str(args.fps),
        "-i",
        str(FRAMES / "frame-%05d.png"),
        "-i",
        str(wav_path),
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-shortest",
        str(out_video),
    ]
    run(ffmpeg_cmd)

    print(f"Done! Video at: {out_video}")

if __name__ == "__main__":
    main()
