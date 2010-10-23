//
//  TLCameraTimeline.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLPhoto;

@interface TLCameraTimeline : NSObject {
@private
	NSManagedObjectContext* modelContext;
}

@property (nonatomic, retain) NSManagedObjectContext* modelContext;

- (NSArray*)timestampsForCameraTime:(NSDate*)cameraTime;
- (NSArray*)offsetTimestampVerticesFrom:(NSDate*)startDate to:(NSDate*)endDate;

@end
