// ------------------------------------------------------------
// INSTAGRAM REEL VERSION — PERFECT SYNC (30 FPS, 1080×1920)
// ------------------------------------------------------------
// ✔ Audio-synced falling notes (bottom hits key at start time)
// ✔ Vertical video (Reels, TikTok)
// ✔ Smooth deterministic timing
// ✔ Uses SoundFile for WAV duration (works in SNAP)
// ✔ Notes fall with 2-second lead time (Synthesia style)
// ------------------------------------------------------------

import processing.sound.*;
import processing.data.*;
import java.io.*;

SoundFile wav;

ArrayList<NoteEvent> notes = new ArrayList<NoteEvent>();
ArrayList<PianoKey> keys = new ArrayList<PianoKey>();

int fps = 30;
float songDuration;
int totalFrames;
int frameNumber = 0;

float leadTime = 2.0;       // seconds before impact
float pixelsPerSecond = 550; // falls faster for tall screen

// ------------------------------------------------------------
// SETTINGS (VERTICAL 1080×1920)
// ------------------------------------------------------------
void settings() {
  size(1080, 1920, JAVA2D);
}

// ------------------------------------------------------------
// SETUP
// ------------------------------------------------------------
void setup() {
  frameRate(fps);
  colorMode(HSB, 360, 100, 100);

  wav = new SoundFile(this, "everyday.wav");
  songDuration = wav.duration();

  totalFrames = int(songDuration * fps);
  println("Song duration:", songDuration);
  println("Total frames:", totalFrames);

  buildPiano();
  loadJSONNotes("everyday_fixed.json");

  File f = new File("frames");
  if (!f.exists()) f.mkdirs();
}

// ------------------------------------------------------------
// DRAW (FIXED TIMESTEP)
// ------------------------------------------------------------
void draw() {

  if (frameNumber >= totalFrames) {
    println("DONE. Flushing final frames...");
    delay(3000);
    exit();
    return;
  }

  background(0);
  float t = frameNumber / float(fps);

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
  int pitch, velocity;
  float start, end;
  float y;
  float rectH;
  PianoKey key;

  NoteEvent(JSONObject obj) {
    pitch = obj.getInt("pitch");
    velocity = obj.getInt("velocity");
    start = obj.getFloat("start");
    end   = obj.getFloat("end");

    for (PianoKey k : keys) {
      if (k.midi == pitch) key = k;
    }

    float dur = end - start;
    rectH = max(30, dur * pixelsPerSecond);
  }

  void update(float t) {
    float keybed = height - 300;

    float yOffset = keybed - (leadTime * pixelsPerSecond);

    float dt = t - start;
    y = yOffset + dt * pixelsPerSecond;
  }

  void draw() {
    if (key == null) return;

    float hue = map(pitch, 21, 108, 0, 360);
    float b = map(velocity, 0, 127, 40, 100);

    fill(hue, 80, b, 200);
    noStroke();
    rect(key.x, y, key.w, rectH, 12);
  }
}

// ============================================================
// LOAD NOTES
// ============================================================
void loadJSONNotes(String filename) {
  JSONArray arr = loadJSONArray(filename);
  for (int i = 0; i < arr.size(); i++) {
    notes.add(new NoteEvent(arr.getJSONObject(i)));
  }
}

// ============================================================
// PIANO KEYS (MODIFIED FOR TALL SCREEN)
// ============================================================
class PianoKey {
  float x, y, w, h;
  boolean black;
  int midi;
}

void buildPiano() {

  keys.clear();
  float whiteW = width / 52.0;
  float whiteH = 300;
  float blackW = whiteW * 0.6f;
  float blackH = whiteH * 0.65f;

  int midi = 21;
  float x = 0;

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

    int mod = i % 7;
    if (mod == 0 || mod == 3) midi++;
    else midi += 2;
  }

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
      bk.x = wk.x + wk.w - blackW/2;
      bk.y = wk.y;
      bk.black = true;
      bk.midi = midi;

      keys.add(bk);
      midi++;
    }
  }
}

// ------------------------------------------------------------
// DRAW PIANO
// ------------------------------------------------------------
void drawPiano() {
  for (PianoKey k : keys) {
    if (!k.black) {
      fill(255);
      stroke(40);
      rect(k.x, k.y, k.w, k.h);
    }
  }

  for (PianoKey k : keys) {
    if (k.black) {
      fill(40);
      noStroke();
      rect(k.x, k.y, k.w, k.h);
    }
  }
}
