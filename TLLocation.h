//
//  TLLocation.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 7/1/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLCoordinate.h"

@class TLTrack;

@interface TLLocation : NSObject < NSCopying, NSCoding > {
@private
	TLCoordinate originalCoordinate;
	TLCoordinate coordinate;
	TLCoordinateAccuracy horizontalAccuracy;
	TLCoordinateAltitude altitude;
	TLCoordinateAccuracy verticalAccuracy;
}

// Designated initializer
- (id)initWithCoordinate:(TLCoordinate)coord
	  horizontalAccuracy:(TLCoordinateAccuracy)hAccuracy
				altitude:(TLCoordinateAltitude)alt
		verticalAccuracy:(TLCoordinateAccuracy)vAccuracy
				 perturb:(BOOL)shouldPerturb;

// Helper initializers
+ (id)locationWithCoordinate:(TLCoordinate)coord
		  horizontalAccuracy:(TLCoordinateAccuracy)hAccuracy
					altitude:(TLCoordinateAltitude)alt
			verticalAccuracy:(TLCoordinateAccuracy)vAccuracy;
+ (id)locationWithCoordinate:(TLCoordinate)coord
		  horizontalAccuracy:(TLCoordinateAccuracy)hAccuracy;

// copy helpers
- (id)perturbedLocation;


// Properties
@property (readonly, nonatomic) TLCoordinate originalCoordinate;
@property (readonly, nonatomic) TLCoordinate coordinate;
@property (readonly, nonatomic) TLCoordinateAccuracy horizontalAccuracy;
@property (readonly, nonatomic) TLCoordinateAltitude altitude;
@property (readonly, nonatomic) TLCoordinateAccuracy verticalAccuracy;

@end
