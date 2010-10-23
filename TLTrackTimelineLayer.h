//
//  TLTrackTimelineLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineLayer.h"

@interface TLTrackTimelineLayer : TLTimelineLayer {
@private
	id dataSource;
}

@property (nonatomic, assign) id dataSource;
- (void)reloadData;

@end


@interface NSObject (TLTrackTimelineLayerDataSource)
- (NSArray*)trackTimelineLayer:(TLTrackTimelineLayer*)trackLayer
				tracksFromDate:(NSDate*)startDate
						toDate:(NSDate*)endDate;
@end
