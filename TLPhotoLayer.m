//
//  TLPhotoLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 9/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLPhotoLayer.h"

#import "TLPhoto.h"
#import "TLLocation.h"

#import "TLMercatalogStyler.h"
#import "TLSelectionManager.h"
#import "TLMercatalogViewShared.h"

#include "TLGeometry.h"
#include "TLFloat.h"
#import "TLCocoaToolbag.h"
#import "TLPhotoLayout.h"


const NSUInteger TLPhotoLayerAcceptedEventFlags = NSAlternateKeyMask | NSShiftKeyMask | NSCommandKeyMask;
static const CGFloat TLPhotoLayerDragImageSize = 50.0f;

static void TLPhotoDisplayInFrame(TLPhoto* photo, CGRect frame,
								  CGContextRef ctx, CGSize pixelSize);
static void TLPhotoDisplayAnchor(CGPoint anchorPoint, CGPoint framePoint,
								 CGContextRef ctx, CGSize mmSize);

@interface TLPhotoLayer ()
@property (nonatomic, copy) NSArray* draggedPhotos;
@property (nonatomic, assign, getter=isDragTarget) BOOL dragTarget;
@property (nonatomic, assign) TLBounds selectionBox;

// tracking zone management
- (void)startActiveTrackingSet;
- (void)finishActiveTrackingSet;
- (void)enableTrackingZone:(TLTrackingZone*)trackingZone;
@end


NSString* const TLPhotoMapLayerSelectionDidChangeNotification = @"TLPhotoMapLayer_SelectionDidChangeNotification";
static NSString* const TLPhotoLayerPhotoKey = @"TLMercatalogPhotoLayer_TrackedPhotoKey";


@implementation TLPhotoLayer

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) {
		selectionManager = [TLSelectionManager new];
		[selectionManager setDelegate:self];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(systemColorsChanged:)
													 name:NSControlTintDidChangeNotification
												   object:NSApp];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(systemColorsChanged:)
													 name:NSSystemColorsDidChangeNotification
												   object:NSApp];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[selectionManager setDelegate:nil];
	[selectionManager release];
	[previewLocations release];
	[draggedPhotos release];
	[displayedPhotos release];
	[super dealloc];
}


#pragma mark Basic accessors

@synthesize delegate;
@synthesize dataSource;
@synthesize selectionBox;

- (void)setSelectionBox:(TLBounds)newSelectionBox {
	if (TLBoundsEqualToBounds(newSelectionBox, selectionBox)) return;
	selectionBox = newSelectionBox;
	[self setNeedsDisplay];
}

@synthesize displayedPhotos;

- (void)setDisplayedPhotos:(NSSet*)newDisplayedPhotos {
	// TODO: look into why same set of photos can get continually set
	if ([newDisplayedPhotos isEqualToSet:displayedPhotos]) return;
	[displayedPhotos release];
	displayedPhotos = [newDisplayedPhotos copy];
	[self setNeedsDisplay];
}

- (NSArray*)dataSourcePhotosInBounds:(TLBounds)targetBounds underProjection:(TLProjectionRef)proj {
	NSArray* photos = nil;
	if ([dataSource respondsToSelector:@selector(photoLayer:photosInBounds:underProjection:)]) {
		photos = [dataSource photoLayer:self photosInBounds:targetBounds underProjection:proj];
	}
	return photos;
}

@synthesize dragTarget;

- (void)setDragTarget:(BOOL)newDragTarget {
	if (newDragTarget == dragTarget) return;
	dragTarget = newDragTarget;
	[self setNeedsDisplay];
}

@synthesize previewLocations;

- (void)setPreviewLocations:(NSArray*)newPreviewLocations {
	[previewLocations autorelease];
	previewLocations = [newPreviewLocations copy];
	[self setNeedsDisplay];
}

- (void)reloadData {
	[self setNeedsDisplay];
}

- (void)setActive:(BOOL)newIsActive {
	if ([self isActive] == newIsActive) return;
	[super setActive:newIsActive];
	[self setNeedsDisplay];
}

- (void)systemColorsChanged:(NSNotification*)notification {
	(void)notification;
	if ([[self selectedPhotos] count] || dragTarget) {
		[self setNeedsDisplay];
	}
}


#pragma mark Drawing

