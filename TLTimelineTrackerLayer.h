//
//  TLTimelineTrackerLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineInteractiveLayer.h"

@class TLTimestamp;


@interface TLTimelineTrackerLayer : TLTimelineInteractiveLayer {
@private
	id delegate;
}

@property (nonatomic, assign) id delegate;

@end


@interface NSObject (TLTimelineTrackerLayerDelegate)

- (void)timelineTrackerLayer:(TLTimelineTrackerLayer*)trackerLayer
			mouseAtTimestamp:(TLTimestamp*)mouseTimestamp;

@end
