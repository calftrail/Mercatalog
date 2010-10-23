//
//  TLModelHost.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLLibraryHost;

@interface TLModelHost : NSManagedObject {}
+ (NSString*)entityName;
+ (TLLibraryHost*)libraryHostInContext:(NSManagedObjectContext*)modelContext;

@property (nonatomic, retain) NSNumber* nextPhotoID;
@property (nonatomic, retain) id modelHomeBase;
@property (nonatomic, retain) NSNumber* modelAlwaysShowTimeline;
@property (nonatomic, retain) NSNumber* modelAlwaysShowTracks;
@end
