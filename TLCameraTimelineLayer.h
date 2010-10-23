//
//  TLCameraTimelineLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineLayer.h"


@interface TLCameraTimelineLayer : TLTimelineLayer {
@private
	id dataSource;
}

@property (nonatomic, assign) id dataSource;
- (void)reloadData;

@end


@interface NSObject (TLCameraTimelineLayerDataSource)
- (NSArray*)cameraTimelineLayer:(TLCameraTimelineLayer*)cameraTimelineLayer
				offsetsFromDate:(NSDate*)startDate
						 toDate:(NSDate*)endDate;
@end
