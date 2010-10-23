/*
 *  TLMercatalogControllerShared.h
 *  Mercatalog
 *
 *  Created by Nathan Vander Wilt on 12/17/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

@class TLTimestamp;

extern const NSDragOperation TLDragOperationInternal;
extern NSString* const TLMercatalogSelectionDidChangeNotification;

NSArray* TLMercatalogAcceptedDropTypes(void);

BOOL TLMercatalogWritePhotosToPasteboard(NSArray* photos,
										 NSPasteboard* pboard, id owner);

NSArray* TLMercatalogPhotosFromPasteboard(NSPasteboard* pboard);
NSArray* TLMercatalogFilesFromPasteboard(NSPasteboard* pboard);

BOOL TLMercatalogPhotosAreLocked(NSArray* photos);
NSMapTable* TLMercatalogTimestampPhotos(NSArray* photos,
										TLTimestamp* firstTimestamp);
