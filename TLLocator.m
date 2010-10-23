//
//  TLLocator.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLLocator.h"

#import "TLLibraryHost.h"
#import "TLTrack.h"
#import "TLPhoto.h"

#import "TLWaypoint.h"
#import "TLLocation.h"
#import "TLTimestamp.h"

#import "TLCocoaToolbag.h"
#include "TLFloat.h"
#include "TLGeoidGeometry.h"


#pragma mark Interpolation factors

static const double TLLocatorHomeAcceleration = 0.025;
static const double TLLocatorSnapTolerance = 0.2;

static TLProjectionGeoidRef TLLocatorInterpolationGeoid(void);

static TLLocation* TLLocatorInterpolate(TLTimestamp* targetTimestamp,
										TLWaypoint* earlierWaypoint,
										TLWaypoint* laterWaypoint,
										TLLocation* homeLocation,
										BOOL interpolateWhenPossible);


#pragma mark Main implementation

@implementation TLLocator

#pragma mark Class defaults

+ (TLLocation*)timbuktu {
	// based on to http://en.wikipedia.org/wiki/Timbuktu
	TLCoordinate timbuktuCoord = TLCoordinateMake(16.7759,-3.0094);
	TLCoordinateAccuracy timbuktuHorzAccuracy = 4200.0;
	TLCoordinateAltitude timbuktuAltitude = 261.0;
	return [TLLocation locationWithCoordinate:timbuktuCoord
						   horizontalAccuracy:timbuktuHorzAccuracy
									 altitude:timbuktuAltitude
							 verticalAccuracy:TLCoordinateAccuracyUnknown];
}

+ (TLLocation*)timeZoneCity {
	/* Information about the closest city chosen in time zone preferences is stored under key
	 com.apple.TimeZonePref.Last_Selected_City in /Library/Preferences/.GlobalPreferences:
	 CFArrayRef info = CFPreferencesCopyValue(CFSTR("com.apple.TimeZonePref.Last_Selected_City"),
	 kCFPreferencesAnyApplication,
	 kCFPreferencesAnyUser,
	 kCFPreferencesCurrentHost); */
	enum TL_TimeZoneCityIndexes {
		TLTimeZoneCityLatitude = 0,
		TLTimeZoneCityLongitude,
		TLTimeZoneCityUnknownIntString,
		TLTimeZoneCityZoneName,
		TLTimeZoneCityCountryCode,
		TLTimeZoneCityCityName1,
		TLTimeZoneCityNationName1,
		TLTimeZoneCityCityName2,
		TLTimeZoneCityNationName2
	};
	NSArray* cityInfo = [[NSUserDefaults standardUserDefaults]
						 arrayForKey:@"com.apple.TimeZonePref.Last_Selected_City"];
	NSString* latString = [cityInfo objectAtIndex:TLTimeZoneCityLatitude];
	NSString* lonString = [cityInfo objectAtIndex:TLTimeZoneCityLongitude];
	
	TLLocation* cityLocation = nil;
	if ([latString isKindOfClass:[NSString class]] &&
		[lonString isKindOfClass:[NSString class]])
	{
		TLCoordinateDegrees latitude = [latString doubleValue];
		TLCoordinateDegrees longitude = [lonString doubleValue];
		if (TLFloatBetweenInclusive(latitude, -90.0, 90.0) &&
			TLFloatBetweenInclusive(longitude, -180.0, 180.0) &&
			!(latitude == 0.0 && longitude == 0.0))
		{
			TLCoordinate cityCoord = TLCoordinateMake(latitude, longitude);
			const TLCoordinateAccuracy cityAccuracy = 10000.0;
			cityLocation = [TLLocation locationWithCoordinate:cityCoord
										   horizontalAccuracy:cityAccuracy];
		}
	}
	return cityLocation;
}

+ (TLLocation*)defaultHomeBase {
	TLLocation* defaultHomeBase = [self timeZoneCity];
	if (!defaultHomeBase) {
		defaultHomeBase = [self timbuktu];
	}
	return defaultHomeBase;
}

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


#pragma mark Accessors

@synthesize modelContext;

- (NSArray*)evidenceTracks {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host allTracks];
}

- (NSArray*)evidencePhotos {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host evidencePhotos];
}

- (TLLocation*)homeBase {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	return [host homeBase];
}

