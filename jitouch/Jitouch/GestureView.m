//
//  GestureView.m
//  Jitouch
//
//  Copyright 2021 Supasorn Suwajanakorn and Sukolsak Sakshuwong. All rights reserved.
//

#import "GestureView.h"

@implementation GestureView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        points = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor clearColor] set];
    NSRectFill([self frame]);

    CGContextRef context = [[NSGraphicsContext currentContext]graphicsPort];

    if ([points count] > 0) {
        // Chrome ink, after polished sterling silver (Chrome Hearts): a dark edge, contrasting bands so the line reads
        // as polished sterling, rope-twisted below, a white highlight off-center, and a glint sliding along it.
        float minX = 10000, minY = 10000, maxX = -10000, walked = 0;
        BOOL penUp = YES;
        NSPoint last = NSZeroPoint;
        CGMutablePathRef line = CGPathCreateMutable();
        for (NSUInteger i = 0; i < [points count]; i++) {
            NSPoint p = [[points objectAtIndex:i] pointValue];
            if (isnan(p.x)) { penUp = YES; continue; }
            if (penUp) CGPathMoveToPoint(line, NULL, p.x, p.y);
            else { CGPathAddLineToPoint(line, NULL, p.x, p.y); walked += hypotf(p.x - last.x, p.y - last.y); }
            penUp = NO;
            last = p;
            if (p.x < minX) minX = p.x;
            if (p.x > maxX) maxX = p.x;
            if (p.y < minY) minY = p.y;
        }

        const float W = 11; // tube width in points. ponytail: knob
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, CGSizeMake(0, -2), 6, [[NSColor colorWithWhite:0 alpha:0.45] CGColor]);
        CGContextAddPath(context, line);
        CGContextSetLineWidth(context, W + 3);
        CGContextSetRGBStrokeColor(context, 0.10, 0.10, 0.11, 1); // dark edge
        CGContextStrokePath(context);
        CGContextRestoreGState(context);
        // Mirror chrome bands, edge to center: bright rim, the dark reflected horizon, a light core.
        const float bands[][2] = {{W, 0.90f}, {W * 0.64f, 0.28f}, {W * 0.34f, 0.78f}}; // width, gray
        for (int b = 0; b < 3; b++) {
            CGContextAddPath(context, line);
            CGContextSetLineWidth(context, bands[b][0]);
            CGContextSetGrayStrokeColor(context, bands[b][1], 1);
            CGContextStrokePath(context);
        }
        CGContextSaveGState(context); // highlight, nudged up-left like light from above
        CGContextTranslateCTM(context, -W * 0.12f, W * 0.14f);
        CGContextAddPath(context, line);
        CGContextSetLineWidth(context, W * 0.18f);
        CGContextSetGrayStrokeColor(context, 1, 0.95);
        CGContextStrokePath(context);
        CGContextRestoreGState(context);

        // Rope twist, like a sterling cable chain: a blackened groove across the tube every few points, slanted
        // against the direction of travel, with a polished edge beside it. Clipped to the tube.
        CGContextSaveGState(context);
        CGContextAddPath(context, line);
        CGContextSetLineWidth(context, W);
        CGContextReplacePathWithStrokedPath(context);
        CGContextClip(context);
        {
            const float twist = 6.5f, slant = 0.95f; // points between grooves; groove angle off the line (radians)
            float since = 0;
            BOOL up = YES;
            NSPoint q = NSZeroPoint;
            for (NSUInteger i = 0; i < [points count]; i++) {
                NSPoint p = [[points objectAtIndex:i] pointValue];
                if (isnan(p.x)) { up = YES; continue; }
                if (!up) {
                    float seg = hypotf(p.x - q.x, p.y - q.y), dir = atan2f(p.y - q.y, p.x - q.x), t = twist - since;
                    for (; t <= seg; t += twist) {
                        NSPoint c = NSMakePoint(q.x + (p.x - q.x) * t / seg, q.y + (p.y - q.y) * t / seg);
                        float a = dir + slant, dx = cosf(a) * W * 0.75f, dy = sinf(a) * W * 0.75f;
                        float ox = cosf(dir) * 1.6f, oy = sinf(dir) * 1.6f;
                        CGContextSetLineWidth(context, 1.8f);
                        CGContextSetRGBStrokeColor(context, 0.07, 0.07, 0.08, 0.9);
                        CGContextStrokeLineSegments(context, (CGPoint[]){{c.x - dx, c.y - dy}, {c.x + dx, c.y + dy}}, 2);
                        CGContextSetLineWidth(context, 1.0f);
                        CGContextSetGrayStrokeColor(context, 1, 0.75);
                        CGContextStrokeLineSegments(context, (CGPoint[]){{c.x - dx + ox, c.y - dy + oy}, {c.x + dx + ox, c.y + dy + oy}}, 2);
                    }
                    since = seg - (t - twist);
                }
                up = NO;
                q = p;
            }
        }
        CGContextRestoreGState(context);

        // Glint: a soft white flare that travels the line once a second, so the chrome catches the light.
        if (walked > 0) {
            float target = fmodf(phase, 1.0f) * walked, along = 0;
            penUp = YES;
            NSPoint prev = NSZeroPoint, glint = last;
            for (NSUInteger i = 0; i < [points count]; i++) {
                NSPoint p = [[points objectAtIndex:i] pointValue];
                if (isnan(p.x)) { penUp = YES; continue; }
                if (!penUp) {
                    float seg = hypotf(p.x - prev.x, p.y - prev.y);
                    if (along + seg >= target && seg > 0) {
                        float t = (target - along) / seg;
                        glint = NSMakePoint(prev.x + (p.x - prev.x) * t, prev.y + (p.y - prev.y) * t);
                        break;
                    }
                    along += seg;
                }
                penUp = NO;
                prev = p;
            }
            CGContextSaveGState(context);
            CGContextSetShadowWithColor(context, CGSizeZero, 8, [[NSColor colorWithWhite:1 alpha:0.9] CGColor]);
            CGContextSetGrayFillColor(context, 1, 0.95);
            CGContextFillEllipseInRect(context, CGRectMake(glint.x - 2.5f, glint.y - 2.5f, 5, 5));
            CGContextRestoreGState(context);
        }
        CGPathRelease(line);

        if (hintText[0]) { // the letter that fired, in silver with a blackened edge, centered under the drawing
            NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
            [shadow setShadowColor:[NSColor colorWithWhite:0 alpha:0.55]];
            [shadow setShadowOffset:NSMakeSize(0, -2)];
            [shadow setShadowBlurRadius:6];
            NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:56 weight:NSFontWeightHeavy],
                                    NSForegroundColorAttributeName: [NSColor colorWithWhite:0.92 alpha:1],
                                    NSStrokeColorAttributeName: [NSColor colorWithWhite:0.08 alpha:1],
                                    NSStrokeWidthAttributeName: @(-3), // negative: fill and outline
                                    NSShadowAttributeName: shadow};
            NSString *text = [NSString stringWithUTF8String:hintText];
            NSSize size = [text sizeWithAttributes:attrs];
            [text drawAtPoint:NSMakePoint((minX + maxX - size.width) / 2, MAX(4, minY - size.height - 20)) withAttributes:attrs];
        }
    }
}

