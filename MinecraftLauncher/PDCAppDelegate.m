//
//  PDCAppDelegate.m
//  MinecraftLauncher
//
//  Created by Peter Clark on 4/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "PDCAppDelegate.h"

@implementation PDCAppDelegate {
    NSTask *task;
    NSPipe *taskOutput;
    NSFileHandle *taskStdOut;
    NSPipe *taskErr;
    NSFileHandle *taskStdErr;
    NSPipe *taskIn;
    NSString *jarLocation;
}

@synthesize commandField = _commandField;

@synthesize window = _window;
@synthesize startButton = _startButton;
@synthesize logView = _logView;


- (BOOL) isSubtaskRunning {
    return ((nil != task) && [task isRunning]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSBundle *mainBundle = [NSBundle mainBundle];
    jarLocation = [mainBundle pathForResource:@"minecraft_server" ofType:@"jar"];
    
    NSLog(@"Found jarfile at:%@", jarLocation);
    
    if (nil == jarLocation) {
        [_startButton setEnabled:false];
        [self appendText:@"minecraft_server.jar file not found in main bundle.\n"];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // we're about to exit, so shut down the server.
    if ([self isSubtaskRunning]) {
        NSLog(@"signalling server to shut down.");
        [self appendText:@"Signalling server to shut down...\n"];
        [self tellChild:@"stop"];
    }
}

- (IBAction)launchServer:(id)sender {
    if (![self isSubtaskRunning]) {
        [self startServerInTask];
        [_startButton setTitle:@"Stop Server"];
    } else {
        [self tellChild:@"stop"];
        [_startButton setTitle:@"Start Server"];
        task = nil;
    }
}

// add text to the output window, and scroll to the bottom.
// TODO add coloring?
- (void) appendText:(NSString *)string {
    NSRange range;
    
    int initialLength = [[_logView string] length];
    range = NSMakeRange (initialLength, 0);
    
    // insert our new text at the bottom of the textview
    [_logView replaceCharactersInRange: range withString: string];
    
    // and then scroll all the way to the bottom.
    range = NSMakeRange(initialLength + [string length], 0);
    [_logView scrollRangeToVisible: range];
}


// send some data to the child process.
- (void)tellChild:(NSString *)cmd {
    if ([self isSubtaskRunning]) {
        NSFileHandle *childStdIn = [taskIn fileHandleForWriting];
        NSString *command = [cmd stringByAppendingString:@"\n"];
        NSData *valToSend = [command dataUsingEncoding:NSASCIIStringEncoding];
        [childStdIn writeData:valToSend];
        [self appendText:command];
    }
}

- (IBAction)sendCommand:(id)sender {
    NSString *cmd = [_commandField stringValue];
    NSLog(@"Got string of: %@\n", cmd);
    
    [self tellChild: cmd];
    
    [_commandField setStringValue:@""];
}

- (void)startServerInTask;
{
    task = [[NSTask alloc] init];
    // -Xmx1024M -Xms1024M -jar minecraft_server.jar nogui
    NSArray *args = [NSArray arrayWithObjects:@"-Xmx1024M", @"-Xms1024M",
                     @"-jar", jarLocation, @"nogui", nil];
    
    [task setLaunchPath:@"/usr/bin/java"];
    [task setArguments:args];
    
    // get an NSFileHandle to watch stdout from the subprocess
    taskOutput = [NSPipe pipe];
    [task setStandardOutput:taskOutput];
    taskStdOut = [taskOutput fileHandleForReading];
    [taskStdOut readInBackgroundAndNotify];

    // and one to watch stderr
    taskErr = [NSPipe pipe];
    [task setStandardError:taskErr];
    taskStdErr = [taskErr fileHandleForReading];
    [taskStdErr readInBackgroundAndNotify];

    // and one for stdin
    taskIn = [NSPipe pipe];
    [task setStandardInput:taskIn];

    // set up to get notified if the child task exits.
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(taskExited:) 
     name:NSTaskDidTerminateNotification 
     object:task
     ];
    
    // set up to get notified when the child task has output for us to display.
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(taskHasData:)
     name:NSFileHandleReadCompletionNotification 
     object:taskStdOut
     ];

    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(taskHasData:)
     name:NSFileHandleReadCompletionNotification 
     object:taskStdErr
     ];

    [task launch];
}

- (void)taskExited:(NSNotification *)note
{
    NSLog(@"taskExited has been called.\n");
    
    // unregister the task
    [[NSNotificationCenter defaultCenter] 
     removeObserver:self 
     name:NSTaskDidTerminateNotification 
     object:task
     ];
    
    // don't want to unregister for NSFileHandleReadCompletionNotification here, because
    // we might still get a notification about the dying gasps of output from the subtask.
}

// called when the subtask has something for us to read
- (void)taskHasData:(NSNotification *)note
{
    NSLog(@"taskHasData has been called.\n");
    NSFileHandle *sender = [note object];
    NSData *inData = [[note userInfo] objectForKey:@"NSFileHandleNotificationDataItem"];
    
    if ([inData length] > 0) {
        NSString *output = [[NSString alloc] initWithData:inData encoding:NSASCIIStringEncoding];
    
        [self appendText: output];
    
        // need to re-enable the file handle to notify us again.
        [sender readInBackgroundAndNotify];
    } else {
        /*  we've hit EOF, which probably means that the subtask is done.
            rather than asking for a repeat of readInBackgroundAndNotify, unregister ourselves from the notification center.
         */
        [[NSNotificationCenter defaultCenter]
         removeObserver:self 
         name:NSFileHandleReadCompletionNotification 
         object:taskStdOut
         ];

        [[NSNotificationCenter defaultCenter]
         removeObserver:self 
         name:NSFileHandleReadCompletionNotification 
         object:taskStdErr
         ];
    }
    
}

@end
