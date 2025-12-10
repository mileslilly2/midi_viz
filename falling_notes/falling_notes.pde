// ------------------------------------------------------------
// PERFECT SYNC PIANO-ROLL RENDERER (Processing + Sound library)
// ------------------------------------------------------------
// ✔ Reads WAV duration from SoundFile → works in SNAP
// ✔ Computes total frames = duration * fps
// ✔ Advances time deterministically: t = frame / fps
// ✔ Loads notes from everyday_fixed.json
// ✔ Uses your original piano layout
// ✔ Saves frames for ffmpeg
// ------------------------------------------------------------

import processing.sound.*;
import processing.data.*;
import java.io.*;

ArrayList<NoteEvent> notes = new ArrayList<NoteEvent>();
ArrayList<PianoKey> keys = new ArrayList<PianoKey>();

SoundFile wav;

float songDuration = 0;
int fps = 30;
int totalFrames = 0;
int frameNumber = 0;

float pixelsPerSecond = 350;

// ------------------------------------------------------------
// SETTINGS
// ------------------------------------------------------------
void settings() {
  size(1080, 920, JAVA2D);  // No OpenGL for SNAP
}

// ------------------------------------------------------------
// SETUP
// ------------------------------------------------------------
void setup() {
  frameRate(fps);
  colorMode(HSB, 360, 100, 100);

  println("Loading WAV...");
  wav = new SoundFile(this, "everyday.wav");
  songDuration = wav.duration();
  println("Song duration =", songDuration, "seconds");

  totalFrames = int(songDuration * fps);
  println("Rendering", totalFrames, "frames at", fps, "fps");

  buildPiano();
  loadJSONNotes("everyday_fixed.json");

  println("Loaded", notes.size(), "notes.");

  File f = new File("frames");
  if (!f.exists()) f.mkdirs();
}

// ------------------------------------------------------------
// MAIN DRAW LOOP (DETERMINISTIC TIMESTEP)
// ------------------------------------------------------------
void draw() {

  if (frameNumber >= totalFrames) {
    println("Rendering complete.");
    exit();
    return;
  }

  background(0);

  // Fixed simulation time for this frame:
  float t = frameNumber / float(fps);

  // update + draw notes
  for (NoteEvent n : notes) {
    n.update(t);
    n.draw();
  }

  drawPiano();

  saveFrame("frames/frame_" + nf(frameNumber, 5) + ".png");
  frameNumber++;
}


// ============================================================
// NOTE EVENT
// ============================================================
class NoteEvent {
  int pitch;
  int velocity;
  float start, end;
  float y;
  float rectH;
  PianoKey key;

  float yOffset = -600;  // START ABOVE THE SCREEN

  NoteEvent(JSONObject obj) {
    pitch = obj.getInt("pitch");
    velocity = obj.getInt("velocity");
    start = obj.getFloat("start");
    end   = obj.getFloat("end");

    // assign key
    for (PianoKey k : keys) {
      if (k.midi == pitch) {
        key = k;
        break;
      }
    }

    // height based on duration
    float dur = end - start;
    rectH = max(20, dur * pixelsPerSecond);
  }

  void update(float t) {
    float dt = t - start;
    y = yOffset + dt * pixelsPerSecond;
  }

  void draw() {
    if (key == null) return;

    float hue = map(pitch, 21, 108, 0, 360);
    float b = map(velocity, 0, 127, 30, 100);

    fill(hue, 80, b, 180);
    noStroke();
    rect(key.x, y, key.w, rectH, 8);
  }
}


// ============================================================
// LOAD JSON
// ============================================================
void loadJSONNotes(String filename) {
  JSONArray arr = loadJSONArray(filename);
  for (int i = 0; i < arr.size(); i++) {
    notes.add(new NoteEvent(arr.getJSONObject(i)));
  }
}


// ============================================================
// PIANO KEY CLASS
// ============================================================
class PianoKey {
  float x, y, w, h;
  boolean black;
  int midi;
}


// ============================================================
// BUILD YOUR ORIGINAL PIANO
// ============================================================
void buildPiano() {
  keys.clear();

  float whiteW = width / 52.0;
  float whiteH = 200;
  float blackW = whiteW * 0.6;
  float blackH = whiteH * 0.65;

  int midi = 21;
  float x = 0;

  // white keys
  for (int i = 0; i < 52; i++) {
    PianoKey k = new PianoKey();
    k.x = x;
    k.y = height - whiteH;
    k.w = whiteW;
    k.h = whiteH;
    k.black = false;
    k.midi = midi;

    keys.add(k);
    x += whiteW;

    int pattern = i % 7;
    if (pattern == 0 || pattern == 3) midi++;
    else midi += 2;
  }

  // black keys
  int[] blackPattern = {1,2,4,5,6};
  midi = 22;

  for (int octave = 0; octave < 7; octave++) {
    for (int bp : blackPattern) {
      int wi = octave * 7 + bp;
      if (wi >= 52) continue;

      PianoKey wk = keys.get(wi);

      PianoKey bk = new PianoKey();
      bk.w = blackW;
      bk.h = blackH;
      bk.x = wk.x + wk.w - (blackW * 0.5);
      bk.y = height - whiteH;
      bk.black = true;
      bk.midi = midi;

      keys.add(bk);
      midi++;
    }
  }
}


// ============================================================
// DRAW PIANO
// ============================================================
void drawPiano() {

  // white keys
  for (PianoKey k : keys) {
    if (!k.black) {
      fill(255);
      stroke(40);
      rect(k.x, k.y, k.w, k.h);
    }
  }

  // black keys
  for (PianoKey k : keys) {
    if (k.black) {
      fill(30);
      noStroke();
      rect(k.x, k.y, k.w, k.h);
    }
  }
}
