//
//  TLLocation.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 7/1/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLLocation.h"

#include "TLRandom.h"
#include "TLProjectionInfo.h"
#include "TLCoordGeometry.h"

static CGSize TLProjectionInfoMetersPerDegree(TLCoordinate targetCoord);
static TLCoordinate TLCoordinatePerturb(TLCoordinate origCoord, TLCoordinateAccuracy accuracy);


@implementation TLLocation

#pragma mark Archiving

static NSString* const TLLocationWrappedDataKey = @"TLLocation_WrappedData";

enum {
	TLLocationOriginalCoordinateLatitudeIndex = 0,
	TLLocationOriginalCoordinateLongitudeIndex = 1,
	TLLocationCoordinateLatitudeIndex = 2,
	TLLocationCoordinateLongitudeIndex = 3,
	TLLocationHorizontalAccuracyIndex = 4,
	TLLocationAltitudeIndex = 5,
	TLLocationVerticalAccuracyIndex = 6,
	TLLocationDataCount = 7
};

- (void)encodeWithCoder:(NSCoder*)encoder {
	const size_t dataSize = TLLocationDataCount * sizeof(CFSwappedFloat64);
	CFSwappedFloat64* dataArray = (CFSwappedFloat64*)malloc(dataSize);
	dataArray[TLLocationOriginalCoordinateLatitudeIndex] = CFConvertFloat64HostToSwapped(originalCoordinate.lat);
	dataArray[TLLocationOriginalCoordinateLongitudeIndex] = CFConvertFloat64HostToSwapped(originalCoordinate.lon);
	dataArray[TLLocationCoordinateLatitudeIndex] = CFConvertFloat64HostToSwapped(coordinate.lat);
	dataArray[TLLocationCoordinateLongitudeIndex] = CFConvertFloat64HostToSwapped(coordinate.lon);
	dataArray[TLLocationHorizontalAccuracyIndex] = CFConvertFloat64HostToSwapped(horizontalAccuracy);
	dataArray[TLLocationAltitudeIndex] = CFConvertFloat64HostToSwapped(altitude);
	dataArray[TLLocationVerticalAccuracyIndex] = CFConvertFloat64HostToSwapped(verticalAccuracy);
	// NOTE: this avoids autorelease to reduce memory pressure
	NSData* data = [[NSData alloc] initWithBytesNoCopy:dataArray length:dataSize freeWhenDone:YES];
	[encoder encodeObject:data forKey:TLLocationWrappedDataKey];
	[data release];
}

- (id)initWithCoder:(NSCoder*)coder {
	self = [super init];
	if (self) {
		NSData* data = [coder decodeObjectForKey:TLLocationWrappedDataKey];
		const CFSwappedFloat64* dataArray = (CFSwappedFloat64*)[data bytes];
		NSAssert1([data length] == TLLocationDataCount * sizeof(CFSwappedFloat64),
				  @"Bad location data length (%lu)", (long unsigned)[data length]);
		originalCoordinate.lat = CFConvertFloat64SwappedToHost(dataArray[TLLocationOriginalCoordinateLatitudeIndex]);
		originalCoordinate.lon = CFConvertFloat64SwappedToHost(dataArray[TLLocationOriginalCoordinateLongitudeIndex]);
		coordinate.lat = CFConvertFloat64SwappedToHost(dataArray[TLLocationCoordinateLatitudeIndex]);
		coordinate.lon = CFConvertFloat64SwappedToHost(dataArray[TLLocationCoordinateLongitudeIndex]);
		horizontalAccuracy = CFConvertFloat64SwappedToHost(dataArray[TLLocationHorizontalAccuracyIndex]);
		altitude = CFConvertFloat64SwappedToHost(dataArray[TLLocationAltitudeIndex]);
		verticalAccuracy = CFConvertFloat64SwappedToHost(dataArray[TLLocationVerticalAccuracyIndex]);
	}
    return self;
}


#pragma mark Lifecycle

+ (void)initialize {
	if (self != [TLLocation class]) return;
	TLRandomInit();
}

