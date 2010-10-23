//
//  TLMercatalogProjectController.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 9/8/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLMercatalogProjectController.h"

#import "TLCocoaToolbag.h"

#import "TLMercatalogLibrary.h"
#import "TLLibraryHost.h"
#import "TLImportController.h"
#import "TLExportController.h"
#import "TLPhoto.h"
#import "TLTrack.h"

#import "TLLocator.h"
#import "TLMapController.h"
#import "TLTimelineController.h"

#import "TLJimBos.h"


@interface TLMercatalogProjectController ()
- (void)performFileImportInBackground:(NSArray*)filenames;
@property (nonatomic, copy) NSSet* selectedPhotos;
- (void)updateTrackShowing;
- (void)updateTimelineShowing;
@end


@implementation TLMercatalogProjectController

#pragma mark Lifecycle

- (id)initWithProject:(NSURL*)projectURL error:(NSError**)err {
	self = [super init];
	if (self) {
		NSError* internalError = nil;
		library = [[TLMercatalogLibrary alloc] initWithURL:projectURL
													options:0
													  error:&internalError];
		if (internalError) {
			if (err) *err = internalError;
			[self dealloc];
			return nil;
		}
	}
	return self;
}

- (void)awakeFromNib {
	[library setWindowForSheet:projectWindow];
	
	NSManagedObjectContext* modelContext = [library modelContext];
	mapController = [TLMapController new];
	[mapController setModelContext:modelContext];
	[mapController setDelegate:self];
	timelineController = [TLTimelineController new];
	[timelineController setModelContext:modelContext];
	[timelineController setDelegate:self];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(modelChanged:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:modelContext];
	
	[self updateTrackShowing];
	[self updateTimelineShowing];
}

- (void)dealloc {
	if (library) {
		NSLog(@"Project controller not properly closed!");
	}
	[projectWindow release];
	[mapController release];
	[timelineController release];
	[library release];
	[super dealloc];
}


#pragma mark Window/project management

- (void)loadWindow {
	BOOL windowLoaded = [NSBundle loadNibNamed:@"ProjectWindow" owner:self];
	if (!windowLoaded) {
		NSLog(@"Could not load project window");
	}
}

- (NSWindow*)window {
	if (!projectWindow) {
		[self loadWindow];
	}
	return projectWindow;
}

- (void)closeProject {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[library close];
	[library release];
	library = nil;
}

