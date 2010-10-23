//
//  TLTimelineView.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 3/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineView.h"
#import "TLTimelineView+HostInternals.h"

#import "TLTimelineLayer.h"
#import "TLTimelineLayer+HostInternals.h"
#import "TLTimelineInteractiveLayer.h"

#import "TLTrackingManager.h"

#import "TLTime.h"
#import "TLTimelineInfo.h"

#include "TLFloat.h"
#include "TLCocoaToolbag.h"


@interface TLTimelineView () < TLTimelineInfo >
- (NSDate*)tomorrow;
- (NSDate*)yearAgo;
- (void)setVisibleTimeRange:(TLTimeRange)timeRange;
- (id < TLTimelineInfo >)currentTimelineInfo;
@property (nonatomic, retain) NSEvent* eventForDrag;
- (CGSize)screenPixelsPerMillimeter;
- (void)invalidateDisplaySizeCache;
@end


@implementation TLTimelineView

#pragma mark Lifecycle

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		layers = [NSMutableArray new];
		layerTrackingManagers = [[NSMapTable mapTableWithStrongToStrongObjects] retain];
		startDate = [[self yearAgo] retain];
		endDate = [[self tomorrow] retain];
		timeZone = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[layers release];
	[layerTrackingManagers release];
	[timeZone release];
	[startDate release];
	[endDate release];
	[eventForDrag release];
	[super dealloc];
}


#pragma mark Notifications

- (void)viewWillMoveToWindow:(NSWindow*)newWindow {
	NSWindow* oldWindow = [self window];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowDidChangeScreenNotification
												  object:oldWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowScreenChanged:)
												 name:NSWindowDidChangeScreenNotification
											   object:newWindow];
	[self invalidateDisplaySizeCache];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowDidBecomeKeyNotification
												  object:oldWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateActive:)
												 name:NSWindowDidBecomeKeyNotification
											   object:newWindow];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSWindowDidResignKeyNotification
												  object:oldWindow];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateActive:)
												 name:NSWindowDidResignKeyNotification
											   object:newWindow];
}

- (void)windowScreenChanged:(NSNotification*)notification {
	(void)notification;
	[self invalidateDisplaySizeCache];
	[self setNeedsDisplay:YES];
}

- (void)updateActive:(NSNotification*)notification {
	(void)notification;
	BOOL isActive = ([[self window] isKeyWindow] && [[self window] firstResponder] == self);
	for (TLTimelineLayer* layer in layers) {
		[layer setActive:isActive];
	}
}

- (BOOL)becomeFirstResponder {
	[self updateActive:nil];
	return YES;
}

- (BOOL)resignFirstResponder {
	[self performSelector:@selector(updateActive:) withObject:nil afterDelay:0.0];
	return YES;
}

- (BOOL)acceptsFirstResponder {
	return YES;
}


#pragma mark Accessors

@synthesize timeZone;

- (void)setTimeZone:(NSTimeZone*)newTimeZone {
	if ([newTimeZone isEqualToTimeZone:timeZone]) return;
	(void)[newTimeZone isEqualToTimeZone:nil];
	[timeZone release];
	timeZone = [newTimeZone copy];
	[self setNeedsDisplay:YES];
}

@synthesize eventForDrag;

- (void)addLayer:(TLTimelineLayer*)layer {
	[layers insertObject:layer atIndex:0];
	[layer setHost:self];
	if ([layer isKindOfClass:[TLTimelineInteractiveLayer class]]) {
		TLTimelineInteractiveLayer* interactiveLayer = (TLTimelineInteractiveLayer*)layer;
		[self updateDropTypesForLayer:interactiveLayer];
	}
	[self setNeedsDisplay:YES];
}

@synthesize startDate;

- (void)setStartDate:(NSDate*)newStartDate {
	NSAssert([newStartDate compare:[self endDate]] == NSOrderedAscending, @"Start date must be earlier than end date");
	[startDate autorelease];
	startDate = [newStartDate copy];
	[self setNeedsDisplay:YES];
}

@synthesize endDate;

- (void)setEndDate:(NSDate*)newEndDate {
	NSAssert([newEndDate compare:[self startDate]] == NSOrderedDescending, @"End date must be later than start date");
	[endDate autorelease];
	endDate = [newEndDate copy];
	[self setNeedsDisplay:YES];
}

