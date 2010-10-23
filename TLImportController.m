//
//  TLImportController.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/16/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLImportController.h"

#import "TLGPXFile.h"
#import "TLCocoaToolbag.h"
#import "TLPhoto.h"
#import "TLTrack.h"

#import "TLTimestamp.h"
#import "TLLocator.h"
#import "TLCameraTimeline.h"
#import "TLLibraryHost.h"

#import "TLMainThreadPerformer.h"


@interface TLImportController ()
- (void)doImport;
@end


@implementation TLImportController

#pragma mark Lifecycle

- (id)initWithFilenames:(NSArray*)theFilenames
				library:(TLMercatalogLibrary*)theLibrary
			   delegate:(id)theDelegate
{
	self = [super init];
	if (self) {
		delegate = theDelegate;
		library = [theLibrary retain];
		filenames = [theFilenames copy];
	}
	return self;
}

- (void)dealloc {
	[library release];
	[filenames release];
	[super dealloc];
}


#pragma mark Accesors

@synthesize delegate;
@synthesize library;
@synthesize filenames;

- (NSManagedObjectContext*)modelContext {
	return [[self library] modelContext];
}


#pragma mark User interface code

- (void)loadSheet {
	NSWindow* window = [[self library] windowForSheet];
	if (!window) return;
	BOOL sheetLoaded = [NSBundle loadNibNamed:@"ImportSheet" owner:self];
	if (!sheetLoaded) return;
	
	NSString* preparingText = NSLocalizedString(@"Preparing to import.", @"Import dialog text when import begins.");
	[importProgressText setStringValue:preparingText];
	[importProgressBar setUsesThreadedAnimation:YES];
	[importProgressBar setIndeterminate:YES];
	[importProgressBar startAnimation:self];
	[importCurrentText setStringValue:@""];
	
	[NSApp beginSheet:importSheet
	   modalForWindow:window
		modalDelegate:self
	   didEndSelector:NULL
		  contextInfo:NULL];
	/* NOTE: while the use of 0 is not documented, it does help the
	 app keep from getting too antsy. This is corroborated by
	 http://www.cocoabuilder.com/archive/message/cocoa/2006/2/3/155978 */
	[NSApp cancelUserAttentionRequest:0];
}

- (void)unloadSheet {
	[NSApp endSheet:importSheet];
	[importSheet orderOut:self];
	[importSheet release];
	importSheet = nil;
}

- (BOOL)reportProgress:(NSUInteger)numProcessed
				 files:(NSArray*)allFiles
				errors:(NSArray*)errors
{
	NSString* progressText = nil;
	NSString* mostRecentFile = @"";
	if (numProcessed && numProcessed < [allFiles count]) {
		NSUInteger numErrors = [errors count];
		NSUInteger numTotal = [allFiles count];
		
		[importProgressBar setIndeterminate:NO];
		double percent =  (double)numProcessed / numTotal;
		double barRange = [importProgressBar maxValue] - [importProgressBar minValue];
		double progress = [importProgressBar minValue] + (percent * barRange);
		[importProgressBar setDoubleValue:progress];
		
		// TODO: localize
		if (!numErrors) {
			progressText = [NSString stringWithFormat:@"Imported %lu of %lu files.",
							(long unsigned)numProcessed,
							(long unsigned)numTotal];
		}
		else if (numErrors == 1) {
			progressText = [NSString stringWithFormat:@"Imported %lu of %lu files, with one error.",
							(long unsigned)numProcessed,
							(long unsigned)numTotal];
		}
		else {
			progressText = [NSString stringWithFormat:@"Imported %lu of %lu files, with %lu errors.",
							(long unsigned)numProcessed,
							(long unsigned)numTotal,
							(long unsigned)numErrors];
		}
		mostRecentFile = [allFiles objectAtIndex:(numProcessed-1)];
	}
	else if (numProcessed) {
		[importProgressBar setIndeterminate:YES];
		progressText = @"Finishing import.";
	}
	else {
		NSUInteger preprocessedCount = [allFiles count];
		[importProgressBar setIndeterminate:YES];
		progressText = [NSString stringWithFormat:@"Preparing to import %lu files.",
						(long unsigned)preprocessedCount];
		if (preprocessedCount) {
			mostRecentFile = [allFiles lastObject];
		}
	}
	[importProgressText setStringValue:progressText];
	[importCurrentText setStringValue:mostRecentFile];
	[importSheet displayIfNeeded];
	
	return YES;
}


