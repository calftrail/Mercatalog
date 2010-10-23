//
//  TLTimelineTrackerLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineTrackerLayer.h"

#import "TLTimestamp.h"

@implementation TLTimelineTrackerLayer

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)ctx;
	
	CGRect visibleBounds = [timelineInfo visibleBounds];
	TLTrackingZone* trackZone = [TLTrackingZone trackingZoneWithBounds:visibleBounds
															  identity:self
															  userInfo:nil];
	
	[self setActiveTrackingZones:[NSArray arrayWithObject:trackZone]];
}

@synthesize delegate;

- (void)notifyMouse:(NSPoint)windowPoint withInfo:(id < TLTimelineInfo >)timelineInfo {
	if ([[self delegate] respondsToSelector:@selector(timelineTrackerLayer:mouseAtTimestamp:)]) {
		TLTimestamp* timestamp = nil;
		if (timelineInfo) {
			CGPoint targetPoint = [timelineInfo convertWindowPointToTimeline:windowPoint];
			tl_time_t targetTime = [timelineInfo timeForPoint:targetPoint].time;
			
			CGFloat positionInaccuracy = [timelineInfo significantInteractiveSize].width / 2.0f;
			CGPoint earlyMousePoint = CGPointMake(targetPoint.x - positionInaccuracy, targetPoint.y);
			tl_time_t earliestMouseTime = [timelineInfo timeForPoint:earlyMousePoint].time;
			CGPoint lateMousePoint = CGPointMake(targetPoint.x - positionInaccuracy, targetPoint.y);
			tl_time_t latestMouseTime = [timelineInfo timeForPoint:lateMousePoint].time;
			NSTimeInterval mouseAccuracy = (latestMouseTime - earliestMouseTime) / 2.0f;
			
			timestamp = [TLTimestamp timestampWithTime:TLTimeToDate(targetTime)
											  accuracy:mouseAccuracy];
		}
		[[self delegate] timelineTrackerLayer:self mouseAtTimestamp:timestamp];
	}
}

- (void)mouseEntered:(NSEvent*)mouseEventOrNil
		trackingZone:(TLTrackingZone*)zone
			withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)mouseEventOrNil;
	(void)zone;
	NSPoint windowPoint = [self mouseLocationInWindow];
	[self notifyMouse:windowPoint
			 withInfo:timelineInfo];
}

- (void)mouseMoved:(NSEvent*)mouseEventOrNil
	inTrackingZone:(TLTrackingZone*)zone
		  withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)mouseEventOrNil;
	(void)zone;
	NSPoint windowPoint = [self mouseLocationInWindow];
	[self notifyMouse:windowPoint
			 withInfo:timelineInfo];
}

- (void)mouseExited:(NSEvent*)mouseEventOrNil
	   trackingZone:(TLTrackingZone*)zone
		   withInfo:(id < TLTimelineInfo >)timelineInfo
{
	(void)mouseEventOrNil;
	(void)zone;
	(void)timelineInfo;
	[self notifyMouse:NSZeroPoint
			 withInfo:nil];
}



@end
