//
//  TLPhoto.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 4/4/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLModelPhoto.h"

@class TLOffsetTimestamp;
@class TLLocation;
@class TLTimestamp;

static const NSUInteger TLPhotoSizeOriginal = 0;

enum {
	TLPhotoMetadataNone = 0,
	TLPhotoMetadataBasic = 1,
	TLPhotoMetadataFull = 3
};
typedef NSUInteger TLPhotoMetadataAmount;


@interface TLPhoto : TLModelPhoto {}

+ (void)setExportSoftwareName:(NSString*)newSoftwareName;
+ (NSString*)exportSoftwareName;

+ (NSArray*)validTypes;

// NOTE: this must be successfully called before other values are valid
- (BOOL)setWithImageAtPath:(NSError**)err;

- (BOOL)cacheThumbnails:(NSError**)err;
- (void)uncacheThumbnails;

@property (nonatomic, copy) TLLocation* location;
@property (nonatomic, assign, getter=isLocked) BOOL locked;
@property (nonatomic, copy) TLTimestamp* timestamp;
@property (nonatomic, readonly) NSDate* originalDate;	// cameraDate falling back to fileDate
@property (nonatomic, readonly) TLOffsetTimestamp* offsetTimestamp;

@property (nonatomic, readonly) int64_t uniqueID;

- (CGImageSourceRef)originalImageSource;
- (CGImageSourceRef)imageSourceForSize:(CGFloat)approximateSize;
- (CGImageRef)createThumbnailForSize:(CGFloat)approximateSize;

- (BOOL)saveToPath:(NSString*)path
			 size:(NSUInteger)exportSize
	 withMetadata:(TLPhotoMetadataAmount)metadataAmount
			error:(NSError**)err;

@end
