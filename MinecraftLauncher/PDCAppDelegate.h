//
//  PDCAppDelegate.h
//  MinecraftLauncher
//
//  Created by Peter Clark on 4/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PDCAppDelegate : NSObject <NSApplicationDelegate>

// connections in IB
@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSButton *startButton;
@property (unsafe_unretained) IBOutlet NSTextView *logView;
@property (weak) IBOutlet NSTextFieldCell *commandField;

- (IBAction)launchServer:(id)sender;
- (IBAction)sendCommand:(id)sender;

@end
