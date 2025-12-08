import processing.core.*;

public class FallingNotesRenderer {
    public static void main(String[] args) {
        if (args.length < 1) {
            System.out.println("Usage: java FallingNotesRenderer <json_file>");
            System.exit(1);
        }

        String jsonPath = args[0];
        System.out.println("Launching renderer with: " + jsonPath);

        FallingNotesSketch.jsonPath = jsonPath;
        String[] sketchArgs = { "FallingNotesSketch" };
        PApplet.runSketch(sketchArgs, new FallingNotesSketch());
    }
}
