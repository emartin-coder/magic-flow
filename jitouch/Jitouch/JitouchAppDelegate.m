//
//  JitouchAppDelegate.m
//  Jitouch
//
//  Copyright 2021 Supasorn Suwajanakorn and Sukolsak Sakshuwong. All rights reserved.
//  Modified work Copyright 2021 Aaron Kollasch. All rights reserved.
//

#import "JitouchAppDelegate.h"
#import "Settings.h"
#import "Gesture.h"
#import "CursorWindow.h"
#import <Carbon/Carbon.h>
#import <CoreFoundation/CFPreferences.h>
#import "SystemPreferences.h"

CursorWindow *cursorWindow;
CGKeyCode keyMap[128]; // for dvorak support

@implementation JitouchAppDelegate

@synthesize window;

- (void)unloadJitouchLaunchAgent {
    NSString *plistPath = [@"~/Library/LaunchAgents/com.jitouch.Jitouch.plist" stringByStandardizingPath];
    NSArray *unloadArgs = [NSArray arrayWithObjects:@"unload",
                           plistPath,
                           nil];
    NSTask *unloadTask = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:unloadArgs];
    [unloadTask waitUntilExit];
}

#pragma mark - Menu

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    return YES;
}

- (void)showIcon {
    theMenu = [[[NSMenu alloc] initWithTitle:@"Contextual Menu"] autorelease];

    if (enAll)
        [theMenu insertItemWithTitle:@"Turn Magic Flow Off" action:@selector(switchChange:) keyEquivalent:@"" atIndex:0];
    else
        [theMenu insertItemWithTitle:@"Turn Magic Flow On" action:@selector(switchChange:) keyEquivalent:@"" atIndex:0];

    //[theMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
    [theMenu insertItemWithTitle:@"Open Preferences..." action:@selector(preferences:) keyEquivalent:@"" atIndex:1];
    [theMenu insertItem:[NSMenuItem separatorItem] atIndex:2];
    [theMenu insertItemWithTitle:@"Quit Magic Flow" action:@selector(quit:) keyEquivalent:@"" atIndex:3];

    NSStatusBar *bar = [NSStatusBar systemStatusBar];
    theItem = [bar statusItemWithLength:NSVariableStatusItemLength];
    [theItem retain];
    [self updateIconImage];
    [theItem setHighlightMode:YES];
    [theItem setMenu:theMenu];
}

- (void)hideIcon {
    [[NSStatusBar systemStatusBar] removeStatusItem:theItem];
    [theItem release];
    theItem = nil;
}

// Menu bar icon: an Aladdin-style genie lamp, vector-drawn as a template so macOS colors it for light and dark
// menu bars. On: solid, with a wisp of smoke from the spout. Off: faded, no smoke.
static NSImage *lampIcon(BOOL on) {
    NSImage *img = [NSImage imageWithSize:NSMakeSize(22, 16) flipped:NO drawingHandler:^BOOL(NSRect r) {
        CGContextRef cg = [[NSGraphicsContext currentContext] CGContext];
        CGContextSetAlpha(cg, on ? 1 : 0.35); // one layer, faded once, so overlapping parts don't darken
        CGContextBeginTransparencyLayer(cg, NULL);
        [[NSColor blackColor] set];
        NSBezierPath *lamp = [NSBezierPath bezierPath];
        [lamp moveToPoint:NSMakePoint(4, 8)]; // bowl, then the spout out to its tip, then back along the rim
        [lamp curveToPoint:NSMakePoint(10, 3) controlPoint1:NSMakePoint(4, 5) controlPoint2:NSMakePoint(6.5, 3)];
        [lamp curveToPoint:NSMakePoint(15, 5.5) controlPoint1:NSMakePoint(12.5, 3) controlPoint2:NSMakePoint(14, 4)];
        [lamp lineToPoint:NSMakePoint(21, 9.6)];
        [lamp lineToPoint:NSMakePoint(21, 10.4)];
        [lamp lineToPoint:NSMakePoint(15.5, 8)];
        [lamp closePath];
        [lamp appendBezierPathWithRect:NSMakeRect(9, 2, 2, 1.5)];                              // stem
        [lamp appendBezierPathWithRoundedRect:NSMakeRect(7.5, 0.8, 5, 1.6) xRadius:0.8 yRadius:0.8]; // foot
        [lamp appendBezierPathWithOvalInRect:NSMakeRect(7, 7.6, 6, 3)];                        // lid
        [lamp appendBezierPathWithOvalInRect:NSMakeRect(9.1, 10.3, 1.8, 1.8)];                 // knob
        [lamp fill];
        NSBezierPath *handle = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(1, 5.1, 4.2, 4.2)];
        [handle setLineWidth:1.4];
        [handle stroke];
        if (on) {
            NSBezierPath *wisp = [NSBezierPath bezierPath];
            [wisp moveToPoint:NSMakePoint(21, 11.2)];
            [wisp curveToPoint:NSMakePoint(19, 15.4) controlPoint1:NSMakePoint(22.6, 13) controlPoint2:NSMakePoint(17.8, 13.6)];
            [wisp setLineWidth:1.1];
            [wisp setLineCapStyle:NSLineCapStyleRound];
            [wisp stroke];
        }
        CGContextEndTransparencyLayer(cg);
        return YES;
    }];
    [img setTemplate:YES];
    return img;
}

