// Feeds synthetic Magic Mouse touch frames into magicMouseFingerRecognizer and checks what it recognizes.
// Run: tests/run.sh   (exit 0 = all pass)
#import <Cocoa/Cocoa.h>
static NSString *jtTestRecognized;
#define JITOUCH_TEST 1
#include "../jitouch/Jitouch/Gesture.m"

static const double FRAME = 0.01; // 100 Hz, close to the real touch frame rate
static double now = 1000;
static int failures = 0;

typedef struct { float x, y; } P;

static Finger touch(int ident, float x, float y) {
    Finger f;
    memset(&f, 0, sizeof f);
    f.identifier = ident;
    f.state = MTTouchStateTouching;
    f.px = x;
    f.py = y;
    f.size = 1.0f;
    return f;
}

// One frame: the drawing finger (if down) plus any extra resting touches such as a thumb.
static void frame(int fingerDown, P p, const Finger *extra, int nExtra) {
    Finger d[4];
    int n = 0;
    if (fingerDown) d[n++] = touch(1, p.x, p.y);
    for (int i = 0; i < nExtra; i++) d[n++] = extra[i];
    magicMouseFingerRecognizer(d, n, now);
    now += FRAME;
}

static void idle(double secs, const Finger *extra, int nExtra) {
    for (double t = 0; t < secs; t += FRAME) frame(0, (P){0, 0}, extra, nExtra);
}

// Finger lands and stays still long enough to arm a letter (0.6 s), then draws without lifting.
static void hold(P p, const Finger *extra, int nExtra) {
    for (int i = 0; i < 60; i++) frame(1, p, extra, nExtra);
}

static void tap(P p, const Finger *extra, int nExtra) {
    for (int i = 0; i < 6; i++) frame(1, p, extra, nExtra); // 60 ms touch
    idle(0.08, extra, nExtra);                              // 80 ms gap
}

// Draws straight segments through the points, `perSeg` frames each, finger held down throughout.
static void stroke(const P *pts, int n, int perSeg, const Finger *extra, int nExtra) {
    frame(1, pts[0], extra, nExtra);
    for (int s = 0; s + 1 < n; s++)
        for (int i = 1; i <= perSeg; i++) {
            float t = (float)i / perSeg;
            frame(1, (P){pts[s].x + (pts[s + 1].x - pts[s].x) * t, pts[s].y + (pts[s + 1].y - pts[s].y) * t}, extra, nExtra);
        }
}

static void reset(void) {
    [jtTestRecognized release];
    jtTestRecognized = nil;
    idle(1.0, NULL, 0); // long gap so no state leaks between cases
}

static void clr(void) { [jtTestRecognized release]; jtTestRecognized = nil; }
static void hold_for(int frames, P p) { for (int i = 0; i < frames; i++) frame(1, p, NULL, 0); }

static void expect(const char *name, const char *want) {
    const char *got = jtTestRecognized ? [jtTestRecognized UTF8String] : "(nothing)";
    int ok = strcmp(got, want) == 0 && !isMMFingerRecognizing && !mmCursorHidden; // the pointer always comes back
    if (!ok) failures++;
    printf("%s  %-44s want %-10s got %s%s\n", ok ? "PASS" : "FAIL", name, want, got,
           isMMFingerRecognizing ? " (still blocking scroll!)" : "");
}

// A check on state, not just on what was recognized: a false condition always fails.
static void expect_if(int ok, const char *name, const char *want) { expect(name, ok ? want : "CHECK FAILED"); }

static const P L_[] = {{0.40, 0.85}, {0.40, 0.45}, {0.68, 0.45}};
static const P Z_[] = {{0.35, 0.85}, {0.65, 0.85}, {0.35, 0.45}, {0.65, 0.45}};

static void drawLetter(const P *pts, int n, const Finger *extra, int nExtra) {
    hold(pts[0], extra, nExtra);
    stroke(pts, n, 15, extra, nExtra);
    idle(0.6, extra, nExtra); // lift
}

// Multi-stroke shapes are written in physical proportions; the sensor is 10 x 15, so widen x by 15/10
// around the middle to get the normalized coordinates the mouse would report.
static void drawStrokes(const P *const *strokes, const int *lens, int nStrokes) {
    P wide[8][8];
    for (int i = 0; i < nStrokes; i++)
        for (int j = 0; j < lens[i]; j++)
            wide[i][j] = (P){0.5f + (strokes[i][j].x - 0.5f) * 1.5f, strokes[i][j].y};
    hold(wide[0][0], NULL, 0);
    for (int i = 0; i < nStrokes; i++) {
        stroke(wide[i], lens[i], 12, NULL, 0);
        idle(i + 1 < nStrokes ? 0.25 : 0.6, NULL, 0); // pen lift between strokes, then the end-of-letter wait
    }
}

