//
//  TLPhotoTimelineLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLPhotoTimelineLayer.h"

#import "TLPhoto.h"
#import "TLOffsetTimestamp.h"

#import "TLMercatalogViewShared.h"
#import "TLMercatalogStyler.h"

#import "TLCocoaToolbag.h"
#import "TLSelectionManager.h"
#include "TLGeometry.h"
#include "TLFloat.h"


@interface TLPhotoTimelineLayer ()
@property (nonatomic, copy) NSArray* draggedPhotos;
@property (nonatomic, assign, getter=isDragTarget) BOOL dragTarget;
@property (nonatomic, retain) NSMutableSet* mutableDisplayedPhotos;
@property (nonatomic, assign) TLTimeRange selectionRange;
@end

NSString* const TLPhotoTimelineLayerSelectionDidChangeNotification = @"TLPhotoTimelineLayer_SelectionDidChange";
NSString* const TLPhotoTimelineLayerDisplayedPhotosDidChangeNotification = @"TLPhotoTimelineLayer_DisplayedPhotosDidChange";

@implementation TLPhotoTimelineLayer

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) {
		selectionManager = [TLSelectionManager new];
		[selectionManager setDelegate:self];
		[selectionManager setContinuousSelectionModel:TLSelectionManagerModelFixedPoint];
		displayedPhotos = [NSMutableSet new];
		
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
	[previewTimestamps release];
	[displayedPhotos release];
	[super dealloc];
}


#pragma mark Basic accessors

@synthesize delegate;

- (void)reloadData {
	[self setNeedsDisplay];
}

@synthesize dataSource;

- (void)setDataSource:(id)newDataSource {
	dataSource = newDataSource;
	[self reloadData];
}

@synthesize dragTarget;

- (void)setDragTarget:(BOOL)newDragTarget {
	if (newDragTarget == dragTarget) return;
	dragTarget = newDragTarget;
	[self setNeedsDisplay];
}

@synthesize previewTimestamps;

- (void)setPreviewTimestamps:(NSArray*)newPreviewTimestamps {
	[previewTimestamps autorelease];
	previewTimestamps = [newPreviewTimestamps copy];
	[self setNeedsDisplay];
}

- (NSArray*)dataSourcePhotosInTimeRange:(TLTimeRange)timeRange {
	NSArray* photos = nil;
	if ([[self dataSource] respondsToSelector:@selector(photoTimelineLayer:photosFromDate:toDate:)]) {
		NSDate* startDate = TLTimeToDate(timeRange.start);
		NSDate* endDate = TLTimeToDate(timeRange.start + timeRange.duration);
		photos = [[self dataSource] photoTimelineLayer:self photosFromDate:startDate toDate:endDate];
	}
	return photos;
}

- (TLTimeRange)selectionRange {
	return TLTimeRangeMake(selectionStart, selectionDuration);
}

- (void)setSelectionRange:(TLTimeRange)newSelectionRange {
	selectionStart = newSelectionRange.start;
	selectionDuration = newSelectionRange.duration;
	[self setNeedsDisplay];
}

//@synthesize displayedPhotos;
- (NSSet*)displayedPhotos {
	return displayedPhotos;
}
@synthesize mutableDisplayedPhotos = displayedPhotos;