- (CGRect)photoRectAtLocation:(TLLocation*)photoLocation
					 withInfo:(id < TLMapInfo >)mapInfo
					isPreview:(BOOL)isPreview
{
	TLCoordinate photoCoord = [photoLocation coordinate];
	TLProjectionError err = TLProjectionErrorNone;
	CGPoint photoPoint = TLProjectionProjectCoordinate([mapInfo projection], photoCoord, &err);
	if (err) return CGRectNull;
	
	CGSize baseSize = CGSizeZero;
	if (isPreview) {
		baseSize = [[TLMercatalogStyler defaultStyler] photoDropPreviewProxySize];
	}
	else {
		baseSize = [[TLMercatalogStyler defaultStyler] photoProxySize];
	}
	CGSize mmSize = [mapInfo millimeterSize];
	return TLCGRectMakeAroundPoint(photoPoint,
								   baseSize.width * mmSize.width,
								   baseSize.height * mmSize.height);
}

- (void)emitTrackingZone:(TLBounds)trackingRect forPhoto:(TLPhoto*)photo {
	NSDictionary* trackInfo = [NSDictionary dictionaryWithObject:photo forKey:TLPhotoLayerPhotoKey];
	TLTrackingZone* trackingZone = [TLTrackingZone trackingZoneWithBounds:trackingRect
																 identity:photo
																 userInfo:trackInfo];
	[self enableTrackingZone:trackingZone];
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLMapInfo >)mapInfo {
	[self startActiveTrackingSet];
	CGRect boundsToDraw = CGContextGetClipBoundingBox(ctx);
	TLProjectionRef proj = [mapInfo projection];
	NSArray* photosToDraw = [self dataSourcePhotosInBounds:boundsToDraw underProjection:proj];
	for (TLPhoto* photo in photosToDraw) {
		if ([[self displayedPhotos] containsObject:photo] ||
			[[self selectedPhotos] containsObject:photo])
		{
			continue;
		}
		CGRect photoRect = [self photoRectAtLocation:[photo location] withInfo:mapInfo isPreview:NO];
		if (CGRectIsNull(photoRect)) continue;
		TLPhotoDrawProxyInFrame(photo, NO, NO,
								photoRect, ctx,
								[mapInfo significantVisualSize], [mapInfo millimeterSize]);
		[self emitTrackingZone:photoRect forPhoto:photo];
	}
	// draw selected photos *after* the others so they are always on top
	BOOL selectionsAreActive = [self isActive];
	for (TLPhoto* photo in [self selectedPhotos]) {
		CGRect photoRect = [self photoRectAtLocation:[photo location] withInfo:mapInfo isPreview:NO];
		if (CGRectIsNull(photoRect)) continue;
		TLPhotoDrawProxyInFrame(photo, YES, selectionsAreActive,
								photoRect, ctx,
								[mapInfo significantVisualSize], [mapInfo millimeterSize]);
		[self emitTrackingZone:photoRect forPhoto:photo];
	}
	
	for (TLLocation* previewLocation in [self previewLocations]) {
		CGRect previewRect = [self photoRectAtLocation:previewLocation withInfo:mapInfo isPreview:YES];
		if (CGRectIsNull(previewRect)) continue;
		TLPhotoDrawDropPreviewInFrame(previewRect, ctx);
	}
	
	if ([self isDragTarget] && ![[self previewLocations] count]) {
		TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
		CGContextSetStrokeColorWithColor(ctx, [styler dropHighlightColor]);
		CGFloat mmScale = TLSizeGetAverageWidth([mapInfo millimeterSize]);
		CGFloat dropHighlightWidth = mmScale * [styler dropHighlightWidth];
		CGContextSetLineWidth(ctx, dropHighlightWidth);
		CGRect dropRect = CGRectInset([mapInfo visibleBounds],
									  dropHighlightWidth / 2.0f, dropHighlightWidth / 2.0f);
		CGContextStrokeRect(ctx, dropRect);
	}
	
	if (!TLBoundsEqualToBounds([self selectionBox], TLBoundsZero)) {
		TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
		CGFloat mmScale = TLSizeGetAverageWidth([mapInfo millimeterSize]);
		CGContextSetLineWidth(ctx, mmScale * [styler selectionBoxWidth]);
		CGContextSetFillColorWithColor(ctx, [styler selectionBoxFillColor]);
		CGContextSetStrokeColorWithColor(ctx, [styler selectionBoxStrokeColor]);
		CGContextFillRect(ctx, [self selectionBox]);
		CGContextStrokeRect(ctx, [self selectionBox]);
	}
	
	if ([[self displayedPhotos] count]) {
		CGFloat mmScale = TLSizeGetAverageWidth([mapInfo millimeterSize]);
		CGFloat minPhotoSize = 10.0f * mmScale;
		TLPhotoLayout* photoLayout = [TLPhotoLayout photoLayoutForPhotos:[self displayedPhotos]
																inBounds:[mapInfo visibleBounds]
															minDimension:minPhotoSize
															  projection:proj];
		
		for (TLPhoto* photo in [self displayedPhotos]) {
			if (![photoLayout photoHasLayout:photo]) continue;
			CGPoint photoAnchor = [photoLayout anchorForPhoto:photo];
			CGPoint frameCenter = TLCGRectGetCenter([photoLayout frameForPhoto:photo]);
			TLPhotoDisplayAnchor(photoAnchor, frameCenter,
								 ctx, [mapInfo millimeterSize]);
			
			CGRect photoTrackRect = [self photoRectAtLocation:[photo location] withInfo:mapInfo isPreview:NO];
			[self emitTrackingZone:photoTrackRect forPhoto:photo];
		}
		for (TLPhoto* photo in [self displayedPhotos]) {
			if (![photoLayout photoHasLayout:photo]) continue;
			CGRect photoFrame = [photoLayout frameForPhoto:photo];
			CGRect paddedFrame = CGRectInset(photoFrame,
											 0.05f * CGRectGetWidth(photoFrame),
											 0.05f * CGRectGetHeight(photoFrame));
			TLPhotoDisplayInFrame(photo, paddedFrame, ctx, [mapInfo significantVisualSize]);
		}
	}
	[self finishActiveTrackingSet];
}


