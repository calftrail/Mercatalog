//
//  TLMapController.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLMapController.h"

#import "TLMapView.h"
#import "TLMapFrameLayer.h"
#import "TLGraticuleMapLayer.h"
#import "TLNaturalEarthLayer.h"
#import "TLMapNavigationLayer.h"
#import "TLMapLocationLayer.h"
#import "TLPhotoLayer.h"
#import "TLTrackLayer.h"

#import "TLLibraryHost.h"
#import "TLTrack.h"
#import "TLPhoto.h"
#import "TLLocation.h"
#import "TLTimestamp.h"
#import "TLLocator.h"

#include "TLGeometry.h"

#include "TLMercatalogControllerShared.h"
#import "TLCocoaToolbag.h"


const NSDragOperation TLDragOperationInternal = NSDragOperationPrivate;


@implementation TLMapController

#pragma mark Lifecycle

- (void)awakeFromNib {
	TLMapFrameLayer* mapFrameLayer = [[TLMapFrameLayer new] autorelease];
	[view addLayer:mapFrameLayer];
    
    TLNaturalEarthLayer* naturalEarthLayer = [[TLNaturalEarthLayer new] autorelease];
    [view addLayer:naturalEarthLayer];
	
    TLGraticuleMapLayer* graticuleLayer = [[TLGraticuleMapLayer new] autorelease];
	[view addLayer:graticuleLayer];
	
	trackLayer = [[TLTrackLayer new] autorelease];
	[trackLayer setDataSource:self];
	//[trackLayer setHidden:YES];
	[view addLayer:trackLayer];
	
	navigationLayer = [[TLMapNavigationLayer new] autorelease];
	[navigationLayer setDelegate:self];
	[view addLayer:navigationLayer];
	
	locationLayer = [[TLMapLocationLayer new] autorelease];
	[locationLayer setDelegate:self];
	[view addLayer:locationLayer];
	 
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	[locationLayer setHomeBase:[host homeBase]];
	
	NSArray* dropTypes = TLMercatalogAcceptedDropTypes();
	photoLayer = [[TLPhotoLayer new] autorelease];
	[photoLayer setDelegate:self];
	[photoLayer setDataSource:self];
	[photoLayer setRegisteredDragTypes:dropTypes];
	[view addLayer:photoLayer];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[modelContext release];
	[navigationLayer setDelegate:nil];
	[locationLayer setDelegate:nil];
	[photoLayer setDelegate:nil];
	[photoLayer setDataSource:nil];
	[trackLayer setDataSource:nil];
	[view release];
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
	view = [[TLMapView alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, 1.0f, 1.0f)];
	[view setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
	[view awakeFromNib];
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
	[locationLayer setHidden:!newTracksVisible];
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

- (void)setDisplayedPhotos:(NSSet*)newDisplayedPhotos {
	[photoLayer setDisplayedPhotos:newDisplayedPhotos];
}

- (NSSet*)displayedPhotos {
	return [photoLayer displayedPhotos];
}

- (IBAction)zoomCompletelyOut:(id)sender {
	[navigationLayer zoomCompletelyOut:sender];
}

- (void)setPreviewTimestamps:(NSArray*)previewTimestamps {
	(void)previewTimestamps;
	
	if ([[self delegate]
		 respondsToSelector:@selector(mapControllerWantsPreview:forTimestamps:)])
	{
		[[self delegate] mapControllerWantsPreview:self
									 forTimestamps:previewTimestamps];
	}
}

- (void)setPreviewLocations:(NSArray*)previewLocations {
	[photoLayer setPreviewLocations:previewLocations];
}

- (void)setMouseLocation:(TLLocation*)mouseLocation {
	[locationLayer setPreviewLocation:mouseLocation];
}

- (void)mapLocationLayerDidSetHomeBase:(TLMapLocationLayer*)theLocationLayer {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	[host setHomeBase:[theLocationLayer homeBase]];
}

- (void)mapNavigationLayerDidIgnoreClick:(TLMapNavigationLayer*)navLayer {
	(void)navLayer;
	[photoLayer setSelectedPhotos:nil];
}

- (void)photoMapLayerSelectionDidChange:(NSNotification*)notification {
	(void)notification;
	NSNotification* newNotification = [NSNotification notificationWithName:TLMercatalogSelectionDidChangeNotification
																	object:self];
	if ([[self delegate] respondsToSelector:@selector(controllerSelectionDidChange:)]) {
		[[self delegate] controllerSelectionDidChange:newNotification];
	}
	[[NSNotificationCenter defaultCenter] postNotification:newNotification];
}

- (TLLocator*)locator {
	TLLocator* locator = [[TLLocator new] autorelease];
	[locator setModelContext:[self modelContext]];
	return locator;
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

- (void)performFileImportInBackground:(NSArray*)filenames {
	if ([[self delegate] respondsToSelector:@selector(controllerNeedsImport:forFiles:)]) {
		[[self delegate] controllerNeedsImport:self forFiles:filenames];
	}
}


#pragma mark Data source

- (NSArray*)trackLayer:(TLTrackLayer*)layer
		tracksInBounds:(TLBounds)bounds
	   underProjection:(TLProjectionRef)proj
{
	(void)layer;
	(void)bounds;
	(void)proj;
	
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host allTracks];
}

- (NSArray*)photoLayer:(TLPhotoLayer*)layer
		photosInBounds:(TLBounds)bounds
	   underProjection:(TLProjectionRef)proj
{
	(void)layer;
	(void)bounds;
	(void)proj;
	
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host visiblePhotos];
}

- (BOOL)photoLayer:(TLPhotoLayer*)layer
	   writePhotos:(NSArray*)photos
	  toPasteboard:(NSPasteboard*)pasteboard
{
	(void)layer;
	return TLMercatalogWritePhotosToPasteboard(photos, pasteboard, self);
}

- (NSArray*)photoLayer:(TLPhotoLayer*)layer
	filenamesForPhotos:(NSArray*)photosDropped
 promisedAtDestination:(NSURL*)dropDestination
{
	(void)layer;
	return [self filenamesForPhotos:photosDropped promisedAtDestination:dropDestination];
}


#pragma mark Drop destination

- (NSMapTable*)locatePhotos:(NSArray*)photos usingSingleLocation:(TLLocation*)location {
	NSMapTable* photoLocations = [NSMapTable mapTableWithStrongToStrongObjects];
	for (TLPhoto* photo in photos) {
		[photoLocations setObject:[location perturbedLocation] forKey:photo];
	}
	return photoLocations;
}

- (TLLocation*)locationForMouseInMap:(CGPoint)targetPoint withInfo:(id < TLMapInfo >)mapInfo {
	TLProjectionError err = TLProjectionErrorNone;
	TLCoordinate mouseCoord = TLProjectionUnprojectPoint([mapInfo projection], targetPoint, &err);
	if (err) return nil;
	CGSize interactiveSize = [mapInfo significantInteractiveSize];
	CGFloat interactiveDistance = TLSizeGetAverageWidth(interactiveSize);
	TLCoordinateAccuracy mouseAccuracy = interactiveDistance / 2.0f;
	return [TLLocation locationWithCoordinate:mouseCoord
						   horizontalAccuracy:mouseAccuracy];
}

- (NSSet*)timestampsForMouseInMap:(CGPoint)targetPoint withInfo:(id < TLMapInfo >)mapInfo {
	TLLocation* mouseLocation = [self locationForMouseInMap:targetPoint withInfo:mapInfo];
	if (!mouseLocation) return nil;
	const double trackSnapFactor = 40.0f;
	TLCoordinateAccuracy searchDistance = trackSnapFactor * [mouseLocation horizontalAccuracy];
	TLLocation* searchLocation = [TLLocation locationWithCoordinate:[mouseLocation coordinate]
												 horizontalAccuracy:searchDistance];
	return [[self locator] trackTimestampsAtLocation:searchLocation];
}

- (TLTimestamp*)timestampNearestPhoto:(TLPhoto*)firstPhoto inTimestamps:(NSSet*)timestamps {
	NSDate* targetDate = [[firstPhoto timestamp] time];
	
	TLTimestamp* closestTimestamp = nil;
	NSTimeInterval closestInterval = 0.0;
	for (TLTimestamp* timestamp in timestamps) {
		NSTimeInterval interval = fabs([targetDate timeIntervalSinceDate:[timestamp time]]);
		if (!closestTimestamp || interval < closestInterval) {
			closestTimestamp = timestamp;
			closestInterval = interval;
		}
	}
	return closestTimestamp;
}

- (BOOL)acceptInternalDrop:(id < NSDraggingInfo >)dropInfo
			   withMapInfo:(id < TLMapInfo >)mapInfo
			   previewOnly:(BOOL)justPreview
{
	NSPasteboard* pasteboard = [dropInfo draggingPasteboard];
	NSArray* photos = TLMercatalogPhotosFromPasteboard(pasteboard);
	if (![photos count] || TLMercatalogPhotosAreLocked(photos)) return NO;
	
	CGPoint mouseOnMap = [mapInfo convertWindowPointToMap:[dropInfo draggingLocation]];
	NSSet* mouseTimestamps = [self timestampsForMouseInMap:mouseOnMap withInfo:mapInfo];
	if ([mouseTimestamps count]) {
		// use timestamp closest to first photo's timestamp
		TLPhoto* mousePhoto = [photos objectAtIndex:0];
		TLTimestamp* mouseTimestamp = [self timestampNearestPhoto:mousePhoto
													 inTimestamps:mouseTimestamps];
		NSMapTable* photoTimestamps = TLMercatalogTimestampPhotos(photos, mouseTimestamp);
		NSMapTable* photoLocations = [[self locator] locateTimestamps:photoTimestamps];
		if (justPreview) {
			NSArray* previewTimestamps = TLNSMapTableAllObjects(photoTimestamps);
			NSArray* previewLocations = TLNSMapTableAllObjects(photoLocations);
			[self setPreviewTimestamps:previewTimestamps];
			[photoLayer setPreviewLocations:previewLocations];
		}
		else {
			for (TLPhoto* photo in photos) {
				TLTimestamp* newTimestamp = [photoTimestamps objectForKey:photo];
				TLLocation* newLocation = [photoLocations objectForKey:photo];
				[photo setTimestamp:newTimestamp];
				[photo setLocation:newLocation];
			}
			[self setPreviewTimestamps:nil];
		}
	}
	else {
		TLLocation* mouseLocation = [self locationForMouseInMap:mouseOnMap withInfo:mapInfo];
		NSMapTable* photoLocations = [self locatePhotos:photos usingSingleLocation:mouseLocation];
		if (justPreview) {
			NSArray* previewLocations = TLNSMapTableAllObjects(photoLocations);
			[photoLayer setPreviewLocations:previewLocations];
		}
		else {
			for (TLPhoto* photo in photos) {
				TLLocation* newLocation = [photoLocations objectForKey:photo];
				[photo setLocation:newLocation];
			}
		}
		[self setPreviewTimestamps:nil];
	}
	
	return YES;
}

- (BOOL)acceptExternalDrop:(id < NSDraggingInfo >)dropInfo
			   withMapInfo:(id < TLMapInfo >)mapInfo
			   previewOnly:(BOOL)justPreview
{
	(void)mapInfo;
	
	NSPasteboard* pasteboard = [dropInfo draggingPasteboard];
	NSArray* filenames = TLMercatalogFilesFromPasteboard(pasteboard);
	if (![filenames count]) return NO;
	
	if (!justPreview) {
		[self performFileImportInBackground:filenames];
	}
	return YES;
}

- (NSDragOperation)photoLayer:(TLPhotoLayer*)layer
				 validateDrop:(id < NSDraggingInfo >)dropInfo
				  withMapInfo:(id < TLMapInfo >)mapInfo
{
	(void)layer;
	
	BOOL internalDrop = [self acceptInternalDrop:dropInfo withMapInfo:mapInfo previewOnly:YES];
	if (internalDrop) return TLDragOperationInternal;
	
	BOOL externalDrop = [self acceptExternalDrop:dropInfo withMapInfo:mapInfo previewOnly:YES];
	if (externalDrop) return NSDragOperationLink;
	
	return NSDragOperationNone;
}

- (BOOL)photoLayer:(TLPhotoLayer*)layer
		acceptDrop:(id < NSDraggingInfo >)dropInfo
	   withMapInfo:(id < TLMapInfo >)mapInfo
{
	(void)layer;
	
	BOOL internalDrop = [self acceptInternalDrop:dropInfo withMapInfo:mapInfo previewOnly:NO];
	if (internalDrop) return YES;
	
	BOOL externalDrop = [self acceptExternalDrop:dropInfo withMapInfo:mapInfo previewOnly:NO];
	if (externalDrop) return YES;
	
	return NO;
}

- (void)photoLayerDropDidCancel:(TLPhotoLayer*)layer {
	(void)layer;
	[self setPreviewTimestamps:nil];
}

@end