- (void)notifyDisplayedPhotosDidChange {
	NSNotification* notification = [NSNotification notificationWithName:TLPhotoTimelineLayerDisplayedPhotosDidChangeNotification
																 object:self];
	if ([[self delegate] respondsToSelector:@selector(photoTimelineLayerDisplayedPhotosDidChange:)]) {
		[[self delegate] photoTimelineLayerDisplayedPhotosDidChange:notification];
	}
	[[NSNotificationCenter defaultCenter] postNotification:notification];
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

- (void)notifySelectionDidChange {
	NSNotification* notification = [NSNotification notificationWithName:TLPhotoTimelineLayerSelectionDidChangeNotification
																 object:self];
	if ([[self delegate] respondsToSelector:@selector(photoTimelineLayerSelectionDidChange:)]) {
		[[self delegate] photoTimelineLayerSelectionDidChange:notification];
	}
	[[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)selectionManagerDidChangeSelection:(TLSelectionManager*)manager {
	NSAssert(manager == selectionManager, @"Delegate method must be called by instance's SelectionManger");
	[self setNeedsDisplay];
	[self notifySelectionDidChange];
}

- (void)systemColorsChanged:(NSNotification*)notification {
	(void)notification;
	if ([[self selectedPhotos] count] || dragTarget) {
		[self setNeedsDisplay];
	}
}

- (void)setActive:(BOOL)newIsActive {
	if ([self isActive] == newIsActive) return;
	[super setActive:newIsActive];
	[self setNeedsDisplay];
}


#pragma mark Drawing

- (CGRect)photoRectForPhoto:(TLPhoto*)photo
				   withInfo:(id < TLTimelineInfo >)timelineInfo
{
	tl_time_t actualTime = TLTimeFromDate([[photo timestamp] time]);
	NSTimeInterval offset = [[photo offsetTimestamp] offset];
	TLTimePair photoTimePair = TLTimePairMake(actualTime, offset);
	CGPoint photoPoint = [timelineInfo pointForTime:photoTimePair];
	
	CGSize baseSize = [[TLMercatalogStyler defaultStyler] photoProxySize];
	CGSize mmSize = [timelineInfo millimeterSize];
	return TLCGRectMakeAroundPoint(photoPoint,
								   baseSize.width * mmSize.width,
								   baseSize.height * mmSize.height);
}

- (CGRect)previewRectForTimestamp:(TLTimestamp*)timestamp
						 withInfo:(id < TLTimelineInfo >)timelineInfo
{
	tl_time_t previewTime = TLTimeFromDate([timestamp time]);
	NSTimeInterval previewOffset = 0.0;
	if ([timestamp isKindOfClass:[TLOffsetTimestamp class]]) {
		previewOffset = [(TLOffsetTimestamp*)timestamp offset];
	}
	TLTimePair photoTimePair = TLTimePairMake(previewTime, previewOffset);
	CGPoint photoPoint = [timelineInfo pointForTime:photoTimePair];
	
	CGSize baseSize = [[TLMercatalogStyler defaultStyler] photoDropPreviewProxySize];
	CGSize mmSize = [timelineInfo millimeterSize];
	return TLCGRectMakeAroundPoint(photoPoint,
								   baseSize.width * mmSize.width,
								   baseSize.height * mmSize.height);
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	CGRect boundsToDraw = CGContextGetClipBoundingBox(ctx);
	TLTimeRange drawRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, boundsToDraw);
	NSArray* photos = [self dataSourcePhotosInTimeRange:drawRange];
	
	NSMutableArray* newTrackingZones = [NSMutableArray array];
	NSMutableArray* selectedPhotosToDraw = [NSMutableArray array];
	for (TLPhoto* photo in photos) {
		if ([[self selectedPhotos] containsObject:photo]) {
			[selectedPhotosToDraw addObject:photo];
			continue;
		}
		CGRect photoRect = [self photoRectForPhoto:photo withInfo:timelineInfo];
		if (CGRectIsNull(photoRect)) continue;
		TLPhotoDrawProxyInFrame(photo, NO, NO,
								photoRect, ctx,
								[timelineInfo significantVisualSize], [timelineInfo millimeterSize]);
		TLTrackingZone* trackZone = [TLTrackingZone trackingZoneWithBounds:photoRect
																  identity:photo
																  userInfo:nil];
		[newTrackingZones addObject:trackZone];
	}
	BOOL selectionsAreActive = [self isActive];
	for (TLPhoto* photo in selectedPhotosToDraw) {
		CGRect photoRect = [self photoRectForPhoto:photo withInfo:timelineInfo];
		if (CGRectIsNull(photoRect)) continue;
		TLPhotoDrawProxyInFrame(photo, YES, selectionsAreActive,
								photoRect, ctx,
								[timelineInfo significantVisualSize], [timelineInfo millimeterSize]);
		TLTrackingZone* trackZone = [TLTrackingZone trackingZoneWithBounds:photoRect
																  identity:photo
																  userInfo:nil];
		[newTrackingZones addObject:trackZone];
	}
	
	[self setActiveTrackingZones:newTrackingZones];
	
	if ([self isDragTarget] && ![[self previewTimestamps] count]) {
		TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
		CGContextSetStrokeColorWithColor(ctx, [styler dropHighlightColor]);
		CGFloat mmScale = TLSizeGetAverageWidth([timelineInfo millimeterSize]);
		CGFloat dropHighlightWidth = mmScale * [styler dropHighlightWidth];
		CGContextSetLineWidth(ctx, dropHighlightWidth);
		CGRect dropRect = CGRectInset([timelineInfo visibleBounds],
									  dropHighlightWidth / 2.0f, dropHighlightWidth / 2.0f);
		CGContextStrokeRect(ctx, dropRect);
	}
	
	for (TLTimestamp* timestamp in [self previewTimestamps]) {
		CGRect previewRect = [self previewRectForTimestamp:timestamp withInfo:timelineInfo];
		if (CGRectIsNull(previewRect)) continue;
		TLPhotoDrawDropPreviewInFrame(previewRect, ctx);
	}
	
	TLTimeRange currentSelection = [self selectionRange];
	if (currentSelection.duration) {
		TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
		CGFloat mmScale = TLSizeGetAverageWidth([timelineInfo millimeterSize]);
		CGFloat selectionBoxStrokeWidth = mmScale * [styler selectionBoxWidth];
		CGContextSetLineWidth(ctx, selectionBoxStrokeWidth);
		CGColorRef fillColor = TLCGColorCreateGenericHSB(250.0f/360.0f, 1.0f, 0.25f, 0.05f);
		TLCFAutorelease(fillColor);
		CGContextSetFillColorWithColor(ctx, fillColor);
		CGColorRef strokeColor = TLCGColorCreateGenericHSB(250.0f/360.0f, 1.0f, 0.1f, 1.0f);
		TLCFAutorelease(strokeColor);
		CGContextSetStrokeColorWithColor(ctx, strokeColor);
		CGFloat startX = [timelineInfo pointForTime:TLTimePairMake(currentSelection.start, 0.0)].x;
		CGFloat endX = [timelineInfo pointForTime:TLTimePairMake(TLTimeRangeGetEnd(currentSelection), 0.0)].x;
		CGFloat startY = CGRectGetMinY([timelineInfo visibleBounds]);
		CGFloat endY = CGRectGetMaxY([timelineInfo visibleBounds]);
		CGPoint startPoint = CGPointMake(startX, startY);
		CGPoint endPoint = CGPointMake(endX, endY);
		CGRect selectionBox = TLCGRectMakeFromPoints(startPoint, endPoint);
		CGContextFillRect(ctx, selectionBox);
		CGContextStrokeRect(ctx, selectionBox);
	}
}


#pragma mark Mouse tracking

- (void)mouseEntered:(NSEvent*)mouseEventOrNil trackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEventOrNil;
	(void)timelineInfo;
	
	TLPhoto* enteredPhoto = [zone identity];
	NSMutableSet* photos = [self mutableDisplayedPhotos];
	[photos addObject:enteredPhoto];
	[self notifyDisplayedPhotosDidChange];
}

/*
- (void)mouseMoved:(NSEvent*)mouseEventOrNil inTrackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEventOrNil;
	(void)zone;
	(void)timelineInfo;
}
 */

- (void)mouseExited:(NSEvent*)mouseEventOrNil trackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEventOrNil;
	(void)timelineInfo;
	
	TLPhoto* exitedPhoto = [zone identity];
	NSMutableSet* photos = [self mutableDisplayedPhotos];
	[photos removeObject:exitedPhoto];
	[self notifyDisplayedPhotosDidChange];
}