- (void)updateIconImage {
    [theItem setImage:lampIcon(enAll != 0)];
}

- (void)preferences:(id)sender  {
    NSString *prefPath = @"/Applications/Magic Flow Settings.app"; // this fork's settings window; the old panel is a fallback
    if (![[NSFileManager defaultManager] fileExistsAtPath:prefPath])
        prefPath = [@"~/Library/PreferencePanes/Jitouch.prefPane" stringByExpandingTildeInPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        prefPath = @"/Library/PreferencePanes/Jitouch.prefPane";
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        [[NSWorkspace sharedWorkspace] openFile:prefPath];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Can't find the jitouch preference panel."];
        [alert setInformativeText:@"Please reinstall jitouch."];
        [alert setAlertStyle:NSAlertStyleWarning];
        [NSApp activateIgnoringOtherApps:YES];
        [alert runModal];
        [alert release];
    }
}


- (void)quit:(id)sender {
    [self unloadJitouchLaunchAgent];

    // Quit
    [NSApp terminate: sender];
}

- (void)refreshMenu {
    if (theItem == nil && [[settings objectForKey:@"ShowIcon"] intValue] == 1){
        [self showIcon];
    } else if (theItem != nil && [[settings objectForKey:@"ShowIcon"] intValue] == 0){
        [self hideIcon];
    }
    if (theItem) {
        if (enAll) {
            [[theMenu itemAtIndex:0] setTitle:@"Turn Magic Flow Off"];
        } else {
            [[theMenu itemAtIndex:0] setTitle:@"Turn Magic Flow On"];
        }
        [self updateIconImage];
    }
}

- (void)switchChange:(id)sender {
    enAll = !enAll;
    [self refreshMenu];
    [self saveSettings];

    if (!enAll)
        turnOffGestures();
}

#pragma mark - Settings

- (void)saveSettings {
    [Settings setKey:@"enAll" withInt:enAll];
    [Settings noteSettingsUpdated2];
}

- (void)settingsUpdated:(NSNotification *)aNotification {
    //[Settings loadSettings];

    [Settings loadSettings2:aNotification.userInfo]; // fixes bug in mountain lion
    [self refreshMenu];

    if (!enAll)
        turnOffGestures();
    else if (!enMMAll || !enCharRegMM)
        mmForceRelease(); // Magic Mouse finger gestures just turned off: don't leave a drag holding the button
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    mmForceRelease(); // quitting mid-drag must not leave the left button held
}

#pragma mark - Initialization


- (void)checkAXAPI {
    AXIsProcessTrustedWithOptions((CFDictionaryRef)@{(id)kAXTrustedCheckOptionPrompt: @(YES)});
}

/*
void languageChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    for (int i = 0; i < 128; i++)
        keyMap[i] = (CGKeyCode)i;
    NSString *inputSource = (NSString*)TISGetInputSourceProperty(TISCopyCurrentKeyboardInputSource(), kTISPropertyLocalizedName);
    if ([inputSource isEqualToString:@"Dvorak"] || [inputSource isEqualToString:@"Svorak"]) {
        keyMap[13] = 43; //w -> ,
        keyMap[12] = 7;  //q -> x
        keyMap[17] = 40; //t -> k
        keyMap[4] = 38;  //h -> j
        keyMap[15] = 31; //r -> o
        keyMap[45] = 37; //n -> l
        keyMap[8] = 34; //c -> i
        keyMap[9] = 47; //v -> >
        keyMap[31] = 1; //o ->
        keyMap[37] = 45; //l -> n
        keyMap[3] = 32; // f -> u
        keyMap[40] = 17;
    } else if ([inputSource isEqualToString:@"French"]) {
        keyMap[13] = 6;  //w -> z
        keyMap[12] = 0;  //q -> a
    }
}
*/

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // One copy only: the login agent and a Finder double-click can both start the app, and two copies fire every gesture twice.
    NSArray *running = [NSRunningApplication runningApplicationsWithBundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
    for (NSRunningApplication *app in running) {
        if (app.processIdentifier != getpid()) {
            [NSApp terminate:nil];
            return;
        }
    }

    [Settings loadSettings];

    [self refreshMenu];

    // Move this task to prefpane instead. Starting at Sierra
    //[self addJitouchToLoginItems];

    cursorWindow = [[CursorWindow alloc] init];

    //languageChanged(NULL, NULL, NULL, NULL, NULL);

    gesture = [[Gesture alloc] init];

    //[self showIcon];

    [self checkAXAPI];

    [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                        selector: @selector(settingsUpdated:)
                                                            name: @"My Notification"
                                                          object: @"com.jitouch.Jitouch.PrefpaneTarget"];

    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(wokeUp:) name:NSWorkspaceDidWakeNotification object: NULL];

    //CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(), self, languageChanged, kTISNotifySelectedKeyboardInputSourceChanged, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)wokeUp:(NSNotification *)aNotification {
    NSLog(@"Woke up.");
    [self reload];
}

- (void)reload {
    [gesture reload];
}

#pragma mark -

- (void) dealloc {
    [cursorWindow release];
    [super dealloc];
}

@end