-(void)setVisibleTimeRange:(TLTimeRange)timeRange {
	NSDate* newStartDate = TLTimeToDate(timeRange.start);
	[self setStartDate:newStartDate];
	NSDate* newEndDate = TLTimeToDate(timeRange.start + timeRange.duration);
	[self setEndDate:newEndDate];
}

static const NSTimeInterval TLTimelineViewApproximateSecondsInDay = 24.0 * 60.0 * 60.0;
static const NSTimeInterval TLTimelineViewApproximateSecondsInYear = 365.0 * 24.0 * 60.0 * 60.0;

- (NSDate*)tomorrow {
	// TODO: should use calendar functions instead, as these gloss over too much
	NSDate* today = [NSDate date];
	return [today addTimeInterval:TLTimelineViewApproximateSecondsInDay];
}

- (NSDate*)yearAgo {
	// TODO: should use calendar functions instead, as these gloss over too much
	NSDate* today = [NSDate date];
	return [today addTimeInterval:-TLTimelineViewApproximateSecondsInYear];
}

- (void)reloadData {
	[self setNeedsDisplay:YES];
}

- (id < TLTimelineInfo >)currentTimelineInfo {
	return self;
}


#pragma mark View-time transform

// position = (time + shiftAmount) * unitsPerSecond
// time = (position / unitsPerSecond) - shiftAmount
- (void)getShiftAmount:(NSTimeInterval*)shiftAmount andUnitsPerSecond:(double*)unitsPerSecond {
	CGFloat viewOrigin = [self bounds].origin.x;
	CGFloat viewWidth = [self bounds].size.width;
	
	tl_time_t timeStart = TLTimeFromDate([self startDate]);
	tl_time_t timeEnd = TLTimeFromDate([self endDate]);
	NSTimeInterval timeWidth = timeEnd - timeStart;
	
	if (shiftAmount) *shiftAmount = viewOrigin - timeStart;
	if (unitsPerSecond) *unitsPerSecond = viewWidth / timeWidth;
}


static const NSTimeInterval TLTimelineViewMaxOffset = 12.0 * 60.0 * 60.0;

- (CGFloat)offsetToY:(NSTimeInterval)offset {
	CGFloat halfHeight = NSMaxY([self bounds]) - NSMidY([self bounds]);
	double pointY = NSMidY([self bounds]) + offset * (halfHeight / TLTimelineViewMaxOffset);
	pointY = fmin(NSMaxY([self bounds]), pointY);
	pointY = fmax(NSMinY([self bounds]), pointY);
	return (CGFloat)pointY;
}

- (NSTimeInterval)offsetFromY:(CGFloat)yPosition {
	CGFloat halfHeight = NSMaxY([self bounds]) - NSMidY([self bounds]);
	CGFloat unshiftedY = yPosition - NSMidY([self bounds]);
	NSTimeInterval interval = unshiftedY * (TLTimelineViewMaxOffset / halfHeight);
	return interval;
}


#pragma mark Screen resolution

- (CGSize)screenPixelsPerMillimeter {
	/* NOTE: TLScreenPixelsPerMillimeter() is an expensive function, so we prefer to use a cached result */
	if (CGSizeEqualToSize(cachedScreenSizeInMillimeters, CGSizeZero)) {
		cachedScreenSizeInMillimeters = TLScreenPixelsPerMillimeter([[self window] screen]);
	}
	return cachedScreenSizeInMillimeters;
}

- (void)invalidateDisplaySizeCache {
	cachedScreenSizeInMillimeters = CGSizeZero;
}


#pragma mark TimelineInfo accessors

- (CGPoint)pointForTime:(TLTimePair)timePair {
	NSTimeInterval shiftAmount = 0.0;
	double unitsPerSecond = 0.0;
	[self getShiftAmount:&shiftAmount andUnitsPerSecond:&unitsPerSecond];
	double pointX = (timePair.time + shiftAmount) * unitsPerSecond;
	CGFloat pointY = [self offsetToY:timePair.offset];
	return CGPointMake((CGFloat)pointX, (CGFloat)pointY);
}

