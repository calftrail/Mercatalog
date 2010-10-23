//
//  TLModelPhoto.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLPhoto;
@class TLModelLocation;
@class TLModelTimestamp;


@interface TLModelPhoto : NSManagedObject {}
+ (NSString*)entityName;
+ (TLPhoto*)photoInContext:(NSManagedObjectContext*)modelContext;

@property (nonatomic, retain) NSNumber* cacheID;
@property (nonatomic, retain) NSDate* cameraDate;
@property (nonatomic, retain) NSDate* fileDate;
@property (nonatomic, retain) id modelLocation;
@property (nonatomic, retain) NSNumber* modelLocked;
@property (nonatomic, retain) id modelTimestamp;
@property (nonatomic, retain) NSString* path;
@end
