//
//  TLPhotoTimelineLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineInteractiveLayer.h"

@class TLSelectionManager;

@interface TLPhotoTimelineLayer : TLTimelineInteractiveLayer {
@private
	id delegate;
	id dataSource;
	
	TLSelectionManager* selectionManager;
	NSMutableSet* displayedPhotos;
	
	BOOL dragTarget;
	NSArray* previewTimestamps;
	NSArray* draggedPhotos;
	
	double selectionStart;
	NSTimeInterval selectionDuration;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) id dataSource;
- (void)reloadData;

@property (nonatomic, copy) NSArray* previewTimestamps;

@property (nonatomic, readonly) NSSet* displayedPhotos;

@property (nonatomic, copy) NSSet* selectedPhotos;
- (void)selectPhotos:(NSArray*)photos byExtendingSelection:(BOOL)shouldExtend;

@end

// Notifications posted
extern NSString* const TLPhotoTimelineLayerSelectionDidChangeNotification;
extern NSString* const TLPhotoTimelineLayerDisplayedPhotosDidChangeNotification;


@interface NSObject (TLPhotoTimelineLayerDelegate)
- (void)photoTimelineLayerSelectionDidChange:(NSNotification*)notification;
- (void)photoTimelineLayerDisplayedPhotosDidChange:(NSNotification*)notification;
@end


@interface NSObject (TLPhotoTimelineLayerDataSource)

- (NSArray*)photoTimelineLayer:(TLPhotoTimelineLayer*)photoLayer
			  photosFromDate:(NSDate*)startDate
					  toDate:(NSDate*)endDate;

// drag source
- (BOOL)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
			   writePhotos:(NSArray*)photos
			  toPasteboard:(NSPasteboard*)pasteboard;

- (NSDragOperation)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
			  dragSourceMaskForPhotos:(NSArray*)photosDragging
				   destinationIsLocal:(BOOL)isLocal;

- (NSArray*)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
			filenamesForPhotos:(NSArray*)photosDropped
		 promisedAtDestination:(NSURL*)dropDestination;

- (void)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
			 concludedDrag:(NSArray*)photosDragged
			 withOperation:(NSDragOperation)operation;

// drag destination
- (NSDragOperation)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
						 validateDrop:(id < NSDraggingInfo >)dropInfo
							 withInfo:(id < TLTimelineInfo >)timelineInfo;

- (BOOL)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
				acceptDrop:(id < NSDraggingInfo >)dropInfo
				  withInfo:(id < TLTimelineInfo >)timelineInfo;

- (void)photoTimelineLayerDropDidCancel:(TLPhotoTimelineLayer*)layer;

@end
