//
//  TLTimelineNavigationLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineNavigationLayer.h"

#import "TLTimelineView.h"
#import "TLTimelineLayer+HostInternals.h"

#import "TLTime.h"
#import "TLMercatalogViewShared.h"
#import "TLMercatalogStyler.h"
#include "TLGeometry.h"
#include "TLFloat.h"
#import "TLCocoaToolbag.h"


static const CGFloat TLTimelineNavigationScrollZoomScale = 0.1f;

@interface TLTimelineNavigationLayer ()
@property (nonatomic, assign, getter=isDragging) BOOL dragging;
- (void)zoomTimelineTo:(CGRect)selectedBounds withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)zoomTimelineByAmount:(CGFloat)zoomPercent
						from:(CGPoint)anchorPoint
					withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)panTimelineFrom:(CGPoint)mouseInTimeBegin
					 to:(CGPoint)mouseInTimeEnd
			   withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)setHostRange:(TLTimeRange)timeRange;
//- (void)setHostTimezone:(NSTimeZone*)timeZone;
@end


@implementation TLTimelineNavigationLayer

#pragma mark Drawing

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	if (![self isDragging] || initialClickWasHeld) return;
	
	TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
	CGFloat mmScale = TLSizeGetAverageWidth([timelineInfo millimeterSize]);
	CGContextSetLineWidth(ctx, mmScale * [styler zoomBoxWidth]);
	
	bool zoomingOut = TLNavigationIsReverseZoom(dragStart, dragCurrent);
	CGFloat zoomBoxHue = 205.0f;
	CGContextSetFillColorWithColor(ctx, [styler zoomBoxFillColorWithHueDegrees:zoomBoxHue]);
	if (!zoomingOut) {
		CGRect visibleBounds = CGContextGetClipBoundingBox(ctx);
		CGContextFillRect(ctx, visibleBounds);
	}
	
	CGContextSetStrokeColorWithColor(ctx, [styler zoomBoxStrokeColorWithHueDegrees:zoomBoxHue]);
	CGPoint fullDragStart = CGPointMake(dragStart.x, CGRectGetMaxY([timelineInfo visibleBounds]));
	CGPoint fullDragCurrent = CGPointMake(dragCurrent.x, CGRectGetMinY([timelineInfo visibleBounds]));
	CGRect selectionBounds = TLCGRectMakeFromPoints(fullDragStart, fullDragCurrent);
	if (!zoomingOut) {
		CGContextClearRect(ctx, selectionBounds);
	}
	else {
		CGContextFillRect(ctx, selectionBounds);
	}
	CGContextStrokeRect(ctx, selectionBounds);
}


#pragma mark Accessors

@synthesize delegate;

@synthesize dragging;

- (void)setDragging:(BOOL)newDragging {
	dragging = newDragging;
	[self setNeedsDisplay];
}


#pragma mark Mouse event handling

- (BOOL)hitTest:(NSPoint)windowPoint
	  withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)windowPoint;
	(void)mouseEventOrNil;
	(void)timelineInfo;
	return YES;
}

- (void)mouseDown:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	initialClickWasHeld = NO;
	[self setDragging:NO];
	NSPoint dragInWindow = [mouseEvent locationInWindow];
	dragStart = [timelineInfo convertWindowPointToTimeline:dragInWindow];
	dragCurrent = dragStart;
	[[NSCursor crosshairCursor] push];	
	[self performSelector:@selector(checkClickHeld) withObject:nil afterDelay:TLNavigationDragDelay];
}

- (void)checkClickHeld {
	if ([self isDragging]) return;
	initialClickWasHeld = YES;
	[NSCursor pop];
	[[NSCursor closedHandCursor] push];
}

- (void)mouseDragged:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	NSPoint dragInWindow = [mouseEvent locationInWindow];
	dragCurrent = [timelineInfo convertWindowPointToTimeline:dragInWindow];
	[self setDragging:YES];
	
	if (initialClickWasHeld) {
		// mouse deltaY is always flipped
		NSPoint dragInWindowPrevious = NSMakePoint((dragInWindow.x - [mouseEvent deltaX]),
												   (dragInWindow.y + [mouseEvent deltaY]));
		CGPoint mouseInTimeBegin = [timelineInfo convertWindowPointToTimeline:dragInWindowPrevious];
		CGPoint mouseInTimeEnd = dragCurrent;
		
		[self panTimelineFrom:mouseInTimeBegin to:mouseInTimeEnd withInfo:timelineInfo];
		(void)mouseInTimeBegin;
		(void)mouseInTimeEnd;
	}
}

