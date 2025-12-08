import processing.core.*;
import processing.data.*;
import java.util.HashMap;

public class FallingNotesSketch extends PApplet {

    static String jsonPath;

    JSONArray notes;

    float minPitch = 21;
    float maxPitch = 108;
    float totalDuration = 0;

    int FPS = 60;
    float windowSecs = 6.0f;
    int keyboardHeight = 350;

    HashMap<Integer, Integer> pitchToWhite = new HashMap<>();
    int whiteKeyCount = 0;
    int activeIdx = 0;

    PGraphics cachedBg;

    public void settings() {
        size(1080, 1920, P2D);
    }

    public void setup() {
        if (jsonPath == null) {
            System.err.println("jsonPath is null. Pass everyday_fixed.json as an argument.");
            exit();
        }

        notes = loadJSONArray(jsonPath);

        float minP = 999;
        float maxP = 0;
        float maxTime = 0;

        for (int i = 0; i < notes.size(); i++) {
            JSONObject n = notes.getJSONObject(i);
            float p = n.getFloat("pitch");
            float end = n.getFloat("end");
            if (p < minP) minP = p;
            if (p > maxP) maxP = p;
            if (end > maxTime) maxTime = end;
        }

        minPitch = max(21, minP);
        maxPitch = min(108, maxP);
        totalDuration = maxTime;

        int w = 0;
        for (int p = (int) minPitch; p <= (int) maxPitch; p++) {
            if (!isBlack(p)) {
                pitchToWhite.put(p, w);
                w++;
            }
        }
        whiteKeyCount = w;

        cachedBg = generateBackground();

        frameRate(FPS);
        colorMode(HSB, 360, 100, 100, 100);
        noStroke();
    }

    public void draw() {
        float now = frameCount / (float) FPS;

        if (now > totalDuration + 2) {
            System.out.println("FINISHED");
            exit();
        }

        image(cachedBg, 0, 0);

        drawKeyboard();
        drawNotes(now);

        saveFrame("frames/frame-%05d.png");
    }

    // Helpers
    boolean isBlack(int p) {
        int m = p % 12;
        return (m == 1 || m == 3 || m == 6 || m == 8 || m == 10);
    }

    float pmap(float v, float a1, float a2, float b1, float b2) {
        return (v - a1) * (b2 - b1) / (a2 - a1) + b1;
    }

    PGraphics generateBackground() {
        PGraphics pg = createGraphics(width, height, P2D);
        pg.beginDraw();
        pg.noStroke();
        pg.colorMode(HSB, 360, 100, 100, 100);

        int step = 6;

        for (int y = 0; y < height; y += step) {
            for (int x = 0; x < width; x += step) {
                float n = noise(x * 0.003f, y * 0.003f);
                int c = pg.color(220 + 80 * n, 30 + 40 * n, 5 + 20 * n, 60);
                pg.fill(c);
                pg.rect(x, y, step, step);
            }
        }

        pg.endDraw();
        return pg;
    }

    void drawNotes(float now) {
        float left = 80;
        float right = width - 80;
        float kbTop = height - keyboardHeight;

        while (activeIdx < notes.size()) {
            JSONObject n = notes.getJSONObject(activeIdx);
            float end = n.getFloat("end");
            if (end >= now) break;
            activeIdx++;
        }

        for (int i = activeIdx; i < notes.size(); i++) {
            JSONObject n = notes.getJSONObject(i);
            float start = n.getFloat("start");

            if (start > now + windowSecs) break;

            if (start >= now) {
                float pitch = n.getFloat("pitch");
                float vel = n.getFloat("velocity");
                float end = n.getFloat("end");
                float dur = end - start;

                float y = pmap(start - now, 0, windowSecs, kbTop, 0);

                Integer wi = pitchToWhite.get((int) pitch);
                if (wi == null) continue;

                float x = pmap(wi, 0, whiteKeyCount - 1, left, right);
                float h = pmap(dur, 0, 1.5f, 20, 240);
                float w = pmap(vel, 0, 127, 10, 32);

                float hueVal = pmap(pitch, minPitch, maxPitch, 180, 330);
                float satVal = pmap(vel, 0, 127, 40, 100);

                fill(hueVal, satVal, 80, 30);
                rect(x - w * 1.5f, y - h * 1.5f, w * 3, h * 3);

                fill(hueVal, satVal, 100, 100);
                rect(x - w / 2, y - h, w, h);
            }
        }
    }

    void drawKeyboard() {
        float kbTop = height - keyboardHeight;
        float kbLeft = 80;
        float kbRight = width - 80;
        float kbWidth = kbRight - kbLeft;

        float whiteW = kbWidth / (float) whiteKeyCount;

        fill(0, 0, 95);

        for (int p : pitchToWhite.keySet()) {
            int wi = pitchToWhite.get(p);
            float x = kbLeft + wi * whiteW;
            rect(x, kbTop, whiteW, keyboardHeight);
        }
    }
}