#pragma mark Selection accessors

- (void)notifySelectionDidChange {
	NSNotification* notification = [NSNotification notificationWithName:TLPhotoMapLayerSelectionDidChangeNotification
																 object:self];
	if ([[self delegate] respondsToSelector:@selector(photoMapLayerSelectionDidChange:)]) {
		[[self delegate] photoMapLayerSelectionDidChange:notification];
	}
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)selectionManagerDidChangeSelection:(TLSelectionManager*)manager {
	NSAssert(manager == selectionManager, @"Delegate method must be called by instance's SelectionManger");
	[self setNeedsDisplay];
	[self notifySelectionDidChange];
}

- (NSSet*)selectedPhotos {
	return [selectionManager selectedItems];
}

- (void)setSelectedPhotos:(NSSet*)newSelectedPhotos {
	[selectionManager setSelectedItems:newSelectedPhotos];
}

- (void)selectPhotos:(NSArray*)photos byExtendingSelection:(BOOL)shouldExtend {
	NSSet* photosAsSet = [NSSet setWithArray:photos];
	[selectionManager selectItems:photosAsSet byExtendingSelection:shouldExtend];
}


#pragma mark Tracking zone management

- (void)startActiveTrackingSet {
	NSAssert(!pendingTrackingSet, @"Nested tracking sets not allowed");
	pendingTrackingSet = [[NSMutableArray array] retain];
}

- (void)finishActiveTrackingSet {
	NSAssert(pendingTrackingSet, @"Finish requested without started tracking set");
	[self setActiveTrackingZones:pendingTrackingSet];
	[pendingTrackingSet release];
	pendingTrackingSet = nil;
}

- (void)enableTrackingZone:(TLTrackingZone*)trackingZone {
	NSAssert(pendingTrackingSet, @"Can't enable tracking zone without active set");
	[pendingTrackingSet addObject:trackingZone];
}


#pragma mark Mouse event handling

typedef struct TL_PhotoCompareContext {
	CGPoint basePoint;
	TLProjectionRef projection;
} TLPhotoCompareContext;