#pragma mark Mouse event handling

- (NSSet*)photosUnderPoint:(CGPoint)targetPoint withInfo:(id < TLTimelineInfo >)timelineInfo forHitTest:(BOOL)stopAfterOneFound {
	CGSize interactiveSize = [timelineInfo significantInteractiveSize];
	
	CGRect targetBounds = TLCGRectMakeAroundPoint(targetPoint,
												  2.0f * interactiveSize.width,
												  2.0f * interactiveSize.height);
	TLTimeRange searchRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, targetBounds);
	NSArray* nearbyPhotos = [self dataSourcePhotosInTimeRange:searchRange];
	
	NSMutableSet* hitPhotos = [NSMutableSet set];
	for (TLPhoto* photo in nearbyPhotos) {
		CGRect photoRect = [self photoRectForPhoto:photo withInfo:timelineInfo];
		if (CGRectIsNull(photoRect)) continue;
		CGRect photoTarget = CGRectInset(photoRect, -interactiveSize.width, -interactiveSize.height);
		if (CGRectContainsPoint(photoTarget, targetPoint)) {
			[hitPhotos addObject:photo];
			if (stopAfterOneFound) break;
		}
	}
	return hitPhotos;
}

typedef struct {
	tl_time_t targetTime;
} TLPhotoTimelineCompareContext;

