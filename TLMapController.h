//
//  TLMapController.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLMapView;
@class TLPhotoLayer;
@class TLTrackLayer;
@class TLMapNavigationLayer;
@class TLMapLocationLayer;
@class TLLocation;

@interface TLMapController : NSObject {
	IBOutlet TLMapView* view;
@private
	id delegate;
	NSManagedObjectContext* modelContext;
	__weak TLPhotoLayer* photoLayer;
	__weak TLTrackLayer* trackLayer;
	__weak TLMapNavigationLayer* navigationLayer;
	__weak TLMapLocationLayer* locationLayer;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) NSManagedObjectContext* modelContext;
- (NSView*)view;

@property (nonatomic, assign) BOOL tracksVisible;
@property (nonatomic, copy) NSSet* selectedPhotos;
@property (nonatomic, copy) NSSet* displayedPhotos;

- (void)setPreviewLocations:(NSArray*)previewLocations;
- (void)setMouseLocation:(TLLocation*)mouseLocation;
- (IBAction)zoomCompletelyOut:(id)sender;

@end


@interface NSObject (TLMapControllerDelegate)
- (void)mapControllerWantsPreview:(TLMapController*)aMapController
					forTimestamps:(NSArray*)previewTimestamps;
- (void)controllerSelectionDidChange:(NSNotification*)aNotification;
- (NSArray*)controllerNeedsFilenames:(id)aMercController
					forDroppedPhotos:(NSArray*)photosDropped
					   atDestination:(NSURL*)dropDestination;
- (void)controllerNeedsImport:(id)aMercController
					 forFiles:(NSArray*)filenames;
@end
