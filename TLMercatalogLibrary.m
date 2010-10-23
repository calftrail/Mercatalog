//
//  TLMercatalogLibrary.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLMercatalogLibrary.h"

#import "TLTrack.h"
#import "TLPhoto.h"
#import "TLLibraryHost.h"
#import "TLLocator.h"


@implementation TLMercatalogLibrary

#pragma mark Archiving / lifecycle

- (NSPersistentStoreCoordinator*)preparedStoreCoordinator:(NSError**)err {
	NSString* modelPath = [[NSBundle mainBundle] pathForResource:@"Mercatalog" ofType:@"mom"];
	NSURL* modelURL = [NSURL fileURLWithPath:modelPath isDirectory:NO];
	NSManagedObjectModel* objectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	[objectModel autorelease];
	NSPersistentStoreCoordinator* newStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
														 initWithManagedObjectModel:objectModel];
	[newStoreCoordinator autorelease];
	
	// TODO: this should use project locking
	NSString* storePath = [[self currentBundlePath] stringByAppendingPathComponent:@"database.coredata"];
	NSURL* storeURL = [NSURL fileURLWithPath:storePath isDirectory:NO];
	NSError* internalError = nil;
	(void)[newStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType	//NSXMLStoreType
											configuration:nil
													  URL:storeURL
												  options:nil
													error:&internalError];
	if (internalError) {
		if (err) *err = internalError;
		return nil;
	}
	return newStoreCoordinator;
}

- (BOOL)createWithOptions:(TLProjectBundleFlags)flags error:(NSError**)err {
	(void)flags;
	
	NSError* internalError = nil;
	storeCoordinator = [[self preparedStoreCoordinator:&internalError] retain];
	if (internalError) {
		if (err) *err = internalError;
		return NO;
	}
	
	NSManagedObjectContext* modelContext = [[NSManagedObjectContext alloc] init];
	[modelContext setPersistentStoreCoordinator:storeCoordinator];
	
	TLLibraryHost* host = [TLLibraryHost libraryHostInContext:modelContext];
	[host setHomeBase:[TLLocator defaultHomeBase]];
	
	BOOL saved = [modelContext save:&internalError];
	if (!saved) {
		NSLog(@"modelContext - %@\n", internalError);
	}
	
	return YES;
}

- (BOOL)loadWithOptions:(TLProjectBundleFlags)flags error:(NSError**)err {
	(void)flags;
	
	NSError* internalError = nil;
	storeCoordinator = [[self preparedStoreCoordinator:&internalError] retain];
	if (internalError) {
		if (err) *err = internalError;
		return NO;
	}
	
	return YES;
}

- (void)close {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	for (NSManagedObject* deletedObject in [[self modelContext] deletedObjects]) {
		if (![deletedObject isKindOfClass:[TLPhoto class]]) continue;
		TLPhoto* deletedPhoto = (TLPhoto*)deletedObject;
		[deletedPhoto uncacheThumbnails];
		NSURL* copyURL = [host photoOriginalCopyLocation:[deletedPhoto uniqueID]];
		(void)[[NSFileManager defaultManager] removeItemAtPath:[copyURL path] error:NULL];
	}
	
	NSError* internalError = nil;
	(void)[[self modelContext] save:&internalError];
	if (internalError) {
		NSLog(@"modelContext - %@\n", internalError);
		NSArray* allErrors = [[internalError userInfo] objectForKey:NSDetailedErrorsKey];
		for (NSError* subError in allErrors) {
			NSLog(@" - %@\n", subError);
		}
		NSArray* conflicts = [[internalError userInfo] objectForKey:@"conflictList"];
		for (id conflictRecord in conflicts) {
			NSLog(@" * %@\n", conflictRecord);
		}
	}
	
	[super close];
}

- (void)dealloc {
	[storeCoordinator release];
	[super dealloc];
}


#pragma mark Accessors

@synthesize windowForSheet;

- (void)setUndoManager:(NSUndoManager*)newUndoManager {
	[[self modelContext] setUndoManager:newUndoManager];
}

- (NSUndoManager*)undoManager {
	return [[self modelContext] undoManager];
}

+ (TLLibraryHost*)contextLibraryHost:(NSManagedObjectContext*)aModelContext
							   error:(NSError**)err
{
	NSFetchRequest* request = [[NSFetchRequest new] autorelease];
	NSEntityDescription* entity = [NSEntityDescription entityForName:[TLLibraryHost entityName]
											  inManagedObjectContext:aModelContext];
	[request setEntity:entity];
	NSError* internalError = nil;
	NSArray* hostArray = [aModelContext executeFetchRequest:request error:&internalError];
	TLLibraryHost* libraryHost = nil;
	if (internalError) {
		if (err) *err = internalError;
	}
	else if ([hostArray count] != 1) {
		if (err) {
			*err = [NSError errorWithDomain:NSCocoaErrorDomain
									   code:NSFileReadCorruptFileError
								   userInfo:nil];
		}
	}
	else {
		libraryHost = [hostArray objectAtIndex:0];
	}
	return libraryHost;
}

- (NSManagedObjectContext*)freshModelContext {
	NSManagedObjectContext* freshContext = [[NSManagedObjectContext new] autorelease];
	[storeCoordinator lock];
	[freshContext setPersistentStoreCoordinator:storeCoordinator];
	[storeCoordinator unlock];
	return freshContext;
}

- (NSManagedObjectContext*)modelContext {
	static NSString* const TLMercatalogLibraryModelContextKey = @"TLMercatalogLibrary_ModelContext";
	
	NSMutableDictionary* perThread = [[NSThread currentThread] threadDictionary];
	NSManagedObjectContext* modelContext = [perThread objectForKey:TLMercatalogLibraryModelContextKey];
	if (!modelContext) {
		modelContext = [self freshModelContext];
		[perThread setObject:modelContext forKey:TLMercatalogLibraryModelContextKey];
		
		TLLibraryHost* host = [[self class] contextLibraryHost:modelContext error:NULL];
		NSAssert(host, @"Context must have valid host object");
		[host setLibrary:self];
		[TLLibraryHost registerLibraryHost:host forContext:modelContext];
	}
	return modelContext;
}

@end