- (TLTimePair)timeForPoint:(CGPoint)timelinePoint {
	NSTimeInterval shiftAmount = 0.0;
	double unitsPerSecond = 0.0;
	[self getShiftAmount:&shiftAmount andUnitsPerSecond:&unitsPerSecond];
	tl_time_t pointTime = (timelinePoint.x / unitsPerSecond) - shiftAmount;
	NSTimeInterval pointOffset = [self offsetFromY:timelinePoint.y];
	return TLTimePairMake(pointTime, pointOffset);
}

- (CGRect)visibleBounds {
	return NSRectToCGRect([self bounds]);
}

- (CGSize)millimeterSize {
	CGFloat userScale = [[self window] userSpaceScaleFactor];
	//CGFloat userScale = 1.0f;
	CGSize screenMMSize = [self screenPixelsPerMillimeter];
	NSSize scaledMillimeterSize = NSMakeSize(screenMMSize.width * userScale, screenMMSize.height * userScale);
	return NSSizeToCGSize([self convertSizeFromBase:scaledMillimeterSize]);
}

- (CGSize)unscaledMillimeterSize {
	NSSize screenMMSize = NSSizeFromCGSize([self screenPixelsPerMillimeter]);
	return NSSizeToCGSize([self convertSizeFromBase:screenMMSize]);
}

- (CGSize)significantVisualSize {
	return NSSizeToCGSize([self convertSizeFromBase:NSMakeSize(1.0f, 1.0f)]);
}

- (CGSize)significantInteractiveSize {
	return NSSizeToCGSize([self convertSizeFromBase:NSMakeSize(1.1f, 1.1f)]);
}

- (CGPoint)convertWindowPointToTimeline:(NSPoint)windowPoint {
	return NSPointToCGPoint([self convertPoint:windowPoint fromView:nil]);
}

- (NSPoint)convertTimelinePointToWindow:(CGPoint)timelinePoint {
	return [self convertPoint:NSPointFromCGPoint(timelinePoint) toView:nil];
}


#pragma mark Drawing

- (void)drawRect:(NSRect)rect {
	// draw background
	[[NSColor colorWithDeviceHue:0.164f saturation:0.15f brightness:0.99f alpha:1.0f] set];
	NSRectFill(rect);
	
	CGContextRef ctx = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	
	for (TLTimelineLayer* layer in [layers reverseObjectEnumerator]) {
		if ([layer isHidden]) continue;
		CGContextBeginTransparencyLayer(ctx, NULL);
		[layer drawInContext:ctx withInfo:timelineInfo];
		CGContextEndTransparencyLayer(ctx);
	}
}


#pragma mark Mouse dispatch

- (TLTimelineInteractiveLayer*)layerHitByEvent:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	BOOL scrollEvent = ([mouseEvent type] == NSScrollWheel);
	TLTimelineInteractiveLayer* hitLayer = nil;
	NSPoint mouseInWindow = [mouseEvent locationInWindow];
	for (TLTimelineLayer* layer in layers) {
		if ([layer isKindOfClass:[TLTimelineInteractiveLayer class]]) {
			TLTimelineInteractiveLayer* interactiveLayer = (TLTimelineInteractiveLayer*)layer;
			BOOL layerHit = (scrollEvent ?
							 [interactiveLayer wantsScrollEvents] :
							 [interactiveLayer hitTest:mouseInWindow withEvent:mouseEvent withInfo:timelineInfo]);
			if (layerHit) {
				hitLayer = interactiveLayer;
				break;
			}
		}
	}
	return hitLayer;
}

- (void)mouseDown:(NSEvent*)mouseEvent {
	[self setEventForDrag:mouseEvent];
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	currentMouseLayer = [self layerHitByEvent:mouseEvent withInfo:timelineInfo];
	[currentMouseLayer mouseDown:mouseEvent withInfo:timelineInfo];
}

- (void)mouseDragged:(NSEvent*)mouseEvent {
	[currentMouseLayer mouseDragged:mouseEvent withInfo:[self currentTimelineInfo]];
}

- (void)mouseUp:(NSEvent*)mouseEvent {
	[self setEventForDrag:nil];
	[currentMouseLayer mouseUp:mouseEvent withInfo:[self currentTimelineInfo]];
	currentMouseLayer = nil;
}

