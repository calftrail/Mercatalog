//
//  TLTimelineController.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineController.h"

#import "TLTimelineView.h"
#import "TLCalendarTimelineLayer.h"
#import "TLTimelineNavigationLayer.h"
#import "TLTrackTimelineLayer.h"
#import "TLCameraTimelineLayer.h"
#import "TLPhotoTimelineLayer.h"
#import "TLTimelineTrackerLayer.h"
#import "TLTimelineTimeZoneLayer.h"

#import "TLLibraryHost.h"
#import "TLPhoto.h"
#import "TLTrack.h"
#import "TLTimestamp.h"
#import "TLCameraTimeline.h"
#import "TLLocator.h"

#import "TLMercatalogControllerShared.h"
#import "TLCocoaToolbag.h"


@implementation TLTimelineController

#pragma mark Lifecycle

- (void)awakeFromNib {
	TLCalendarTimelineLayer* calendarLayer = [[TLCalendarTimelineLayer new] autorelease];
	[view addLayer:calendarLayer];
	
	navigationLayer = [[TLTimelineNavigationLayer new] autorelease];
	[navigationLayer setDelegate:self];
	[view addLayer:navigationLayer];
	
	trackLayer = [[TLTrackTimelineLayer new] autorelease];
	[trackLayer setDataSource:self];
	[view addLayer:trackLayer];
	
	cameraTimelineLayer = [[TLCameraTimelineLayer new] autorelease];
	[cameraTimelineLayer setDataSource:self];
	[view addLayer:cameraTimelineLayer];
	
	NSArray* dropTypes = TLMercatalogAcceptedDropTypes();
	photoLayer = [[TLPhotoTimelineLayer new] autorelease];
	[photoLayer setDelegate:self];
	[photoLayer setDataSource:self];
	[photoLayer setRegisteredDropTypes:dropTypes];
	[view addLayer:photoLayer];
	
	TLTimelineTimeZoneLayer* timeZoneLayer = [[TLTimelineTimeZoneLayer new] autorelease];
	[view addLayer:timeZoneLayer];
	
	trackerLayer = [[TLTimelineTrackerLayer new] autorelease];
	[trackerLayer setDelegate:self];
	[view addLayer:trackerLayer];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[modelContext release];
	[photoLayer setDelegate:nil];
	[photoLayer setDataSource:nil];
	[navigationLayer setDelegate:nil];
	[trackLayer setDataSource:nil];
	[cameraTimelineLayer setDataSource:nil];
	[trackerLayer setDelegate:nil];
	[super dealloc];
}


#pragma mark Basic accessors

@synthesize delegate;

@synthesize modelContext;

- (void)setModelContext:(NSManagedObjectContext*)newModelContext {
	if (newModelContext == modelContext) return;
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:modelContext];
	[modelContext release];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(modelChanged:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:newModelContext];
	modelContext = [newModelContext retain];
}