- (void)mouseUp:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	[self setDragging:NO];
	NSPoint dragInWindow = [mouseEvent locationInWindow];
	dragCurrent = [timelineInfo convertWindowPointToTimeline:dragInWindow];
	
	if (!initialClickWasHeld) {
		CGRect selectedBounds = TLCGRectMakeFromPoints(dragStart, dragCurrent);
		if (TLFloatEqual(selectedBounds.size.width, 0.0) &&
			[[self delegate] respondsToSelector:@selector(timelineNavigationLayerDidIgnoreClick:)])
		{
			[[self delegate] timelineNavigationLayerDidIgnoreClick:self];
		}
		else if (!TLFloatEqual(selectedBounds.size.width, 0.0)) {
			if (TLNavigationIsReverseZoom(dragStart, dragCurrent)) {
				CGRect displayedBounds = [timelineInfo visibleBounds];
				selectedBounds.size.height = 1.0f;
				displayedBounds.size.height = 1.0f;
				CGAffineTransform reverseZoom = TLTransformFromRectToRect(selectedBounds,
																		  displayedBounds,
																		  TLAspectIgnore);
				CGRect reverseBounds = CGRectApplyAffineTransform(displayedBounds, reverseZoom);
				[self zoomTimelineTo:reverseBounds withInfo:timelineInfo];
			}
			else {
				[self zoomTimelineTo:selectedBounds withInfo:timelineInfo];
			}
		}
	}
	[NSCursor pop];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkClickHeld) object:nil];
}

- (BOOL)wantsScrollEvents {
	return YES;
}

- (void)scrollWheel:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	NSPoint mouseInWindow = [mouseEvent locationInWindow];
	CGPoint mouseOnTime = [timelineInfo convertWindowPointToTimeline:mouseInWindow];
	CGFloat zoomPercent = TLTimelineNavigationScrollZoomScale * [mouseEvent deltaY];
	[self zoomTimelineByAmount:zoomPercent from:mouseOnTime withInfo:timelineInfo];
	
	NSPoint scrollInWindow = NSMakePoint(mouseInWindow.x - [mouseEvent deltaX],
										 mouseInWindow.y + [mouseEvent deltaY]);
	CGPoint scrollInMap = [timelineInfo convertWindowPointToTimeline:scrollInWindow];
	[self panTimelineFrom:scrollInMap to:mouseOnTime withInfo:timelineInfo];
}


#pragma mark Time handling

- (void)zoomTimelineTo:(CGRect)selectedBounds withInfo:(id < TLTimelineInfo >)timelineInfo {
	TLTimeRange selectedRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, selectedBounds);
	[self setHostRange:selectedRange];
}

- (void)zoomTimelineByAmount:(CGFloat)zoomPercent
						from:(CGPoint)anchorPoint
					withInfo:(id < TLTimelineInfo >)timelineInfo
{
	CGFloat scaleFactor = NAN;
	if (zoomPercent < 0.0f) {
		scaleFactor = 1.0f - zoomPercent;
	}
	else {
		scaleFactor = 1.0f / (1.0f + zoomPercent);
	}
	CGAffineTransform zoom = CGAffineTransformMakeTranslation(anchorPoint.x, anchorPoint.y);
	zoom = CGAffineTransformScale(zoom, scaleFactor, scaleFactor);
	zoom = CGAffineTransformTranslate(zoom, -anchorPoint.x, -anchorPoint.y);
	CGRect zoomedBounds = CGRectApplyAffineTransform([timelineInfo visibleBounds], zoom);
	[self zoomTimelineTo:zoomedBounds withInfo:timelineInfo];
}

- (void)panTimelineFrom:(CGPoint)mouseInTimeBegin
					 to:(CGPoint)mouseInTimeEnd
			   withInfo:(id < TLTimelineInfo >)timelineInfo
{
	TLTimePair movedTime = [timelineInfo timeForPoint:mouseInTimeBegin];
	TLTimePair targetTime = [timelineInfo timeForPoint:mouseInTimeEnd];
	NSTimeInterval timeAdjustment = movedTime.time - targetTime.time;
	TLTimeRange oldRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, [timelineInfo visibleBounds]);
	TLTimeRange newRange = TLTimeRangeMake(oldRange.start + timeAdjustment, oldRange.duration);
	[self setHostRange:newRange];
}


#pragma mark Host accessors

- (void)setHostRange:(TLTimeRange)timeRange {
	const NSTimeInterval minSeconds = 5.0;
	if (timeRange.duration < minSeconds) {
		NSTimeInterval padding = minSeconds - timeRange.duration;
		timeRange.start -= padding / 2.0;
		timeRange.duration += padding;
	}
	const NSTimeInterval secondsInFakeYear = 365.0 * 24.0 * 60.0 * 60.0;
	// don't let timeline zoom out more than "1825 -> 5 years from current"
	NSDate* minDate = [NSDate dateWithTimeIntervalSinceReferenceDate:-(176.0 * secondsInFakeYear)];
	NSDate* maxDate = [[NSDate date] addTimeInterval:(5.0 * secondsInFakeYear)];
	NSDate* startDate = TLTimeToDate(timeRange.start);
	if ([startDate isLessThan:minDate]) {
		startDate = minDate;
	}
	[[self host] setStartDate:startDate];
	NSDate* endDate = TLTimeToDate(TLTimeRangeGetEnd(timeRange));
	if ([endDate isGreaterThan:maxDate]) {
		endDate = maxDate;
	}
	[[self host] setEndDate:endDate];
}

@end
