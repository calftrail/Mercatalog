//
//  TLMercatalogProjectController.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 9/8/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLMercatalogLibrary;
@class TLMapController;
@class TLTimelineController;


@interface TLMercatalogProjectController : NSObject {
	IBOutlet NSWindow* projectWindow;
	IBOutlet NSToolbarItem* lockButton;
@private
	TLMercatalogLibrary* library;
	TLMapController* mapController;
	TLTimelineController* timelineController;
}

- (id)initWithProject:(NSURL*)project error:(NSError**)err;
- (NSWindow*)window;
- (void)closeProject;

- (IBAction)lockPhotos:(id)sender;
- (IBAction)unlockPhotos:(id)sender;
- (IBAction)zoomCompletelyOut:(id)sender;
- (IBAction)toggleTimelineAlwaysShown:(id)sender;
- (IBAction)toggleTracksAlwaysShown:(id)sender;
- (IBAction)exportKMZ:(id)sender;
- (IBAction)exportFiles:(id)sender;
- (IBAction)importFiles:(id)sender;

@end