- (void)flagsChanged:(NSEvent*)event {
	[currentMouseLayer flagsChanged:event withInfo:[self currentTimelineInfo]];
}

- (void)scrollWheel:(NSEvent*)mouseEvent {
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	TLTimelineInteractiveLayer* hitLayer = [self layerHitByEvent:mouseEvent withInfo:timelineInfo];
	[hitLayer scrollWheel:mouseEvent withInfo:timelineInfo];
}

@end


@implementation TLTimelineView (TLTimelineViewHostInternals)

- (void)setLayerNeedsDisplay:(TLTimelineLayer*)layer {
	(void)layer;
	[self setNeedsDisplay:YES];
}

- (NSPoint)mouseLocationInWindow {
	return [[self window] mouseLocationOutsideOfEventStream];
}

#pragma mark Track zone management

- (void)trackingManager:(TLTrackingManager*)manager
   replaceTrackingAreas:(NSArray*)oldTrackingAreas
	  withTrackingAreas:(NSArray*)newTrackingAreas
{
	(void)manager;
	
	for (NSTrackingArea* oldArea in oldTrackingAreas) {
		[self removeTrackingArea:oldArea];
	}
	for (NSTrackingArea* newArea in newTrackingAreas) {
		[self addTrackingArea:newArea];
	}
}

- (void)trackingManager:(TLTrackingManager*)manager
	  mouseDidEnterZone:(TLTrackingZone*)trackZone
			  withEvent:(NSEvent*)eventOrNil
{
	TLTimelineInteractiveLayer* layer = [layerTrackingManagers objectForKey:manager];
	[layer mouseEntered:eventOrNil trackingZone:trackZone withInfo:[self currentTimelineInfo]];
}

- (void)trackingManager:(TLTrackingManager*)manager
	 mouseDidMoveInZone:(TLTrackingZone*)trackZone
			  withEvent:(NSEvent*)eventOrNil
{
	TLTimelineInteractiveLayer* layer = [layerTrackingManagers objectForKey:manager];
	[layer mouseMoved:eventOrNil inTrackingZone:trackZone withInfo:[self currentTimelineInfo]];
}

- (void)trackingManager:(TLTrackingManager*)manager
	   mouseDidExitZone:(TLTrackingZone*)trackZone
			  withEvent:(NSEvent*)eventOrNil
{
	TLTimelineInteractiveLayer* layer = [layerTrackingManagers objectForKey:manager];
	[layer mouseExited:eventOrNil trackingZone:trackZone withInfo:[self currentTimelineInfo]];
}

- (NSArray*)activeTrackingZonesForLayer:(TLTimelineInteractiveLayer*)layer {
	return [layerTrackingManagers objectForKey:layer];
}

- (void)setActiveTrackingZones:(NSArray*)trackingZones forLayer:(TLTimelineInteractiveLayer*)layer {
	TLTrackingManager* layerManager = [layerTrackingManagers objectForKey:layer];
	if (!layerManager) {
		layerManager = [[TLTrackingManager new] autorelease];
		[layerManager setDelegate:self];
		[layerTrackingManagers setObject:layerManager forKey:layer];
		[layerTrackingManagers setObject:layer forKey:layerManager];
	}
	[layerManager setActiveTrackingZones:trackingZones];
}

#pragma mark Drag source support

- (NSPasteboard*)dragPasteboardForLayer:(TLTimelineInteractiveLayer*)layer {
	(void)layer;
	if (![self eventForDrag]) {
		return nil;
	}
	return [NSPasteboard pasteboardWithName:NSDragPboard];
}

- (void)dragFromLayer:(TLTimelineInteractiveLayer*)layer
			withImage:(CGImageRef)dragImage
			   anchor:(CGPoint)imagePoint
			slideBack:(BOOL)shouldSlideBack
{
	NSAssert([self eventForDrag], @"Layer initiated drag at improper time");
	NSImage* cocoaImage = TLNSImageFromCGImage(dragImage, TLDragTransparencyDefault);
	
	// calculate image lower-left location in view
	NSPoint mouseDownInWindow = [eventForDrag locationInWindow];
	NSPoint imageCornerInWindow = NSMakePoint((mouseDownInWindow.x - imagePoint.x),
											  (mouseDownInWindow.y - imagePoint.y));
	NSPoint imageCornerInView = [self convertPoint:imageCornerInWindow fromView:nil];
	
	NSPasteboard* dragPasteboard = [self dragPasteboardForLayer:layer];
	[self dragImage:cocoaImage
				 at:imageCornerInView
			 offset:NSZeroSize
			  event:eventForDrag
		 pasteboard:dragPasteboard
			 source:layer
		  slideBack:shouldSlideBack];
}