- (void)setTimelineDisplayed:(BOOL)newTimelineDisplayed {
	NSView* hostView = [[self window] contentView];
	NSArray* subViews = [hostView subviews];
	for (NSView* subview in subViews) {
		[subview removeFromSuperview];
	}
	
	if (newTimelineDisplayed) {
		NSSplitView* splitView = [[NSSplitView alloc] initWithFrame:[hostView bounds]];
		[splitView autorelease];
		[splitView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
		[splitView setVertical:NO];
		[splitView setDividerStyle:NSSplitViewDividerStyleThin];
		[splitView setIsPaneSplitter:YES];
		[hostView addSubview:splitView];
		
		[splitView addSubview:[mapController view]];
		[splitView addSubview:[timelineController view]];
		[splitView adjustSubviews];
		CGFloat splitPosition = 0.8f * NSHeight([hostView bounds]);
		[splitView setPosition:splitPosition ofDividerAtIndex:0];
	}
	else {
		NSView* mapView = [mapController view];
		[mapView setFrame:[hostView bounds]];
		[mapView setAutoresizingMask:(NSViewHeightSizable | NSViewWidthSizable)];
		[hostView addSubview:mapView];
	}
}


#pragma mark Controller glue

static NSCellStateValue TLMercatalogPhotosLockedState(NSSet* photos) {
	BOOL firstTime = YES;
	NSCellStateValue lockedState = NSMixedState;
	for (TLPhoto* photo in photos) {
		BOOL photoLocked = [photo isLocked];
		if (firstTime) {
			lockedState = photoLocked ? NSOnState : NSOffState;
			firstTime = NO;
		}
		else if (photoLocked && lockedState == NSOffState) {
			lockedState = NSMixedState;
			break;
		}
		else if (!photoLocked && lockedState == NSOnState) {
			lockedState = NSMixedState;
			break;
		}
	}
	return lockedState;
}

- (void)updateLockInterfaceForPhotos:(NSSet*)selectedPhotos {
	if ([selectedPhotos count]) {
		[lockButton setEnabled:YES];
		NSCellStateValue photosLockState = TLMercatalogPhotosLockedState(selectedPhotos);
		[(NSButton*)[lockButton view] setState:photosLockState];
		if (photosLockState == NSOffState || photosLockState == NSMixedState) {
			[lockButton setAction:@selector(lockPhotos:)];
			[lockButton setLabel:@"Lock"];
		}
		else {
			[lockButton setAction:@selector(unlockPhotos:)];
			[lockButton setLabel:@"Unlock"];
		}
	}
	else {
		[(NSButton*)[lockButton view] setState:NSOffState];
		[lockButton setLabel:@"Lock"];
		[lockButton setEnabled:NO];
	}
}

- (void)updateTimelineShowing {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
	BOOL showTimeline = [host alwaysShowTimeline];
	
	NSMenu* viewMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
	NSMenuItem* timelineMenu = [viewMenu itemAtIndex:0];
	if (!timelineMenu) { printf("timelineMenu not found\n"); }
	[timelineMenu setState:(showTimeline ? NSOnState : NSOffState)];
	
	NSSet* visiblePhotos = [NSSet setWithArray:[host visiblePhotos]];
	NSCellStateValue photoLockState = TLMercatalogPhotosLockedState(visiblePhotos);
	if (![visiblePhotos count]) {
		// treat as locked if no photos
		photoLockState = NSOnState;
	}
	if (photoLockState == NSOnState && !showTimeline) {
		[self setTimelineDisplayed:NO];
	}
	else {
		[self setTimelineDisplayed:YES];
	}
}

- (void)updateTrackShowing {
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
	BOOL showTracks = [host alwaysShowTracks];
	
	NSMenu* viewMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
	NSMenuItem* trackMenu = [viewMenu itemAtIndex:1];
	if (!trackMenu) { printf("trackMenu not found\n"); }
	[trackMenu setState:(showTracks ? NSOnState : NSOffState)];
	
	NSSet* visiblePhotos = [NSSet setWithArray:[host visiblePhotos]];
	NSCellStateValue photoLockState = TLMercatalogPhotosLockedState(visiblePhotos);
	if (photoLockState == NSOnState && !showTracks) {
		[mapController setTracksVisible:NO];
		[timelineController setTracksVisible:NO];
	}
	else {
		[mapController setTracksVisible:YES];
		[timelineController setTracksVisible:YES];
	}
}

- (void)updateSelection {
	NSMutableSet* newSelection = [NSMutableSet setWithSet:[self selectedPhotos]];
	for (TLPhoto* photo in [self selectedPhotos]) {
		if ([photo isDeleted]) {
			[newSelection removeObject:photo];
		}
	}
	[self setSelectedPhotos:newSelection];
}

- (void)delayedModelChanged {
	[self updateLockInterfaceForPhotos:[self selectedPhotos]];
	[self updateTrackShowing];
	[self updateTimelineShowing];
	[self updateSelection];	
}

- (void)modelChanged:(NSNotification*)aNotification {
	(void)aNotification;
	// delay updates to ensure host object gets its notification first
	[self performSelector:@selector(delayedModelChanged) withObject:nil afterDelay:0.0];
}

- (void)setSelectedPhotos:(NSSet*)newSelectedPhotos {
	[mapController setSelectedPhotos:newSelectedPhotos];
	[timelineController setSelectedPhotos:newSelectedPhotos];
	[self updateLockInterfaceForPhotos:newSelectedPhotos];
}

- (NSSet*)selectedPhotos {
	return [mapController selectedPhotos];
}

- (NSUndoManager*)windowWillReturnUndoManager:(NSWindow *)window {
	(void)window;
	return [library undoManager];
}

- (void)mapControllerWantsPreview:(TLMapController*)aMapController
					forTimestamps:(NSArray*)previewTimestamps
{
	(void)aMapController;
	[timelineController setPreviewTimestamps:previewTimestamps];
}

- (void)timelineControllerWantsPreview:(TLTimelineController*)aTimelineController
						  forLocations:(NSArray*)previewLocations
{
	(void)aTimelineController;
	[mapController setPreviewLocations:previewLocations];
}

- (void)timelineControllerWantsDisplay:(TLTimelineController*)aTimelineController
							 forPhotos:(NSSet*)displayedPhotos
{
	(void)aTimelineController;
	[mapController setDisplayedPhotos:displayedPhotos];
}

- (void)timelineControllerMouse:(TLTimelineController*)aTimelineController
				   isAtLocation:(TLLocation*)mouseLocation
{
	(void)aTimelineController;
	[mapController setMouseLocation:mouseLocation];
}

- (void)controllerSelectionDidChange:(NSNotification*)aNotification {
	id controller = [aNotification object];
	if ([controller respondsToSelector:@selector(selectedPhotos)]) {
		NSSet* newSelection = [controller selectedPhotos];
		[self setSelectedPhotos:newSelection];
	}
}

- (NSArray*)controllerNeedsFilenames:(id)aMercController
					forDroppedPhotos:(NSArray*)photosDropped
					   atDestination:(NSURL*)dropDestination
{
	(void)aMercController;
	if ([[TLJimBos sharedRegistrar] isExpired]) {
		[[TLJimBos sharedRegistrar] performSelector:@selector(showDemoInformation:)
										 withObject:self
										 afterDelay:0.0];
		return [NSArray array];
	}	
	
	TLExportController* exporter = [[TLExportController new] autorelease];
	[exporter setPhotos:[NSSet setWithArray:photosDropped]];
	return [exporter exportToFolder:dropDestination error:NULL];
}

- (void)controllerNeedsImport:(id)aMercController
					 forFiles:(NSArray*)filenames
{
	(void)aMercController;
	[self performFileImportInBackground:filenames];
}


#pragma mark Action handlers

- (IBAction)delete:(id)sender {
	(void)sender;
	for (TLPhoto* photo in [self selectedPhotos]) {
		[[library modelContext] deleteObject:photo];
	}
}

- (IBAction)zoomCompletelyOut:(id)sender {
	[mapController zoomCompletelyOut:sender];
}

- (IBAction)toggleTimelineAlwaysShown:(id)sender {
	(void)sender;
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
	BOOL newShowTimeline = ![host alwaysShowTimeline];
	[host setAlwaysShowTimeline:newShowTimeline];
}

- (IBAction)toggleTracksAlwaysShown:(id)sender {
	(void)sender;
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
	BOOL newShowTracks = ![host alwaysShowTracks];
	[host setAlwaysShowTracks:newShowTracks];
}

- (IBAction)lockPhotos:(id)sender {
	(void)sender;
	for (TLPhoto* photo in [self selectedPhotos]) {
		[photo setLocked:YES];
	}
	[[library modelContext] processPendingChanges];
}

- (IBAction)unlockPhotos:(id)sender {
	(void)sender;
	for (TLPhoto* photo in [self selectedPhotos]) {
		[photo setLocked:NO];
	}
	[[library modelContext] processPendingChanges];
}

- (IBAction)selectAll:(id)sender {
	(void)sender;
	TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
	NSSet* allPhotos = [NSSet setWithArray:[host visiblePhotos]];
	[self setSelectedPhotos:allPhotos];
}


#pragma mark Export

- (NSSet*)currentPhotosForExport {
	NSSet* exportPhotos = [self selectedPhotos];
	if (![exportPhotos count]) {
		TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
		NSArray* allPhotos = [host visiblePhotos];
		exportPhotos = [NSSet setWithArray:allPhotos];
	}
	return exportPhotos;
}

- (IBAction)exportKMZ:(id)sender {
	(void)sender;
	
	if ([[TLJimBos sharedRegistrar] isExpired]) {
		[[TLJimBos sharedRegistrar] showDemoInformation:self];
		return;
	}
	
	NSSavePanel* savePanel = [NSSavePanel savePanel];
	[savePanel setRequiredFileType:TLExportKMZType];
	[savePanel setTitle:NSLocalizedString(@"Export KMZ", @"Save panel title for exporting KMZ")];
	[savePanel setPrompt:NSLocalizedString(@"Export", @"Save panel button label to perform export")];
	//[savePanel setMessage:@"Here is the news"];
	NSInteger result = [savePanel runModal];
	if (result != NSOKButton) return;
	
	NSURL* kmzURL = [NSURL fileURLWithPath:[savePanel filename] isDirectory:NO];
	NSSet* kmlPhotos = [self currentPhotosForExport];
	
	TLExportController* exporter = [[TLExportController new] autorelease];
	[exporter setPhotos:kmlPhotos];
	NSError* error = nil;
	(void)[exporter exportToKMZ:kmzURL error:&error];
	if (error) {
		[NSApp presentError:error];
	}
}

- (IBAction)exportFiles:(id)sender {
	(void)sender;
	
	if ([[TLJimBos sharedRegistrar] isExpired]) {
		[[TLJimBos sharedRegistrar] showDemoInformation:self];
		return;
	}	
	
	NSSet* exportPhotos = [self currentPhotosForExport];
	NSError* error = nil;
	if ([exportPhotos count] > 1) {
		NSOpenPanel* choosePanel = [NSOpenPanel openPanel];
		[choosePanel setTitle:NSLocalizedString(@"Choose folder", @"Choose panel title for exporting photos")];
		[choosePanel setPrompt:NSLocalizedString(@"Export", @"Choose panel button label to perform export")];
		[choosePanel setMessage:NSLocalizedString(@"Choose folder where photos should be exported.",
												  @"Choose panel instructions for exporting photos")];
		[choosePanel setCanChooseFiles:NO];
		[choosePanel setCanChooseDirectories:YES];
		[choosePanel setCanCreateDirectories:YES];
		NSInteger result = [choosePanel runModal];
		if (result != NSOKButton) return;
		
		NSString* exportPath = [choosePanel filename];
		
		TLExportController* exporter = [[TLExportController new] autorelease];
		[exporter setPhotos:exportPhotos];
		(void)[exporter exportToFolder:[NSURL fileURLWithPath:exportPath isDirectory:YES] error:NULL];
	}
	else if ([exportPhotos count]) {
		TLPhoto* exportPhoto = [exportPhotos anyObject];
		NSSavePanel* savePanel = [NSSavePanel savePanel];
		[savePanel setRequiredFileType:(id)kUTTypeJPEG];
		[savePanel setTitle:NSLocalizedString(@"Export photo", @"Save panel title for exporting photo")];
		[savePanel setPrompt:NSLocalizedString(@"Export", @"Save panel button label to perform export")];
		NSString* name = [[[exportPhoto path] lastPathComponent] stringByDeletingPathExtension];
		NSInteger result = [savePanel runModalForDirectory:nil file:name];
		if (result != NSOKButton) return;
		
		
		[exportPhoto saveToPath:[savePanel filename]
						   size:0
				   withMetadata:TLPhotoMetadataFull
						  error:&error];
	}
	
	if (error) {
		[NSApp presentError:error];
	}
}


#pragma mark File import

+ (NSArray*)actuallyAcceptedTypes {
	static NSArray* acceptedTypes = nil;
	if (!acceptedTypes) {
		NSArray* imageTypes = [TLPhoto validTypes];
		NSMutableArray* importableTypes = [NSMutableArray arrayWithArray:imageTypes];
		[importableTypes addObject:@"com.topografix.gpx"];
		[importableTypes addObject:(id)kUTTypeFolder];
		acceptedTypes = [importableTypes copy];
	}
	return acceptedTypes;
}

// NOTE: this is to work around rdar://problem/6410673
#define MEDIA_ALIAS_WORKAROUND
#ifdef MEDIA_ALIAS_WORKAROUND
- (BOOL)panel:(id)sender shouldShowFilename:(NSString*)filename {
	(void)sender;
	
	NSURL* fileURL = [NSURL fileURLWithPath:filename];
	NSString* uti = TLFileGetUTI(fileURL);
	if (UTTypeConformsTo((CFStringRef)uti, kUTTypeAliasFile)) {
		NSURL* resolvedURL = TLFileResolveFinderAlias(fileURL);
		if (!resolvedURL) return NO;
		uti = TLFileGetUTI(resolvedURL);
	}
	if (!uti) return NO;
	NSArray* acceptedTypes = [[self class] actuallyAcceptedTypes];
	return TLFileUTIConformsToAny(uti, acceptedTypes);
}
#endif /* MEDIA_ALIAS_WORKAROUND */

- (IBAction)importFiles:(id)sender {
	(void)sender;
	NSOpenPanel* choosePanel = [NSOpenPanel openPanel];
	[choosePanel setTitle:NSLocalizedString(@"Import files", @"Choose panel title for importing files")];
	[choosePanel setPrompt:NSLocalizedString(@"Import", @"Choose panel button label to perform import")];
	[choosePanel setMessage:NSLocalizedString(@"Choose photos, GPX tracklogs or their containing folders to import.",
											  @"Choose panel instructions for exporting photos")];
	[choosePanel setCanChooseFiles:YES];
	[choosePanel setCanChooseDirectories:YES];
	[choosePanel setAllowsMultipleSelection:YES];
	
	NSArray* importableTypes = [[self class] actuallyAcceptedTypes];
#ifdef MEDIA_ALIAS_WORKAROUND
	[choosePanel setDelegate:self];
	importableTypes = [NSMutableArray array];
	// see rdar://problem/6410690 for why not using kUTTypeImage to trigger media browser
	[(NSMutableArray*)importableTypes addObject:(id)kUTTypeJPEG];
	[(NSMutableArray*)importableTypes addObject:(id)kUTTypeData];
#endif /* MEDIA_ALIAS_WORKAROUND */
	NSInteger result = [choosePanel runModalForTypes:importableTypes];
	if (result != NSOKButton) return;
	
	NSArray* filenames = [choosePanel filenames];
	if (![filenames count]) return;
	[self performFileImportInBackground:filenames];
}

- (void)delayedPerformFileImportInBackground:(NSArray*)filenames {
	TLImportController* importer = [[TLImportController alloc] initWithFilenames:filenames
																		 library:library
																		delegate:self];
	[importer autorelease];
	[importer startImport:nil];
}

- (void)performFileImportInBackground:(NSArray*)filenames {
	[self performSelector:@selector(delayedPerformFileImportInBackground:)
			   withObject:filenames
			   afterDelay:1.0];
}

- (void)undoImport:(NSDictionary*)importInfo {
	NSArray* photos = [importInfo objectForKey:@"photos"];
	NSArray* tracks = [importInfo objectForKey:@"tracks"];
	for (TLPhoto* photo in photos) {
		[[library modelContext] deleteObject:photo];
	}
	for (TLTrack* track in tracks) {
		[[library modelContext] deleteObject:track];
	}
}

- (void)importControllerDidImport:(TLImportController*)importController
						   photos:(NSArray*)photos
						   tracks:(NSArray*)tracks
{
	(void)importController;
	
	NSDictionary* undoInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  photos, @"photos", tracks, @"tracks", nil];
	[[[library modelContext] undoManager] registerUndoWithTarget:self
														selector:@selector(undoImport:)
														  object:undoInfo];
	
	if ([tracks count]) {
		TLLibraryHost* host = [TLLibraryHost libraryHostForContext:[library modelContext]];
		TLLocator* locator = [[TLLocator new] autorelease];
		[locator setModelContext:[library modelContext]];
		
		// relocate any unlocked photos from previous imports
		NSSet* photosJustImported = [NSSet setWithArray:photos];
		for (TLPhoto* photo in [host visiblePhotos]) {
			if (![photosJustImported containsObject:photo] && ![photo isLocked]) {
				TLLocation* adjustedLocation = [locator locationAtTimestamp:[photo timestamp]];
				[photo setLocation:adjustedLocation];
			}
		}
	}
	
	if ([tracks count] && ![photos count]) {
		// TODO: show tracks regardless of lock state?
	}
	
	if ([photos count]) {
		[self setSelectedPhotos:[NSSet setWithArray:photos]];
	}
}

@end