static NSComparisonResult TLCompareTrackStartTimes(TLTrack* track1,
												   TLTrack* track2,
												   void* info)
{
	(void)info;
	NSDate* date1 = [track1 startDate];
	NSDate* date2 = [track2 startDate];
	return [date1 compare:date2];
}

// NOTE: this may return value equal to array count, use with caution!
- (NSUInteger)trackInsertionIndex:(NSMutableArray*)activeTracks
					 forStartDate:(NSDate*)targetDate
{
	[activeTracks sortUsingFunction:TLCompareTrackStartTimes context:NULL];
	
	NSTimeInterval targetTime = [targetDate timeIntervalSinceReferenceDate];
	NSUInteger firstLaterTrackIdx = 0;
	for (TLTrack* track in activeTracks) {
		// update scan position and break if found
		NSTimeInterval trackTime = [[track startDate] timeIntervalSinceReferenceDate];
		if (trackTime > targetTime) break;
		++firstLaterTrackIdx;
	}
	return firstLaterTrackIdx;
}

static NSComparisonResult TLComparePhotoTimestamps(TLPhoto* photo1,
												   TLPhoto* photo2,
												   void* info)
{
	(void)info;
	NSDate* date1 = [[photo1 timestamp] time];
	NSDate* date2 = [[photo2 timestamp] time];
	return [date1 compare:date2];
}

