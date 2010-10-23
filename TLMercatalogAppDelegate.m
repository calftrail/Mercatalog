//
//  TLMercatalogAppDelegate.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 8/9/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLMercatalogAppDelegate.h"

#import "TLMercatalogProjectController.h"
#import "TLPhoto.h"

#import "TLJimBos.h"


@implementation TLMercatalogAppDelegate

- (IBAction)showAcknowledgements:(id)sender {
	(void)sender;
	NSString* ackPath = [[NSBundle mainBundle] pathForResource:@"Acknowledgments" ofType:@"html"];
	if (ackPath) {
		(void)[[NSWorkspace sharedWorkspace] openFile:ackPath];
	}
	else {
		NSLog(@"Could not find Acknowledgments file");
	}
}

- (IBAction)showRegistration:(id)sender {
	(void)sender;
	[[TLJimBos sharedRegistrar] showRegistrationWindow:self];
}

- (void)applicationDidFinishLaunching:(NSNotification*)aNotification {
	(void)aNotification;
	
	[[TLJimBos sharedRegistrar] showDemoInformation:self];
	
	NSDictionary* defaultDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
									 [NSNumber numberWithBool:YES], @"CopyOriginalPhotos", nil];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultDefaults];
	NSDictionary* appInfo = [[NSBundle mainBundle] infoDictionary];
	NSString* appName = [appInfo objectForKey:(id)kCFBundleNameKey];
	NSString* appVersion = [appInfo objectForKey:@"CFBundleShortVersionString"];
	NSString* fullAppName = [NSString stringWithFormat:@"%S v%S",
							 [appName cStringUsingEncoding:NSUTF16StringEncoding],
							 [appVersion cStringUsingEncoding:NSUTF16StringEncoding]];
	[TLPhoto setExportSoftwareName:fullAppName];
	
	NSString* picturesFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
	NSString* libraryPath = [picturesFolder stringByAppendingPathComponent:@"Mercatalog Library.mercatalog"];
	NSURL* projectURL = [NSURL fileURLWithPath:libraryPath];
	NSError* error = nil;
	projectController = [[TLMercatalogProjectController alloc] initWithProject:projectURL error:&error];
	if (error) {
		[NSApp presentError:error];
	}
	NSWindow* projectWindow = [projectController window];
	[projectWindow orderFront:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)theApplication {
	(void)theApplication;
	if (0) {
		return NO;
	}
	return YES;
}

- (void)applicationWillTerminate:(NSNotification*)aNotification {
	(void)aNotification;
	[projectController closeProject];
}

@end
