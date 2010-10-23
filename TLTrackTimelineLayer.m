//
//  TLTrackTimelineLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTrackTimelineLayer.h"

#import "TLTrack.h"

#import "TLMercatalogStyler.h"
#import "TLGeometry.h"

@implementation TLTrackTimelineLayer

@synthesize dataSource;

- (void)reloadData {
	[self setNeedsDisplay];
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	NSArray* tracks = nil;
	if ([dataSource respondsToSelector:@selector(trackTimelineLayer:tracksFromDate:toDate:)]) {
		CGRect boundsToDraw = CGContextGetClipBoundingBox(ctx);
		TLTimeRange drawRange = TLTimelineInfoTimeRangeForBounds(timelineInfo, boundsToDraw);
		NSDate* drawStartDate = TLTimeToDate(drawRange.start);
		NSDate* drawEndDate = TLTimeToDate(drawRange.start + drawRange.duration);
		tracks = [dataSource trackTimelineLayer:self tracksFromDate:drawStartDate toDate:drawEndDate];
	}
	
	TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
	CGContextSetStrokeColorWithColor(ctx, [styler trackColor]);
	CGFloat millimeterFactor = TLSizeGetAverageWidth([timelineInfo millimeterSize]);
	CGContextSetLineWidth(ctx, [styler trackWidth] * millimeterFactor);
	CGContextSetLineCap(ctx, [styler trackLineCap]);
	
	for (TLTrack* track in tracks) {
		tl_time_t startTime = TLTimeFromDate([track startDate]);
		tl_time_t endTime = TLTimeFromDate([track endDate]);
		CGPoint startPoint = [timelineInfo pointForTime:TLTimePairMake(startTime, 0.0)];
		CGPoint endPoint = [timelineInfo pointForTime:TLTimePairMake(endTime, 0.0)];
		
		CGContextMoveToPoint(ctx, startPoint.x, startPoint.y);
		CGContextAddLineToPoint(ctx, endPoint.x, endPoint.y);
		CGContextStrokePath(ctx);
	}
}

@end
