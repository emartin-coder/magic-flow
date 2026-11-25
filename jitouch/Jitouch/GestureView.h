//
//  GestureView.h
//  Jitouch
//
//  Copyright 2021 Supasorn Suwajanakorn and Sukolsak Sakshuwong. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface GestureView : NSView {
    NSMutableArray *points;
    char hintText[20];
    NSTimer *sparkleTimer; // redraws the chrome glint while a drawing is on screen
    float phase;
}
@property float pad; // extra empty px on every side, so the line's shadow is never cut off at the edge
- (void)setHintText:(const char*)str;
- (void)addPointX:(float)x Y:(float)y;
- (void)addRelativePointX:(float)x Y:(float)y;
- (void)clear;
- (void)breakStroke;
- (void)dropLastPoints:(int)n;

@end