- (void)addPointX:(float)x Y:(float)y {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    CGFloat width = [self frame].size.width - 30 - 150 - 2 * self.pad;
    CGFloat height = [self frame].size.height - 30 - 100 - 2 * self.pad;

    NSValue *point = [NSValue valueWithPoint:NSMakePoint(x*width + 15 + self.pad, y*height + 15 + 100 + self.pad)];
    [points addObject:point];
    [pool release];

    [self startSparkles];
    [self setNeedsDisplay:YES];
}

- (void)addRelativePointX:(float)x Y:(float)y {
    CGFloat width = [self frame].size.width;
    CGFloat height = [self frame].size.height;

    NSValue *point = [NSValue valueWithPoint:NSMakePoint(width/2 + x, height/2 + y)];
    [points addObject:point];
    [self setNeedsDisplay:YES];
}

- (void)dropLastPoints:(int)n { // the lift trim: forget the last n points of the current stroke
    while (n-- > 0 && [points count] > 0 && !isnan([[points lastObject] pointValue].x)) [points removeLastObject];
    [self setNeedsDisplay:YES];
}
- (void)breakStroke { // pen lift between strokes of a multi-stroke letter
    [points addObject:[NSValue valueWithPoint:NSMakePoint(NAN, NAN)]];
}
- (void)startSparkles {
    if (sparkleTimer) return;
    sparkleTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0 / 30 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];
}
- (void)tick {
    phase += 1.0f / 30;
    [self setNeedsDisplay:YES];
}
- (void)clear {
    [sparkleTimer invalidate];
    [sparkleTimer release];
    sparkleTimer = nil;
    [points removeAllObjects];
    [self setNeedsDisplay:YES];
}

- (void)setHintText:(const char*)str {
    strcpy(hintText, str);
}

- (void)dealloc {
    [points release];
    [super dealloc];
}

@end