static NSComparisonResult TLCompareBasedOnDistanceToPoint(TLPhoto* photo1, TLPhoto* photo2, void* contextPtr) {
	TLPhotoCompareContext* info = (TLPhotoCompareContext*)contextPtr;
	CGPoint basePoint = info->basePoint;
	TLProjectionRef proj = info->projection;
	CGPoint projectedPhotoLocation1 = TLProjectionProjectCoordinate(proj, [[photo1 location] coordinate], NULL);
	CGPoint projectedPhotoLocation2 = TLProjectionProjectCoordinate(proj, [[photo2 location] coordinate], NULL);
	CGFloat distance1 = TLPointDistanceSquared(basePoint, projectedPhotoLocation1);
	CGFloat distance2 = TLPointDistanceSquared(basePoint, projectedPhotoLocation2);
	return TLFloatCompareNaive(distance1, distance2);
}

- (NSArray*)sortPhotos:(NSSet*)photos
			 fromPoint:(NSPoint)windowPoint
			  withInfo:(id < TLMapInfo >)mapInfo
{
	TLProjectionRef proj = [mapInfo projection];
	CGPoint targetPoint = [mapInfo convertWindowPointToMap:windowPoint];
	NSMutableArray* sortedPhotos = [NSMutableArray arrayWithCapacity:[photos count]];
	for (TLPhoto* photo in photos) [sortedPhotos addObject:photo];
	TLPhotoCompareContext sortContext = {.basePoint = targetPoint, .projection = proj};
	[sortedPhotos sortUsingFunction:TLCompareBasedOnDistanceToPoint context:&sortContext];
	return sortedPhotos;
}

- (NSSet*)photosUnderPoint:(NSPoint)windowPoint withInfo:(id < TLMapInfo >)mapInfo forHitTest:(BOOL)stopAfterOneFound {
	CGSize interactiveSize = [mapInfo significantInteractiveSize];
	
	CGPoint targetPoint = [mapInfo convertWindowPointToMap:windowPoint];
	CGRect searchBounds = TLCGRectMakeAroundPoint(targetPoint,
												  2.0f * interactiveSize.width,
												  2.0f * interactiveSize.height);
	TLProjectionRef proj = [mapInfo projection];
	NSArray* nearbyPhotos = [self dataSourcePhotosInBounds:searchBounds underProjection:proj];
	
	NSMutableSet* hitPhotos = [NSMutableSet set];
	for (TLPhoto* photo in nearbyPhotos) {
		CGRect photoRect = [self photoRectAtLocation:[photo location] withInfo:mapInfo isPreview:NO];
		if (CGRectIsNull(photoRect)) continue;
		CGRect photoTarget = CGRectInset(photoRect, -interactiveSize.width, -interactiveSize.height);
		if (CGRectContainsPoint(photoTarget, targetPoint)) {
			[hitPhotos addObject:photo];
			if (stopAfterOneFound) break;
		}
	}
	return hitPhotos;
}

- (id)selectionManager:(TLSelectionManager*)manager
		itemUnderPoint:(NSPoint)windowPoint
			  userInfo:(void*)userInfo
{
	(void)manager;
	id < TLMapInfo > mapInfo = (id < TLMapInfo >)userInfo;
	
	NSSet* photos = [self photosUnderPoint:windowPoint withInfo:mapInfo forHitTest:NO];
	NSArray* sortedPhotos = [self sortPhotos:photos fromPoint:windowPoint withInfo:mapInfo];
	if (![sortedPhotos count]) return nil;
	return [sortedPhotos objectAtIndex:0];
}

- (NSSet*)selectionManager:(TLSelectionManager*)manager
		allItemsUnderPoint:(NSPoint)windowPoint
				  userInfo:(void*)userInfo
{
	(void)manager;
	id < TLMapInfo > mapInfo = (id < TLMapInfo >)userInfo;
	
	return [self photosUnderPoint:windowPoint withInfo:mapInfo forHitTest:NO];
}

