//
//  TLModelPhoto.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLModelPhoto.h"


@implementation TLModelPhoto

@dynamic cacheID;
@dynamic cameraDate;
@dynamic fileDate;
@dynamic modelLocation;
@dynamic modelLocked;
@dynamic modelTimestamp;
@dynamic path;

+ (NSString*)entityName {
	return @"Photo";
}

+ (TLPhoto*)photoInContext:(NSManagedObjectContext*)modelContext {
	return (TLPhoto*)[NSEntityDescription insertNewObjectForEntityForName:[self entityName]
												   inManagedObjectContext:modelContext];
}

@end
