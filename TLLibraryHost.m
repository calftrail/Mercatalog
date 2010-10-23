//
//  TLLibraryHost.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLLibraryHost.h"

#import "TLMercatalogLibrary.h"
#import "TLPhoto.h"
#import "TLTrack.h"


@interface TLLibraryHost ()
@property (nonatomic, retain) NSArray* cachedTracks;
@property (nonatomic, retain) NSArray* cachedPhotos;
@end


@implementation TLLibraryHost

#pragma mark Class lifecycle

static NSString* const TLLibraryHostHostsKey = @"TLLibraryHost_Hosts";

+ (void)registerLibraryHost:(TLLibraryHost*)libraryHost
				 forContext:(NSManagedObjectContext*)aModelContext
{
	NSMutableDictionary* perThread = [[NSThread currentThread] threadDictionary];
	NSMapTable* threadHosts = [perThread objectForKey:TLLibraryHostHostsKey];
	if (!threadHosts) {
		threadHosts = [NSMapTable mapTableWithStrongToStrongObjects];
		[perThread setObject:threadHosts forKey:TLLibraryHostHostsKey];
	}
	
	if (libraryHost) {
		[threadHosts setObject:libraryHost forKey:aModelContext];
	}
	else {
		[threadHosts removeObjectForKey:aModelContext];
	}
}

+ (TLLibraryHost*)libraryHostForContext:(NSManagedObjectContext*)aModelContext {
	NSMutableDictionary* perThread = [[NSThread currentThread] threadDictionary];
	NSMapTable* threadHosts = [perThread objectForKey:TLLibraryHostHostsKey];
	return [threadHosts objectForKey:aModelContext];
}


#pragma mark Lifecycle

- (void)registerNotifications {
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(modelChanged:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:[self managedObjectContext]];
}

- (void)awakeFromInsert {
	[self registerNotifications];
}

- (void)awakeFromFetch {
	[self registerNotifications];
}

- (void)didTurnIntoFault {
	[self setCachedTracks:nil];
	[self setCachedPhotos:nil];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


#pragma mark Accessors

@synthesize library;

@synthesize cachedTracks;
@synthesize cachedPhotos;

- (NSManagedObjectContext*)modelContext {
	return [self managedObjectContext];
}

- (void)setHomeBase:(TLLocation*)newHomeBase {
	TLLocation* homeBaseCopy = [newHomeBase copy];
	[self setModelHomeBase:homeBaseCopy];
	[homeBaseCopy release];
}

- (TLLocation*)homeBase {
	return [self modelHomeBase];
}

- (void)setAlwaysShowTimeline:(BOOL)newAlwaysShowTimeline {
	[self setModelAlwaysShowTimeline:[NSNumber numberWithBool:newAlwaysShowTimeline]];
}

- (BOOL)alwaysShowTimeline {
	return [[self modelAlwaysShowTimeline] boolValue];
}

- (void)setAlwaysShowTracks:(BOOL)newAlwaysShowTracks {
	[self setModelAlwaysShowTracks:[NSNumber numberWithBool:newAlwaysShowTracks]];
}

- (BOOL)alwaysShowTracks {
	return [[self modelAlwaysShowTracks] boolValue];
}


#pragma mark Photo and thumbnail helpers

- (int64_t)makePhotoID {
	int64_t photoId = [[self nextPhotoID] longLongValue];
	NSAssert(photoId < LLONG_MAX,
			 @"Maximum photoId exceeded. Check for porcine precipitation");
	[self setNextPhotoID:[NSNumber numberWithLongLong:(photoId + 1)]];
	return photoId;
}

- (NSString*)photoOriginalsFolder {
	static NSString* const originalsFolder = @"Originals";
	[[self library] ensureDirectoryExists:originalsFolder];
	
	return [[[self library] currentBundlePath]
			stringByAppendingPathComponent:originalsFolder];
}

- (NSURL*)photoOriginalCopyLocation:(int64_t)uniqueID {
	NSString* base = [self photoOriginalsFolder];
	NSString* fileName = [NSString stringWithFormat:@"%lli.JPG", (long long)uniqueID];
	NSString* fullPath = [base stringByAppendingPathComponent:fileName];
	return [NSURL fileURLWithPath:fullPath isDirectory:NO];
}

- (NSURL*)photoThumbnailLocation:(int64_t)uniqueID forSize:(NSString*)sizeName {
	static NSString* const thumbnailsBase = @"Cached Thumbnails";
	NSString* thumbnailFolder = [thumbnailsBase stringByAppendingPathComponent:sizeName];
	[[self library] ensureDirectoryExists:thumbnailFolder];
	
	NSString* fullDirectory = [[[self library] currentBundlePath]
							   stringByAppendingPathComponent:thumbnailFolder];
	NSString* photoFilename = [NSString stringWithFormat:@"%lli.jpg", (long long)uniqueID];
	NSString* fullPath = [fullDirectory stringByAppendingPathComponent:photoFilename];
	return [NSURL fileURLWithPath:fullPath isDirectory:NO];
}


#pragma mark Model object fetching

- (void)modelChanged:(NSNotification*)notification {
	(void)notification;
	
	/*
	printf("modelChanged (%s): %s\n\n",
		   [[NSThread currentThread] isMainThread] ? "*" : "_",
		   [[[notification userInfo] description] UTF8String]);
	 */
	
	[self setCachedPhotos:nil];
	[self setCachedTracks:nil];
}

- (NSArray*)visiblePhotos {
	if (![self cachedPhotos]) {
		NSFetchRequest* request = [[NSFetchRequest new] autorelease];
		NSEntityDescription* entity = [NSEntityDescription entityForName:[TLPhoto entityName]
												  inManagedObjectContext:[self modelContext]];
		[request setEntity:entity];
		NSArray* visiblePhotos = [[self modelContext] executeFetchRequest:request error:NULL];
		[self setCachedPhotos:visiblePhotos];
	}
	return [self cachedPhotos];
}

- (NSArray*)evidencePhotos {
	NSArray* allPhotos = [self visiblePhotos];
	NSMutableArray* evidencePhotos = [NSMutableArray array];
	for (TLPhoto* photo in allPhotos) {
		if ([photo isLocked]) {
			[evidencePhotos addObject:photo];
		}
	}
	return evidencePhotos;
}

- (NSArray*)allTracks {
	if (![self cachedTracks]) {
		NSFetchRequest* request = [[NSFetchRequest new] autorelease];
		NSEntityDescription* entity = [NSEntityDescription entityForName:[TLTrack entityName]
												  inManagedObjectContext:[self modelContext]];
		[request setEntity:entity];
		NSArray* allTracks = [[self modelContext] executeFetchRequest:request error:NULL];
		[self setCachedTracks:allTracks];
	}
	return [self cachedTracks];
}

@end
