//
//  TLTime.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTime.h"

#include "TLFloat.h"


#pragma mark Basic time type

tl_time_t TLTimeFromDate(NSDate* date) {
	return [date timeIntervalSinceReferenceDate];
}

NSDate* TLTimeToDate(tl_time_t aTime) {
	return [NSDate dateWithTimeIntervalSinceReferenceDate:aTime];
}


#pragma mark Time and offset pair

TLTimePair TLTimePairMake(tl_time_t theTime, NSTimeInterval offset) {
	TLTimePair timePair = { .time = theTime, .offset = offset };
	return timePair;
}

TLTimePair TLTimePairMakeWithDate(NSDate* date, NSTimeInterval offset) {
	TLTimePair timePair = { .time = TLTimeFromDate(date), .offset = offset };
	return timePair;
}


#pragma mark Time range

TLTimeRange TLTimeRangeMake(tl_time_t start, NSTimeInterval duration) {
	NSCAssert(TLFloatGreaterThanOrEqual(duration, 0.0), @"Duration should be positive");
	TLTimeRange timeRange = { .start = start, .duration = duration };
	return timeRange;
}

TLTimeRange TLTimeRangeMakeWithTimes(tl_time_t start, tl_time_t end) {
	NSTimeInterval duration = end - start;
	return TLTimeRangeMake(start, duration);
}

TLTimeRange TLTimeRangeMakeWithDates(NSDate* startDate, NSDate* endDate) {
	return TLTimeRangeMakeWithTimes(TLTimeFromDate(startDate), TLTimeFromDate(endDate));
}

tl_time_t TLTimeRangeGetEnd(TLTimeRange timeRange) {
	return timeRange.start + timeRange.duration;
}

bool TLTimeRangeContainsTime(TLTimeRange timeRange, tl_time_t targetTime) {
	return TLFloatBetweenInclusive(targetTime, timeRange.start, TLTimeRangeGetEnd(timeRange));
}