static void drawO(void) {
    P pts[41];
    for (int i = 0; i <= 40; i++) { // counterclockwise from the top, like the "O" template
        float a = M_PI / 2 + 2 * M_PI * i / 40;
        pts[i] = (P){0.5 + 0.18 * cosf(a), 0.65 + 0.2 * sinf(a)};
    }
    hold(pts[0], NULL, 0);
    stroke(pts, 41, 2, NULL, 0);
    idle(0.6, NULL, 0);
}


// The whole alphabet, drawn through the real recognizer (hold, draw, lift between strokes, fire). Shapes are written
// in a unit box (y up) independently of the templates in PDollar.m, then drawn narrow / normal / wide, upright and
// slanted, at a handwriting-like height. Returns how many drawings read as the wrong letter or as nothing.
typedef struct { int n; P p[24]; } AlphaStroke;
typedef struct { const char *letter; int nStrokes; AlphaStroke st[4]; } AlphaForm;
static const AlphaForm alphabet[] = {
    {"A", 3, {{2, {{0.000, 0.000}, {0.500, 1.000}}}, {2, {{0.500, 1.000}, {1.000, 0.000}}}, {2, {{0.220, 0.420}, {0.780, 0.420}}}}},
    {"B", 2, {{2, {{0.000, 0.000}, {0.000, 1.000}}}, {9, {{0.000, 1.000}, {0.550, 0.970}, {0.720, 0.800}, {0.550, 0.530}, {0.000, 0.520}, {0.650, 0.470}, {0.800, 0.250}, {0.620, 0.020}, {0.000, 0.000}}}}},
    {"C", 1, {{8, {{0.950, 0.850}, {0.600, 1.000}, {0.250, 0.900}, {0.030, 0.550}, {0.100, 0.200}, {0.400, 0.000}, {0.750, 0.050}, {0.950, 0.200}}}}},
    {"D", 2, {{2, {{0.000, 0.000}, {0.000, 1.000}}}, {6, {{0.000, 1.000}, {0.500, 0.950}, {0.850, 0.650}, {0.850, 0.350}, {0.500, 0.050}, {0.000, 0.000}}}}},
    {"E", 2, {{4, {{0.800, 1.000}, {0.000, 1.000}, {0.000, 0.000}, {0.800, 0.000}}}, {2, {{0.000, 0.500}, {0.600, 0.500}}}}},
    {"F", 2, {{3, {{0.000, 0.000}, {0.000, 1.000}, {0.750, 1.000}}}, {2, {{0.000, 0.520}, {0.550, 0.520}}}}},
    {"G", 1, {{9, {{0.950, 0.850}, {0.600, 1.000}, {0.200, 0.880}, {0.020, 0.500}, {0.150, 0.120}, {0.500, 0.000}, {0.900, 0.150}, {0.920, 0.450}, {0.550, 0.450}}}}},
    {"H", 3, {{2, {{0.000, 1.000}, {0.000, 0.000}}}, {2, {{0.800, 1.000}, {0.800, 0.000}}}, {2, {{0.000, 0.550}, {0.800, 0.550}}}}},
    {"I", 3, {{2, {{0.100, 1.000}, {0.700, 1.000}}}, {2, {{0.400, 1.000}, {0.400, 0.000}}}, {2, {{0.100, 0.000}, {0.700, 0.000}}}}},
    {"J", 1, {{6, {{0.750, 1.000}, {0.750, 0.350}, {0.650, 0.080}, {0.400, 0.000}, {0.150, 0.080}, {0.050, 0.300}}}}},
    {"K", 2, {{2, {{0.000, 1.000}, {0.000, 0.000}}}, {3, {{0.750, 1.000}, {0.050, 0.450}, {0.800, 0.000}}}}},
    {"L", 1, {{3, {{0.000, 1.000}, {0.000, 0.000}, {0.700, 0.000}}}}},
    {"L", 2, {{2, {{0.000, 1.000}, {0.000, 0.000}}}, {2, {{0.000, 0.000}, {0.700, 0.000}}}}},
    {"M", 1, {{5, {{0.000, 0.000}, {0.050, 1.000}, {0.450, 0.300}, {0.850, 1.000}, {0.900, 0.000}}}}},
    {"M", 3, {{2, {{0.000, 0.000}, {0.000, 1.000}}}, {3, {{0.000, 1.000}, {0.450, 0.300}, {0.900, 1.000}}}, {2, {{0.900, 1.000}, {0.900, 0.000}}}}},
    {"N", 1, {{4, {{0.000, 0.000}, {0.000, 1.000}, {0.750, 0.000}, {0.750, 1.000}}}}},
    {"N", 3, {{2, {{0.000, 0.000}, {0.000, 1.000}}}, {2, {{0.000, 1.000}, {0.750, 0.000}}}, {2, {{0.750, 0.000}, {0.750, 1.000}}}}},
    {"O", 1, {{17, {{0.500, 1.000}, {0.309, 0.962}, {0.146, 0.854}, {0.038, 0.691}, {0.000, 0.500}, {0.038, 0.309}, {0.146, 0.146}, {0.309, 0.038}, {0.500, 0.000}, {0.691, 0.038}, {0.854, 0.146}, {0.962, 0.309}, {1.000, 0.500}, {0.962, 0.691}, {0.854, 0.854}, {0.691, 0.962}, {0.500, 1.000}}}}},
    {"P", 2, {{2, {{0.000, 0.000}, {0.000, 1.000}}}, {5, {{0.000, 1.000}, {0.550, 0.980}, {0.750, 0.800}, {0.600, 0.550}, {0.000, 0.500}}}}},
    {"P", 1, {{6, {{0.000, 0.000}, {0.000, 1.000}, {0.550, 0.980}, {0.750, 0.800}, {0.600, 0.550}, {0.000, 0.500}}}}},
    {"Q", 2, {{17, {{0.500, 1.000}, {0.309, 0.962}, {0.146, 0.854}, {0.038, 0.691}, {0.000, 0.500}, {0.038, 0.309}, {0.146, 0.146}, {0.309, 0.038}, {0.500, 0.000}, {0.691, 0.038}, {0.854, 0.146}, {0.962, 0.309}, {1.000, 0.500}, {0.962, 0.691}, {0.854, 0.854}, {0.691, 0.962}, {0.500, 1.000}}}, {2, {{0.550, 0.300}, {0.950, 0.000}}}}},
    {"R", 2, {{2, {{0.000, 0.000}, {0.000, 1.000}}}, {6, {{0.000, 1.000}, {0.550, 0.980}, {0.750, 0.800}, {0.600, 0.550}, {0.000, 0.500}, {0.750, 0.000}}}}},
    {"S", 1, {{9, {{0.850, 0.880}, {0.500, 1.000}, {0.120, 0.900}, {0.100, 0.650}, {0.450, 0.500}, {0.850, 0.350}, {0.880, 0.100}, {0.500, 0.000}, {0.100, 0.120}}}}},
    {"T", 2, {{2, {{0.000, 1.000}, {0.900, 1.000}}}, {2, {{0.450, 1.000}, {0.450, 0.000}}}}},
    {"U", 1, {{7, {{0.000, 1.000}, {0.000, 0.300}, {0.150, 0.050}, {0.400, 0.000}, {0.650, 0.050}, {0.800, 0.300}, {0.800, 1.000}}}}},
    {"V", 1, {{3, {{0.000, 1.000}, {0.450, 0.000}, {0.900, 1.000}}}}},
    {"V", 2, {{2, {{0.000, 1.000}, {0.450, 0.000}}}, {2, {{0.450, 0.000}, {0.900, 1.000}}}}},
    {"W", 1, {{5, {{0.000, 1.000}, {0.220, 0.000}, {0.450, 0.700}, {0.680, 0.000}, {0.900, 1.000}}}}},
    {"X", 2, {{2, {{0.000, 1.000}, {0.850, 0.000}}}, {2, {{0.850, 1.000}, {0.000, 0.000}}}}},
    {"Y", 2, {{2, {{0.000, 1.000}, {0.450, 0.500}}}, {3, {{0.900, 1.000}, {0.450, 0.500}, {0.450, 0.000}}}}},
    {"Z", 1, {{4, {{0.000, 1.000}, {0.800, 1.000}, {0.000, 0.000}, {0.850, 0.000}}}}},
};
static int alphabetTest(int verbose) {
    const float widths[] = {0.55f, 0.75f, 1.0f}, shears[] = {0, 0.15f};
    int bad = 0, total = 0;
    for (size_t k = 0; k < sizeof alphabet / sizeof alphabet[0]; k++) {
        const AlphaForm *a = &alphabet[k];
        char misses[200] = "";
        int ok = 0, n = 0;
        for (int w = 0; w < 3; w++)
            for (int h = 0; h < 2; h++) {
                P out[4][24];
                for (int i = 0; i < a->nStrokes; i++)
                    for (int j = 0; j < a->st[i].n; j++) {
                        float u = a->st[i].p[j].x + shears[h] * (a->st[i].p[j].y - 0.5f), v = a->st[i].p[j].y;
                        out[i][j] = (P){0.5f + (u - 0.5f) * widths[w] * 0.40f * 1.5f, 0.42f + v * 0.40f}; // 10 x 15 sensor
                    }
                reset();
                hold(out[0][0], NULL, 0);
                for (int i = 0; i < a->nStrokes; i++) {
                    stroke(out[i], a->st[i].n, a->st[i].n > 3 ? 4 : 12, NULL, 0);
                    idle(i + 1 < a->nStrokes ? 0.25 : 0.8, NULL, 0);
                }
                const char *got = jtTestRecognized ? [jtTestRecognized UTF8String] : "-";
                n++;
                if (strcmp(got, a->letter) == 0) ok++;
                else snprintf(misses + strlen(misses), sizeof misses - strlen(misses), " %s(w%.2f%s)", got, widths[w], h ? " slant" : "");
            }
        total += n;
        bad += n - ok;
        if (verbose || ok < n) printf("%s  %s %d-stroke: %d/%d%s\n", ok == n ? "PASS" : "FAIL", a->letter, a->nStrokes, ok, n, misses);
    }
    printf("      alphabet: %d of %d drawings read correctly\n", total - bad, total);
    return bad;
}

