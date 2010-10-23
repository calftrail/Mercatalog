//
//  TLCameraTimeline.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLCameraTimeline.h"

#import "TLLibraryHost.h"
#import "TLPhoto.h"
#import "TLOffsetTimestamp.h"
#import "TLFloat.h"


@implementation TLCameraTimeline

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) {
		// ...
	}
	return self;
}

- (void)dealloc {
	// ...
	[super dealloc];
}

+ (void)initialize {
	if (self != [TLCameraTimeline class]) return;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(timeZoneChanged:)
												 name:NSSystemTimeZoneDidChangeNotification
											   object:nil];
}

+ (void)timeZoneChanged:(NSNotification*)notification {
	/* NOTE: calling +[NSTimeZone resetSystemTimeZone] causes the same notification
	 to be sent. This can be supressed by un/re-registering or by taking advantage
	 of the fact that only the first notification has a non-nil object. rdar://problem/6345011 */
	if(![notification object]) return;
	(void)notification;
	[NSTimeZone resetSystemTimeZone];
}

#pragma mark Basic accessors

@synthesize modelContext;


#pragma mark Evidence recording

static NSComparisonResult TLComparePhotoTimestamps(TLPhoto* photo1,
												   TLPhoto* photo2,
												   void* info)
{
	(void)info;
	NSDate* photoDate1 = [[photo1 timestamp] time];
	NSDate* photoDate2 = [[photo2 timestamp] time];
	return [photoDate1 compare:photoDate2];
}

// NOTE: this may return value equal to array count, use with caution!
- (NSUInteger)photoInsertionIndex:(NSMutableArray*)activePhotos
					 forTimestamp:(TLTimestamp*)targetTimestamp
{
	// photo timestamps can change, so we always need to ensure correct evidence order
	[activePhotos sortUsingFunction:TLComparePhotoTimestamps context:NULL];
	
	NSTimeInterval targetTime = [[targetTimestamp time] timeIntervalSinceReferenceDate];
	NSUInteger firstLaterPhotoIdx = 0;
	for (TLPhoto* photo in activePhotos) {
		// update scan position and break if found
		NSTimeInterval photoTime = [[[photo timestamp] time] timeIntervalSinceReferenceDate];
		if (photoTime > targetTime) break;
		++firstLaterPhotoIdx;
	}
	return firstLaterPhotoIdx;
}


#pragma mark Offset information

- (void)appendOffsetTimestampVertices:(NSMutableArray*)offsetTimestamps
						  forTimeZone:(NSTimeZone*)timeZone
							 fromDate:(NSDate*)startDate
							   toDate:(NSDate*)endDate
{
	NSDate* nextDST = [timeZone nextDaylightSavingTimeTransitionAfterDate:startDate];
	while ([nextDST isLessThan:endDate]) {
		// time of transition has same offset as the moment before, but we want the new offset
		const NSTimeInterval magicNumber = 1.5 * 60.0 * 60.0;
		NSDate* adjustedDST = [nextDST addTimeInterval:magicNumber];
		NSTimeInterval timeZoneOffset = -[timeZone secondsFromGMTForDate:adjustedDST];
		TLOffsetTimestamp* timestamp = [TLOffsetTimestamp timestampWithTime:nextDST
																   accuracy:TLTimestampAccuracyUnknown
																	 offset:timeZoneOffset];
		[offsetTimestamps addObject:timestamp];
		// NOTE: using adjustedDST below is required due to rdar://problem/6425623
		NSDate* potentialNextDST = [timeZone nextDaylightSavingTimeTransitionAfterDate:adjustedDST];
		// NOTE: we must check lessThan below because of rdar://problem/6427309
		if (!potentialNextDST || [potentialNextDST isLessThanOrEqualTo:nextDST]) break;
		nextDST = potentialNextDST;
	}
}

- (NSArray*)evidencePhotos {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host evidencePhotos];
}

- (NSArray*)offsetTimestampsFrom:(NSDate*)startDate to:(NSDate*)endDate {
	NSMutableArray* activePhotos = [NSMutableArray arrayWithArray:[self evidencePhotos]];
	TLTimestamp* startDateTimestamp = [TLTimestamp timestampWithTime:startDate
															accuracy:TLTimestampAccuracyUnknown];
	NSUInteger photoIdx = [self photoInsertionIndex:activePhotos
									   forTimestamp:startDateTimestamp];
	
	NSTimeZone* timeZone = [NSTimeZone systemTimeZone];
	
	NSMutableArray* offsetTimestamps = [NSMutableArray array];
	NSDate* prevDate = nil;
	if (photoIdx) {
		TLPhoto* earlierPhoto = [activePhotos objectAtIndex:(photoIdx - 1)];
		TLOffsetTimestamp* timestamp = [earlierPhoto offsetTimestamp];
		[offsetTimestamps addObject:timestamp];
		prevDate = [timestamp time];
	}
	else {
		NSTimeInterval startOffset = -[timeZone secondsFromGMTForDate:startDate];
		TLOffsetTimestamp* startTimestamp = [TLOffsetTimestamp timestampWithTime:startDate
																		accuracy:TLTimestampAccuracyUnknown
																		  offset:startOffset];
		[offsetTimestamps addObject:startTimestamp];
		prevDate = startDate;
	}
	while (photoIdx < [activePhotos count]) {
		TLOffsetTimestamp* photoTimestamp = [[activePhotos objectAtIndex:photoIdx] offsetTimestamp];
		NSDate* photoDate = [photoTimestamp time];
		if (prevDate) {
			[self appendOffsetTimestampVertices:offsetTimestamps
									forTimeZone:timeZone
									   fromDate:prevDate
										 toDate:photoDate];
		}
		[offsetTimestamps addObject:photoTimestamp];
		
		prevDate = photoDate;
		if ([photoDate isGreaterThan:endDate]) break;
		++photoIdx;
	}
	if ([prevDate isLessThan:endDate]) {
		[self appendOffsetTimestampVertices:offsetTimestamps
								forTimeZone:timeZone
								   fromDate:prevDate
									 toDate:endDate];
		NSTimeInterval endOffset = -[timeZone secondsFromGMTForDate:endDate];
		TLOffsetTimestamp* endTimestamp = [TLOffsetTimestamp timestampWithTime:endDate
																	  accuracy:TLTimestampAccuracyUnknown
																		offset:endOffset];
		[offsetTimestamps addObject:endTimestamp];
	}	
	return offsetTimestamps;
}

