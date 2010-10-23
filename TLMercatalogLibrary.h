//
//  TLMercatalogLibrary.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLProjectBundle.h"

@class TLPhoto;
@class TLTrack;
@class TLLibraryHost;

@interface TLMercatalogLibrary : TLProjectBundle {
@private
	NSPersistentStoreCoordinator* storeCoordinator;
	NSArray* cachedTracks;
	NSWindow* windowForSheet;
}

- (NSManagedObjectContext*)modelContext;

@property (nonatomic, retain) NSWindow* windowForSheet;

@end
