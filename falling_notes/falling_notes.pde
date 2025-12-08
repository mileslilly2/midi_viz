// ------------------------------------------------------------
// REALISTIC MIDI FALLING PIANO (USING JSON INSTEAD OF MIDI)
// ------------------------------------------------------------
//  ✔ Reads everyday_fixed.json (exported from your Python script)
//  ✔ Realistic 88-key layout
//  ✔ Notes fall based on start/end seconds
//  ✔ JAVA2D only — works in Processing Snap on Lubuntu
// ------------------------------------------------------------

import java.io.*;
import processing.data.JSONObject;
import processing.data.JSONArray;

ArrayList<NoteEvent> notes = new ArrayList<NoteEvent>();
ArrayList<PianoKey> keys = new ArrayList<PianoKey>();

float pixelsPerSecond = 350;   // falling speed
float startTime = 0;
int frameCounter = 0;

// ------------------------------------------------------------
// SETTINGS
// ------------------------------------------------------------
void settings() {
  size(1080, 920, JAVA2D);   // NO OpenGL
}

// ------------------------------------------------------------
// SETUP
// ------------------------------------------------------------
void setup() {
  frameRate(60);
  colorMode(HSB, 360, 100, 100);

  println("Building piano...");
  buildPiano();

  println("Loading JSON notes...");
  loadJSONNotes("everyday_fixed.json");

  println("Loaded " + notes.size() + " notes");

  File f = new File("frames");
  if (!f.exists()) f.mkdirs();

  startTime = millis() / 1000.0;
}

// ------------------------------------------------------------
// DRAW LOOP
// ------------------------------------------------------------
void draw() {
  background(0);

  float t = (millis() / 1000.0) - startTime;

  // draw falling notes
  for (NoteEvent n : notes) {
    n.update(t);
    n.draw();
  }

  drawPiano();

  // save frame
  saveFrame("frames/frame_" + nf(frameCounter++, 5) + ".png");
}

// ============================================================
// 1. LOAD JSON
// ============================================================
class NoteEvent {
  int pitch;
  int velocity;
  float start;
  float end;
  PianoKey key;
  float y;

  NoteEvent(JSONObject obj) {
    pitch = obj.getInt("pitch");
    velocity = obj.getInt("velocity");
    start = obj.getFloat("start");
    end = obj.getFloat("end");

    // find piano key
    for (PianoKey k : keys) {
      if (k.midi == pitch) {
        key = k;
        break;
      }
    }
  }

  void update(float t) {
    float dt = t - start;
    y = dt * pixelsPerSecond;
  }

  void draw() {
    if (key == null) return;

    float dur = end - start;
    float h = max(20, dur * pixelsPerSecond);

    float hue = map(pitch, 21, 108, 0, 360);
    float b = map(velocity, 0, 127, 30, 100);

    fill(hue, 80, b, 180);
    noStroke();
    rect(key.x, y, key.w, h, 8);
  }
}

void loadJSONNotes(String filename) {
  JSONArray arr = loadJSONArray(filename);
  for (int i = 0; i < arr.size(); i++) {
    notes.add(new NoteEvent(arr.getJSONObject(i)));
  }
}

// ============================================================
// 2. REALISTIC PIANO CONSTRUCTION
// ============================================================
class PianoKey {
  float x, y, w, h;
  boolean black;
  int midi;
}

void buildPiano() {
  keys.clear();

  float whiteW = width / 52.0;
  float whiteH = 200;
  float blackW = whiteW * 0.6;
  float blackH = whiteH * 0.65;

  int midi = 21; // A0
  float x = 0;

  // White keys
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

  // Black key positions
  int[] blackPattern = {1,2,4,5,6};
  midi = 22;

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
      bk.black = true;
      bk.midi = midi;

      keys.add(bk);
      midi++;
    }
  }
}

void drawPiano() {
  // draw white keys
  for (PianoKey k : keys) {
    if (!k.black) {
      fill(255);
      stroke(40);
      rect(k.x, k.y, k.w, k.h);
    }
  }

  // draw black keys
  for (PianoKey k : keys) {
    if (k.black) {
      fill(30);
      noStroke();
      rect(k.x, k.y, k.w, k.h);
    }
  }
}