#pragma mark Background import code

- (NSArray*)findAllFiles:(NSArray*)filesAndFolders
			   inFolders:(BOOL)recurse
				  errors:(NSMutableArray*)errors
{
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	
	NSMutableArray* allFiles = [NSMutableArray array];
	NSArray* remainingFilesAndFolders = filesAndFolders;
	while ([remainingFilesAndFolders count]) {
		NSMutableArray* newRemainingFilesAndFolders = [NSMutableArray array];
		for (NSString* fileOrFolder in remainingFilesAndFolders) {
			if (shouldCancel) {
				return nil;
			}
			
			NSAutoreleasePool* looPPool = [NSAutoreleasePool new];
			BOOL isDirectory = NO;
			BOOL exists = [fileManager fileExistsAtPath:fileOrFolder isDirectory:&isDirectory];
			if (!exists) {
				NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:fileOrFolder forKey:NSFilePathErrorKey];
				NSError* err = [NSError errorWithDomain:NSCocoaErrorDomain
												   code:NSFileReadNoSuchFileError
											   userInfo:errorInfo];
				[errors addObject:err];
			}
			else if (isDirectory && recurse) {
				NSString* folder = fileOrFolder;
				NSError* err = nil;
				NSArray* subpaths = [fileManager contentsOfDirectoryAtPath:folder error:&err];
				if (err) [errors addObject:err];
				for (NSString* subpath in subpaths) {
					NSString* fullpath = [folder stringByAppendingPathComponent:subpath];
					[newRemainingFilesAndFolders addObject:fullpath];
				}
			}
			else {
				NSString* file = fileOrFolder;
				NSString* filename = [file lastPathComponent];
				// don't try to import hidden files
				if ([filename length] && [filename characterAtIndex:0] != (unichar)'.') {
					[allFiles addObject:file];
				}
			}
			[[self tlMainThreadProxy] reportProgress:0 files:allFiles errors:errors];
			[looPPool release];
		}
		remainingFilesAndFolders = newRemainingFilesAndFolders;
	}
	return allFiles;
}

- (void)importAllFiles:(NSArray*)flatFiles
				 photos:(NSMutableArray*)photos
				 tracks:(NSMutableArray*)tracks
				 errors:(NSMutableArray*)errors
{
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	
	NSUInteger numProcessed = 0;
	for (NSString* file in flatFiles) {
		if (shouldCancel) {
			return;
		}
		
		NSAutoreleasePool* looPPool = [NSAutoreleasePool new];
		NSURL* fileURL = [NSURL fileURLWithPath:file];
		NSString* uti = TLFileGetUTI(fileURL);
		if (UTTypeConformsTo((CFStringRef)uti, CFSTR("com.topografix.gpx"))) {
			TLGPXFile* gpxFile = [[TLGPXFile alloc] initGPXFileWithContentsOfURL:fileURL error:NULL];
			for (TLGPXTracklog* gpxTrack in [gpxFile tracks]) {
				for (TLGPXTrackSegment* gpxSegment in gpxTrack) {
					TLTrack* track = [TLTrack trackInContext:[self modelContext]];
					NSError* internalError = nil;
					(void)[track setWithGPXSegment:gpxSegment error:&internalError];
					if (internalError) {
						[[self modelContext] deleteObject:track];
						[errors addObject:internalError];
					}
					else {
						[tracks addObject:track];
					}
				}
			}
		}
		else if (TLFileUTIConformsToAny(uti, [TLPhoto validTypes])) {
			TLPhoto* photo = [TLPhoto photoInContext:[self modelContext]];
			[photo setPath:file];
			NSError* internalError = nil;
			[photo setWithImageAtPath:&internalError];
			if (internalError) {
				[[self modelContext] deleteObject:photo];
				[errors addObject:internalError];
			}
			else {
				if (copyOriginals) {
					NSURL* copyURL = [host photoOriginalCopyLocation:[photo uniqueID]];
					NSError* copyError = nil;
					(void)[fileManager copyItemAtPath:file
											   toPath:[copyURL path]
												error:&copyError];
					if (copyError) {
						[errors addObject:copyError];
					}
				}
				(void)[photo cacheThumbnails:NULL];
				[photos addObject:photo];
			}
		}
		else {
			NSDictionary* errorInfo = [NSDictionary dictionaryWithObject:file forKey:NSFilePathErrorKey];
			NSError* internalError = [NSError errorWithDomain:NSCocoaErrorDomain
														 code:NSFileReadCorruptFileError
													 userInfo:errorInfo];
			[errors addObject:internalError];
		}
		++numProcessed;
		[[self tlMainThreadProxy] reportProgress:numProcessed files:flatFiles errors:errors];
		[looPPool release];
	}
}

