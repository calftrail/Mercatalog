//
//  TLCalendarTimelineLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLCalendarTimelineLayer.h"

#import "TLCocoaToolbag.h"
#import "TLGeometry.h"
#import "TLFloat.h"

enum {
	kTLTimeCalendarUnitNone = 0,
	kTLTimeCalendarUnitDecade = -10,
	kTLTimeCalendarUnitCentury = -100,
	kTLTimeCalendarUnitMillenium = -1000
};
typedef tl_int_t TLTimeCalendarUnit;

static TLTimeCalendarUnit TLTimeNextLargerUnit(TLTimeCalendarUnit extendedUnit);
//static TLTimeCalendarUnit TLTimeNextSmallerUnit(TLTimeCalendarUnit extendedUnit);
static CFTimeInterval TLTimeGetAverageLengthOfUnit(TLTimeCalendarUnit extendedUnit);

static Boolean TLTimeRangeOfUnit(CFCalendarRef calendar, TLTimeCalendarUnit extendedUnit,
								 CFAbsoluteTime targetTime,
								 CFAbsoluteTime* startTime, CFTimeInterval* duration);

@implementation TLCalendarTimelineLayer

- (NSString*)dateFormatForUnit:(TLTimeCalendarUnit)extendedUnit {
	CFStringRef dateFormat = NULL;
	switch (extendedUnit) {
		case kCFCalendarUnitEra:
			dateFormat = CFSTR("G");
			break;
		case kTLTimeCalendarUnitMillenium:
		case kTLTimeCalendarUnitCentury:
		case kTLTimeCalendarUnitDecade:
		case kCFCalendarUnitYear:
			dateFormat = CFSTR("yyyy");
			break;
		case kCFCalendarUnitMonth:
			dateFormat = CFSTR("MMMM");
			break;
		case kCFCalendarUnitDay:
			dateFormat = CFSTR("d");
			break;
		case kCFCalendarUnitWeekday:
			dateFormat = CFSTR("EEEE");
			break;
		case kCFCalendarUnitHour:
			dateFormat = CFSTR("ha");
			break;
		case kCFCalendarUnitMinute:
			dateFormat = CFSTR("h:mm");
			break;
		case kCFCalendarUnitSecond:
			dateFormat = CFSTR(":ss");
			break;
	}
	return (NSString*)dateFormat;
}

- (CGFloat)tickWidthForUnit:(TLTimeCalendarUnit)extendedUnit {
	CGFloat tickWidth = 0.0f;
	switch (extendedUnit) {
		case kCFCalendarUnitEra:
			tickWidth = 1.0f;
			break;
		case kTLTimeCalendarUnitMillenium:
		case kTLTimeCalendarUnitCentury:
		case kTLTimeCalendarUnitDecade:
		case kCFCalendarUnitYear:
			tickWidth = 0.75f;
			break;
		case kCFCalendarUnitMonth:
			tickWidth = 0.5f;
			break;
		case kCFCalendarUnitDay:
			tickWidth = 0.25f;
			break;
		case kCFCalendarUnitWeekday:
			tickWidth = 0.15f;
			break;
		case kCFCalendarUnitHour:
			tickWidth = 0.1f;
			break;
		case kCFCalendarUnitMinute:
			tickWidth = 0.075f;
			break;
		case kCFCalendarUnitSecond:
			tickWidth = 0.025f;
			break;
	}
	return tickWidth / 5.0f;
}