#pragma mark Drag destination support

- (void)updateDropTypesForLayer:(TLTimelineInteractiveLayer*)updatedLayer {
	(void)updatedLayer;
	
	// walk all interactive layers collecting drag types
	NSMutableSet* combinedTypes = [NSMutableSet set];
	for (TLTimelineLayer* layer in layers) {
		if (![layer isKindOfClass:[TLTimelineInteractiveLayer class]]) continue;
		TLTimelineInteractiveLayer* interactiveLayer = (TLTimelineInteractiveLayer*)layer;
		NSArray* layerTypes = [interactiveLayer registeredDropTypes];
		[combinedTypes addObjectsFromArray:layerTypes];
	}
	
	[self unregisterDraggedTypes];	// this may not be necessary?
	NSArray* viewDragTypes = [combinedTypes allObjects];
	[self registerForDraggedTypes:viewDragTypes];
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender {
	if (currentMouseLayer) {
		// skip search below if the mouse is re-entering in the same session
		id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
		return [currentMouseLayer draggingEntered:sender withInfo:timelineInfo];
	}
	
	// topmost layer with type matching pasteboard will handle this drop
	NSPasteboard* dragPasteboard = [sender draggingPasteboard];
	TLTimelineInteractiveLayer* targetLayer = nil;
	for (TLTimelineLayer* layer in layers) {
		if (![layer isKindOfClass:[TLTimelineInteractiveLayer class]]) continue;
		TLTimelineInteractiveLayer* interactiveLayer = (TLTimelineInteractiveLayer*)layer;
		NSArray* layerTypes = [interactiveLayer registeredDropTypes];
		if ([dragPasteboard availableTypeFromArray:layerTypes]) {
			targetLayer = interactiveLayer;
			break;
		}
	}
	currentMouseLayer = targetLayer;
	
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	return [currentMouseLayer draggingEntered:sender withInfo:timelineInfo];
}

- (BOOL)wantsPeriodicDraggingUpdates {
	// note that this returns NO if currentMouseLayer is nil
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	return [currentMouseLayer wantsPeriodicDraggingUpdates:timelineInfo];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender {
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	// returns NSDragOperationNone if no destination layer
	return [currentMouseLayer draggingUpdated:sender withInfo:timelineInfo];
}

- (void)draggingExited:(id < NSDraggingInfo >)sender {
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	[currentMouseLayer draggingExited:sender withInfo:timelineInfo];
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender {
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	// returns NO if no destination layer
	return [currentMouseLayer prepareForDropOperation:sender withInfo:timelineInfo];
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender {
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	// return NO if no destination layer
	return [currentMouseLayer performDropOperation:sender withInfo:timelineInfo];
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender {
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	[currentMouseLayer concludeDropOperation:sender withInfo:timelineInfo];
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender {
	/* NOTE: see notes in -[TLMapView draggingEnded] about this method. */
	id < TLTimelineInfo > timelineInfo = [self currentTimelineInfo];
	[currentMouseLayer draggingEnded:sender withInfo:timelineInfo];
	currentMouseLayer = nil;
}


@end

extern TLTimeRange TLTimelineInfoTimeRangeForBounds(id < TLTimelineInfo > timelineInfo, CGRect bounds) {
	CGPoint startPoint = CGPointMake(CGRectGetMinX(bounds), 0.0f);
	CGPoint endPoint = CGPointMake(CGRectGetMaxX(bounds), 0.0f);
	tl_time_t startTime = [timelineInfo timeForPoint:startPoint].time;
	tl_time_t endTime = [timelineInfo timeForPoint:endPoint].time;
	return TLTimeRangeMakeWithTimes(startTime, endTime);
}
