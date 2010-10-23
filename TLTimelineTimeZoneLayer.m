//
//  TLTimelineTimeZoneLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/5/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineTimeZoneLayer.h"

#import "TLTimelineView.h"
#import "TLTimelineLayer+HostInternals.h"
#include "TLGeometry.h"
#import "TLCocoaToolbag.h"
#include "TLFloat.h"


@implementation TLTimelineTimeZoneLayer

#pragma mark Drawing

- (TLTimePair)timePairFromInfo:(id < TLTimelineInfo >)timelineInfo
					  withDrag:(BOOL)useDragOffset
{
	NSDate* startDate = [[self host] startDate];
	
	NSTimeInterval offset = 0.0;
	if (isDragging && useDragOffset) {
		offset = dragTimeOffset;
	}
	else {
		NSTimeZone* timeZone = [timelineInfo timeZone];
		offset = -[timeZone secondsFromGMTForDate:startDate];
	}
	return TLTimePairMakeWithDate(startDate, offset);
}

- (CGPathRef)zoneHandlePathWithInfo:(id < TLTimelineInfo >)timelineInfo 
						drawingMode:(CGPathDrawingMode*)drawMode
{
	const CGSize zoneSize = CGSizeMake(1.5f * [timelineInfo millimeterSize].width,
									   1.5f * [timelineInfo millimeterSize].height);
	if (drawMode) *drawMode = kCGPathStroke;
	
	TLTimePair leftTime = [self timePairFromInfo:timelineInfo withDrag:YES];
	CGPoint leftPoint = [timelineInfo pointForTime:leftTime];
	
	CGFloat paddingX = 1.5f * [timelineInfo millimeterSize].width;
	CGPoint centerPoint = CGPointMake(leftPoint.x + paddingX, leftPoint.y);
	CGRect handleRect = TLCGRectMakeAroundPoint(centerPoint, zoneSize.width, zoneSize.height);
	
	CGMutablePathRef handlePath = CGPathCreateMutable();
	CGPathAddEllipseInRect(handlePath, NULL, handleRect);
	return (CGPathRef)[(id)handlePath autorelease];
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	CGColorRef zoneHandleColor = CGColorCreateGenericGray(0.1f, 0.9f);
	CGContextSetStrokeColorWithColor(ctx, zoneHandleColor);
	CGContextSetFillColorWithColor(ctx, zoneHandleColor);
	CGColorRelease(zoneHandleColor);
	CGPathDrawingMode drawMode = kCGPathFill;
	CGPathRef handlePath = [self zoneHandlePathWithInfo:timelineInfo drawingMode:&drawMode];
	CGContextAddPath(ctx, handlePath);
	CGContextDrawPath(ctx, drawMode);
	
	static const NSTimeInterval hourInterval = 60.0 * 60.0;
	tl_int_t hours = lround([[timelineInfo timeZone] secondsFromGMT] / hourInterval);
	NSString* labelString = hours ? [NSString stringWithFormat:@"%+li", hours] : @"GMT";
	CGFloat labelSize = 2.0f * TLSizeGetAverageWidth([timelineInfo millimeterSize]);
	CGRect handleBox = CGPathGetBoundingBox(handlePath);
	CGFloat labelPadding = 0.5f * [timelineInfo millimeterSize].width;
	CGPoint labelPosition = CGPointMake(CGRectGetMaxX(handleBox) + labelPadding,
										CGRectGetMidY(handleBox));
	CGRect labelRect = CGRectNull;
	TLTextDrawString(ctx, labelPosition, labelSize, labelString, &labelRect);
	labelPosition.y -= CGRectGetHeight(labelRect) / 2.5f;
	TLTextDrawString(ctx, labelPosition, labelSize, labelString, NULL);
}


#pragma mark Mouse event handling

- (BOOL)hitTest:(NSPoint)windowPoint
	  withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)mouseEventOrNil;
	CGPoint mouseInTime = [timelineInfo convertWindowPointToTimeline:windowPoint];
	CGRect handleRect = CGPathGetBoundingBox([self zoneHandlePathWithInfo:timelineInfo
															  drawingMode:NULL]);
	return CGRectContainsPoint(handleRect, mouseInTime);	
}

- (void)mouseDown:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	isDragging = YES;	// assume handle was hit if mouse down received
	CGPoint mouseInTime = [timelineInfo convertWindowPointToTimeline:[mouseEvent locationInWindow]];
	TLTimePair zoneTime = [self timePairFromInfo:timelineInfo withDrag:NO];
	CGFloat zoneY = [timelineInfo pointForTime:zoneTime].y;
	dragMouseOffsetY = mouseInTime.y - zoneY;
}

- (NSTimeInterval)clampedOffset:(NSTimeInterval)offset snapToHour:(BOOL)hourSnap {
	static const NSTimeInterval hourInterval = 60.0 * 60.0;
	NSTimeInterval clampedOffset = TLFloatClampNaive(offset, -12.0 * hourInterval, 12.0 * hourInterval);
	if (hourSnap) {
		clampedOffset = round(dragTimeOffset / hourInterval) * hourInterval;
	}
	return clampedOffset;
}

- (void)mouseDragged:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	CGPoint mouseInTime = [timelineInfo convertWindowPointToTimeline:[mouseEvent locationInWindow]];
	CGFloat draggedZoneY = mouseInTime.y - dragMouseOffsetY;
	CGPoint dragPoint = CGPointMake(CGRectGetMinX([timelineInfo visibleBounds]), draggedZoneY);
	dragTimeOffset = [timelineInfo timeForPoint:dragPoint].offset;
	NSInteger timeZoneOffset = -(NSInteger)[self clampedOffset:dragTimeOffset snapToHour:NO];
	NSTimeZone* dragTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:timeZoneOffset];
	[[self host] setTimeZone:dragTimeZone];
}

- (void)mouseUp:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEvent;
	(void)timelineInfo;
	isDragging = NO;
	
	NSInteger timeZoneOffset = -(NSInteger)[self clampedOffset:dragTimeOffset snapToHour:YES];
	NSTimeZone* dragTimeZone = [NSTimeZone timeZoneForSecondsFromGMT:timeZoneOffset];
	[[self host] setTimeZone:dragTimeZone];
}


@end
