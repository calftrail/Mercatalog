//
//  TLModelTrack.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLModelTrack.h"

@implementation TLModelTrack

+ (NSString*)entityName {
	return @"Track";
}

+ (TLTrack*)trackInContext:(NSManagedObjectContext*)modelContext {
	return (TLTrack*)[NSEntityDescription insertNewObjectForEntityForName:[self entityName]
												   inManagedObjectContext:modelContext];
}

@dynamic modelWaypoints;
@dynamic modelStartTime;
@dynamic modelEndTime;

@end