int main(void) {
    @autoreleasepool {
        initNormPdf();
        initChars();
        clickSpeed = 0.25f; // Jitouch default (Settings.m)
        enCharRegMM = 1;

        if (getenv("JT_ALPHABET_ONLY")) return alphabetTest(1) ? 1 : 0; // tests/run.sh: with your trained letters
        if (getenv("JT_PERSONAL_TEST")) { // JITOUCH_LETTERS holds 3 zig-zag "Q" examples (tests/run.sh)
            static const P zz[] = {{0.35, 0.80}, {0.60, 0.70}, {0.35, 0.60}, {0.60, 0.50}, {0.35, 0.40}};
            reset(); drawLetter(zz, 5, NULL, 0); expect("one stroke matches your trained letter", "Q");
            static const P line[] = {{0.50, 0.40}, {0.50, 0.85}};
            reset(); drawLetter(line, 2, NULL, 0); expect("straight stroke still ignored with training", "(nothing)");
            reset(); drawLetter(L_, 3, NULL, 0); expect("built-in one-stroke L still works with training", "L");
            printf(failures ? "\n%d FAILED\n" : "\nALL PASSED\n", failures);
            return failures ? 1 : 0;
        }

        reset(); drawLetter(L_, 3, NULL, 0);                      expect("hold, then draw L", "L");
        reset(); drawLetter(Z_, 4, NULL, 0);                      expect("hold, then draw Z", "Z");
        reset(); drawO();                                         expect("hold, then draw O", "O");

        static const P N_[] = {{0.35, 0.45}, {0.35, 0.85}, {0.65, 0.45}, {0.65, 0.85}};
        static const P up[] = {{0.50, 0.40}, {0.50, 0.85}};
        static const P down[] = {{0.50, 0.85}, {0.50, 0.40}};
        static const P S_[] = {{0.62, 0.88}, {0.40, 0.74}, {0.60, 0.58}, {0.40, 0.44}, {0.30, 0.44}};
        reset(); drawLetter(S_, 5, NULL, 0);                      expect("hold, then draw S (screenshot)", "S");
        static const P G_[] = {{0.62, 0.85}, {0.40, 0.65}, {0.55, 0.42}, {0.68, 0.56}, {0.52, 0.56}};
        static const P M_[] = {{0.30, 0.45}, {0.38, 0.85}, {0.47, 0.55}, {0.56, 0.85}, {0.64, 0.45}};
        static const P Y_[] = {{0.35, 0.85}, {0.48, 0.62}, {0.61, 0.85}, {0.40, 0.45}};
        reset(); drawLetter(G_, 5, NULL, 0);                      expect("hold, then draw G", "G");
        reset(); drawLetter(M_, 5, NULL, 0);                      expect("hold, then draw M", "M");
        reset(); drawLetter(Y_, 4, NULL, 0);                      expect("hold, then draw Y", "Y");
        reset(); drawLetter(N_, 4, NULL, 0);                      expect("hold, then draw N (New)", "N");
        reset(); drawLetter(up, 2, NULL, 0);                      expect("straight stroke up is ignored (scroll-like)", "(nothing)");
        reset(); drawLetter(down, 2, NULL, 0);                    expect("straight stroke down is ignored (scroll-like)", "(nothing)");

        // Multi-stroke letters, written the normal way.
        { static const P a[] = {{0.40, 0.85}, {0.40, 0.45}}, b[] = {{0.40, 0.85}, {0.65, 0.85}}, c[] = {{0.40, 0.65}, {0.58, 0.65}};
          const P *st[] = {a, b, c}; const int ln[] = {2, 2, 2};
          reset(); drawStrokes(st, ln, 3); expect("multi-stroke F (3 strokes)", "F"); }
        { static const P a[] = {{0.35, 0.85}, {0.65, 0.85}}, b[] = {{0.50, 0.85}, {0.50, 0.45}};
          const P *st[] = {a, b}; const int ln[] = {2, 2};
          reset(); drawStrokes(st, ln, 2); expect("multi-stroke T (2 strokes)", "T"); }
        { static const P a[] = {{0.35, 0.85}, {0.35, 0.45}}, b[] = {{0.65, 0.85}, {0.65, 0.45}}, c[] = {{0.35, 0.65}, {0.65, 0.65}};
          const P *st[] = {a, b, c}; const int ln[] = {2, 2, 2};
          reset(); drawStrokes(st, ln, 3); expect("multi-stroke H (3 strokes)", "H"); }
        { static const P a[] = {{0.40, 0.85}, {0.40, 0.45}}, b[] = {{0.40, 0.85}, {0.65, 0.85}}, c[] = {{0.40, 0.65}, {0.60, 0.65}}, d[] = {{0.40, 0.45}, {0.65, 0.45}};
          const P *st[] = {a, b, c, d}; const int ln[] = {2, 2, 2, 2};
          reset(); drawStrokes(st, ln, 4); expect("multi-stroke E (4 strokes)", "E"); }
        { static const P a[] = {{0.35, 0.85}, {0.65, 0.45}}, b[] = {{0.65, 0.85}, {0.35, 0.45}};
          const P *st[] = {a, b}; const int ln[] = {2, 2};
          reset(); drawStrokes(st, ln, 2); expect("multi-stroke X (2 strokes)", "X"); }

        // Known misses (printed above): a 2-stroke F drawn wide reads as P, and a very narrow 3-stroke N trips the
        // parallel-flick guard. Fail only on a regression below today's 183 of 186.
        if (alphabetTest(0) > 3) failures++;

        // Must NOT trigger.
        reset(); stroke(L_, 3, 15, NULL, 0); idle(0.6, NULL, 0); expect("no hold first (normal scroll)", "(nothing)");
        reset(); tap(L_[0], NULL, 0); idle(0.6, NULL, 0);         expect("one-finger tap (click)", "Click");
        reset(); tap(L_[0], NULL, 0); tap(L_[0], NULL, 0);        expect("two quick taps (double click)", "Double Click");
        reset(); jtTestButtonDown = 1; tap(L_[0], NULL, 0); jtTestButtonDown = 0;
        expect("tap that was a real button press (no extra click)", "(nothing)");
        reset(); mmLastScrollWall = CFAbsoluteTimeGetCurrent(); tap(L_[0], NULL, 0); mmLastScrollWall = 0;
        expect("tap while scrolling (no click)", "(nothing)");
        reset();
        for (int i = 0; i < 40; i++) frame(1, L_[0], NULL, 0);    // 400 ms touch: a rest, not a tap
        idle(0.08, NULL, 0); stroke(L_, 3, 15, NULL, 0); idle(0.6, NULL, 0);
        expect("slow first touch", "(nothing)");
        reset();
        hold(L_[0], NULL, 0); stroke(L_, 2, 15, NULL, 0);
        { Finger second = touch(2, 0.6, 0.7); frame(1, L_[1], &second, 1); }
        idle(0.6, NULL, 0);
        expect("second finger lands mid-letter (cancel)", "(nothing)");
        { Finger two = touch(2, 0.6, 0.7); // second finger next to the first
          reset(); for (int i = 0; i < 8; i++) frame(1, L_[0], &two, 1); idle(0.3, NULL, 0);
          expect("two-finger tap (right click)", "Right Click");
          reset(); for (int i = 0; i < 50; i++) frame(1, L_[0], &two, 1); idle(0.3, NULL, 0);
          expect("two fingers resting 0.5 s (no right click)", "(nothing)"); }
        reset(); for (int i = 0; i < 200; i++) frame(1, L_[0], NULL, 0); stroke(L_, 3, 15, NULL, 0); idle(0.6, NULL, 0);
        expect("finger resting 2 s, then moves (scroll)", "(nothing)");
        reset(); hold(L_[0], NULL, 0); idle(0.6, NULL, 0);
        expect("armed, lifted without drawing", "(nothing)");
        reset(); tap(L_[0], NULL, 0); frame(1, L_[0], NULL, 0); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0);
        expect("tap, touch again, mouse moves (drag at once)", "Drag");
        for (int i = 0; i < 20; i++) { jtTestPointer.x += 10; frame(1, L_[0], NULL, 0); }
        { CGPoint at = jtTestPointer; frame(0, L_[0], NULL, 0); // lift: released on this frame, where the cursor is
          expect_if(mmLiftPtr.x == at.x && mmDragging == 0, "lift: released at once, at the cursor", "Drag released"); }
        { mmDragScrollSum = 0; int jitter = 0, slide = 0;
          for (int i = 0; i < 5; i++) jitter += mmDragScrollPasses(1.5, 0.5); // resting finger: 10 points total
          for (int i = 0; i < 3; i++) slide += mmDragScrollPasses(6, 0);       // deliberate slide
          int ok = jitter == 0 && slide >= 1;
          if (!ok) failures++;
          printf("%s  %-44s jitter passed %d, slide passed %d\n", ok ? "PASS" : "FAIL",
                 "scroll during drag: jitter held, slide passes", jitter, slide); }
        clr(); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0);
        expect("finger flickers back while the mouse moves (re-grab)", "Drag");
        idle(0.3, NULL, 0);
        reset(); tap(L_[0], NULL, 0); idle(0.4, NULL, 0); frame(1, L_[0], NULL, 0); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0);
        expect("tap, touch again 0.5 s later, mouse moves (drag)", "Drag");
        idle(0.3, NULL, 0);
        reset(); tap(L_[0], NULL, 0); idle(0.4, NULL, 0); tap(L_[0], NULL, 0);
        expect("two taps 0.5 s apart (two clicks, not double)", "Click");
        reset(); tap(L_[0], NULL, 0); idle(0.8, NULL, 0); frame(1, L_[0], NULL, 0); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0); idle(0.3, NULL, 0);
        expect("touch 0.9 s after a tap, mouse moves at once (one-touch drag)", "Drag released");
        reset(); hold(L_[0], NULL, 0); jtTestPointer.x += 30; frame(1, L_[0], NULL, 0); idle(0.6, NULL, 0);
        expect("armed dot, then mouse moves (no drag)", "(nothing)");
        reset(); frame(1, L_[0], NULL, 0); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0);
        expect("finger lands, mouse moves at once (one-touch drag)", "Drag");
        idle(0.3, NULL, 0); expect("lift after one-touch drag", "Drag released");
        reset(); mmLastMoveWall = CFAbsoluteTimeGetCurrent(); frame(1, L_[0], NULL, 0);
        for (int i = 0; i < 60; i++) { jtTestPointer.x += 1; frame(1, L_[0], NULL, 0); }
        idle(0.3, NULL, 0); mmLastMoveWall = 0;
        expect("finger lands mid-sweep, mouse keeps moving (drag: how you grab windows)", "Drag released");
        reset(); for (int i = 0; i < 40; i++) frame(1, L_[0], NULL, 0); jtTestPointer.x += 10; frame(1, L_[0], NULL, 0); idle(0.3, NULL, 0);
        expect("mouse moves 0.4 s after landing (too late, no drag)", "(nothing)");

        // Gesture-collision edge cases (independent review, 2026-11-10).
        { P a = {0.5, 0.6};
          reset(); frame(1, (P){0.20, 0.5}, NULL, 0); frame(1, (P){0.14, 0.5}, NULL, 0); hold_for(3, (P){0.12, 0.5}); idle(0.3, NULL, 0);
          expect("finger slides into the edge zone (no click)", "(nothing)");
          reset(); hold_for(15, a); idle(0.08, NULL, 0); hold_for(15, a); idle(0.3, NULL, 0);
          expect("double tap, 150 ms touches, 80 ms gap", "Double Click");
          reset(); tap(L_[0], NULL, 0); drawLetter(L_, 3, NULL, 0);
          expect("tap, then hold and draw L within 0.6 s", "L");
          reset(); tap(a, NULL, 0); frame(1, a, NULL, 0); jtTestPointer.x += 4; hold_for(5, a); idle(0.3, NULL, 0);
          expect("double tap with 4 px pointer drift", "Double Click");
          reset(); frame(1, a, NULL, 0); jtTestPointer.x += 4; hold_for(5, a); idle(0.3, NULL, 0);
          expect("single tap with 4 px pointer drift", "Click");
          reset(); tap(a, NULL, 0); clr(); mmLastScrollWall = CFAbsoluteTimeGetCurrent(); tap(a, NULL, 0); mmLastScrollWall = 0;
          expect("tap, then a tap while scrolling", "(nothing)");
          reset(); frame(1, a, NULL, 0); jtTestPointer.x += 10; hold_for(5, a); idle(0.3, NULL, 0); clr(); idle(1.0, NULL, 0);
          { Finger th = touch(1, 0.05, 0.40); for (int i = 0; i < 6; i++) { magicMouseFingerRecognizer(&th, 1, now); now += FRAME; } idle(0.3, NULL, 0); }
          expect("edge thumb with a reused id taps after a drag", "(nothing)"); }

        // Drag state machine edge cases (independent review, 2026-11-10).
        { P a = {0.5, 0.6};
          // A second finger lands mid-drag, then the drag finger lifts: the button must come up anyway.
          reset(); frame(1, a, NULL, 0); jtTestPointer.x += 10; hold_for(5, a);
          { Finger second = touch(2, 0.55, 0.7);
            for (int i = 0; i < 5; i++) frame(1, a, &second, 1);          // both fingers down
            for (int i = 0; i < 30; i++) { magicMouseFingerRecognizer(&second, 1, now); now += FRAME; } } // drag finger up
          expect("second finger stays after the drag finger lifts (release)", "Drag released");
          idle(0.3, NULL, 0);
          // A real button press mid-drag: hand over quietly (no release of our own), drag mode off.
          reset(); frame(1, a, NULL, 0); jtTestPointer.x += 10; hold_for(5, a);
          mmHwPress = 1; hold_for(2, a);
          expect_if(mmDragging == 0 && mmStep == 0, "real click mid-drag (hands over, no stray release)", "Drag");
          idle(0.3, NULL, 0);
          // Two-finger tap while dragging must not right-click.
          reset(); frame(1, a, NULL, 0); jtTestPointer.x += 10; frame(1, a, NULL, 0);
          { Finger second = touch(2, 0.55, 0.7); for (int i = 0; i < 3; i++) frame(1, a, &second, 1); }
          idle(0.3, NULL, 0);
          expect("two-finger tap during a drag (no right click)", "Drag released"); }

        // Volume strip: the very front of the mouse (y >= 0.85). Slide sideways there; everything else stays normal.
        { static const P right[] = {{0.40, 0.92}, {0.70, 0.92}}, left[] = {{0.60, 0.92}, {0.30, 0.92}};
          static const P midSlide[] = {{0.40, 0.60}, {0.70, 0.60}}, upFromTop[] = {{0.50, 0.92}, {0.50, 0.50}};
          reset(); stroke(right, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("front strip, slide right (volume up)", "Volume Up");
          reset(); stroke(left, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("front strip, slide left (volume down)", "Volume Down");
          reset(); tap(right[0], NULL, 0); idle(0.6, NULL, 0);
          expect("front strip, tap (still a click)", "Click");
          reset(); stroke(midSlide, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("sideways slide lower down (no volume)", "(nothing)");
          reset(); stroke(upFromTop, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("front strip, slide toward you (no volume)", "(nothing)");
          // Scroll is held back while a front-strip touch is undecided, and released once it isn't volume.
          reset(); frame(1, right[0], NULL, 0); frame(1, right[0], NULL, 0);
          { int held = mmStripPending;
            static const P down40[] = {{0.40, 0.92}, {0.40, 0.50}}; // straight toward you from where it landed
            stroke(down40, 2, 15, NULL, 0);
            int released = !mmStripPending && !isMMFingerRecognizing;
            idle(0.3, NULL, 0);
            expect_if(held && released, "strip touch holds scroll, then releases it (scroll toward you)", "(nothing)"); }
          // Smooth: a long slide reaches the top, and no single touch frame jumps the volume by more than 6 points.
          reset(); { static const P wide[] = {{0.10, 0.92}, {0.90, 0.92}}; stroke(wide, 2, 40, NULL, 0); }
          { float level = mmVolLevel, jump = mmVolMaxJump; idle(0.3, NULL, 0);
            printf("      (level %.2f, biggest one-frame change %.3f)\n", level, jump);
            expect_if(level >= 0.999f && jump <= 0.06f, "full-width slide: reaches 100%, smoothly", "Volume Up"); }
          // A quick flick still moves the volume smoothly, not in one jump.
          reset(); { static const P flick[] = {{0.30, 0.92}, {0.60, 0.92}}; stroke(flick, 2, 3, NULL, 0); hold_for(10, flick[1]); }
          { float level = mmVolLevel, jump = mmVolMaxJump; idle(0.3, NULL, 0);
            printf("      (flick: level %.2f, biggest one-frame change %.3f)\n", level, jump);
            expect_if(level > 0.75f && jump <= 0.06f, "quick flick: eased, no jump", "Volume Up"); }
          // Lifting mid-ease still lands exactly where the finger stopped.
          reset(); { static const P flick[] = {{0.30, 0.92}, {0.60, 0.92}}; stroke(flick, 2, 3, NULL, 0); }
          frame(0, (P){0, 0}, NULL, 0);
          { float level = mmVolLevel; idle(0.3, NULL, 0);
            expect_if(fabsf(level - 0.80f) < 0.01f, "lift mid-ease: lands where the finger stopped", "Volume Up"); }
          // A second finger ends the volume slide.
          reset(); stroke(right, 2, 15, NULL, 0);
          { Finger second = touch(2, 0.5, 0.6); frame(1, right[1], &second, 1); int ended = mmStep == 0 && !isMMFingerRecognizing;
            idle(0.3, NULL, 0); expect_if(ended, "second finger ends a volume slide", "Volume Up"); } }
        // Other edges: off by default. Stepped sliders send one step per stretch of travel, direction by slide.
        { static const P leftFwd[] = {{0.06, 0.65}, {0.06, 0.95}}, backRight[] = {{0.30, 0.05}, {0.70, 0.05}},
                         rightFwd[] = {{0.94, 0.65}, {0.94, 0.95}}, thumb[] = {{0.06, 0.20}, {0.06, 0.50}};
          reset(); stroke(leftFwd, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("left edge off: slide forward does nothing", "(nothing)");
          mmEdgeMode[1] = 4; mmEdgeMode[2] = 3; mmEdgeMode[3] = 1;
          reset(); stroke(leftFwd, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("left edge, tabs: slide forward (next tab)", "Tab +");
          reset(); stroke(backRight, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("back edge, zoom: slide right (zoom in)", "Zoom +");
          reset(); stroke(rightFwd, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("right edge, volume: slide forward", "Volume Up");
          reset(); stroke(thumb, 2, 15, NULL, 0); idle(0.3, NULL, 0);
          expect("thumb zone low on the side: not an edge", "(nothing)");
          { static const P backLeft[] = {{0.70, 0.05}, {0.30, 0.05}};
            reset(); stroke(backLeft, 2, 15, NULL, 0); idle(0.3, NULL, 0);
            expect("back edge, zoom: slide left (zoom out)", "Zoom -"); }
          mmEdgeMode[1] = mmEdgeMode[2] = mmEdgeMode[3] = 0; }
        // Lifting: a shrinking contact that slides sideways for the last frames is trimmed, so the stroke ends
        // where the finger stopped, not in a hook.
        { static const P down[] = {{0.40, 0.80}, {0.40, 0.45}};
          reset(); hold(down[0], NULL, 0); stroke(down, 2, 15, NULL, 0);
          const float sizes[] = {0.55f, 0.40f, 0.25f};
          for (int i = 0; i < 3; i++) {
              Finger d = touch(1, 0.40f + 0.025f * (i + 1), 0.45f); d.size = sizes[i];
              magicMouseFingerRecognizer(&d, 1, now); now += FRAME;
          }
          frame(0, (P){0, 0}, NULL, 0); // lift
          float endX = mmPts[mmNPts - 1].x / pdollarAspectX;
          printf("      (stroke ends at x %.3f; the finger stopped at 0.400, the hook reached 0.475)\n", endX);
          idle(0.8, NULL, 0);
          expect_if(fabsf(endX - 0.40f) < 0.005f, "lift hook trimmed", jtTestRecognized ? [jtTestRecognized UTF8String] : "(nothing)"); }
        // The early letter shown at the lift is exactly what fires.
        { const P *shapes[] = {L_, Z_}; int counts[] = {3, 4};
          for (int i = 0; i < 2; i++) {
              reset(); mmLastPreview[0] = 0; drawLetter(shapes[i], counts[i], NULL, 0);
              const char *got = jtTestRecognized ? [jtTestRecognized UTF8String] : "";
              expect_if(strcmp(mmLastPreview, got) == 0, i ? "preview matches what fired (Z)" : "preview matches what fired (L)", got[0] ? got : "(nothing)");
          } }
        // The pointer hides once a letter is armed (the dot appears) and is back after the letter ends.
        { static const P lF[] = {{0.40, 0.40}, {0.40, 0.70}, {0.60, 0.70}};
          reset(); hold(lF[0], NULL, 0); stroke(lF, 3, 12, NULL, 0); int hid = mmCursorHidden; idle(0.8, NULL, 0);
          expect_if(hid && !mmCursorHidden, "pointer hidden while drawing, back after", jtTestRecognized ? [jtTestRecognized UTF8String] : "(nothing)"); }

        // Finger slips off for 0.1 s at the corner of an L and lands where it left: still one stroke.
        { static const P back[] = {{0.413, 0.45}, {0.68, 0.45}}; // lands 0.013 away, like the recorded slip
          reset(); hold(L_[0], NULL, 0); stroke(L_, 2, 15, NULL, 0); idle(0.1, NULL, 0); stroke(back, 2, 15, NULL, 0); idle(0.6, NULL, 0); }
        expect("finger slips off mid-stroke, comes back", "L");

        // Scroll and click guards.
        reset(); jtTestButtonDown = 1; hold(L_[0], NULL, 0); jtTestButtonDown = 0; stroke(L_, 3, 15, NULL, 0); idle(0.6, NULL, 0);
        expect("button held down while still (a drag), then move", "(nothing)");
        reset(); mmLastScrollWall = CFAbsoluteTimeGetCurrent(); hold(L_[0], NULL, 0); stroke(L_, 3, 15, NULL, 0); idle(0.6, NULL, 0);
        mmLastScrollWall = 0;
        expect("touch while still scrolling, then stroke", "(nothing)");
        reset(); for (int i = 0; i < 30; i++) frame(1, L_[0], NULL, 0); mmLastScrollWall = CFAbsoluteTimeGetCurrent() + 1;
        hold(L_[0], NULL, 0); stroke(L_, 3, 15, NULL, 0); idle(0.6, NULL, 0);
        mmLastScrollWall = 0;
        expect("scroll event during the hold", "(nothing)");
        { static const P f1[] = {{0.50, 0.40}, {0.50, 0.75}}, f2[] = {{0.52, 0.42}, {0.52, 0.80}}, f3[] = {{0.49, 0.38}, {0.50, 0.72}};
          const P *st[] = {f1, f2, f3}; const int ln[] = {2, 2, 2};
          reset(); drawStrokes(st, ln, 3); expect("tap, then 3 parallel scroll flicks", "(nothing)"); }
        reset(); hold(L_[0], NULL, 0); stroke(L_, 2, 15, NULL, 0); cancelRecognition = 1; stroke(L_ + 1, 2, 15, NULL, 0); idle(0.6, NULL, 0);
        expect("mouse click while drawing cancels", "(nothing)");

        // Real grip: thumb resting on the left side of the mouse the whole time.
        Finger thumb = touch(9, 0.05, 0.40);
        reset(); idle(0.1, &thumb, 1); drawLetter(L_, 3, &thumb, 1); expect("thumb resting on side, draw L", "L");

        static const P edgeL[] = {{0.10, 0.80}, {0.10, 0.35}, {0.40, 0.35}}; // passes through the side "thumb" zone
        reset(); drawLetter(edgeL, 3, NULL, 0); expect("letter drawn along the side edge", "L");

        printf(failures ? "\n%d FAILED\n" : "\nALL PASSED\n", failures);
    }
    return failures ? 1 : 0;
}
