//
//  GestureWindow.m
//  Jitouch
//
//  Copyright 2021 Supasorn Suwajanakorn and Sukolsak Sakshuwong. All rights reserved.
//

#import "GestureWindow.h"
#import "GestureView.h"

@implementation GestureWindow

static float trackpadWidth = 400 + 150;
static float trackpadHeight = 300 + 100;

static float magicMouseWidth = 800;
static float magicMouseHeight = 800;

- (id)init {
    NSSize size = [[NSScreen mainScreen] frame].size;
    self = [super initWithContentRect:NSMakeRect(size.width/2 - trackpadWidth/2, size.height/2 - trackpadHeight/2, trackpadWidth, trackpadHeight) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    if (self != nil) {
        self.alphaValue = 1.0;
        self.opaque = NO;
        self.backgroundColor = [NSColor clearColor];

        gestureView = [[GestureView alloc] initWithFrame:[self frame]];
        [self setContentView:gestureView];
    }
    return self;
}
- (void)setUpWindowForTrackpad {
    NSArray *arr = [NSScreen screens];
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint location = CGEventGetUnflippedLocation(ourEvent);
    CFRelease(ourEvent);

    NSRect scr;
    NSPoint orig;
    NSSize size;
    int isIn = 0;
    for (int i = 0; i<[arr count]; i++) {
        scr = [[arr objectAtIndex:i] frame];
        orig = scr.origin;
        size = scr.size;

        if (location.x >= orig.x && location.x <= orig.x + size.width &&
           location.y >= orig.y && location.y <= orig.y + size.height) {
            isIn = i;
            break;
        }
    }
    scr = [[arr objectAtIndex:isIn] frame];
    orig = scr.origin;
    size = scr.size;
    gestureView.pad = 0;
    [self setFrame:NSMakeRect(orig.x+size.width/2 - trackpadWidth/2, orig.y+size.height/2 - trackpadHeight/2, trackpadWidth, trackpadHeight) display:YES];
}
// Fingertip drawing on the Magic Mouse: same height as the trackpad box, but as narrow as the mouse surface
// (sensor is 10 x 15), so a letter on screen has the proportions your finger drew. GestureView keeps a
// 180 x 130 margin for the start ring and hint text, so only the drawing area gets the mouse's shape.
- (void)setUpWindowForMouseSurface {
    [self setUpWindowForTrackpad]; // picks the screen under the pointer and centers on it
    NSRect f = [self frame];
    float width = (trackpadHeight - 130) * (10.0f / 15.0f) + 180;
    float pad = 30; // the star and its glow reach ~30 px past the fingertip
    gestureView.pad = pad;
    [self setFrame:NSMakeRect(f.origin.x + (f.size.width - width) / 2 - pad, f.origin.y - pad, width + 2 * pad, f.size.height + 2 * pad) display:YES];
}
// Same box, moved so the first touch (x, y) lands under the pointer; kept on the pointer's screen.
// The math mirrors GestureView addPointX: (15 px margin, 180 x 130 total margin, 100 px hint gap).
- (void)setUpWindowForMouseSurfaceAtX:(float)x Y:(float)y {
    [self setUpWindowForMouseSurface];
    NSRect f = [self frame];
    CGEventRef ev = CGEventCreate(NULL);
    CGPoint loc = CGEventGetUnflippedLocation(ev);
    CFRelease(ev);
    float pad = gestureView.pad;
    f.origin.x = loc.x - (x * (f.size.width - 180 - 2 * pad) + 15 + pad);
    f.origin.y = loc.y - (y * (f.size.height - 130 - 2 * pad) + 115 + pad);
    for (NSScreen *s in [NSScreen screens]) {
        NSRect r = [s frame];
        if (!NSPointInRect(loc, r)) continue;
        f.origin.x = MAX(r.origin.x, MIN(f.origin.x, NSMaxX(r) - f.size.width));
        f.origin.y = MAX(r.origin.y, MIN(f.origin.y, NSMaxY(r) - f.size.height));
        break;
    }
    [self setFrame:f display:YES];
}
- (void)setUpWindowForMagicMouse {
    CGEventRef ourEvent = CGEventCreate(NULL);
    CGPoint ourLoc = CGEventGetUnflippedLocation(ourEvent);
    CFRelease(ourEvent);
    [self setFrame:NSMakeRect(ourLoc.x - magicMouseWidth/2, ourLoc.y - magicMouseHeight/2, magicMouseWidth, magicMouseHeight) display:YES];

}
- (void)setPossibleAlphabet:(NSString*)a {
    [tf setStringValue:a];
}

- (void)drawRect:(NSRect)dirtyRect {
}

- (void)addPointX:(float)x Y:(float)y {
    [gestureView addPointX:x Y:y];
}
- (void)addRelativePointX:(float)x Y:(float)y {
    [gestureView addRelativePointX:x Y:y];
}
- (void)breakStroke {
    [gestureView breakStroke];
}
- (void)dropLastPoints:(int)n {
    [gestureView dropLastPoints:n];
}

- (void)clear {
    [gestureView clear];
}

- (void)refresh {
    [gestureView setNeedsDisplay:YES];
}
- (void)setHintText:(const char*)str {
    [gestureView setHintText:str];
    [self refresh];
}

- (void)dealloc {
    [tf release];
    [super dealloc];
}

@end
