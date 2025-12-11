// ------------------------------------------------------------
// TERMINAL VELOCITY VISUALIZER (Aphex Twin Style)
// - Uses audio_features_small.json
// - Uses MIDI note timing (auto-seconds/milliseconds detection)
// - Gravity + vortex black-hole physics
// - Ghost trails + comet trails
// - WAV-driven color modulation (centroid/rms/chroma/beat)
// - Chromatic aberration + glitch sorting
// ------------------------------------------------------------

import java.util.*;
import java.io.File;
import processing.data.*;

// ------------------------------------------------------------
// STRUCTS
// ------------------------------------------------------------

class Note {
  float pitch, velocity, start, end;
}

class Particle {
  float x, y, vx, vy;
  float life, maxLife;
  color c;

  // comet trail
  ArrayList<PVector> trail = new ArrayList<PVector>();
  int maxTrail = 65; // Terminal Velocity

  Particle(float _x, float _y, float _angle, float _speed, float _life, color _c) {
    x = _x;
    y = _y;
    vx = cos(_angle) * _speed;
    vy = sin(_angle) * _speed;
    life = maxLife = _life;
    c = _c;
  }

  void update(float centerX, float centerY, float vortexStrength, float gravBase) {
    // VECTOR TO CENTER
    float dx = centerX - x;
    float dy = centerY - y;
    float dist = sqrt(dx*dx + dy*dy) + 0.0001;

    // GRAVITY (inverse square enhanced)
    float grav = gravBase / (dist*0.3 + 0.4);
    vx += dx/dist * grav;
    vy += dy/dist * grav;

    // VORTEX SWIRL (black hole)
    float orthoX = -dy / dist;
    float orthoY = dx / dist;
    vx += orthoX * vortexStrength;
    vy += orthoY * vortexStrength;

    // terminal velocity warp near singularity
    if (dist < 40) {
      vx *= 1.22;
      vy *= 1.22;
    }

    // motion
    x += vx;
    y += vy;
    life--;

    // record trail
    trail.add(new PVector(x, y));
    if (trail.size() > maxTrail) trail.remove(0);
  }