- (NSArray*)offsetTimestampVerticesFrom:(NSDate*)startDate to:(NSDate*)endDate {
	NSArray* offsetTimestamps = [self offsetTimestampsFrom:startDate to:endDate];
	NSMutableArray* offsetVertices = [NSMutableArray array];
	TLOffsetTimestamp* prevTimestamp = nil;
	for (TLOffsetTimestamp* timestamp in offsetTimestamps) {
		if (prevTimestamp) {
			TLOffsetTimestamp* transition = [TLOffsetTimestamp timestampWithTime:[timestamp time]
																		accuracy:[timestamp accuracy]
																		  offset:[prevTimestamp offset]];
			[offsetVertices addObject:transition];
		}
		[offsetVertices addObject:timestamp];
		prevTimestamp = timestamp;
	}
	return offsetVertices;
}

- (NSIndexSet*)evidenceInsertionIndexesForTargetCameraTime:(NSDate*)targetTime
												  inPhotos:(NSMutableArray*)activePhotos
{
	// photo timestamps can change, so we always need to ensure correct evidence order
	[activePhotos sortUsingFunction:TLComparePhotoTimestamps context:NULL];
	
	NSMutableIndexSet* insertionIndexes = [NSMutableIndexSet indexSet];
	NSTimeInterval targetInterval = [targetTime timeIntervalSinceReferenceDate];
	NSUInteger photoIdx = 0;
	BOOL isInGroup = YES;
	for (TLPhoto* photo in activePhotos) {
		// emit indexes of each first photo after targetTime
		NSDate* photoTime = [photo originalDate];
		if ([photoTime timeIntervalSinceReferenceDate] > targetInterval) {
			if (isInGroup) [insertionIndexes addIndex:photoIdx];
			isInGroup = NO;
		}
		else {
			isInGroup = YES;
		}
		++photoIdx;
	}
	if (isInGroup) [insertionIndexes addIndex:photoIdx];
	return insertionIndexes;
}

- (NSArray*)offsetTimestampVerticesForCameraTime:(NSDate*)cameraTime {
	/*
	NSTimeInterval maxPositiveOffset = 0.0;
	NSTimeInterval minNegativeOffset = 0.0;
	// TODO: scan evidencePhotos and check time zone to set offsets
	NSDate* startDate = [cameraTime addTimeInterval:minNegativeOffset];
	NSDate* endDate = [cameraTime addTimeInterval:maxPositiveOffset];
	 */
	(void)cameraTime;
	NSDate* startDate = [NSDate distantPast];
	NSDate* endDate = [NSDate distantFuture];
	return [self offsetTimestampVerticesFrom:startDate to:endDate];
}

- (NSArray*)timestampsForCameraTime:(NSDate*)targetCameraTime {
	NSArray* offsetVertices = [self offsetTimestampVerticesForCameraTime:targetCameraTime];
	NSMutableArray* timestamps = [NSMutableArray array];
	TLOffsetTimestamp* prevOffsetTimestamp = nil;
	NSDate* prevCameraTime = nil;
	for (TLOffsetTimestamp* offsetTimestamp in offsetVertices) {
		NSTimeInterval offset = [offsetTimestamp offset];
		NSDate* cameraTime = [[offsetTimestamp time] addTimeInterval:-offset];
		if (prevOffsetTimestamp) {
			NSTimeInterval segmentDuration = [cameraTime timeIntervalSinceDate:prevCameraTime];
			NSTimeInterval targetDuration = [targetCameraTime timeIntervalSinceDate:prevCameraTime];
			double travel = targetDuration / segmentDuration;
			if (TLFloatBetweenInclusive(travel, 0.0, 1.0)) {
				NSTimeInterval prevOffset = [prevOffsetTimestamp offset];
				NSTimeInterval targetOffset = prevOffset + travel * (prevOffset - offset);
				NSDate* date = [targetCameraTime addTimeInterval:targetOffset];
				
				NSTimeInterval prevAccuracy = [prevOffsetTimestamp accuracy];
				NSTimeInterval accuracyDifference = ([offsetTimestamp accuracy] - prevAccuracy);
				NSTimeInterval accuracy = prevAccuracy + travel * accuracyDifference;
				
				TLTimestamp* timestamp = [TLTimestamp timestampWithTime:date accuracy:accuracy];
				[timestamps addObject:timestamp];
			}
		}
		prevOffsetTimestamp = offsetTimestamp;
		prevCameraTime = cameraTime;
	}
	return timestamps;
}

@end
