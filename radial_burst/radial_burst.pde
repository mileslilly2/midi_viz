// ------------------------------------------------------------
// APHEX TWIN STYLE RADIAL VIZ — SUPER VERSION
// - Uses audio_features_small.json (Python extracted)
// - Uses MIDI JSON (auto-detect ms/seconds)
// - Beat-reactive + onset-reactive additions
// - Fixed transforms, guaranteed visible output
// ------------------------------------------------------------

import java.util.*;
import java.io.File;
import processing.data.*;

class Note {
  float pitch, velocity, start, end;
}

// particles
class Particle {
  float x, y, vx, vy, life, maxLife;
  color c;

  Particle(float _x, float _y, float _angle, float _speed, float _life, color _c) {
    x=_x; y=_y;
    vx = cos(_angle) * _speed;
    vy = sin(_angle) * _speed;
    life = maxLife = _life;
    c = _c;
  }

  void update() {
    x += vx;
    y += vy;
    life -= 1;
  }

  void draw() {
    float alpha = map(life, 0, maxLife, 0, 255);
    stroke(c, alpha);
    point(x, y);
  }

  boolean dead() { return life <= 0; }
}

// ------------------------------------------------------------
// GLOBALS
// ------------------------------------------------------------

int FPS = 60;

ArrayList<Note> notes = new ArrayList<Note>();
ArrayList<Particle> particles = new ArrayList<Particle>();

float[] rms, onsetStrength, centroid, bandwidth, flatness;
int[] onsetFrames, beatFrames;
float[][] chroma;

float audioDuration;
int totalFrames;

// for beat detection fast lookup:
boolean[] isBeat;

// ------------------------------------------------------------

void setup() {
  size(1080, 1920);
  frameRate(FPS);

  loadAudioFeatures();
  loadMidiJSON_autoDetect();   // NEW auto-detect timing mode

  makeBeatLookup();

  println("Loaded MIDI notes: " + notes.size());
  println("Frames: " + totalFrames);

  File framesDir = new File(dataPath("frames"));
  if (!framesDir.exists()) framesDir.mkdirs();
}

// ------------------------------------------------------------

void draw() {
  int f = frameCount;
  if (f >= totalFrames) {
    println("Done.");
    exit();
  }

  float t = f / float(totalFrames);
  float now = audioDuration * t;     // seconds

  float amp = rms[f];
  float bright = centroid[f];

  boolean beat = isBeat[f];

  // ---------------------------------------------------------
  // BACKGROUND (flatness-driven + beat pulse)
  // ---------------------------------------------------------
  float flat = flatness[f];
  float bgBump = beat ? 40 : 0;

  background(flat*40 + bgBump, 0, flat*120 + bgBump);

  translate(width/2, height/2);

  // ---------------------------------------------------------
  // GLOBAL SPIN + JITTER
  // ---------------------------------------------------------
  float spinSpeed = 0.4 + bright * 1.4;
  if (beat) spinSpeed *= 1.4;

  rotate(now * spinSpeed);

  float jitter = amp * 40 + (beat ? 20 : 0);
  translate((noise(now*3)-0.5)*jitter, (noise(999+now*3)-0.5)*jitter);

  // ---------------------------------------------------------
  // MIDI bursts
  // ---------------------------------------------------------
  for (Note n : notes) {
    if (now >= n.start && now <= n.end) {
      drawBurst(n, now, f, beat);
    }
  }

  // ---------------------------------------------------------
  // Circular halo (spectral + beat-reactive)
  // ---------------------------------------------------------
  drawHalo(f, amp, bright, bandwidth[f], chroma[f], beat);

  // ---------------------------------------------------------
  // Particles
  // ---------------------------------------------------------
  for (int i = particles.size()-1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    p.draw();
    if (p.dead()) particles.remove(i);
  }

  // ---------------------------------------------------------
  // Save output
  // ---------------------------------------------------------
  saveFrame("frames/frame####.png");
}

// ------------------------------------------------------------
// BURST FROM MIDI + AUDIO FEATURES + BEAT REACTIVITY
// ------------------------------------------------------------