- (NSSet*)selectionManager:(TLSelectionManager*)manager
				itemsInBox:(NSRect)windowRect
				  userInfo:(void*)userInfo
{
	(void)manager;
	id < TLMapInfo > mapInfo = (id < TLMapInfo >)userInfo;
	
	NSPoint windowPoint1 = windowRect.origin;
	NSPoint windowPoint2 = NSMakePoint(windowPoint1.x + windowRect.size.width,
									   windowPoint1.y + windowRect.size.height);
	
	CGPoint mapPoint1 = [mapInfo convertWindowPointToMap:windowPoint1];
	CGPoint mapPoint2 = [mapInfo convertWindowPointToMap:windowPoint2];
	TLBounds targetBounds = TLCGRectMakeFromPoints(mapPoint1, mapPoint2);
	[self setSelectionBox:targetBounds];
	
	TLProjectionRef proj = [mapInfo projection];
	NSArray* nearbyPhotos = [self dataSourcePhotosInBounds:targetBounds underProjection:proj];
	
	NSMutableSet* hitPhotos = [NSMutableSet set];
	for (TLPhoto* photo in nearbyPhotos) {
		TLCoordinate photoCoord = [[photo location] coordinate];
		TLProjectionError err = TLProjectionErrorNone;
		CGPoint photoPoint = TLProjectionProjectCoordinate(proj, photoCoord, &err);
		if (err) continue;
		
		if (CGRectContainsPoint(targetBounds, photoPoint)) {
			[hitPhotos addObject:photo];
		}
	}
	return hitPhotos;
}



- (BOOL)selectionManagerShouldInitiateDragLater:(TLSelectionManager*)manager
									  dragEvent:(NSEvent*)dragEvent
								  originalEvent:(NSEvent*)mouseDownEvent
									   userInfo:(void*)userInfo
{
	(void)manager;
	(void)dragEvent;
	id < TLMapInfo > mapInfo = (id < TLMapInfo >)userInfo;
	
	NSArray* photosToDrag = [self sortPhotos:[self selectedPhotos]
								   fromPoint:[mouseDownEvent locationInWindow]
									withInfo:mapInfo];
	
	BOOL photosWrittenToPasteboard = NO;
	if ([dataSource respondsToSelector:@selector(photoLayer:writePhotos:toPasteboard:)]) {
		NSPasteboard* pasteboard = [self dragPasteboard];
		photosWrittenToPasteboard = [dataSource photoLayer:self writePhotos:photosToDrag toPasteboard:pasteboard];
	}
	
	if (photosWrittenToPasteboard) {
		[self setDraggedPhotos:photosToDrag];
		CGImageRef dragImage = TLPhotoCreateDragImageForPhotos(photosToDrag);
		[self dragWithImage:dragImage anchor:CGPointZero slideBack:YES];
		CGImageRelease(dragImage);
	}
	
	return NO;
}

- (BOOL)hitTest:(NSPoint)windowPoint
	  withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLMapInfo >)mapInfo
{
	NSSet* hitPhotos = [self photosUnderPoint:windowPoint withInfo:mapInfo forHitTest:YES];
	return ([hitPhotos count] || [mouseEventOrNil modifierFlags] & TLPhotoLayerAcceptedEventFlags);
}

- (void)mouseDown:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	[selectionManager mouseDown:mouseEvent userInfo:mapInfo];
}

- (void)mouseDragged:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	[selectionManager mouseDragged:mouseEvent userInfo:mapInfo];
}

- (void)mouseUp:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	(void)mapInfo;
	[selectionManager mouseUp:mouseEvent];
	[self setSelectionBox:TLBoundsZero];
}


#pragma mark Drag source

@synthesize draggedPhotos;

static const NSDragOperation TLPhotoLayerDefaultDragSourceMask = NSDragOperationCopy;

- (NSDragOperation)dragSourceOperationMaskForLocal:(BOOL)isLocal {
	NSDragOperation dragMask = TLPhotoLayerDefaultDragSourceMask;
	if ([dataSource respondsToSelector:@selector(photoLayer:dragSourceMaskForPhotos:destinationIsLocal:)]) {
		dragMask = [dataSource photoLayer:self
				  dragSourceMaskForPhotos:[self draggedPhotos]
					   destinationIsLocal:isLocal];
	}
	return dragMask;
}

- (NSArray*)namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination {
	// NOTE: data source *must* implement the following method if it causes a promise drag
	return [dataSource photoLayer:self
			   filenamesForPhotos:[self draggedPhotos]
			promisedAtDestination:dropDestination];
}

- (void)dragEndedWithOperation:(NSDragOperation)operation {
	if ([dataSource respondsToSelector:@selector(photoLayer:concludedDrag:withOperation:)]) {
		[dataSource photoLayer:self concludedDrag:[self draggedPhotos] withOperation:operation];
	}
	[self setDraggedPhotos:nil];
}


