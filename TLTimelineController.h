//
//  TLTimelineController.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLTimelineView;
@class TLPhotoTimelineLayer;
@class TLTrackTimelineLayer;
@class TLTimelineTrackerLayer;
@class TLCameraTimelineLayer;
@class TLTimelineNavigationLayer;
@class TLLocation;


@interface TLTimelineController : NSObject {
	IBOutlet TLTimelineView* view;
@private
	id delegate;
	NSManagedObjectContext* modelContext;
	__weak TLPhotoTimelineLayer* photoLayer;
	__weak TLTrackTimelineLayer* trackLayer;
	__weak TLTimelineTrackerLayer* trackerLayer;
	__weak TLCameraTimelineLayer* cameraTimelineLayer;
	__weak TLTimelineNavigationLayer* navigationLayer;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) NSManagedObjectContext* modelContext;

- (NSView*)view;

@property (nonatomic, assign) BOOL tracksVisible;
@property (nonatomic, copy) NSSet* selectedPhotos;

- (void)setPreviewTimestamps:(NSArray*)previewTimestamps;

@end


@interface NSObject (TLTimelineControllerDelegate)
- (void)timelineControllerWantsPreview:(TLTimelineController*)aTimelineController
						  forLocations:(NSArray*)previewLocations;
- (void)timelineControllerWantsDisplay:(TLTimelineController*)aTimelineController
							 forPhotos:(NSSet*)displayedPhotos;
- (void)timelineControllerMouse:(TLTimelineController*)aTimelineController
				   isAtLocation:(TLLocation*)mouseLocation;
- (void)controllerSelectionDidChange:(NSNotification*)aNotification;
- (NSArray*)controllerNeedsFilenames:(id)aMercController
					forDroppedPhotos:(NSArray*)photosDropped
					   atDestination:(NSURL*)dropDestination;
- (void)controllerNeedsImport:(id)aMercController
					 forFiles:(NSArray*)filenames;
@end
