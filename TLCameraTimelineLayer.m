//
//  TLCameraTimelineLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLCameraTimelineLayer.h"

#import "TLOffsetTimestamp.h"
#include "TLGeometry.h"
#import "TLCocoaToolbag.h"


@implementation TLCameraTimelineLayer

@synthesize dataSource;

- (void)reloadData {
	[self setNeedsDisplay];
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	CGRect boundsToDraw = CGContextGetClipBoundingBox(ctx);
	TLTimeRange drawRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, boundsToDraw);
	NSDate* drawStartDate = TLTimeToDate(drawRange.start);
	NSDate* drawEndDate = TLTimeToDate(drawRange.start + drawRange.duration);
	
	NSArray* offsetTimestamps = nil;
	if ([dataSource respondsToSelector:@selector(cameraTimelineLayer:offsetsFromDate:toDate:)]) {
		offsetTimestamps = [dataSource cameraTimelineLayer:self
										   offsetsFromDate:drawStartDate
													toDate:drawEndDate];
	}
	if (![offsetTimestamps count]) return;
	
	CGColorRef cameraOffsetColor = TLCGColorCreateGenericHSB(40.0f / 360.0f, 1.0f, 1.0f, 1.0f);
	CGContextSetStrokeColorWithColor(ctx, cameraOffsetColor);
	CGColorRelease(cameraOffsetColor);
	CGContextSetLineWidth(ctx, 0.15f * TLSizeGetAverageWidth([timelineInfo millimeterSize]));
	
	BOOL firstPoint = YES;
	for (TLOffsetTimestamp* timestamp in offsetTimestamps) {
		TLTimePair timePair = TLTimePairMakeWithDate([timestamp time], [timestamp offset]);
		CGPoint point = [timelineInfo pointForTime:timePair];
		if (firstPoint) {
			CGContextMoveToPoint(ctx, point.x, point.y);
			firstPoint = NO;
		}
		else {
			CGContextAddLineToPoint(ctx, point.x, point.y);
		}
	}
	CGContextStrokePath(ctx);
}

@end