#pragma mark Drag destination

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLMapInfo >)mapInfo {
	NSDragOperation dragOperation = NSDragOperationNone;
	if ([dataSource respondsToSelector:@selector(photoLayer:validateDrop:withMapInfo:)]) {
		dragOperation = [dataSource photoLayer:self validateDrop:dropInfo withMapInfo:mapInfo];
	}
	if (dragOperation) [self setDragTarget:YES];
	return dragOperation;
}

- (void)draggingExited:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLMapInfo >)mapInfo {
	(void)dropInfo;
	(void)mapInfo;
	[self setDragTarget:NO];
	[self setPreviewLocations:nil];
	if ([dataSource respondsToSelector:@selector(photoLayerDropDidCancel:)]) {
		[dataSource photoLayerDropDidCancel:self];
	}
}

- (void)draggingEnded:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLMapInfo >)mapInfo {
	(void)dropInfo;
	(void)mapInfo;
	[self setDragTarget:NO];
	[self setPreviewLocations:nil];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLMapInfo >)mapInfo {
	NSDragOperation dragOperation = NSDragOperationNone;
	if ([dataSource respondsToSelector:@selector(photoLayer:validateDrop:withMapInfo:)]) {
		dragOperation = [dataSource photoLayer:self validateDrop:dropInfo withMapInfo:mapInfo];
	}
	if (dragOperation) [self setDragTarget:YES];
	else [self setDragTarget:NO];
	return dragOperation;
}

- (BOOL)prepareForDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLMapInfo >)mapInfo {
	(void)dropInfo;
	(void)mapInfo;
	return YES;
}

- (BOOL)performDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLMapInfo >)mapInfo {
	BOOL dropSuccessful = NO;
	if ([dataSource respondsToSelector:@selector(photoLayer:acceptDrop:withMapInfo:)]) {
		dropSuccessful = [dataSource photoLayer:self acceptDrop:dropInfo withMapInfo:mapInfo];
	}
	return dropSuccessful;
}


#pragma mark Mouseover handling

- (void)mouseEntered:(id < TLMapInfo >)mapInfo trackingZone:(TLTrackingZone*)zone withEvent:(NSEvent*)mouseEventOrNil {
	(void)mapInfo;
	(void)mouseEventOrNil;
	TLPhoto* photo = [[zone userInfo] objectForKey:TLPhotoLayerPhotoKey];
	
	NSMutableSet* currentDisplayedPhotos = [[self displayedPhotos] mutableCopy];
	if (!currentDisplayedPhotos) currentDisplayedPhotos = [NSMutableSet set];
	//printf("+ had %lu, ", (tl_uint_t)[currentDisplayedPhotos count]);
	[currentDisplayedPhotos addObject:photo];
	//printf("now %lu\n", (tl_uint_t)[currentDisplayedPhotos count]);
	[self setDisplayedPhotos:currentDisplayedPhotos];
}

- (void)mouseExited:(id < TLMapInfo >)mapInfo trackingZone:(TLTrackingZone*)zone withEvent:(NSEvent*)mouseEventOrNil {
	(void)mapInfo;
	(void)mouseEventOrNil;
	TLPhoto* photo = [[zone userInfo] objectForKey:TLPhotoLayerPhotoKey];
	
	NSMutableSet* currentDisplayedPhotos = [[self displayedPhotos] mutableCopy];
	//printf("- had %lu, ", (tl_uint_t)[currentDisplayedPhotos count]);
	[currentDisplayedPhotos removeObject:photo];
	//printf("now %lu\n", (tl_uint_t)[currentDisplayedPhotos count]);
	[self setDisplayedPhotos:currentDisplayedPhotos];
}

@end


#pragma mark Photo drawing helpers

void TLPhotoDisplayInFrame(TLPhoto* photo, CGRect frame,
						   CGContextRef ctx, CGSize pixelSize)
{
	CGFloat pixelWidth = frame.size.width / pixelSize.width;
	CGImageRef thumbnail = [photo createThumbnailForSize:pixelWidth];
	if (thumbnail) {
		CGRect insetFrame = TLCGRectInsetToAspect(frame,
												  CGImageGetWidth(thumbnail),
												  CGImageGetHeight(thumbnail));
		CGContextDrawImage(ctx, insetFrame, thumbnail);
		CGImageRelease(thumbnail);
	}
}