- (id)initWithCoordinate:(TLCoordinate)coord
	  horizontalAccuracy:(TLCoordinateAccuracy)hAccuracy
				altitude:(TLCoordinateAltitude)alt
		verticalAccuracy:(TLCoordinateAccuracy)vAccuracy
				 perturb:(BOOL)shouldPerturb
{
	self = [super init];
	if (self) {
		originalCoordinate = coord;
		if (shouldPerturb) {
			coordinate = TLCoordinatePerturb(coord, hAccuracy);
		}
		else {
			coordinate = coord;
		}
		horizontalAccuracy = hAccuracy;
		altitude = alt;
		verticalAccuracy = vAccuracy;
	}
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (id)copyWithZone:(NSZone*)zone {
	TLLocation* location = [[TLLocation allocWithZone:zone] initWithCoordinate:[self originalCoordinate]
															horizontalAccuracy:[self horizontalAccuracy]
																	  altitude:[self altitude]
															  verticalAccuracy:[self verticalAccuracy]
																	   perturb:NO];
	// keep same perturbed coordinate
	location->coordinate = [self coordinate];
	return location;
}


#pragma mark Convenience creators

+ (id)locationWithCoordinate:(TLCoordinate)coord
		  horizontalAccuracy:(TLCoordinateAccuracy)hAccuracy
					altitude:(TLCoordinateAltitude)alt
			verticalAccuracy:(TLCoordinateAccuracy)vAccuracy
{
	TLLocation* location = [[TLLocation alloc] initWithCoordinate:coord
											   horizontalAccuracy:hAccuracy
														 altitude:alt
												 verticalAccuracy:vAccuracy
														  perturb:YES];
	return [location autorelease];
}

+ (id)locationWithCoordinate:(TLCoordinate)coord
		  horizontalAccuracy:(TLCoordinateAccuracy)hAccuracy
{
	TLLocation* location = [[TLLocation alloc] initWithCoordinate:coord
											   horizontalAccuracy:hAccuracy
														 altitude:TLCoordinateAltitudeUnknown
												 verticalAccuracy:TLCoordinateAccuracyUnknown
														  perturb:YES];
	return [location autorelease];
}

- (id)perturbedLocation {
	TLLocation* location = [self copy];
	location->coordinate = TLCoordinatePerturb([location originalCoordinate],
											   [location horizontalAccuracy]);
	return [location autorelease];
}

#pragma mark Accessors

@synthesize originalCoordinate;
@synthesize coordinate;
@synthesize horizontalAccuracy;
@synthesize altitude;
@synthesize verticalAccuracy;

@end


TLCoordinate TLCoordinatePerturb(TLCoordinate origCoord, TLCoordinateAccuracy accuracy) {
	if (accuracy <= 0.0) return origCoord;
	CGPoint randoms = TLRandomGaussian();
	CGSize degreeSize = TLProjectionInfoMetersPerDegree(origCoord);
	// two standardDeviations is 95.45% certainty
	const double standardDeviations = 2.0;
	double lonAdjustment = (randoms.x * accuracy) / (standardDeviations * degreeSize.width);
	double latAdjustment = (randoms.y * accuracy) / (standardDeviations * degreeSize.height);
	TLCoordinate unclampedCoordinate = TLCoordinateMake(origCoord.lat + latAdjustment,
														origCoord.lon + lonAdjustment);
	return TLCoordinateAdjustToRange(unclampedCoordinate);
}

// use this size only for approximations
CGSize TLProjectionInfoMetersPerDegree(TLCoordinate targetCoord) {
	TLProjectionGeoidMeters equatorCircumference = 2.0 * M_PI * TLProjectionGeoidGetEquatorialRadius(TLProjectionGeoidWGS84);
	TLProjectionGeoidMeters parallelCircumference = cos(targetCoord.lat * TLCoordinateDegreesToRadians) * equatorCircumference;
	double meridianSpacing = parallelCircumference / TLProjectionInfoFullCircle;
	double parallelSpacing = equatorCircumference / TLProjectionInfoFullCircle;		// NOTE: this assumes a spherical earth
	return CGSizeMake((CGFloat)meridianSpacing, (CGFloat)parallelSpacing);
}
