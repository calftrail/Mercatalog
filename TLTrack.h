//
//  TLTrack.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 6/24/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLModelTrack.h"
@class TLGPXTrackSegment;

@interface TLTrack : TLModelTrack {
@private
	NSArray* waypoints;
}

- (BOOL)setWithGPXSegment:(TLGPXTrackSegment*)gpxSegment
					error:(NSError**)err;

@property (nonatomic, readonly, copy) NSArray* waypoints;
@property (nonatomic, readonly) NSDate* startDate;
@property (nonatomic, readonly) NSDate* endDate;

@end