- (void)loadView {
	view = [[TLTimelineView alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, 1.0f, 1.0f)];
	[view setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
	[self awakeFromNib];
}

- (NSView*)view {
	if (!view) {
		[self loadView];
	}
	return view;
}


#pragma mark Glue and external communication

- (void)delayedModelChanged {
	[photoLayer reloadData];
	[trackLayer reloadData];
}

- (void)modelChanged:(NSNotification*)aNotification {
	(void)aNotification;
	// delay updates to ensure host object gets its notification first
	[self performSelector:@selector(delayedModelChanged) withObject:nil afterDelay:0.0];
}

- (void)setTracksVisible:(BOOL)newTracksVisible {
	[trackLayer setHidden:!newTracksVisible];
}

- (BOOL)tracksVisible {
	return ![trackLayer isHidden];
}

- (void)setSelectedPhotos:(NSSet*)newSelectedPhotos {
	[photoLayer setSelectedPhotos:newSelectedPhotos];
}

- (NSSet*)selectedPhotos {
	return [photoLayer selectedPhotos];
}

- (void)setPreviewLocations:(NSArray*)previewLocations {
	if ([[self delegate] respondsToSelector:@selector(timelineControllerWantsPreview:forLocations:)]) {
		[[self delegate] timelineControllerWantsPreview:self forLocations:previewLocations];
	}
}

- (void)setPreviewTimestamps:(NSArray*)previewTimestamps {
	[photoLayer setPreviewTimestamps:previewTimestamps];
}

- (TLLocator*)locator {
	TLLocator* locator = [[TLLocator new] autorelease];
	[locator setModelContext:[self modelContext]];
	return locator;
}

- (TLCameraTimeline*)cameraTimeline {
	TLCameraTimeline* cameraTimeline = [[TLCameraTimeline new] autorelease];
	[cameraTimeline setModelContext:[self modelContext]];
	return cameraTimeline;
}

- (NSArray*)filenamesForPhotos:(NSArray*)photosDropped
		 promisedAtDestination:(NSURL*)dropDestination
{
	NSArray* filenames = nil;
	if ([[self delegate] respondsToSelector:
		 @selector(controllerNeedsFilenames:forDroppedPhotos:atDestination:)])
	{
		[[self delegate] controllerNeedsFilenames:self
								 forDroppedPhotos:photosDropped
									atDestination:dropDestination];
	}
	else {
		NSLog(@"Delegate did not fulfill promise drag.");
		filenames = [NSArray array];
	}
	return filenames;
}

- (void)timelineTrackerLayer:(TLTimelineTrackerLayer*)theTrackerLayer
			mouseAtTimestamp:(TLTimestamp*)mouseTimestamp
{
	(void)theTrackerLayer;
	TLLocation* location = nil;
	if (mouseTimestamp) {
		location = [[self locator] locationAtTimestamp:mouseTimestamp];
	}
	if ([[self delegate] respondsToSelector:@selector(timelineControllerMouse:isAtLocation:)]) {
		[[self delegate] timelineControllerMouse:self isAtLocation:location];
	}
}

- (void)timelineNavigationLayerDidIgnoreClick:(TLTimelineNavigationLayer*)navLayer {
	(void)navLayer;
	[photoLayer setSelectedPhotos:nil];
}

- (void)photoTimelineLayerSelectionDidChange:(NSNotification*)notification {
	(void)notification;
	NSNotification* newNotification = [NSNotification notificationWithName:TLMercatalogSelectionDidChangeNotification
																	object:self];
	if ([[self delegate] respondsToSelector:@selector(controllerSelectionDidChange:)]) {
		[[self delegate] controllerSelectionDidChange:newNotification];
	}
	[[NSNotificationCenter defaultCenter] postNotification:newNotification];
}

- (void)photoTimelineLayerDisplayedPhotosDidChange:(NSNotification*)notification {
	(void)notification;
	if ([[self delegate] respondsToSelector:@selector(timelineControllerWantsDisplay:forPhotos:)]) {
		NSSet* displayedPhotos = [photoLayer displayedPhotos];
		[[self delegate] timelineControllerWantsDisplay:self forPhotos:displayedPhotos];
	}
}


#pragma mark Data source

- (NSArray*)photoTimelineLayer:(TLPhotoTimelineLayer*)aLayer
				photosFromDate:(NSDate*)startDate
						toDate:(NSDate*)endDate
{
	(void)aLayer;
	(void)startDate;
	(void)endDate;
	
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host visiblePhotos];
}

- (NSArray*)trackTimelineLayer:(TLTrackTimelineLayer*)aLayer
				tracksFromDate:(NSDate*)startDate
						toDate:(NSDate*)endDate
{
	(void)aLayer;
	(void)startDate;
	(void)endDate;
	
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host allTracks];
}

- (NSArray*)cameraTimelineLayer:(TLCameraTimelineLayer*)aLayer
				offsetsFromDate:(NSDate*)startDate
						 toDate:(NSDate*)endDate
{
	(void)aLayer;
	return [[self cameraTimeline] offsetTimestampVerticesFrom:startDate to:endDate];
}

