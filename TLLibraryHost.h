//
//  TLLibraryHost.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLModelHost.h"

@class TLMercatalogLibrary;
@class TLLocation;


@interface TLLibraryHost : TLModelHost {
@private
	__weak TLMercatalogLibrary* library;
	NSArray* cachedTracks;
	NSArray* cachedPhotos;
}

+ (void)registerLibraryHost:(TLLibraryHost*)libraryHost
				 forContext:(NSManagedObjectContext*)aModelContext;
+ (id)libraryHostForContext:(NSManagedObjectContext*)aModelContext;

@property (nonatomic, assign) TLMercatalogLibrary* library;

- (int64_t)makePhotoID;
- (NSURL*)photoOriginalCopyLocation:(int64_t)uniqueID;
- (NSURL*)photoThumbnailLocation:(int64_t)uniqueID forSize:(NSString*)sizeName;

@property (nonatomic, copy) TLLocation* homeBase;
@property (nonatomic, assign) BOOL alwaysShowTimeline;
@property (nonatomic, assign) BOOL alwaysShowTracks;

- (NSArray*)visiblePhotos;
- (NSArray*)evidencePhotos;
- (NSArray*)allTracks;

@end