- (void)drawCalendarUnit:(TLTimeCalendarUnit)unit
			   inContext:(CGContextRef)ctx
				withInfo:(id < TLTimelineInfo >)timelineInfo
{
	CGRect visibleBounds = [timelineInfo visibleBounds];
	CGPoint startPoint = CGPointMake(CGRectGetMinX(visibleBounds), 0.0f);
	tl_time_t startTime = [timelineInfo timeForPoint:startPoint].time;
	CGPoint endPoint = CGPointMake(CGRectGetMaxX(visibleBounds), 0.0f);
	tl_time_t endTime = [timelineInfo timeForPoint:endPoint].time;
	NSTimeInterval visibleDuration = endTime - startTime;
	
	CGFloat mmWidth = [timelineInfo millimeterSize].width;
	CFTimeInterval averageUnitLength = TLTimeGetAverageLengthOfUnit(unit);
	CGFloat averageWidthPerUnit = CGRectGetWidth(visibleBounds) * (CGFloat)averageUnitLength / (CGFloat)visibleDuration;
	if (averageWidthPerUnit < 5.0f * mmWidth) return;
	
	NSTimeZone* timeZone = [timelineInfo timeZone];
	NSTimeInterval offsetOfTimezone = -[timeZone secondsFromGMT];
	NSCalendar* calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
	[calendar setTimeZone:timeZone];
	NSDateFormatter* dateFormatter = [[NSDateFormatter new] autorelease];
	[dateFormatter setTimeZone:timeZone];
	
	CGColorRef tickColor = CGColorCreateGenericGray(0.0f, 1.0f);
	CGContextSetStrokeColorWithColor(ctx, tickColor);
	CGColorRelease(tickColor);
	
	TLTimeCalendarUnit biggerUnit = TLTimeNextLargerUnit(unit);
	
	CFAbsoluteTime boundaryTime = startTime;
	NSTimeInterval unitLength = 0.0;
	while (boundaryTime < endTime) {
		CFAbsoluteTime oldBoundaryTime = boundaryTime;
		CFAbsoluteTime potentialBoundaryTime = oldBoundaryTime + unitLength;
		Boolean foundBoundary = TLTimeRangeOfUnit((CFCalendarRef)calendar, unit,
												  potentialBoundaryTime, &boundaryTime, &unitLength);
		if (!foundBoundary || boundaryTime == oldBoundaryTime || unitLength < 0) break;
		
		CFAbsoluteTime biggerBoundaryTime = NAN;
		Boolean foundBiggerBoundary = TLTimeRangeOfUnit((CFCalendarRef)calendar, biggerUnit,
														boundaryTime, &biggerBoundaryTime, NULL);
		if (foundBiggerBoundary && TLFloatEqual(biggerBoundaryTime, boundaryTime)) continue;
		
		TLTimePair boundaryPair = TLTimePairMake(boundaryTime, offsetOfTimezone);
		CGPoint boundaryPoint = [timelineInfo pointForTime:boundaryPair];
		CGContextMoveToPoint(ctx, boundaryPoint.x, CGRectGetMinY(visibleBounds));
		CGContextAddLineToPoint(ctx, boundaryPoint.x, CGRectGetMaxY(visibleBounds));
		CGFloat tickWidth = [self tickWidthForUnit:unit];
		CGContextSetLineWidth(ctx, tickWidth * mmWidth);
		CGContextStrokePath(ctx);
		
		CGFloat anchorSize = 0.75f;
		CGRect anchorRect = TLCGRectMakeAroundPoint(boundaryPoint,
													anchorSize * mmWidth,
													anchorSize * [timelineInfo millimeterSize].height);
		CGContextAddEllipseInRect(ctx, anchorRect);
		CGContextStrokePath(ctx);
		
		NSString* dateFormat = [self dateFormatForUnit:unit];
		[dateFormatter setDateFormat:dateFormat];
		NSString* labelString = [dateFormatter stringFromDate:TLTimeToDate(boundaryTime)];
		
		CGFloat labelSize = 2.5f * mmWidth;
		CGFloat padding = 0.5f * mmWidth;
		CGPoint labelPosition = CGPointMake(boundaryPoint.x + padding, CGRectGetMinY(visibleBounds) + padding);
		CGRect labelRect = CGRectNull;
		TLTextDrawString(ctx, labelPosition, labelSize, labelString, &labelRect);
		if (labelRect.size.width < averageWidthPerUnit) {
			TLTextDrawString(ctx, labelPosition, labelSize, labelString, NULL);
		}
	}
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	TLTimeCalendarUnit unit = kCFCalendarUnitSecond;
	do {
		[self drawCalendarUnit:unit inContext:ctx withInfo:timelineInfo];
		unit = TLTimeNextLargerUnit(unit);
	} while (unit);
}