void drawBurst(Note n, float now, int f, boolean beat) {

  float life = (now - n.start) / (n.end - n.start);
  life = constrain(life, 0, 1);

  float angle = map(n.pitch, 0, 127, 0, TWO_PI);

  float baseR = 150;
  float maxR  = 700;
  float r = baseR + life * maxR + sin(now * 10 + n.pitch) * 20;

  int pc = int(n.pitch) % 12;

  colorMode(HSB, 360,255,255,255);
  color c = color(map(pc,0,12,0,360), 255, 255);

  stroke(c, 220);
  strokeWeight(3 + (beat ? 3 : 1));

  float x1 = cos(angle)*r;
  float y1 = sin(angle)*r;

  float len = 60 + n.velocity + rms[f]*200 + (beat ? 100 : 0);
  float x2 = cos(angle)*(r+len);
  float y2 = sin(angle)*(r+len);

  line(x1,y1,x2,y2);

  // orbiting limbs
  for (int i=0; i<4; i++) {
    float a = angle + TWO_PI*(i/4.0) + now*3;
    float rr = r*0.5 + sin(now*8+i)*40;
    float ax = cos(a)*rr;
    float ay = sin(a)*rr;
    stroke(c,150);
    line(ax,ay, ax+cos(a)*20, ay+sin(a)*20);
  }

  // burst particles
  int pcount = int(map(n.velocity,0,127, 5,30)) + (beat ? 10 : 0);
  for (int i=0; i<pcount; i++) {
    float ang = angle + random(-0.4,0.4);
    float spd = random(3,10) + rms[f]*20;
    float lifeP = random(10,40);
    particles.add(new Particle(x2,y2, ang, spd, lifeP, c));
  }
}

// ------------------------------------------------------------
// HALO (spectral + chroma + beat reactive)
// ------------------------------------------------------------

void drawHalo(int f, float amp, float bright, float bw, float[] chrom, boolean beat) {
  int segments = 720;

  colorMode(HSB, 360,255,255,255);
  strokeWeight(2 + (beat ? 1.5 : 0));

  float baseR = 300 + amp * 280 + (beat ? 40 : 0);
  float jag = bw * 200;

  float px=0, py=0;
  boolean first=true;

  for (int i=0; i<segments; i++) {
    float a = TWO_PI * i / segments;

    float rr = baseR + sin(a*12 + f*0.03)*jag + (beat ? sin(a*24)*20 : 0);

    float cm = chrom[i % 12];
    float hue = map(cm,0,1, 180,360);

    stroke(hue,255,255,200);

    float x = cos(a)*rr;
    float y = sin(a)*rr;

    if (!first) line(px,py, x,y);

    px=x; py=y;
    first=false;
  }
}

// ------------------------------------------------------------
// AUDIO FEATURES LOADER
// ------------------------------------------------------------

void loadAudioFeatures() {
  JSONObject j = loadJSONObject("audio_features_small.json");

  audioDuration = j.getFloat("duration");
  totalFrames   = j.getInt("frames");

  rms            = toFloatArray(j.getJSONArray("rms"));
  onsetStrength  = toFloatArray(j.getJSONArray("onset_strength"));
  centroid       = toFloatArray(j.getJSONArray("centroid"));
  bandwidth      = toFloatArray(j.getJSONArray("bandwidth"));
  flatness       = toFloatArray(j.getJSONArray("flatness"));

  onsetFrames = toIntArray(j.getJSONArray("onset_frames"));
  beatFrames  = toIntArray(j.getJSONArray("beats"));

  chroma = to2DFloat(j.getJSONArray("chroma"));
}

float[] toFloatArray(JSONArray arr) {
  float[] out = new float[arr.size()];
  for (int i=0; i<arr.size(); i++) out[i] = arr.getFloat(i);
  return out;
}

int[] toIntArray(JSONArray arr) {
  int[] out = new int[arr.size()];
  for (int i=0; i<arr.size(); i++) out[i] = arr.getInt(i);
  return out;
}

float[][] to2DFloat(JSONArray arr) {
  float[][] out = new float[arr.size()][];
  for (int i=0; i<arr.size(); i++) {
    JSONArray row = arr.getJSONArray(i);
    out[i] = new float[row.size()];
    for (int k=0; k<row.size(); k++) {
      out[i][k] = row.getFloat(k);
    }
  }
  return out;
}

// ------------------------------------------------------------
// MIDI LOADER — AUTO DETECT MS VS SECONDS
// ------------------------------------------------------------

void loadMidiJSON_autoDetect() {
  JSONArray arr = loadJSONArray("everyday_fixed.json");

  // read first timing to detect scale
  float rawStart = arr.getJSONObject(0).getFloat("start");

  boolean ms = rawStart > 60;  // if > 60 seconds, then it's milliseconds

  float scale = ms ? 1.0/1000.0 : 1.0;

  println("MIDI time units:", ms ? "milliseconds → converting" : "seconds");

  for (int i=0; i<arr.size(); i++) {
    JSONObject o = arr.getJSONObject(i);
    Note n = new Note();
    n.pitch = o.getFloat("pitch");
    n.velocity = o.getFloat("velocity");

    n.start = o.getFloat("start") * scale;
    n.end   = o.getFloat("end")   * scale;

    notes.add(n);
  }
}

// ------------------------------------------------------------
// MAKE FAST LOOKUP ARRAY FOR BEATS
// ------------------------------------------------------------

void makeBeatLookup() {
  isBeat = new boolean[totalFrames];
  for (int b : beatFrames) {
    if (b >= 0 && b < totalFrames) {
      isBeat[b] = true;
    }
  }
}
