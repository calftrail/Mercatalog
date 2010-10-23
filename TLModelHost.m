//
//  TLModelHost.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLModelHost.h"


@implementation TLModelHost
@dynamic nextPhotoID;
@dynamic modelHomeBase;
@dynamic modelAlwaysShowTimeline;
@dynamic modelAlwaysShowTracks;

+ (NSString*)entityName {
	return @"Host";
}

+ (TLLibraryHost*)libraryHostInContext:(NSManagedObjectContext*)modelContext {
	return (TLLibraryHost*)[NSEntityDescription insertNewObjectForEntityForName:[self entityName]
												   inManagedObjectContext:modelContext];
}

@end