- (BOOL)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
			   writePhotos:(NSArray*)photos
			  toPasteboard:(NSPasteboard*)pasteboard
{
	(void)layer;
	return TLMercatalogWritePhotosToPasteboard(photos, pasteboard, self);
}

- (NSArray*)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
			filenamesForPhotos:(NSArray*)photosDropped
		 promisedAtDestination:(NSURL*)dropDestination
{
	(void)layer;
	return [self filenamesForPhotos:photosDropped promisedAtDestination:dropDestination];
}


#pragma mark Drop destination

- (TLTimestamp*)timestampForMouseInTimeline:(CGPoint)targetPoint withInfo:(id < TLTimelineInfo >)timelineInfo {
	tl_time_t mouseTime = [timelineInfo timeForPoint:targetPoint].time;
	NSDate* mouseDate = TLTimeToDate(mouseTime);
	
	CGFloat positionInaccuracy = [timelineInfo significantInteractiveSize].width / 2.0f;
	CGPoint earlyMousePoint = CGPointMake(targetPoint.x - positionInaccuracy, targetPoint.y);
	tl_time_t earliestMouseTime = [timelineInfo timeForPoint:earlyMousePoint].time;
	CGPoint lateMousePoint = CGPointMake(targetPoint.x - positionInaccuracy, targetPoint.y);
	tl_time_t latestMouseTime = [timelineInfo timeForPoint:lateMousePoint].time;
	NSTimeInterval mouseAccuracy = (latestMouseTime - earliestMouseTime) / 2.0f;
	
	return [TLTimestamp timestampWithTime:mouseDate accuracy:mouseAccuracy];
}

- (BOOL)acceptInternalDrop:(id < NSDraggingInfo >)dropInfo
		  withTimelineInfo:(id < TLTimelineInfo >)timelineInfo
			   previewOnly:(BOOL)justPreview
{
	NSPasteboard* pasteboard = [dropInfo draggingPasteboard];
	NSArray* photos = TLMercatalogPhotosFromPasteboard(pasteboard);
	if (![photos count] || TLMercatalogPhotosAreLocked(photos)) return NO;
	
	CGPoint mouseInTimeline = [timelineInfo convertWindowPointToTimeline:[dropInfo draggingLocation]];
	TLTimestamp* mouseTimestamp = [self timestampForMouseInTimeline:mouseInTimeline withInfo:timelineInfo];
	NSMapTable* photoTimestamps = TLMercatalogTimestampPhotos(photos, mouseTimestamp);
	NSMapTable* photoLocations = [[self locator] locateTimestamps:photoTimestamps];
	if (justPreview) {
		NSArray* dropTimestamps = TLNSMapTableAllObjects(photoTimestamps);
		NSArray* dropLocations = TLNSMapTableAllObjects(photoLocations);
		[photoLayer setPreviewTimestamps:dropTimestamps];
		[self setPreviewLocations:dropLocations];
	}
	else {
		for (TLPhoto* photo in photos) {
			TLTimestamp* newTimestamp = [photoTimestamps objectForKey:photo];
			TLLocation* newLocation = [photoLocations objectForKey:photo];
			[photo setTimestamp:newTimestamp];
			[photo setLocation:newLocation];
		}
		[self setPreviewLocations:nil];
	}
	return YES;
}

- (NSDragOperation)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
						 validateDrop:(id < NSDraggingInfo >)dropInfo
							 withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)layer;
	
	BOOL internalDrop = [self acceptInternalDrop:dropInfo withTimelineInfo:timelineInfo previewOnly:YES];
	return internalDrop ? TLDragOperationInternal : NSDragOperationNone;
}

- (BOOL)photoTimelineLayer:(TLPhotoTimelineLayer*)layer
				acceptDrop:(id < NSDraggingInfo >)dropInfo
				  withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)layer;
	
	return [self acceptInternalDrop:dropInfo withTimelineInfo:timelineInfo previewOnly:NO];
}

- (void)photoTimelineLayerDropDidCancel:(TLPhotoTimelineLayer*)layer {
	(void)layer;
	[self setPreviewLocations:nil];
}

@end