void TLPhotoDrawProxyInFrame(TLPhoto* photo,
							 BOOL isHighlighted, BOOL isActive,
							 CGRect photoRect, CGContextRef ctx,
							 CGSize pixelSize, CGSize mmSize)
{
	TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
	
	CGFloat mmScale = TLSizeGetAverageWidth(mmSize);
	CGFloat pixelWidth = photoRect.size.width / pixelSize.width;
	CGImageRef thumbnail = [photo createThumbnailForSize:pixelWidth];
	if (thumbnail) {
		CGContextDrawImage(ctx, photoRect, thumbnail);
		CGImageRelease(thumbnail);
		
		CGColorRef frameColor = TLCGColorCreateGenericHSB(0.0f, 0.0f, 0.0f, 0.7f);
		CGContextSetStrokeColorWithColor(ctx, frameColor);
		CGColorRelease(frameColor);
		CGContextSetLineWidth(ctx, 0.075f * mmScale);
		CGContextStrokeRect(ctx, photoRect);
	}
	else {
		CGContextSetFillColorWithColor(ctx, [styler photoProxyColor]);
		CGContextFillRect(ctx, photoRect);
	}
	
	if (![photo isLocked]) {
		CGContextAddRect(ctx, photoRect);
		CGColorRef unlockedColor = TLCGColorCreateGenericHSB(40.0f / 360.0f, 1.0f, 1.0f, 0.75f);
		CGContextSetFillColorWithColor(ctx, unlockedColor);
		CGColorRelease(unlockedColor);
		CGContextFillPath(ctx);
	}
	
	if (isHighlighted) {
		if (isActive) {
			CGContextSetStrokeColorWithColor(ctx, [styler activeSelectionColor]);
		}
		else {
			CGContextSetStrokeColorWithColor(ctx, [styler inactiveSelectionColor]);
		}
		CGFloat selectionWidth = mmScale * [styler selectionWidth];
		CGContextSetLineWidth(ctx, selectionWidth);
		CGRect selectionRect = CGRectInset(photoRect, -selectionWidth / 2.0f, -selectionWidth / 2.0f);
		CGContextStrokeRect(ctx, selectionRect);
	}
}

void TLPhotoDrawDropPreviewInFrame(CGRect previewRect, CGContextRef ctx) {
	TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
	CGContextSetStrokeColorWithColor(ctx, [styler photoDropPreviewProxyColor]);
	CGContextStrokeRect(ctx, previewRect);
}

void TLPhotoDisplayAnchor(CGPoint anchorPoint, CGPoint framePoint,
						  CGContextRef ctx, CGSize mmSize)
{
	const CGFloat anchorSize = 0.5f;
	const CGFloat lineWidth = 0.15f;
	CGRect anchorRect = TLCGRectMakeAroundPoint(anchorPoint,
												anchorSize * mmSize.width,
												anchorSize * mmSize.height);
	CGContextAddEllipseInRect(ctx, anchorRect);
	CGColorRef anchorColor = TLCGColorCreateGenericHSB(0.0f, 0.0f, 0.0f, 0.5f);
	CGContextSetFillColorWithColor(ctx, anchorColor);
	CGColorRelease(anchorColor);
	CGContextFillPath(ctx);
	
	CGContextMoveToPoint(ctx, anchorPoint.x, anchorPoint.y);
	CGContextAddLineToPoint(ctx, framePoint.x, framePoint.y);
	
	CGColorRef lineColor = TLCGColorCreateGenericHSB(0.0f, 0.0f, 0.0f, 0.85f);
	CGContextSetStrokeColorWithColor(ctx, lineColor);
	CGColorRelease(lineColor);
	CGContextSetLineWidth(ctx, lineWidth * TLSizeGetAverageWidth(mmSize));
	CGContextStrokePath(ctx);
}

CGImageRef TLPhotoCreateDragImageForPhotos(NSArray* photos) {
	NSCAssert([photos count], @"No photos dragged");
	TLPhoto* representativePhoto = [photos objectAtIndex:0];
	return [representativePhoto createThumbnailForSize:TLPhotoLayerDragImageSize];
}
