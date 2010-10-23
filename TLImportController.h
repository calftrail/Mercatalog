//
//  TLImportController.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/16/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLMercatalogLibrary;


@interface TLImportController : NSObject {
	IBOutlet NSWindow* importSheet;
	IBOutlet NSTextField* importProgressText;
	IBOutlet NSProgressIndicator* importProgressBar;
	IBOutlet NSTextField* importCurrentText;
@private
	id delegate;
	TLMercatalogLibrary* library;
	NSArray* filenames;
	
	BOOL shouldCancel;
	BOOL copyOriginals;
}

@property (nonatomic, readonly) id delegate;
@property (nonatomic, readonly) TLMercatalogLibrary* library;
@property (nonatomic, readonly) NSArray* filenames;

- (id)initWithFilenames:(NSArray*)theFilenames
				library:(TLMercatalogLibrary*)theLibrary
			   delegate:(id)theDelegate;

- (IBAction)startImport:(id)sender;
- (IBAction)cancelImport:(id)sender;

@end

@interface NSObject (TLImportControllerDelegate)

- (void)importControllerDidBegin:(TLImportController*)importController;

- (void)importControllerDidImport:(TLImportController*)importController
						   photos:(NSArray*)photos
						   tracks:(NSArray*)tracks;

- (void)importControllerDidCancel:(TLImportController*)importController;

@end