- (TLTimestamp*)bestTimestampForPhoto:(TLPhoto*)photo {
	TLCameraTimeline* cameraTimeline = [[TLCameraTimeline new] autorelease];
	[cameraTimeline setModelContext:[self modelContext]];
	NSArray* timestamps = [cameraTimeline timestampsForCameraTime:[photo originalDate]];
	TLTimestamp* bestTimestamp = nil;
	NSTimeInterval closestInterval = 0.0;
	for (TLTimestamp* timestamp in timestamps) {
		NSTimeInterval interval = fabs([[timestamp time] timeIntervalSinceDate:[photo fileDate]]);
		if (!bestTimestamp || interval < closestInterval) {
			bestTimestamp = timestamp;
			closestInterval = interval;
		}
	}
	return bestTimestamp;
}

- (void)processPhotos:(NSArray*)photos {
	TLLocator* locator = [[TLLocator new] autorelease];
	[locator setModelContext:[self modelContext]];
	for (TLPhoto* photo in photos) {
		TLTimestamp* timestamp = [self bestTimestampForPhoto:photo];
		[photo setTimestamp:timestamp];
		if (![photo location]) {
			TLLocation* location = [locator locationAtTimestamp:timestamp];
			[photo setLocation:location];
		}
	}
}

- (IBAction)startImport:(id)sender {
	(void)sender;
	
	[self loadSheet];
	if ([[self delegate] respondsToSelector:@selector(importControllerDidBegin:)]) {
		[[self delegate] importControllerDidBegin:self];
	}
	
	copyOriginals = [[NSUserDefaults standardUserDefaults] boolForKey:@"CopyOriginalPhotos"];
	[self performSelectorInBackground:@selector(doImport) withObject:nil];
	//[self doImport];
}

- (IBAction)cancelImport:(id)sender {
	(void)sender;
	shouldCancel = YES;
}


- (void)mainThreadCancelImport {
	[self unloadSheet];
	if ([[self delegate] respondsToSelector:@selector(importControllerDidCancel:)]) {
		[[self delegate] importControllerDidCancel:self];
	}
}

- (void)doCancelImport:(NSArray*)photos {
	// remove photo files, then rollback context
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[self modelContext]];
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	for (TLPhoto* deletedPhoto in photos) {
		[deletedPhoto uncacheThumbnails];
		NSURL* copyURL = [host photoOriginalCopyLocation:[deletedPhoto uniqueID]];
		(void)[fileManager removeItemAtPath:[copyURL path] error:NULL];
	}
	[[self modelContext] rollback];
	
	[[self tlMainThreadProxy] mainThreadCancelImport];
}