static NSComparisonResult TLCompareBasedOnDistanceToTime(TLPhoto* photo1, TLPhoto* photo2, void* contextPtr) {
	TLPhotoTimelineCompareContext* info = (TLPhotoTimelineCompareContext*)contextPtr;
	tl_time_t targetTime = info->targetTime;
	tl_time_t photoTime1 = TLTimeFromDate([[photo1 timestamp] time]);
	tl_time_t photoTime2 = TLTimeFromDate([[photo2 timestamp] time]);
	NSTimeInterval photoDistance1 = fabs(photoTime1 - targetTime);
	NSTimeInterval photoDistance2 = fabs(photoTime2 - targetTime);
	return TLFloatCompareNaive(photoDistance1, photoDistance2);
}

- (NSArray*)sortPhotos:(NSSet*)photos fromTime:(tl_time_t)targetTime {
	NSMutableArray* sortedPhotos = [NSMutableArray arrayWithCapacity:[photos count]];
	for (TLPhoto* photo in photos) [sortedPhotos addObject:photo];
	TLPhotoTimelineCompareContext sortContext = { .targetTime = targetTime };
	[sortedPhotos sortUsingFunction:TLCompareBasedOnDistanceToTime context:&sortContext];
	return sortedPhotos;
}

- (id)selectionManager:(TLSelectionManager*)manager
		itemUnderPoint:(NSPoint)windowPoint
			  userInfo:(void*)userInfo
{
	(void)manager;
	id < TLTimelineInfo > timelineInfo = (id < TLTimelineInfo >)userInfo;
	
	CGPoint targetPoint = [timelineInfo convertWindowPointToTimeline:windowPoint];
	NSSet* hitPhotos = [self photosUnderPoint:targetPoint withInfo:timelineInfo forHitTest:NO];
	tl_time_t targetTime = [timelineInfo timeForPoint:targetPoint].time;
	NSArray* sortedPhotos = [self sortPhotos:hitPhotos fromTime:targetTime];
	if (![sortedPhotos count]) return nil;
	return [sortedPhotos objectAtIndex:0];
}

- (NSSet*)selectionManager:(TLSelectionManager*)manager
		allItemsUnderPoint:(NSPoint)windowPoint
				  userInfo:(void*)userInfo
{
	(void)manager;
	id < TLTimelineInfo > timelineInfo = (id < TLTimelineInfo >)userInfo;
	
	CGPoint targetPoint = [timelineInfo convertWindowPointToTimeline:windowPoint];
	return [self photosUnderPoint:targetPoint withInfo:timelineInfo forHitTest:NO];
}

- (TLTimeRange)timeRangeForPhotos:(NSSet*)photos {
	tl_time_t currentMinTime = 0.0;
	tl_time_t currentMaxTime = 0.0;
	BOOL firstPhoto = YES;
	for (TLPhoto* photo in photos) {
		tl_time_t photoTime = TLTimeFromDate([[photo timestamp] time]);
		if (firstPhoto) {
			currentMaxTime = currentMinTime = photoTime;
		}
		else if (photoTime < currentMinTime) {
			currentMinTime = photoTime;
		}
		if (photoTime > currentMaxTime) {
			currentMaxTime = photoTime;
		}
	}
	return TLTimeRangeMakeWithTimes(currentMinTime, currentMaxTime);
}

