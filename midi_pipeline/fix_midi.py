import mido
import wave
import json
from pathlib import Path
import argparse

BASE = Path(__file__).resolve().parents[1]
DATA = BASE / "data"

def main():
    parser = argparse.ArgumentParser(description="Convert MIDI note events into scaled JSON using WAV duration.")
    parser.add_argument("--midi", type=str, default=str(DATA / "everyday.mid"),
                        help="Path to MIDI file (default: data/everyday.mid)")
    parser.add_argument("--wav", type=str, default=str(DATA / "everyday.wav"),
                        help="Path to rendered WAV file (default: data/everyday.wav)")
    parser.add_argument("--out", type=str, default=str(DATA / "everyday_fixed.json"),
                        help="Output JSON path (default: data/everyday_fixed.json)")
    args = parser.parse_args()

    midi_path = Path(args.midi)
    wav_path = Path(args.wav)
    out_path = Path(args.out)

    if not midi_path.exists():
        raise SystemExit(f"MIDI not found: {midi_path}")

    if not wav_path.exists():
        raise SystemExit(f"WAV not found: {wav_path}. Render it with fluidsynth first.")

    print(f"Reading WAV: {wav_path}")
    with wave.open(str(wav_path), "rb") as w:
        frames = w.getnframes()
        rate = w.getframerate()
        true_duration = frames / float(rate)

    print("True WAV duration (sec):", true_duration)

    print(f"Reading MIDI: {midi_path}")
    mid = mido.MidiFile(str(midi_path))

    notes_raw = []
    current_time = 0.0
    active = {}  # pitch -> {start, velocity}

    for msg in mid:
        current_time += msg.time
        if msg.type == "note_on" and msg.velocity > 0:
            active[msg.note] = {"start": current_time, "velocity": msg.velocity}
        elif msg.type in ("note_off", "note_on") and msg.velocity == 0:
            if msg.note in active:
                n = active.pop(msg.note)
                n["end"] = current_time
                n["pitch"] = msg.note
                notes_raw.append(n)

    if not notes_raw:
        raise SystemExit("No notes parsed from MIDI.")

    raw_duration = max(n["end"] for n in notes_raw)
    scale = true_duration / raw_duration

    print("Raw MIDI duration:", raw_duration)
    print("Scale factor:", scale)

    notes_scaled = []
    for n in notes_raw:
        notes_scaled.append({
            "pitch": int(n["pitch"]),
            "velocity": int(n["velocity"]),
            "start": float(n["start"]) * scale,
            "end": float(n["end"]) * scale,
        })

    notes_scaled.sort(key=lambda x: x["start"])

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        json.dump(notes_scaled, f, indent=2)

    print(f"Wrote {out_path} with {len(notes_scaled)} notes.")

if __name__ == "__main__":
    main()
