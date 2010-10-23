//
//  TLTrack.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 6/24/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLTrack.h"

#import "TLGPXTrackSegment.h"

#import "TLLocation.h"
#import "TLTimestamp.h"
#import "TLWaypoint.h"

static const NSTimeInterval TLTimestampBaseGPSAccuracy = 0.5;
static const TLCoordinateAccuracy TLCoordinateBaseGPSAccuracy = 1.2;
static TLCoordinateAccuracy TLCoordinateHorizontalAccuracy(double horizontalDOP, double positionDOP);
static TLCoordinateAccuracy TLCoordinateVerticalAccuracy(double verticalDOP, double positionDOP);

@interface TLTrack ()
@property (nonatomic, readwrite, copy) NSArray* waypoints;
@end


@implementation TLTrack

- (BOOL)setWithGPXSegment:(TLGPXTrackSegment*)trackSegment
					error:(NSError**)err
{
	NSUInteger numTrackpoints = [[trackSegment trackpoints] count];
	if (!numTrackpoints) {
		NSString* errorString = NSLocalizedString(@"GPX track segment must have at least one point",
												  @"Error message when track segment contains no points");
		NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:errorString
															  forKey:NSLocalizedDescriptionKey];
		if (err) *err = [NSError errorWithDomain:@"com.calftrail.mercatalog" code:42 userInfo:errorInfo];
		return NO;
	}
	
	// check if dates are valid
	NSDate* previousDate = nil;
	for (TLGPXWaypoint* trackpoint in trackSegment) {
		NSDate* date = [trackpoint time];
		// TODO: set previousDate, check for nil dates!
		if (previousDate && ![date isGreaterThan:previousDate]) {
			NSString* errorString = NSLocalizedString(@"GPX track dates not valid",
													  @"Error message when track dates in GPX file are not ordered");
			NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:errorString
																  forKey:NSLocalizedDescriptionKey];
			if (err) *err = [NSError errorWithDomain:@"com.calftrail.mercatalog" code:42 userInfo:errorInfo];
			return NO;
		}
	}
	
	NSMutableArray* mutableWaypoints = [NSMutableArray array];
	for (TLGPXWaypoint* trackpoint in trackSegment) {
		TLCoordinateAccuracy hAcc = TLCoordinateHorizontalAccuracy([trackpoint horizontalDOP],
																   [trackpoint positionDOP]);
		TLCoordinateAccuracy vAcc = TLCoordinateVerticalAccuracy([trackpoint verticalDOP],
																 [trackpoint positionDOP]);
		TLLocation* location = [TLLocation locationWithCoordinate:[trackpoint coordinate]
											   horizontalAccuracy:hAcc
														 altitude:[trackpoint elevation]
												 verticalAccuracy:vAcc];
		TLTimestamp* timestamp = [TLTimestamp timestampWithTime:[trackpoint time]
													   accuracy:TLTimestampBaseGPSAccuracy];
		TLWaypoint* waypoint = [TLWaypoint waypointWithLocation:location timestamp:timestamp];
		[mutableWaypoints addObject:waypoint];
	}
	TLWaypoint* startWaypoint = [mutableWaypoints objectAtIndex:0];
	TLWaypoint* endWaypoint = [mutableWaypoints lastObject];
	NSDate* waypointsStartDate = [[startWaypoint timestamp] time];
	NSDate* waypointsEndDate = [[endWaypoint timestamp] time];
	[self setWaypoints:mutableWaypoints];
	[self setModelStartTime:waypointsStartDate];
	[self setModelEndTime:waypointsEndDate];
	return YES;
}


#pragma mark Accessors

- (void)setWaypoints:(NSArray*)newWaypoints {
	NSManagedObject* trackData = [NSEntityDescription insertNewObjectForEntityForName:@"TrackData"
															   inManagedObjectContext:[self managedObjectContext]];
	NSArray* tempWaypoints = [newWaypoints copy];
	[trackData setValue:tempWaypoints forKey:@"waypointData"];
	[tempWaypoints release];
	[self setModelWaypoints:trackData];
}

- (NSArray*)waypoints {
	if (!waypoints) {
		NSManagedObject* trackData = [self modelWaypoints];
		waypoints = [[trackData valueForKey:@"waypointData"] copy];
		if (![self isInserted] && ![self isUpdated]) {
			[[self managedObjectContext] refreshObject:trackData mergeChanges:NO];
		}
	}
	return waypoints;
}

- (NSDate*)startDate {
	return [self modelStartTime];
}

- (NSDate*)endDate {
	return [self modelEndTime];
}

@end


TLCoordinateAccuracy TLCoordinateHorizontalAccuracy(double horizontalDOP, double positionDOP) {
	TLCoordinateAccuracy horizontalAccuracy = TLCoordinateAccuracyUnknown;
	if (horizontalDOP) {
		horizontalAccuracy = TLCoordinateBaseGPSAccuracy * horizontalDOP;
	}
	else if (positionDOP) {
		/* Horizontal typically contributes significantly less dilution.
		 This factor is based on values from AMOD tracker where hdop=1.2, vdop=1.7 and pdop=2.1 */
		const double horizontalComponentFactor = 0.33;
		double presumedHorizontalDOP = sqrt(horizontalComponentFactor * (positionDOP * positionDOP));
		horizontalAccuracy = TLCoordinateBaseGPSAccuracy * presumedHorizontalDOP;
	}
	return horizontalAccuracy;
}

TLCoordinateAccuracy TLCoordinateVerticalAccuracy(double verticalDOP, double positionDOP) {
	TLCoordinateAccuracy verticalAccuracy = TLCoordinateAccuracyUnknown;
	if (verticalDOP) {
		verticalAccuracy = TLCoordinateBaseGPSAccuracy * verticalDOP;
	}
	else if (positionDOP) {
		// see note in TLCoordinateHorizontalAccuracy regarding this factor
		const double verticalComponentFactor = 0.66;
		double presumedVerticalDOP = sqrt(verticalComponentFactor * (positionDOP * positionDOP));
		verticalAccuracy = TLCoordinateBaseGPSAccuracy * presumedVerticalDOP;
	}
	return verticalAccuracy;
}
