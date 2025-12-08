// ------------------------------------------------------------
// REALISTIC MIDI FALLING PIANO  (JAVA2D SAFE VERSION)
// ------------------------------------------------------------
// Features:
//  ✔ 88-key realistic keyboard
//  ✔ MIDI-driven falling notes (pitch, duration, velocity)
//  ✔ JAVA2D only (no OpenGL → safe for Snap / Lubuntu)
//  ✔ Frame export to frames/frame_#####.png
// ------------------------------------------------------------

import javax.sound.midi.*;
ArrayList<PianoKey> keys = new ArrayList<PianoKey>();
ArrayList<PianoNote> notes = new ArrayList<PianoNote>();

float pixelsPerSecond = 400;   // falling speed
int frameCounter = 0;
float startTimeMS;

// ------------------------------------------------------------
// SETTINGS
// ------------------------------------------------------------
void settings() {
  size(1080, 1920, JAVA2D);  // DO NOT USE P2D or P3D
}

// ------------------------------------------------------------
// SETUP
// ------------------------------------------------------------
void setup() {
  frameRate(60);

  println("Building realistic piano...");
  buildPiano();

  println("Loading MIDI file...");
  loadMidiFile("data/everyday.mid");

  File f = new File("frames");
  if (!f.exists()) f.mkdirs();

  startTimeMS = millis();
}

// ------------------------------------------------------------
// DRAW LOOP
// ------------------------------------------------------------
void draw() {
  background(0);

  float t = (millis() - startTimeMS) / 1000.0;

  // Draw falling notes
  for (PianoNote pn : notes) {
    pn.update(t);
    pn.draw();
  }

  // Draw piano last so keys are on top
  drawPiano();

  // Save frame
  saveFrame(String.format("frames/frame_%05d.png", frameCounter++));
}

// ============================================================
// 1. REALISTIC 88-KEY PIANO
// ============================================================
class PianoKey {
  float x, y, w, h;
  boolean isBlack;
  int midi; // MIDI note 21-108
}

void buildPiano() {
  keys.clear();

  float whiteW = width / 52.0;
  float whiteH = 200;
  float blackW = whiteW * 0.6;
  float blackH = whiteH * 0.62;

  int midiNote = 21;  // A0
  float x = 0;

  // Create all white keys first
  for (int i = 0; i < 52; i++) {
    PianoKey k = new PianoKey();
    k.x = x;
    k.y = height - whiteH;
    k.w = whiteW;
    k.h = whiteH;
    k.isBlack = false;
    k.midi = midiNote;

    keys.add(k);

    x += whiteW;

    // Skip black-key MIDI notes for now
    // White-key pattern: A B C D E F G repeating
    int pattern = i % 7;
    if (pattern == 0 || pattern == 3) midiNote++; // A,C,F: skip sharp
    else midiNote += 2;                          // other white keys have sharps
  }

  // Add black keys based on white-key layout
  int[] blackPattern = {1, 2, 4, 5, 6}; // offsets in each octave

  midiNote = 22; // A#0 first black key
  for (int octave = 0; octave < 7; octave++) {
    for (int bp : blackPattern) {
      int whiteIndex = octave * 7 + bp;
      if (whiteIndex >= 52) continue;

      PianoKey wk = keys.get(whiteIndex);

      PianoKey bk = new PianoKey();
      bk.w = blackW;
      bk.h = blackH;
      bk.x = wk.x + wk.w - (blackW * 0.5);
      bk.y = height - whiteH;
      bk.midi = midiNote;
      bk.isBlack = true;

      keys.add(bk);
      midiNote++;
    }
  }
}

void drawPiano() {
  // White keys
  for (PianoKey k : keys) {
    if (!k.isBlack) {
      fill(255);
      stroke(40);
      rect(k.x, k.y, k.w, k.h);
    }
  }

  // Black keys
  for (PianoKey k : keys) {
    if (k.isBlack) {
      fill(20);
      noStroke();
      rect(k.x, k.y, k.w, k.h, 4);
    }
  }
}

// ============================================================
// 2. LOAD MIDI FILE
// ============================================================

class RawNote {
  int midi;
  float startSec;
  float endSec;
  int velocity;
}

void loadMidiFile(String filename) {
  try {
    Sequence seq = MidiSystem.getSequence(new File(filename));
    float ppq = seq.getResolution();
    float bpm = 120;
    float secPerTick = (60.0 / bpm) / ppq;

    ArrayList<RawNote> rawNotes = new ArrayList<>();

    for (Track track : seq.getTracks()) {
      HashMap<Integer, Long> active = new HashMap<>();

      for (int i = 0; i < track.size(); i++) {
        MidiEvent ev = track.get(i);
        MidiMessage msg = ev.getMessage();

        if (msg instanceof ShortMessage) {
          ShortMessage sm = (ShortMessage) msg;

          int cmd = sm.getCommand();
          int midi = sm.getData1();
          int vel = sm.getData2();
          long tick = ev.getTick();
          float sec = tick * secPerTick;

          if (cmd == ShortMessage.NOTE_ON && vel > 0) {
            active.put(midi, tick);
          }

          if ((cmd == ShortMessage.NOTE_OFF) ||
              (cmd == ShortMessage.NOTE_ON && vel == 0)) {

            if (active.containsKey(midi)) {
              long startTick = active.get(midi);
              float startSec = startTick * secPerTick;
              float endSec = sec;

              RawNote rn = new RawNote();
              rn.midi = midi;
              rn.startSec = startSec;
              rn.endSec = endSec;
              rn.velocity = vel;

              rawNotes.add(rn);
              active.remove(midi);
            }
          }
        }
      }
    }

    // Convert raw notes → falling notes
    for (RawNote rn : rawNotes) {
      if (rn.midi < 21 || rn.midi > 108) continue;
      notes.add(new PianoNote(rn.midi, rn.startSec, rn.endSec, rn.velocity));
    }

    println("Loaded " + notes.size() + " notes.");

  } catch (Exception e) {
    e.printStackTrace();
  }
}

// ============================================================
// 3. FALLING NOTES
// ============================================================

class PianoNote {
  int midi;
  float startSec, endSec;
  int velocity;
  PianoKey key;
  float y;

  PianoNote(int midi, float s, float e, int vel) {
    this.midi = midi;
    this.startSec = s;
    this.endSec = e;
    this.velocity = max(20, vel);

    // attach to piano key
    for (PianoKey k : keys) {
      if (k.midi == midi) {
        key = k;
        break;
      }
    }
  }

  void update(float t) {
    float dt = t - startSec;
    y = dt * pixelsPerSecond;
  }

  void draw() {
    if (key == null) return;

    float noteHeight = max(20, (endSec - startSec) * pixelsPerSecond);

    float hue = map(midi, 21, 108, 0, 360);
    float brightness = map(velocity, 1, 127, 40, 100);

    colorMode(HSB, 360, 100, 100);
    fill(hue, 80, brightness, 180);
    noStroke();

    rect(key.x, y, key.w, noteHeight, 8);
  }
}