  void draw() {
    // draw comet trail
    strokeWeight(1.6);
    for (int i = 1; i < trail.size(); i++) {
      float alpha = map(i, 0, trail.size()-1, 0, 255);
      stroke(c, alpha);
      line(trail.get(i-1).x, trail.get(i-1).y, trail.get(i).x, trail.get(i).y);
    }

    // head of particle
    stroke(c, 255);
    strokeWeight(3);
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

boolean[] isBeat;

float globalHueShift = 0;

// ------------------------------------------------------------

void setup() {
  size(1080, 1920);
  frameRate(FPS);

  loadAudioFeatures();
  loadMidiJSON_autoDetect();
  makeBeatLookup();

  println("Loaded audio frames: " + totalFrames);
  println("Loaded MIDI notes: " + notes.size());

  File framesDir = new File(dataPath("frames"));
  if (!framesDir.exists()) framesDir.mkdirs();

  colorMode(HSB, 360, 255, 255, 255);
}

// ------------------------------------------------------------

void draw() {

  int f = frameCount;
  if (f >= totalFrames) {
    println("DONE");
    exit();
  }

  // time
  float t = f / float(totalFrames);
  float now = audioDuration * t;

  // audio features
  float amp = rms[f];
  float bright = centroid[f];
  float bw = bandwidth[f];
  float flat = flatness[f];
  boolean beat = isBeat[f];

  // ------------------------------------------------------------
  // WAV-DRIVEN COLOR SHIFT
  // ------------------------------------------------------------
  float wavHueShift = bright * 200;
  float chromaHue = chroma[f][int(random(12))] * 360;
  float beatHue = beat ? random(360) : 0;

  globalHueShift =
      (frameCount * 0.28) +     // drifting
      wavHueShift +             // brightness → hue
      chromaHue +               // harmonic colors
      beatHue;                  // beat explosion

  globalHueShift %= 360;

  // ------------------------------------------------------------
  // GHOST TRAILS LAYER
  // ------------------------------------------------------------
  noStroke();
  fill(0, 0, 0, beat ? 4 : 12);
  rect(0, 0, width, height);

  pushMatrix();
  translate(width/2, height/2);

  // ------------------------------------------------------------
  // STRONGER VORTEX + CENTER GRAVITY
  // ------------------------------------------------------------
  float vortexStrength = 0.09;
  float gravBase = 0.015;

  // ------------------------------------------------------------
  // BACKGROUND BASED ON FLATNESS
  // ------------------------------------------------------------
  background(flat*40 + (beat?40:0),
             0,
             flat*120 + (beat?40:0));

  // ------------------------------------------------------------
  // GLOBAL ROTATION + JITTER
  // ------------------------------------------------------------
  rotate(now * (0.4 + bright*1.4 + (beat?1.6:0)));

  float j = amp * 40 + (beat ? 25 : 0);
  translate((noise(now*3)-0.5)*j, (noise(999+now*3)-0.5)*j);

  // ------------------------------------------------------------
  // DRAW MIDI BURSTS
  // ------------------------------------------------------------
  for (Note n : notes) {
    if (now >= n.start && now <= n.end) {
      drawBurst(n, now, f, beat);
    }
  }

  // ------------------------------------------------------------
  // HALO
  // ------------------------------------------------------------
  drawHalo(f, amp, bright, bw, chroma[f], beat);

  // ------------------------------------------------------------
  // PARTICLES UPDATE + DRAW
  // ------------------------------------------------------------
  for (int i = particles.size()-1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update(0, 0, vortexStrength, gravBase);
    p.draw();
    if (p.dead()) particles.remove(i);
  }

  popMatrix();

  // ------------------------------------------------------------
  // GLITCH
  // ------------------------------------------------------------
  applyChromaticAndGlitch();

  // save
  saveFrame("frames/frame####.png");
}

// ------------------------------------------------------------
// MIDI BURST
// ------------------------------------------------------------

void drawBurst(Note n, float now, int f, boolean beat) {

  float life = (now - n.start) / (n.end - n.start);
  life = constrain(life, 0, 1);

  float angle = map(n.pitch, 0, 127, 0, TWO_PI);

  float baseR = 150;
  float maxR  = 700;
  float r = baseR + life*maxR + sin(now*10 + n.pitch)*20;

  int pc = int(n.pitch) % 12;

  // COLOR MODULATION
  float baseHue = map(pc, 0, 12, 0, 360);
  float hue = (baseHue + globalHueShift) % 360;
  float sat = constrain(255 * (1 + rms[f]*0.7), 0, 255);

  color c = color(hue, sat, 255);

  stroke(c, 230);
  strokeWeight(3 + (beat?3:1));

  float x1 = cos(angle)*r;
  float y1 = sin(angle)*r;

  // EXTREME BURST LENGTH
  float len = 120 + n.velocity*1.8 + rms[f]*400 + (beat?220:0);

  float x2 = cos(angle)*(r+len);
  float y2 = sin(angle)*(r+len);

  line(x1, y1, x2, y2);

  // Orbiting limbs
  for (int i = 0; i < 4; i++) {
    float a = angle + TWO_PI*(i/4.0) + now*3;
    float rr = r*0.5 + sin(now*8+i)*40;
    float ax = cos(a)*rr;
    float ay = sin(a)*rr;
    stroke(c, 150);
    line(ax, ay, ax+cos(a)*20, ay+sin(a)*20);
  }

  // PARTICLE SHOWER
  int pcount = int(map(n.velocity,0,127,15,45)) + (beat?35:0);
  for (int i=0; i<pcount; i++) {
    float ang = angle + random(-0.4,0.4);
    float spd = random(3,10) + rms[f]*20;
    float lifeP = random(10,40);
    particles.add(new Particle(x2,y2, ang, spd, lifeP, c));
  }
}

// ------------------------------------------------------------
// HALO
// ------------------------------------------------------------

void drawHalo(int f, float amp, float bright, float bw, float[] chrom, boolean beat) {
  int segments = 720;
  strokeWeight(2 + (beat?2:0));

  float baseR = 300 + amp*280 + (beat?60:0);
  float jag = bw * 800;

  float px=0, py=0;
  boolean first=true;

  for (int i=0; i<segments; i++) {
    float a = TWO_PI * i / segments;

    float rr = baseR + sin(a*12 + f*0.03)*jag;

    // Terminal Velocity extra distortion
    rr += sin(f*0.6 + a*30.0) * (beat ? 60 : 30);
    rr += (noise(a*5 + f*0.02)-0.5) * 90;

    // harmonic flicker color
    float cm = chrom[i % 12];
    float h = (map(cm,0,1, 150,330) + globalHueShift) % 360;

    stroke(h, 255, 255, 200);

    float x = cos(a)*rr;
    float y = sin(a)*rr;

    if (!first) line(px,py,x,y);

    px=x; py=y;
    first=false;
  }
}

// ------------------------------------------------------------
// GLITCH
// ------------------------------------------------------------

void applyChromaticAndGlitch() {
  PImage snap = get();

  background(0);
  imageMode(CORNER);

  float shift = 3;

  tint(255,0,0,200);
  image(snap, -shift, -shift);

  tint(0,255,0,200);
  image(snap, 0, shift);

  tint(0,0,255,200);
  image(snap, shift, -shift);

  noTint();

  // DESTRUCTIVE GLITCH
  if (frameCount % 3 == 0) {
    loadPixels();
    int bands = 40;

    // row-sort bands
    for (int b = 0; b < bands; b++) {
      int y = int(random(height));
      int start = y * width;
      int len = width;

      int[] seg = new int[len];
      arrayCopy(pixels, start, seg, 0, len);
      Arrays.sort(seg);

      if (random(1) < 0.5) {
        for (int i=0; i<len/2; i++) {
          int tmp = seg[i];
          seg[i] = seg[len-1-i];
          seg[len-1-i] = tmp;
        }
      }

      arrayCopy(seg, 0, pixels, start, len);
    }

    // vertical glitch columns
    for (int v=0; v<8; v++) {
      int col = int(random(width));
      for (int y=0; y<height; y++) {
        int idx = y*width + col;
        if (idx > 0 && idx < pixels.length) {
          pixels[idx] = pixels[idx] ^ int(random(0xFFFFFF));
        }
      }
    }

    updatePixels();
  }
}

// ------------------------------------------------------------
// LOADERS
// ------------------------------------------------------------

void loadAudioFeatures() {
  JSONObject j = loadJSONObject("audio_features_small.json");

  audioDuration = j.getFloat("duration");
  totalFrames   = j.getInt("frames");

  rms            = toFloat(j.getJSONArray("rms"));
  onsetStrength  = toFloat(j.getJSONArray("onset_strength"));
  centroid       = toFloat(j.getJSONArray("centroid"));
  bandwidth      = toFloat(j.getJSONArray("bandwidth"));
  flatness       = toFloat(j.getJSONArray("flatness"));

  onsetFrames = toInt(j.getJSONArray("onset_frames"));
  beatFrames  = toInt(j.getJSONArray("beats"));

  chroma = to2D(j.getJSONArray("chroma"));
}

float[] toFloat(JSONArray arr) {
  float[] out = new float[arr.size()];
  for (int i=0; i<arr.size(); i++) out[i] = arr.getFloat(i);
  return out;
}

int[] toInt(JSONArray arr) {
  int[] out = new int[arr.size()];
  for (int i=0; i<arr.size(); i++) out[i] = arr.getInt(i);
  return out;
}

float[][] to2D(JSONArray arr) {
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

// MIDI loader with auto ms/sec detection
void loadMidiJSON_autoDetect() {
  JSONArray arr = loadJSONArray("everyday_fixed.json");
  float rawStart = arr.getJSONObject(0).getFloat("start");
  boolean ms = rawStart > 60;
  float scale = ms ? 1.0/1000.0 : 1.0;

  for (int i=0; i<arr.size(); i++) {
    JSONObject o = arr.getJSONObject(i);
    Note n = new Note();
    n.pitch = o.getFloat("pitch");
    n.velocity = o.getFloat("velocity");
    n.start = o.getFloat("start")*scale;
    n.end   = o.getFloat("end")*scale;
    notes.add(n);
  }
}

void makeBeatLookup() {
  isBeat = new boolean[totalFrames];
  for (int b : beatFrames)
    if (b >= 0 && b < totalFrames) isBeat[b] = true;
}
