//
//  TLTime.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#pragma mark Basic time type

// tl_time_t represents seconds since the first instant of 1 January 2001, GMT (same as -[NSDate timeIntervalSinceReferenceDate])
typedef NSTimeInterval tl_time_t;

tl_time_t TLTimeFromDate(NSDate* date);
NSDate* TLTimeToDate(tl_time_t aTime);


#pragma mark Time and offset pair

typedef struct TL_TimePair {
	tl_time_t time;
	NSTimeInterval offset;
} TLTimePair;

TLTimePair TLTimePairMake(tl_time_t time, NSTimeInterval offset);
TLTimePair TLTimePairMakeWithDate(NSDate* date, NSTimeInterval offset);


#pragma mark Time range

typedef struct TL_TimeRange {
	tl_time_t start;
	NSTimeInterval duration;
} TLTimeRange;

static const TLTimeRange TLTimeRangeZero = { .start = 0.0, .duration = 0.0 };

TLTimeRange TLTimeRangeMake(tl_time_t start, NSTimeInterval duration);
TLTimeRange TLTimeRangeMakeWithTimes(tl_time_t start, tl_time_t end);
TLTimeRange TLTimeRangeMakeWithDates(NSDate* startDate, NSDate* endDate);

tl_time_t TLTimeRangeGetEnd(TLTimeRange timeRange);
bool TLTimeRangeContainsTime(TLTimeRange timeRange, tl_time_t targetTime);