// NOTE: this may return value equal to array count, use with caution!
- (NSUInteger)photoInsertionIndex:(NSMutableArray*)activePhotos
					 forTimestamp:(TLTimestamp*)targetTimestamp
{
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

- (NSUInteger)waypointInsertionIndex:(NSArray*)waypoints
							 forDate:(NSDate*)targetDate
{
	NSTimeInterval targetTime = [targetDate timeIntervalSinceReferenceDate];
	NSUInteger firstLaterWaypointIdx = 0;
	for (TLWaypoint* waypoint in waypoints) {
		NSDate* waypointDate = [[waypoint timestamp] time];
		NSTimeInterval waypointTime = [waypointDate timeIntervalSinceReferenceDate];
		if (waypointTime > targetTime) break;
		++firstLaterWaypointIdx;
	}
	return firstLaterWaypointIdx;	
}

- (NSMapTable*)locateTimestamps:(NSMapTable*) timestampObjects {
	NSSet* keys = TLNSMapTableAllKeys(timestampObjects);
	NSMapTable* locations = [NSMapTable mapTableWithStrongToStrongObjects];
	for (id key in keys) {
		TLTimestamp* timestamp = [timestampObjects objectForKey:key];
		TLLocation* location = [self locationAtTimestamp:timestamp];
		[locations setObject:location forKey:key];
	}
	return locations;
}

- (TLLocation*)locationAtTimestamp:(TLTimestamp*)targetTimestamp {
	TLWaypoint* prevWaypoint = nil;
	TLWaypoint* nextWaypoint = nil;
	BOOL forceInterpolation = NO;
	
	// find closest track(s) evidence
	NSMutableArray* activeTracks = [NSMutableArray arrayWithArray:[self evidenceTracks]];
	NSDate* targetDate = [targetTimestamp time];
	NSUInteger laterTrackIdx = [self trackInsertionIndex:activeTracks
											forStartDate:targetDate];
	if (laterTrackIdx > 0) {
		TLTrack* earlierTrack = [activeTracks objectAtIndex:(laterTrackIdx - 1)];
		NSArray* waypoints = [earlierTrack waypoints];
		NSUInteger laterWaypointIdx = [self waypointInsertionIndex:waypoints
														   forDate:targetDate];
		if (laterWaypointIdx < [waypoints count]) {
			nextWaypoint = [waypoints objectAtIndex:laterWaypointIdx];
			// assume we will also get prevWaypoint from this track
			forceInterpolation = YES;
		}
		if (laterWaypointIdx > 0) {
			prevWaypoint = [waypoints objectAtIndex:(laterWaypointIdx - 1)];
		}
		else {
			// track, but none of its waypoints, before targetTimestamp!?
			NSLog(@"Tracklog evidence inconsistency, handling gracefully.");
			forceInterpolation = NO;
		}
	}
	if (!nextWaypoint && laterTrackIdx < [activeTracks count]) {
		TLTrack* laterTrack = [activeTracks objectAtIndex:laterTrackIdx];
		NSArray* waypoints = [laterTrack waypoints];
		if ([waypoints count]) {
			nextWaypoint = [waypoints objectAtIndex:0];
		}
	}
	
	if (!forceInterpolation) {
		// use photo evidence when helpful
		NSMutableArray* activePhotos = [NSMutableArray arrayWithArray:[self evidencePhotos]];
		NSUInteger laterPhotoIdx = [self photoInsertionIndex:activePhotos
												forTimestamp:targetTimestamp];
		if (laterPhotoIdx > 0) {
			TLPhoto* earlierPhoto = [activePhotos objectAtIndex:(laterPhotoIdx - 1)];
			NSDate* photoDate = [[earlierPhoto timestamp] time];
			NSDate* prevDate = [[prevWaypoint timestamp] time];
			// use photo as waypoint if later than prevWaypoint
			if (!prevDate || [photoDate isGreaterThan:prevDate]) {
				prevWaypoint = [TLWaypoint waypointWithLocation:[earlierPhoto location]
													  timestamp:[earlierPhoto timestamp]];
			}
		}
		if (laterPhotoIdx < [activePhotos count]) {
			TLPhoto* laterPhoto = [activePhotos objectAtIndex:laterPhotoIdx];
			NSDate* photoDate = [[laterPhoto timestamp] time];
			NSDate* nextDate = [[nextWaypoint timestamp] time];
			// use photo as waypoint if earlier than nextWaypoint
			if (!nextWaypoint || [photoDate isLessThan:nextDate]) {
				nextWaypoint = [TLWaypoint waypointWithLocation:[laterPhoto location]
													  timestamp:[laterPhoto timestamp]];
			}
		}
		
	}
	
	return TLLocatorInterpolate(targetTimestamp,
								prevWaypoint,
								nextWaypoint,
								[self homeBase],
								forceInterpolation);
}


- (void)addTimestamps:(NSMutableSet*)timestamps
		  forLocation:(TLLocation*)targetLocation
			  inTrack:(TLTrack*)track
{
	TLCoordinateAltitude targetAltitude = [targetLocation altitude];
	bool useAltitudes = (targetAltitude != TLCoordinateAltitudeUnknown);
	if (!useAltitudes) {
		targetAltitude = 0.0;
	}
	TLCoordinate targetCoord = [targetLocation originalCoordinate];
	TLPlanetPoint targetPoint = TLGeoidGetPlanetPoint(TLProjectionGeoidWGS84, targetCoord, targetAltitude);
	TLMetersECEF targetDistance = [targetLocation horizontalAccuracy];
	TLMetersECEF targetDistanceSqd = targetDistance * targetDistance;
	
	TLPlanetPoint prevPoint = TLPlanetPointZero;
	NSDate* prevDate = nil;
	TLTimestamp* closestGroupTimestamp = nil;	// reset to nil if not in group
	TLMetersECEF closestGroupDistanceSqd = 0.0;
	for (TLWaypoint* waypoint in [track waypoints]) {
		TLCoordinate currentCoord = [[waypoint location] originalCoordinate];
		TLCoordinateAltitude currentAltitude = 0.0;
		if (useAltitudes) {
			currentAltitude = [[waypoint location] altitude];
		}
		TLPlanetPoint currentPoint = TLGeoidGetPlanetPoint(TLProjectionGeoidWGS84, currentCoord, currentAltitude);
		NSDate* currentDate = [[waypoint timestamp] time];
		if (!prevDate) {
			prevPoint = currentPoint;
			prevDate = currentDate;
			TLMetersECEF distanceSqd = TLPlanetPointDistanceSquared(targetPoint, currentPoint);
			if (TLFloatLessThanOrEqual(distanceSqd, targetDistanceSqd)) {
				closestGroupTimestamp = [TLTimestamp timestampWithTime:currentDate
															  accuracy:TLTimestampAccuracyUnknown];
			}
			continue;
		}
		
		double lineTravel = TLPlanetClosestTravel(targetPoint, prevPoint, currentPoint);
		double segmentTravel = TLFloatClampNaive(lineTravel, 0.0, 1.0);
		TLPlanetPoint segmentPoint = TLPlanetPointWithTravel(prevPoint, currentPoint, segmentTravel);
		TLMetersECEF distanceSqd = TLPlanetPointDistanceSquared(targetPoint, segmentPoint);
		
		
		if (TLFloatLessThanOrEqual(distanceSqd, targetDistanceSqd)) {
			NSTimeInterval timeDifference = [currentDate timeIntervalSinceDate:prevDate];
			NSTimeInterval timeTravel = segmentTravel * timeDifference;
			NSDate* targetDate = [prevDate addTimeInterval:timeTravel];
			// TODO: calculate accuracy
			TLTimestamp* targetTimestamp = [TLTimestamp timestampWithTime:targetDate
																 accuracy:TLTimestampAccuracyUnknown];
			
			// find closest timestmp in contiguous run of "hit" segments
			if (!closestGroupTimestamp || distanceSqd < closestGroupDistanceSqd) {
				closestGroupTimestamp = targetTimestamp;
				closestGroupDistanceSqd = distanceSqd;
			}
		}
		else if (closestGroupTimestamp) {
			// emit timestamp once we know it's the closest in a group
			[timestamps addObject:closestGroupTimestamp];
			closestGroupTimestamp = nil;
		}
		
		prevPoint = currentPoint;
		prevDate = currentDate;
	}
	if (closestGroupTimestamp) {
		[timestamps addObject:closestGroupTimestamp];
	}	
}

- (NSSet*)trackTimestampsAtLocation:(TLLocation*)targetLocation {
	NSMutableSet* timestamps = [NSMutableSet set];
	for (TLTrack* track in [self evidenceTracks]) {
		[self addTimestamps:timestamps forLocation:targetLocation inTrack:track];
	}
	return timestamps;
}

@end


#pragma mark Interpolation helpers

/* This is fluidDensity * referenceArea * dragCoefficient based on
 http://en.wikipedia.org/w/index.php?title=Density&oldid=250615493#Density_of_air and
 http://en.wikipedia.org/w/index.php?title=Automobile_drag_coefficient&oldid=250352393 */
static const double TLLocatorDragFactor = 1.204 * 0.219;

/* From http://en.wikipedia.org/w/index.php?title=Aptera_Typ-1&oldid=250277514
 and http://hypertextbook.com/facts/2003/AlexSchlessingerman.shtml */
static const double TLLocatorUserMass = 671.3 + 70.0;

/* From Advanced Automotive Technology: Visions of a Super-efficient Family Car, 1995, p. 165
 available at http://www.princeton.edu/~ota/disk1/1995/9514/9514.PDF */
static const double TLLocatorRegainingEfficiency = 0.218;

TLProjectionGeoidRef TLLocatorInterpolationGeoid() {
	return TLProjectionGeoidWGS84;
}

/* Minimum acceleration necessary to go same distance covered by traveling
 at requiredVelocity for availableTime, but starting and ending at baseVelocity. */
static double TLLocatorMinAcceleration(double baseVelocity,
									   double requiredVelocity,
									   NSTimeInterval availableTime)
{
	/* The distance covered at requiredVelocity in availableTime can also be covered
	 by constant acceleration attaining a maximum velocity halfway through the time,
	 followed by equal magnitude constant deceleration back to the baseVelocity.
	 This maximum velocity is double the difference above the baseVelocity, just as
	 an isoceles triangle must be double in height to equal the area of a rectangle
	 with the same base width.
	 (See http://en.wikipedia.org/w/index.php?title=Standard_gravity&oldid=251108683 and
	 http://en.wikipedia.org/w/index.php?title=G-force&oldid=250938464#NASA_g-tolerance_data
	 for information about human-tolerable acceleration magnitudes.) */
	double velocityDifference = requiredVelocity - baseVelocity;
	double differrenceToMaxVelocity = 2.0 * velocityDifference;
	NSTimeInterval halfTime = availableTime / 2.0;
	return fabs(differrenceToMaxVelocity / halfTime);
}

/* Unrecovered work done accelerating to cover the extra targetDistance from
 the baseDistance, starting and ending at the velocity implied by baseDistance. */
static double TLLocatorWorkFromAccelerating(TLMetersECEF baseDistance,
											TLMetersECEF targetDistance,
											NSTimeInterval duration)
{
	/* While theoretically the energy (=work) expended acceleration might be
	 recaptured while decelerating, this is not wholly the case even with a
	 vehicle capable of regenerative braking. */
	double baseVelocity = baseDistance / duration;
	double averageVelocity = targetDistance / duration;
	double necessaryAcceleration = TLLocatorMinAcceleration(baseVelocity,
															averageVelocity,
															duration);
	double necessaryForce = TLLocatorUserMass * necessaryAcceleration;
	double distanceAccelerating = averageVelocity * (duration / 2.0);
	double regainableWork = necessaryForce * distanceAccelerating;
	return (1.0 - TLLocatorRegainingEfficiency) * regainableWork;
}

/* Work needed to go distance during duration. */
static double TLLocatorWorkRequired(TLMetersECEF distance, NSTimeInterval duration) {
	/* Work calculated from force due to drag according to
	 http://en.wikipedia.org/w/index.php?title=Drag_equation&oldid=244349467 */
	double velocity = distance / duration;
	double velocitySqd = velocity * velocity;
	double force = TLLocatorDragFactor * velocitySqd / 2.0;
	return force * distance;
}

static double TLLocatorWorkBetweenWaypoints(TLWaypoint* earlierWaypoint,
											TLWaypoint* laterWaypoint,
											TLMetersECEF* distancePtr,
											NSTimeInterval* durationPtr,
											TLTimestamp* targetTimestamp,
											TLLocation** interpolatedLocationPtr)
{
	TLProjectionGeoidRef geoid = TLLocatorInterpolationGeoid();
	TLLocation* earlierLocation = [earlierWaypoint location];
	TLLocation* laterLocation = [laterWaypoint location];
	TLCoordinateAltitude prevAltitude = [earlierLocation altitude];
	TLCoordinateAltitude nextAltitude = [laterLocation altitude];
	BOOL useAltitudes = (prevAltitude != TLCoordinateAltitudeUnknown &&
						 nextAltitude != TLCoordinateAltitudeUnknown);
	if (!useAltitudes) {
		prevAltitude = 0.0;
		nextAltitude = 0.0;
	}
	
	TLPlanetPoint prevPoint = TLGeoidGetPlanetPoint(geoid,
													[earlierLocation originalCoordinate],
													prevAltitude);
	TLPlanetPoint nextPoint = TLGeoidGetPlanetPoint(geoid,
													[laterLocation originalCoordinate],
													nextAltitude);
	TLMetersECEF distance = TLPlanetPointDistance(prevPoint, nextPoint);
	if (distancePtr) *distancePtr = distance;
	
	NSDate* prevDate = [[earlierWaypoint timestamp] time];
	NSDate* nextDate = [[laterWaypoint timestamp] time];
	NSTimeInterval duration = [nextDate timeIntervalSinceDate:prevDate];
	if (durationPtr) *durationPtr = duration;
	
	if (targetTimestamp && interpolatedLocationPtr) {
		NSTimeInterval durationToTarget = [[targetTimestamp time] timeIntervalSinceDate:prevDate];
		double ratio = durationToTarget / duration;
		TLPlanetPoint interpolatedPoint = TLPlanetPointWithTravel(prevPoint, nextPoint, ratio);
		// TODO: calculate accuracy
		TLCoordinateAltitude altitude = TLCoordinateAltitudeUnknown;
		TLCoordinate coord = TLGeoidGetCoordinate(geoid,
												  interpolatedPoint,
												  (useAltitudes ? &altitude : NULL));
		*interpolatedLocationPtr = [TLLocation locationWithCoordinate:coord
												   horizontalAccuracy:TLCoordinateAccuracyUnknown
															 altitude:altitude
													 verticalAccuracy:TLCoordinateAccuracyUnknown];
	}
	
	return TLLocatorWorkRequired(distance, duration);
}


#pragma mark Interpolation

TLLocation* TLLocatorInterpolate(TLTimestamp* targetTimestamp,
								 TLWaypoint* earlierWaypoint,
								 TLWaypoint* laterWaypoint,
								 TLLocation* homeLocation,
								 BOOL interpolateWhenPossible)
{
	TLLocation* locationBetween = nil;
	TLMetersECEF distanceBetween = 0.0;
	NSTimeInterval durationBetween = 0.0;
	double acceptedSnapWork = 0.0;
	double snapEarlierWork = 0.0;
	double snapLaterWork = 0.0;
	if (earlierWaypoint && laterWaypoint) {
		// how much work to go straight between waypoints?
		double workBetween = TLLocatorWorkBetweenWaypoints(earlierWaypoint,
														   laterWaypoint,
														   &distanceBetween,
														   &durationBetween,
														   targetTimestamp,
														   &locationBetween);
		if (interpolateWhenPossible) return locationBetween;
		acceptedSnapWork = workBetween * (1.0 + TLLocatorSnapTolerance);
		
		// what if we stayed at earlier location?
		TLLocation* snapEarlierLocation = [earlierWaypoint location];
		TLWaypoint* snapEarlierWaypoint = [TLWaypoint waypointWithLocation:snapEarlierLocation
																 timestamp:targetTimestamp];
		NSTimeInterval snapEarlierDurationLeft = 0.0;
		snapEarlierWork += TLLocatorWorkBetweenWaypoints(snapEarlierWaypoint,
														 laterWaypoint,
														 NULL,
														 &snapEarlierDurationLeft,
														 nil, NULL);
		snapEarlierWork += TLLocatorWorkFromAccelerating(0.0,
														 distanceBetween,
														 snapEarlierDurationLeft);
		
		// what if we were already at later location?
		TLLocation* snapLaterLocation = [laterWaypoint location];
		TLWaypoint* snapLaterWaypoint = [TLWaypoint waypointWithLocation:snapLaterLocation
															   timestamp:targetTimestamp];
		NSTimeInterval snapLaterDurationLeft = 0.0;
		snapLaterWork += TLLocatorWorkBetweenWaypoints(earlierWaypoint,
													   snapLaterWaypoint,
													   NULL,
													   &snapLaterDurationLeft,
													   nil, NULL);
		snapLaterWork += TLLocatorWorkFromAccelerating(0.0,
													   distanceBetween,
													   snapLaterDurationLeft);
	}
	
	double snapHomeWork = 0.0;
	double acceptedHomeWork = 0.0;
	if (earlierWaypoint && homeLocation) {
		// what if we went home?, part 1
		TLTimestamp* homeTimestamp = targetTimestamp;
		TLWaypoint* homeWaypoint = [TLWaypoint waypointWithLocation:homeLocation
														  timestamp:homeTimestamp];
		TLMetersECEF distanceHome = 0.0;
		NSTimeInterval durationHome = 0.0;
		snapHomeWork += TLLocatorWorkBetweenWaypoints(earlierWaypoint,
													  homeWaypoint,
													  &distanceHome,
													  &durationHome,
													  nil, NULL);
		snapHomeWork += TLLocatorWorkFromAccelerating(distanceBetween,
													  distanceHome,
													  durationHome);
		double homeForce = TLLocatorUserMass * TLLocatorHomeAcceleration;
		acceptedHomeWork +=  homeForce * distanceHome;
	}
	if (homeLocation && laterWaypoint) {
		// what if we went home?, part 2
		TLTimestamp* homeTimestamp = targetTimestamp;
		TLWaypoint* homeWaypoint = [TLWaypoint waypointWithLocation:homeLocation
														  timestamp:homeTimestamp];
		TLMetersECEF distanceHome = 0.0;
		NSTimeInterval durationHome = 0.0;
		snapHomeWork += TLLocatorWorkBetweenWaypoints(homeWaypoint,
													  laterWaypoint,
													  &distanceHome,
													  &durationHome,
													  nil, NULL);
		snapHomeWork += TLLocatorWorkFromAccelerating(distanceBetween,
													  distanceHome,
													  durationHome);
		double homeForce = TLLocatorUserMass * TLLocatorHomeAcceleration;
		acceptedHomeWork +=  homeForce * distanceHome;
	}
	
	// decide which location to use
	TLLocation* location = nil;
	if (snapHomeWork < acceptedHomeWork) {
		location = [homeLocation perturbedLocation];
	}
	else if (snapEarlierWork < acceptedSnapWork) {
		location = [[earlierWaypoint location] perturbedLocation];
	}
	else if (snapLaterWork < acceptedSnapWork) {
		location = [[laterWaypoint location] perturbedLocation];
	}
	else if (locationBetween) {
		location = locationBetween;
	}
	else {
		double netHomeWork = snapHomeWork - acceptedHomeWork;
		if (earlierWaypoint && snapEarlierWork < netHomeWork) {
			location = [[earlierWaypoint location] perturbedLocation];
		}
		else if (laterWaypoint && snapLaterWork < netHomeWork) {
			location = [[laterWaypoint location] perturbedLocation];
		}
		else {
			location = [homeLocation perturbedLocation];
		}
	}
	return location;
}
