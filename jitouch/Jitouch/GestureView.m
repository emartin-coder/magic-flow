//
//  GestureView.m
//  Jitouch
//
//  Copyright 2021 Supasorn Suwajanakorn and Sukolsak Sakshuwong. All rights reserved.
//

#import "GestureView.h"

// A chubby five-point star with rounded tips (the Warp Star's shape): fat inner radius, arcs at every corner.
static CGPathRef warpStarPath(NSPoint c, float R, float tilt) {
    CGPoint v[10];
    for (int j = 0; j < 10; j++) {
        float r = (j % 2) ? R * 0.55f : R, a = M_PI_2 + tilt + j * M_PI / 5;
        v[j] = CGPointMake(c.x + r * cosf(a), c.y + r * sinf(a));
    }
    CGMutablePathRef p = CGPathCreateMutable();
    CGPathMoveToPoint(p, NULL, (v[9].x + v[0].x) / 2, (v[9].y + v[0].y) / 2);
    for (int j = 0; j < 10; j++)
        CGPathAddArcToPoint(p, NULL, v[j].x, v[j].y, (v[j].x + v[(j + 1) % 10].x) / 2, (v[j].y + v[(j + 1) % 10].y) / 2, (j % 2) ? R * 0.12f : R * 0.22f);
    CGPathCloseSubpath(p);
    return p;
}

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
        // Warp Star, per the official art (WiKirby): a chubby yellow five-point star with a thick dark outline and
        // white shine spots, wobbling while it glows, shedding small pale-yellow stars and dots behind it.
        float minX = 10000, minY = 10000, walked = 0;
        BOOL penUp = YES, any = NO;
        NSPoint last = NSZeroPoint;
        for (NSUInteger i = 0; i < [points count]; i++) {
            NSPoint p = [[points objectAtIndex:i] pointValue];
            if (isnan(p.x)) { penUp = YES; continue; }
            if (!penUp) walked += hypotf(p.x - last.x, p.y - last.y);
            penUp = NO;
            any = YES;
            last = p;
            if (p.x < minX) minX = p.x;
            if (p.y < minY) minY = p.y;
        }

        // Particles every 9 px: alternate little stars and dots, bigger and brighter toward the Warp Star,
        // each twinkling on its own beat, nudged off the line so it reads as a spray.
        penUp = YES;
        float along = 0, next = 0;
        int k = 0;
        NSPoint prev = NSZeroPoint;
        for (NSUInteger i = 0; i < [points count]; i++) {
            NSPoint p = [[points objectAtIndex:i] pointValue];
            if (isnan(p.x)) { penUp = YES; continue; }
            if (!penUp) along += hypotf(p.x - prev.x, p.y - prev.y);
            penUp = NO;
            prev = p;
            if (along < next) continue;
            next = along + 9;
            k++;
            float fresh = walked > 0 ? along / walked : 1; // 0 at the tail, 1 at the star
            float tw = 0.75f + 0.25f * sinf(phase * 6 + k * 2.3f);
            float r = (2.5f + 4.5f * fresh) * tw * ((k % 3 == 0) ? 1.4f : 1.0f);
            NSPoint c = NSMakePoint(p.x + 4 * sinf(k * 1.9f + phase * 2), p.y + 4 * cosf(k * 2.7f + phase * 2));
            CGContextSetRGBFillColor(context, 1, 0.97, 0.62, 0.55 + 0.45 * fresh);
            CGContextSetRGBStrokeColor(context, 1, 0.85, 0.25, 0.55 + 0.45 * fresh);
            CGContextSetLineWidth(context, 1.0);
            if (k % 2) {
                CGPathRef star = warpStarPath(c, r * 1.4f, sinf(k) * 0.5f);
                CGContextAddPath(context, star);
                CGPathRelease(star);
            } else {
                CGContextAddEllipseInRect(context, CGRectMake(c.x - r * 0.6f, c.y - r * 0.6f, r * 1.2f, r * 1.2f));
            }
            CGContextDrawPath(context, kCGPathFillStroke);
        }

        if (any) {
            // Glow, then the star: outline, yellow body with a lighter top, two shine spots.
            float R = 24, tilt = -0.25f + 0.2f * sinf(phase * 4); // wobble back and forth
            CGContextSaveGState(context);
            CGContextSetShadowWithColor(context, CGSizeZero, 14, [[NSColor colorWithRed:1 green:0.95 blue:0.5 alpha:0.9] CGColor]);
            CGPathRef star = warpStarPath(last, R, tilt);
            CGContextAddPath(context, star);
            CGContextSetRGBFillColor(context, 1, 0.84, 0.05, 1);
            CGContextFillPath(context);
            CGContextRestoreGState(context);

            CGContextSaveGState(context);
            CGContextAddPath(context, star);
            CGContextClip(context);
            CGFloat cols[] = {1, 0.97, 0.55, 1,   1, 0.84, 0.05, 1,   0.95, 0.68, 0.0, 1};
            CGFloat locs[] = {0, 0.55, 1};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef g = CGGradientCreateWithColorComponents(cs, cols, locs, 3);
            CGContextDrawLinearGradient(context, g, CGPointMake(last.x, last.y + R), CGPointMake(last.x, last.y - R), 0);
            CGGradientRelease(g);
            CGColorSpaceRelease(cs);
            CGContextRestoreGState(context);

            CGContextAddPath(context, star);
            CGContextSetLineWidth(context, 2.5);
            CGContextSetRGBStrokeColor(context, 0.3, 0.17, 0.05, 1);
            CGContextStrokePath(context);
            CGPathRelease(star);

            CGContextSetRGBFillColor(context, 1, 1, 1, 0.9);
            CGContextFillEllipseInRect(context, CGRectMake(last.x + 4, last.y + 8, 7, 5));
            CGContextFillEllipseInRect(context, CGRectMake(last.x + 12, last.y + 2, 3.5, 3.5));

        }

        [[NSString stringWithUTF8String:hintText]
         drawAtPoint:CGPointMake(minX, minY - 70.0)
         withAttributes:@{
                          NSFontAttributeName: [NSFont systemFontOfSize:40.0],
                          NSForegroundColorAttributeName: [NSColor colorWithRed:0.7 green:0.0 blue:0.0 alpha:0.5]
                          }];
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