- (NSSet*)selectionManager:(TLSelectionManager*)manager
		 itemsBetweenItems:(NSSet*)photos1
				  andItems:(NSSet*)photos2
				  userInfo:(void*)userInfo
{
	(void)manager;
	(void)userInfo;
	
	TLTimeRange range1 = [self timeRangeForPhotos:photos1];
	TLTimeRange range2 = [self timeRangeForPhotos:photos2];
	tl_time_t startTime = fmin(range1.start, range2.start);
	tl_time_t endTime = fmax(TLTimeRangeGetEnd(range1), TLTimeRangeGetEnd(range2));
	TLTimeRange targetRange = TLTimeRangeMakeWithTimes(startTime, endTime);
	NSArray* potentialPhotos = [self dataSourcePhotosInTimeRange:targetRange];
	NSMutableSet* photosBetween = [NSMutableSet set];
	for (TLPhoto* photo in potentialPhotos) {
		tl_time_t photoTime = TLTimeFromDate([[photo timestamp] time]);
		if (TLTimeRangeContainsTime(targetRange, photoTime)) {
			[photosBetween addObject:photo];
		}
	}
	return photosBetween;
}

- (NSSet*)selectionManager:(TLSelectionManager*)manager
				itemsInBox:(NSRect)windowRect
				  userInfo:(void*)userInfo
{
	(void)manager;
	id < TLTimelineInfo > timelineInfo = (id < TLTimelineInfo >)userInfo;
	
	NSPoint windowPoint1 = windowRect.origin;
	NSPoint windowPoint2 = NSMakePoint(windowPoint1.x + windowRect.size.width,
									   windowPoint1.y + windowRect.size.height);
	
	CGPoint layerPoint1 = [timelineInfo convertWindowPointToTimeline:windowPoint1];
	CGPoint layerPoint2 = [timelineInfo convertWindowPointToTimeline:windowPoint2];
	CGRect selectionBounds = TLCGRectMakeFromPoints(layerPoint1, layerPoint2);
	TLTimeRange targetRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, selectionBounds);
	[self setSelectionRange:targetRange];
	
	NSArray* potentialPhotos = [self dataSourcePhotosInTimeRange:targetRange];
	NSMutableSet* photosInBox = [NSMutableSet set];
	for (TLPhoto* photo in potentialPhotos) {
		tl_time_t photoTime = TLTimeFromDate([[photo timestamp] time]);
		if (TLTimeRangeContainsTime(targetRange, photoTime)) {
			[photosInBox addObject:photo];
		}
	}
	return photosInBox;
}

- (BOOL)hitTest:(NSPoint)windowPoint
	  withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLTimelineInfo >)timelineInfo
{
	CGPoint targetPoint = [timelineInfo convertWindowPointToTimeline:windowPoint];
	NSSet* hitPhotos = [self photosUnderPoint:targetPoint withInfo:timelineInfo forHitTest:YES];
	return ([hitPhotos count] || [mouseEventOrNil modifierFlags] & TLPhotoLayerAcceptedEventFlags);
}

- (void)mouseDown:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	[selectionManager mouseDown:mouseEvent userInfo:timelineInfo];
}

- (void)mouseDragged:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	[selectionManager mouseDragged:mouseEvent userInfo:timelineInfo];
}

- (void)mouseUp:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)timelineInfo;
	[selectionManager mouseUp:mouseEvent];
	[self setSelectionRange:TLTimeRangeZero];
}


#pragma mark Drag source

@synthesize draggedPhotos;