- (void)mainThreadFinishImportPhotos:(NSArray*)photoIDs
							  tracks:(NSArray*)trackIDs
{
	NSArray* photos = nil;
	{
		NSFetchRequest* request = [[NSFetchRequest new] autorelease];
		NSEntityDescription* entity = [NSEntityDescription entityForName:[TLPhoto entityName]
												  inManagedObjectContext:[self modelContext]];
		[request setEntity:entity];
		NSPredicate* predicate = [NSPredicate predicateWithFormat:@"self IN %@", photoIDs];
		[request setPredicate:predicate];
		photos = [[self modelContext] executeFetchRequest:request error:NULL];
	}
	
	NSArray* tracks = nil;
	{
		NSFetchRequest* request = [[NSFetchRequest new] autorelease];
		NSEntityDescription* entity = [NSEntityDescription entityForName:[TLTrack entityName]
												  inManagedObjectContext:[self modelContext]];
		[request setEntity:entity];
		NSPredicate* predicate = [NSPredicate predicateWithFormat:@"self IN %@", trackIDs];
		[request setPredicate:predicate];
		tracks = [[self modelContext] executeFetchRequest:request error:NULL];
	}
	
	[self unloadSheet];
	if ([[self delegate] respondsToSelector:@selector(importControllerDidImport:photos:tracks:)]) {
		[[self delegate] importControllerDidImport:self photos:photos tracks:tracks];
	}
}

- (void)finishImport:(NSArray*)errors
			  photos:(NSArray*)photos
			  tracks:(NSArray*)tracks
{
	for (NSError* err in errors) {
		fprintf(stderr, "Mercatalog import error (%s)\n", [[err description] UTF8String]);
		for (NSError* subErr in [[err userInfo] objectForKey:NSDetailedErrorsKey]) {
			fprintf(stderr, " (suberror) (%s)\n", [[subErr description] UTF8String]);
		}
	}
	if ([errors count]) fprintf(stderr, "\n");
	
	NSMutableArray* photoIDs = [NSMutableArray array];
	for (TLPhoto* photo in photos) {
		[photoIDs addObject:[photo objectID]];
	}
	NSMutableArray* trackIDs = [NSMutableArray array];
	for (TLTrack* track in tracks) {
		[trackIDs addObject:[track objectID]];
	}
	[[self tlMainThreadProxy] mainThreadFinishImportPhotos:photoIDs tracks:trackIDs];
}


- (void)mainThreadUseModelSaveNotification:(NSNotification*)saveNotification {
	//printf("save notification - %s\n\n", [[[saveNotification userInfo] description] UTF8String]);
	[[self modelContext] mergeChangesFromContextDidSaveNotification:saveNotification];
}

- (void)grabModelSaveNotification:(NSNotification*)saveNotification {
	[[self tlMainThreadProxy] mainThreadUseModelSaveNotification:saveNotification];
}

- (void)actualDoImport {
	// flatten list of imported files
	NSMutableArray* errors = [NSMutableArray array];
	NSArray* flatFiles = [self findAllFiles:[self filenames] inFolders:YES errors:errors];
	if (shouldCancel) {
		[self doCancelImport:nil];
		return;
	}
	
	// import each file
	[[[self modelContext] undoManager] disableUndoRegistration];
	NSMutableArray* photos = [NSMutableArray array];
	NSMutableArray* tracks = [NSMutableArray array];
	[self importAllFiles:flatFiles photos:photos tracks:tracks errors:errors];
	if (shouldCancel) {
		[self doCancelImport:photos];
		return;
	}
	
	// locate/timestamp photos
	[[self modelContext] processPendingChanges];
	[self processPhotos:photos];
	if (shouldCancel) {
		[self doCancelImport:photos];
		return;
	}
	
	// save data to disk
	NSError* saveError = nil;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(grabModelSaveNotification:)
												 name:NSManagedObjectContextDidSaveNotification
											   object:[self modelContext]];
	(void)[[self modelContext] save:&saveError];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSManagedObjectContextDidSaveNotification
												  object:[self modelContext]];
	if (saveError) {
		[errors addObject:saveError];
	}
	[[[self modelContext] undoManager] enableUndoRegistration];
	[self finishImport:errors photos:photos tracks:tracks];
}

- (void)doImport {
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
	@try {
		[self actualDoImport];
	}
	@catch (NSException* e) {
		NSLog(@"Caught exception on import: %@\n", [e description]);
	}
	@catch (id e) {
		NSLog(@"Caught uknown error on import: %@\n", [e description]);
	}
	
	[pool drain];
}

@end
