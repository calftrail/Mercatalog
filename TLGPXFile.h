//
//  TLGPXFile.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 3/17/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLGPXNode.h"
#import "TLGPXWaypoint.h"
#import "TLGPXTracklog.h"

@interface TLGPXFile : TLGPXNode {
@protected
	NSMutableArray* tracks;
	NSMutableArray* waypoints;
@private
	NSDate* cachedStartDate;
	NSDate* cachedEndDate;
	// parsing states
	NSMutableArray* currentTrack;
	NSMutableArray* currentSegment;
	NSMutableDictionary* currentPoint;
}

- (id)initGPXFileWithContentsOfURL:(NSURL*)url error:(NSError**)error;

- (NSArray*)tracks;
- (NSArray*)waypoints;

@end
