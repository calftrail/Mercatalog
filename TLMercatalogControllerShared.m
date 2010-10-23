//
//  TLMercatalogControllerShared.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLMercatalogControllerShared.h"

#import "TLPhoto.h"
#import "TLOffsetTimestamp.h"

NSString* const TLMercatalogSelectionDidChangeNotification = @"TLMercatalog_SelectionDidChangeNotification";
static NSString* const TLMercatalogInternalPhotosPboardType = @"com.calftrail.mercatalog.photo.pboard";

NSArray* TLMercatalogAcceptedDropTypes() {
	return [NSArray arrayWithObjects:TLMercatalogInternalPhotosPboardType, NSFilenamesPboardType, nil];
}

BOOL TLMercatalogWritePhotosToPasteboard(NSArray* photos,
										 NSPasteboard* pboard, id owner)
{
	NSArray* supportedDragTypes = [NSArray arrayWithObjects:
								   TLMercatalogInternalPhotosPboardType, NSFilesPromisePboardType, nil];
	(void)[pboard declareTypes:supportedDragTypes owner:owner];
	
	NSMutableArray* photoPropertyList = [NSMutableArray arrayWithCapacity:[photos count]];
	for (TLPhoto* photo in photos) {
		NSData* photoPointerAsData = [NSData dataWithBytes:&photo length:sizeof(TLPhoto*)];
		[photoPropertyList addObject:photoPointerAsData];
	}
	BOOL internalsWroteSuccesfully = [pboard setPropertyList:photoPropertyList
													 forType:TLMercatalogInternalPhotosPboardType];
	
	NSArray* promisedFileTypes = [NSArray arrayWithObject:(id)kUTTypeJPEG];
	BOOL filesWroteSuccessfully = [pboard setPropertyList:promisedFileTypes
												  forType:NSFilesPromisePboardType];
	
	return (internalsWroteSuccesfully && filesWroteSuccessfully);
}

NSArray* TLMercatalogPhotosFromPasteboard(NSPasteboard* pboard) {
	NSArray* internalDropTypes = [NSArray arrayWithObject:TLMercatalogInternalPhotosPboardType];
	NSString* internalType = [pboard availableTypeFromArray:internalDropTypes];
	if (!internalType) return nil;
	
	NSArray* photosAsData = [pboard propertyListForType:internalType];
	NSMutableArray* photos = [NSMutableArray arrayWithCapacity:[photosAsData count]];
	for (NSData* photoPointerAsData in photosAsData) {
		TLPhoto* photo = *(TLPhoto**)[photoPointerAsData bytes];
		[photos addObject:photo];
	}
	return photos;
}

NSArray* TLMercatalogFilesFromPasteboard(NSPasteboard* pboard) {
	NSArray* externalDropTypes = [NSArray arrayWithObject:NSFilenamesPboardType];
	NSString* externalType = [pboard availableTypeFromArray:externalDropTypes];
	if (!externalType) return nil;
	
	NSArray* filenames = [pboard propertyListForType:externalType];
	return filenames;	
}

BOOL TLMercatalogPhotosAreLocked(NSArray* photos) {
	BOOL photosLocked = NO;
	for (TLPhoto* photo in photos) {
		if ([photo isLocked]) {
			photosLocked = YES;
			break;
		}
	}
	return photosLocked;
}

NSMapTable* TLMercatalogTimestampPhotos(NSArray* photos, TLTimestamp* firstTimestamp) {
	// the first photo in the array is the one under the mouse when drag was initiated
	TLPhoto* primaryDraggedPhoto = [photos objectAtIndex:0];
	NSDate* primaryPhotoDate = [[primaryDraggedPhoto timestamp] time];
	
	// find offset such that: primaryPhotoTime + offset = mouseTime
	NSTimeInterval offset = [[firstTimestamp time] timeIntervalSinceDate:primaryPhotoDate];
	
	NSMapTable* photoTimestamps = [NSMapTable mapTableWithStrongToStrongObjects];
	for (TLPhoto* photo in photos) {
		NSDate* photoDate = [[photo timestamp] time];
		NSDate* adjustedTime = [photoDate addTimeInterval:offset];
		NSTimeInterval photoOffset = [adjustedTime timeIntervalSinceDate:[photo originalDate]];
		TLOffsetTimestamp* timestamp = [TLOffsetTimestamp timestampWithTime:adjustedTime
																   accuracy:[firstTimestamp accuracy]
																	 offset:photoOffset];
		[photoTimestamps setObject:timestamp forKey:photo];
	}
	return photoTimestamps;
}
