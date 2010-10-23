//
//  TLTimelineInfo.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTime.h"

@protocol TLTimelineInfo

- (NSTimeZone*)timeZone;
- (CGPoint)pointForTime:(TLTimePair)timePair;
- (TLTimePair)timeForPoint:(CGPoint)timelinePoint;
@property (nonatomic, readonly) CGRect visibleBounds;

@property (nonatomic, readonly) CGSize millimeterSize;
@property (nonatomic, readonly) CGSize unscaledMillimeterSize;
@property (nonatomic, readonly) CGSize significantVisualSize;
@property (nonatomic, readonly) CGSize significantInteractiveSize;

- (CGPoint)convertWindowPointToTimeline:(NSPoint)windowPoint;
- (NSPoint)convertTimelinePointToWindow:(CGPoint)timelinePoint;

@end

TLTimeRange TLTimelineInfoTimeRangeForBounds(id < TLTimelineInfo > timelineInfo, CGRect bounds);
