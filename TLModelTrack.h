//
//  TLModelTrack.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLTrack;


@interface TLModelTrack : NSManagedObject {}
+ (NSString*)entityName;
+ (TLTrack*)trackInContext:(NSManagedObjectContext*)modelContext;

@property (nonatomic, retain) NSDate* modelStartTime;
@property (nonatomic, retain) NSDate* modelEndTime;
@property (nonatomic, retain) NSManagedObject* modelWaypoints;
@end