@end

TLTimeCalendarUnit TLTimeNextLargerUnit(TLTimeCalendarUnit extendedUnit) {
	TLTimeCalendarUnit largerUnit = kTLTimeCalendarUnitNone;
	switch (extendedUnit) {
		case kTLTimeCalendarUnitMillenium:
			largerUnit = kCFCalendarUnitEra;
			break;
		case kTLTimeCalendarUnitCentury:
			largerUnit = kTLTimeCalendarUnitMillenium;
			break;
		case kTLTimeCalendarUnitDecade:
			largerUnit = kTLTimeCalendarUnitCentury;
			break;
		case kCFCalendarUnitYear:
			largerUnit = kTLTimeCalendarUnitDecade;
			break;
		case kCFCalendarUnitMonth:
			largerUnit = kCFCalendarUnitYear;
			break;
		case kCFCalendarUnitDay:
			largerUnit = kCFCalendarUnitMonth;
			break;
		case kCFCalendarUnitHour:
			largerUnit = kCFCalendarUnitDay;
			break;
		case kCFCalendarUnitMinute:
			largerUnit = kCFCalendarUnitHour;
			break;
		case kCFCalendarUnitSecond:
			largerUnit = kCFCalendarUnitMinute;
			break;
	}
	return largerUnit;
}

Boolean TLTimeRangeOfUnit(CFCalendarRef calendar, TLTimeCalendarUnit extendedUnit,
						  CFAbsoluteTime targetTime,
						  CFAbsoluteTime* startTime, CFTimeInterval* duration)
{
	Boolean success = FALSE;
	if (extendedUnit < 0) {
		// find containing decade/century/millenium
		int year = 0;
		Boolean smallSuccess = CFCalendarDecomposeAbsoluteTime(calendar, targetTime, "y", &year);
		if (smallSuccess) {
			int roundAmount = -(int)extendedUnit;
			int yearRoundedDown = floorf((float)year / roundAmount) * roundAmount;
			CFAbsoluteTime start = NAN;
			smallSuccess = CFCalendarComposeAbsoluteTime(calendar, &start, "y", yearRoundedDown);
			if (smallSuccess) {
				int yearRoundedUp = yearRoundedDown + roundAmount;
				CFAbsoluteTime end = NAN;
				smallSuccess = CFCalendarComposeAbsoluteTime(calendar, &end, "y", yearRoundedUp);
				if (smallSuccess) {
					if (startTime) *startTime = start;
					if (duration) *duration = end - start;
					success = TRUE;
				}
			}
		}
	}
	else if (extendedUnit > 0) {
		success = CFCalendarGetTimeRangeOfUnit(calendar, extendedUnit, targetTime, startTime, duration);
	}
	return success;
}

CFTimeInterval TLTimeGetAverageLengthOfUnit(TLTimeCalendarUnit extendedUnit) {
	CFTimeInterval averageLength = 1.0;
	switch (extendedUnit) {
		case kCFCalendarUnitEra:
			averageLength *= 5.0;
		case kTLTimeCalendarUnitMillenium:
			averageLength *= 10.0;		// 10 millenium in a century...
		case kTLTimeCalendarUnitCentury:
			averageLength *= 10.0;
		case kTLTimeCalendarUnitDecade:
			averageLength *= 10.0;
		case kCFCalendarUnitYear:
			averageLength *= 12.0;		// 12 months in a year...
		case kCFCalendarUnitMonth:
			averageLength *= (365.0 / 12.0);
		case kCFCalendarUnitDay:
			averageLength *= 24.0;		// 24 hours in a day...
		case kCFCalendarUnitHour:
			averageLength *= 60.0;
		case kCFCalendarUnitMinute:
			averageLength *= 60.0;
		case kCFCalendarUnitSecond:		// ...starting with one second.
			break;
		default:
			averageLength = 0.0;		// (unknown unit)
	}
	return averageLength;
}