- (BOOL)selectionManagerShouldInitiateDragLater:(TLSelectionManager*)manager
									  dragEvent:(NSEvent*)dragEvent
								  originalEvent:(NSEvent*)mouseDownEvent
									   userInfo:(void*)userInfo
{
	(void)manager;
	(void)dragEvent;
	id < TLTimelineInfo > timelineInfo = (id < TLTimelineInfo >)userInfo;
	
	NSSet* unsortedDragPhotos = [self selectedPhotos];
	CGPoint targetPoint = [timelineInfo convertWindowPointToTimeline:[mouseDownEvent locationInWindow]];
	tl_time_t targetTime = [timelineInfo timeForPoint:targetPoint].time;
	NSArray* photosToDrag = [self sortPhotos:unsortedDragPhotos fromTime:targetTime];
	
	BOOL photosWrittenToPasteboard = NO;
	if ([dataSource respondsToSelector:@selector(photoTimelineLayer:writePhotos:toPasteboard:)]) {
		NSPasteboard* pasteboard = [self dragPasteboard];
		photosWrittenToPasteboard = [dataSource photoTimelineLayer:self writePhotos:photosToDrag toPasteboard:pasteboard];
	}
	if (photosWrittenToPasteboard) {
		[self setDraggedPhotos:photosToDrag];
		CGImageRef dragImage = TLPhotoCreateDragImageForPhotos(photosToDrag);
		[self dragWithImage:dragImage anchor:CGPointZero slideBack:YES];
		CGImageRelease(dragImage);
	}
	
	return NO;
}

static const NSDragOperation TLPhotoLayerDefaultDragSourceMask = NSDragOperationCopy;

- (NSDragOperation)dragSourceOperationMaskForLocal:(BOOL)isLocal {
	NSDragOperation dragMask = TLPhotoLayerDefaultDragSourceMask;
	if ([dataSource respondsToSelector:@selector(photoTimelineLayer:dragSourceMaskForPhotos:destinationIsLocal:)]) {
		dragMask = [dataSource photoTimelineLayer:self
						  dragSourceMaskForPhotos:[self draggedPhotos]
							   destinationIsLocal:isLocal];
	}
	return dragMask;
}

- (NSArray*)namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination {
	// NOTE: data source *must* implement the following method if it causes a promise drag
	return [dataSource photoTimelineLayer:self
					   filenamesForPhotos:[self draggedPhotos]
					promisedAtDestination:dropDestination];
}

- (void)dragEndedWithOperation:(NSDragOperation)operation {
	if ([dataSource respondsToSelector:@selector(photoTimelineLayer:concludedDrag:withOperation:)]) {
		[dataSource photoTimelineLayer:self concludedDrag:[self draggedPhotos] withOperation:operation];
	}
	[self setDraggedPhotos:nil];
}


#pragma mark Drag destination

- (NSDragOperation)validateDragging:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	NSDragOperation dragOperation = NSDragOperationNone;
	if ([dataSource respondsToSelector:@selector(photoTimelineLayer:validateDrop:withInfo:)]) {
		dragOperation = [dataSource photoTimelineLayer:self validateDrop:dropInfo withInfo:timelineInfo];
	}
	if (dragOperation) [self setDragTarget:YES];	
	else [self setDragTarget:NO];
	return dragOperation;
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	return [self validateDragging:dropInfo withInfo:timelineInfo];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	return [self validateDragging:dropInfo withInfo:timelineInfo];
}

- (void)draggingExited:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	[self setDragTarget:NO];
	[self setPreviewTimestamps:nil];
	if ([dataSource respondsToSelector:@selector(photoTimelineLayerDropDidCancel:)]) {
		[dataSource photoTimelineLayerDropDidCancel:self];
	}
}

- (void)draggingEnded:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	[self setDragTarget:NO];
	[self setPreviewTimestamps:nil];
}

- (BOOL)prepareForDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	return YES;
}

- (BOOL)performDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	BOOL dropSuccessful = NO;
	if ([dataSource respondsToSelector:@selector(photoTimelineLayer:acceptDrop:withInfo:)]) {
		dropSuccessful = [dataSource photoTimelineLayer:self acceptDrop:dropInfo withInfo:timelineInfo];
	}
	return dropSuccessful;
}

@end
