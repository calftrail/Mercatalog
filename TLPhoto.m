//
//  TLPhoto.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 4/4/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLPhoto.h"

#import "TLOffsetTimestamp.h"
#import "TLLocation.h"

#import "TLLibraryHost.h"

#import "TLCocoaToolbag.h"

static NSDictionary* TLPhotoThumbnailSizes = nil;
static NSString* TLPhotoExportSoftwareName = nil;
static NSArray* TLPhotoValidTypes = nil;

@interface TLPhoto ()
- (NSURL*)originalURL;
- (CFDictionaryRef)originalImageProperties;
- (NSDate*)originalFileDate;
- (NSDate*)originalPhotoDate;
- (TLLocation*)originalPhotoLocation;

- (BOOL)cacheThumbnails:(NSError**)err;
- (void)uncacheThumbnails;
@end


static TLTimestamp* TLTimestampFromPhotoExif(CFDictionaryRef exifProperties);
static void TLTimestampAddToPhotoExif(CFMutableDictionaryRef exifProperties, TLTimestamp* timestamp, TLLocation* location);
static TLLocation* TLLocationFromPhotoGPS(CFDictionaryRef gpsMetadata);
static void TLLocationAddToPhotoGPS(CFMutableDictionaryRef gpsMetadata, TLLocation* location);


@implementation TLPhoto

#pragma mark Class defaults

+ (void)setExportSoftwareName:(NSString*)newSoftwareName {
	[TLPhotoExportSoftwareName autorelease];
	TLPhotoExportSoftwareName = [newSoftwareName copy];
}

+ (NSString*)exportSoftwareName {
	return TLPhotoExportSoftwareName;
}

+ (NSDictionary*)thumbnailSizes {
	return TLPhotoThumbnailSizes;
}

+ (NSArray*)validTypes {
	return TLPhotoValidTypes;
}


#pragma mark Lifecycle

+ (void)initialize {
	if (self != [TLPhoto class]) return;
	
	TLPhotoThumbnailSizes = [[NSDictionary alloc] initWithObjectsAndKeys:
							 tlnum(32), @"Tiny",
							 tlnum(128), @"Small",
							 tlnum(512), @"Medium",
							 nil];
	
	NSMutableSet* imageTypes = [NSMutableSet setWithArray:[(NSArray*)CGImageSourceCopyTypeIdentifiers() autorelease]];
	[imageTypes removeObject:(id)kUTTypeAppleICNS];
	[imageTypes removeObject:(id)kUTTypeICO];
	[imageTypes removeObject:(id)kUTTypePDF];
	[imageTypes removeObject:(id)kUTTypePICT];
	[imageTypes removeObject:(id)kUTTypeQuickTimeImage];
	[imageTypes removeObject:@"com.sgi.sgi-image"];
	[imageTypes removeObject:@"com.adobe.illustrator.ai-image"];
	[imageTypes removeObject:@"com.microsoft.cur"];
	[imageTypes removeObject:@"com.apple.macpaint-image"];
	[imageTypes removeObject:@"public.radiance"];
	TLPhotoValidTypes = [[imageTypes allObjects] retain];
	//printf("%s\n", [[TLPhotoValidTypes description] UTF8String]);
}


#pragma mark Host accessors

- (TLLibraryHost*)host {
	return [TLLibraryHost libraryHostForContext:[self managedObjectContext]];
}

- (NSURL*)copiedOriginalURL {
	NSURL* potentialCopy = [[self host] photoOriginalCopyLocation:[self uniqueID]];
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	BOOL copyExists = [fileManager fileExistsAtPath:[potentialCopy path]];
	return copyExists ? potentialCopy : nil;
}

- (NSURL*)originalURL {
	NSURL* originalURL = [self copiedOriginalURL];
	if (!originalURL) {
		originalURL = [NSURL fileURLWithPath:[self path] isDirectory:NO];
	}
	return originalURL;
}

- (NSURL*)thumbnailURL:(NSString*)sizeName {
	return [[self host] photoThumbnailLocation:[self uniqueID] forSize:sizeName];
}


#pragma mark Accessors

- (NSDate*)originalDate {
	return ([self cameraDate] ? [self cameraDate] : [self fileDate]);
}

- (TLOffsetTimestamp*)offsetTimestamp {
	TLTimestamp* unoffsetTimestamp = [self timestamp];
	NSTimeInterval offset = [[unoffsetTimestamp time] timeIntervalSinceDate:[self originalDate]];
	return [TLOffsetTimestamp timestampWithTime:[unoffsetTimestamp time]
									   accuracy:[unoffsetTimestamp accuracy]
										 offset:offset];
}


#pragma mark Core Data attribute wrappers

- (int64_t)uniqueID {
	return [[self cacheID] longLongValue];
}

- (void)setUniqueID:(int64_t)newUniqueId {
	[self setCacheID:[NSNumber numberWithLongLong:newUniqueId]];
}

- (void)setLocation:(TLLocation*)newLocation {
	TLLocation* locationCopy = [newLocation copy];
	[self setModelLocation:locationCopy];
	[locationCopy release];
}

- (TLLocation*)location {
	return [self modelLocation];
}

- (void)setLocked:(BOOL)newLocked {
	[self setModelLocked:[NSNumber numberWithBool:newLocked]];
}

- (BOOL)isLocked {
	return [[self modelLocked] boolValue];
}

- (void)setTimestamp:(TLTimestamp*)newTimestamp {
	// NOTE: this creates an explicit TLTimestamp copy to avoid storing subclass
	TLTimestamp* timestampCopy = [[TLTimestamp alloc] initWithTime:[newTimestamp time]
														  accuracy:[newTimestamp accuracy]];
	[self setModelTimestamp:newTimestamp];
	[timestampCopy release];
}

- (TLTimestamp*)timestamp {
	return [self modelTimestamp];
}


#pragma mark Photo information

- (NSDate*)originalFileDate {
	NSString* photoPath = [[self originalURL] path];
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	NSDictionary* fileAttributes = [fileManager attributesOfItemAtPath:photoPath error:NULL];
	NSDate* dateModified = [fileAttributes objectForKey:NSFileModificationDate];
	NSDate* dateCreated = [fileAttributes objectForKey:NSFileCreationDate];
	if (!dateModified) return dateCreated;
	else if (!dateCreated) return dateModified;
	else return ([dateCreated timeIntervalSinceReferenceDate] < [dateModified timeIntervalSinceReferenceDate] ? dateCreated : dateModified);
}

static CFDictionaryRef const TLPhotoNoImageOptions = NULL;

- (CFDictionaryRef)originalImageProperties {
	CGImageSourceRef imageSource = [self originalImageSource];
	if (!imageSource) return NULL;
	CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, TLPhotoNoImageOptions);
	TLCFAutorelease(imageProperties);
	return imageProperties;
}

- (NSDate*)originalPhotoDate {
	CFDictionaryRef imageProperties = [self originalImageProperties];
	if (!imageProperties) return nil;
	CFDictionaryRef exifProperties = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyExifDictionary);
	TLTimestamp* exifTimestamp = TLTimestampFromPhotoExif(exifProperties);
	return [exifTimestamp time];
}

- (TLLocation*)originalPhotoLocation {
	CFDictionaryRef imageProperties = [self originalImageProperties];
	if (!imageProperties) return nil;
	CFDictionaryRef gpsData = (CFDictionaryRef)CFDictionaryGetValue(imageProperties, kCGImagePropertyGPSDictionary);
	return TLLocationFromPhotoGPS(gpsData);
}


#pragma mark Image and thumbnail methods

- (CFDictionaryRef)thumbnailOptionsForSize:(CGFloat)approximateSize {
	NSDictionary* thumbnailOptions = [NSDictionary dictionaryWithObjectsAndKeys:
									  (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,									
									  [NSNumber numberWithDouble:approximateSize], (id)kCGImageSourceThumbnailMaxPixelSize,
									  (id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
									  nil];
	return (CFDictionaryRef)thumbnailOptions;
}

- (CFStringRef)thumbnailType {
	return kUTTypeJPEG;
}

- (BOOL)cacheThumbnails:(NSError**)err {
	// TODO: handle errors better (see CGImageSource status functions)
	CGImageSourceRef imageSource = [self originalImageSource];
	if (!imageSource) {
		if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
		return NO;
	}
	
	NSDictionary* thumbnailSizes = [[self class] thumbnailSizes];
	for (NSString* sizeName in thumbnailSizes) {
		CGFloat size = (CGFloat)[[thumbnailSizes objectForKey:sizeName] doubleValue];
		CFDictionaryRef thumbnailOptions = [self thumbnailOptionsForSize:size];
		CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions);
		TLCFAutorelease(thumbnail);
		if (!thumbnail) continue;
		
		CFURLRef path = (CFURLRef)[self thumbnailURL:sizeName];
		if (!path) continue;
		CGImageDestinationRef imageDest = CGImageDestinationCreateWithURL(path, [self thumbnailType], 1, NULL);
		TLCFAutorelease(imageDest);
		if (!imageDest) continue;
		CGImageDestinationAddImage(imageDest, thumbnail, NULL);
		(void)CGImageDestinationFinalize(imageDest);
	}
	return YES;
}

- (BOOL)setProperties:(NSError**)err {
	NSDate* fileDate = [self originalFileDate];
	[self setFileDate:fileDate];
	if (!fileDate) {
		if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];
		return NO;
	}
	[self setCameraDate:[self originalPhotoDate]];
	[self setLocation:[self originalPhotoLocation]];
	
	return YES;
}

- (BOOL)setWithImageAtPath:(NSError**)err {
	NSError* internalError = nil;
	(void)[self setProperties:&internalError];
	if (internalError) {
		if (err) *err = internalError;
		return NO;
	}
	
	// test if file can be opened as image
	CFURLRef imageURL = (CFURLRef)[NSURL fileURLWithPath:[self path] isDirectory:NO];
	CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imageURL, TLPhotoNoImageOptions);
	if (!imageSource) {
		if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
		return NO;
	}
	else {
		CFRelease(imageSource);
	}
	
	[self setUniqueID:[[self host] makePhotoID]];
	return YES;
}

- (void)uncacheThumbnails {
	NSFileManager* fileManager = [[NSFileManager new] autorelease];
	NSDictionary* thumbnailSizes = [[self class] thumbnailSizes];
	for (NSString* sizeName in thumbnailSizes) {
		NSURL* pathURL = [self thumbnailURL:sizeName];
		if (![pathURL isFileURL]) continue;
		NSString* path = [pathURL path];
		if (!path) continue;
		if (path && [pathURL isFileURL]) {
			(void)[fileManager removeItemAtPath:path error:NULL];
		}
	}
}

- (CGImageSourceRef)originalImageSource {
	CFURLRef imageURL = (CFURLRef)[self originalURL];
	if (!imageURL) return NULL;
	CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imageURL, TLPhotoNoImageOptions);
	TLCFAutorelease(imageSource);
	return imageSource;
}

- (NSString*)namedSizeForSize:(CGFloat)approximateSize {
	tl_uint_t targetSize = lround(approximateSize);
	NSString* smallestLargerSizeName = nil;
	tl_uint_t smallestLargerSize = 0;
	NSDictionary* thumbnailSizes = [[self class] thumbnailSizes];
	for (NSString* sizeName in thumbnailSizes) {
		NSNumber* sizeNumber = [thumbnailSizes objectForKey:sizeName];
		tl_uint_t size = [sizeNumber unsignedLongValue];
		if (size < targetSize) continue;
		if (!smallestLargerSizeName || size < smallestLargerSize) {
			smallestLargerSizeName = sizeName;
			smallestLargerSize = size;
		}
	}
	return smallestLargerSizeName;
}

- (CGImageSourceRef)imageSourceForSize:(CGFloat)approximateSize {
	CGImageSourceRef imageSource = NULL;
	NSString* sizeName = [self namedSizeForSize:approximateSize];
	if (sizeName) {
		CFURLRef thumbnailURL = (CFURLRef)[self thumbnailURL:sizeName];
		if (thumbnailURL) {
			imageSource = CGImageSourceCreateWithURL(thumbnailURL, TLPhotoNoImageOptions);
			TLCFAutorelease(imageSource);
		}
	}
	if (!imageSource) {
		// TODO: replace missing cache files?
		imageSource = [self originalImageSource];
	}
	return imageSource;
}

- (CGImageRef)createThumbnailForSize:(CGFloat)approximateSize {
	CGImageSourceRef imageSource = [self imageSourceForSize:approximateSize];
	if (!imageSource) return NULL;
	CFDictionaryRef thumbnailOptions = [self thumbnailOptionsForSize:approximateSize];
	return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions);
}


#pragma mark Photo export

- (BOOL)saveToPath:(NSString*)path
			  size:(NSUInteger)exportSize
	  withMetadata:(TLPhotoMetadataAmount)metadataAmount
			 error:(NSError**)err
{
	CFURLRef pathURL = (CFURLRef)[NSURL fileURLWithPath:path];
	const CFStringRef exportType = kUTTypeJPEG;
	CGImageDestinationRef destination = CGImageDestinationCreateWithURL(pathURL, exportType, 1, NULL);
	if (!destination) {
		if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];
		return NO;
	}
	
	if (exportSize) {
		CFDictionaryRef metadata = NULL;
		if (metadataAmount == TLPhotoMetadataBasic) {
			NSMutableDictionary* basicMetadata = [NSMutableDictionary dictionary];
			
			// add software name
			NSString* softwareName = [[self class] exportSoftwareName];
			if ([softwareName length]) {
				NSMutableDictionary* tiffMetadata = [NSMutableDictionary dictionary];
				[tiffMetadata setObject:softwareName forKey:(id)kCGImagePropertyTIFFSoftware];
				[basicMetadata setObject:tiffMetadata forKey:(id)kCGImagePropertyTIFFDictionary];
			}
			
			// add timestamp
			NSMutableDictionary* exifMetadata = [NSMutableDictionary dictionary];
			TLTimestampAddToPhotoExif((CFMutableDictionaryRef)exifMetadata, [self timestamp], [self location]);
			[basicMetadata setObject:exifMetadata forKey:(id)kCGImagePropertyExifDictionary];
			
			// set location
			NSMutableDictionary* gpsMetadata = [NSMutableDictionary dictionary];
			TLLocationAddToPhotoGPS((CFMutableDictionaryRef)gpsMetadata, [self location]);
			[basicMetadata setObject:gpsMetadata forKey:(id)kCGImagePropertyGPSDictionary];
			
			metadata = (CFDictionaryRef)basicMetadata;
		}
		else if (metadataAmount == TLPhotoMetadataFull) {
			CGImageSourceRef imageSource = [self originalImageSource];
			CFDictionaryRef immutableMetadata = NULL;
			if (imageSource) {
				immutableMetadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
				TLCFAutorelease(immutableMetadata);
			}
			CFMutableDictionaryRef originalMetadata = NULL;
			if (immutableMetadata) {
				originalMetadata = (CFMutableDictionaryRef)CFPropertyListCreateDeepCopy(kCFAllocatorDefault,
																						immutableMetadata,
																						kCFPropertyListMutableContainers);
				TLCFAutorelease(originalMetadata);
			}
			else {
				NSLog(@"Could not read metadata from original image");
				originalMetadata = (CFMutableDictionaryRef)[NSMutableDictionary dictionary];
			}
			
			// add software name
			NSString* softwareName = [[self class] exportSoftwareName];
			if ([softwareName length]) {
				CFMutableDictionaryRef tiffMetadata = (CFMutableDictionaryRef)CFDictionaryGetValue(originalMetadata,
																								   kCGImagePropertyTIFFSoftware);
				if (!tiffMetadata) {
					tiffMetadata = (CFMutableDictionaryRef)[NSMutableDictionary dictionary];
					CFDictionarySetValue(originalMetadata, kCGImagePropertyTIFFDictionary, tiffMetadata);
				}
				CFDictionarySetValue(tiffMetadata, kCGImagePropertyTIFFSoftware, softwareName);
			}
			
			// add timestamp
			CFMutableDictionaryRef exifMetadata = (CFMutableDictionaryRef)CFDictionaryGetValue(originalMetadata,
																							   kCGImagePropertyExifDictionary);
			if (!exifMetadata) {
				exifMetadata = (CFMutableDictionaryRef)[NSMutableDictionary dictionary];
				CFDictionarySetValue(originalMetadata, kCGImagePropertyExifDictionary, exifMetadata);
			}
			TLTimestampAddToPhotoExif(exifMetadata, [self timestamp], [self location]);
			
			// set location
			NSMutableDictionary* gpsMetadata = [NSMutableDictionary dictionary];
			TLLocationAddToPhotoGPS((CFMutableDictionaryRef)gpsMetadata, [self location]);
			CFDictionarySetValue(originalMetadata, kCGImagePropertyGPSDictionary, gpsMetadata);
			
			metadata = originalMetadata;
		}
		CGImageRef photoImage = [self createThumbnailForSize:(CGFloat)exportSize];
		if (!photoImage) {
			if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];
			return NO;
		}
		CGImageDestinationAddImage(destination, photoImage, metadata);
		CGImageRelease(photoImage);
	}
	else {
		CGImageSourceRef imageSource = [self originalImageSource];
		if (!imageSource) {
			if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];
			return NO;
		}
		NSDictionary* originalMetadata = (NSDictionary*)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
		[originalMetadata autorelease];
		
		CFDictionaryRef metadataAdjustments = NULL;
		if (metadataAmount == TLPhotoMetadataNone) {
			NSMutableDictionary* clearMetadata = [NSMutableDictionary dictionary];
			for (NSString* key in originalMetadata) {
				[clearMetadata setObject:[NSNull null] forKey:key];
			}
			metadataAdjustments = (CFDictionaryRef)clearMetadata;
		}
		else if (metadataAmount == TLPhotoMetadataBasic) {
			NSMutableDictionary* basicMetadata = [NSMutableDictionary dictionary];
			for (NSString* key in originalMetadata) {
				[basicMetadata setObject:[NSNull null] forKey:key];
			}
			
			// add software name
			NSString* softwareName = [[self class] exportSoftwareName];
			if ([softwareName length]) {
				NSMutableDictionary* tiffMetadata = [NSMutableDictionary dictionary];
				NSDictionary* originalTiff = [originalMetadata objectForKey:(id)kCGImagePropertyTIFFDictionary];
				for (NSString* key in originalTiff) {
					[tiffMetadata setObject:[NSNull null] forKey:key];
				}
				[tiffMetadata setObject:softwareName forKey:(id)kCGImagePropertyTIFFSoftware];
				[basicMetadata setObject:tiffMetadata forKey:(id)kCGImagePropertyTIFFDictionary];
			}
			
			// add timestamp
			NSMutableDictionary* exifMetadata = [NSMutableDictionary dictionary];
			NSDictionary* originalExif = [originalMetadata objectForKey:(id)kCGImagePropertyExifDictionary];
			for (NSString* key in originalExif) {
				[exifMetadata setObject:[NSNull null] forKey:key];
			}
			TLTimestampAddToPhotoExif((CFMutableDictionaryRef)exifMetadata, [self timestamp], [self location]);
			[basicMetadata setObject:exifMetadata forKey:(id)kCGImagePropertyExifDictionary];
			
			// set location
			NSMutableDictionary* gpsMetadata = [NSMutableDictionary dictionary];
			NSDictionary* originalGPS = [originalMetadata objectForKey:(id)kCGImagePropertyGPSDictionary];
			for (NSString* key in originalGPS) {
				[gpsMetadata setObject:[NSNull null] forKey:key];
			}
			TLLocationAddToPhotoGPS((CFMutableDictionaryRef)gpsMetadata, [self location]);
			[basicMetadata setObject:gpsMetadata forKey:(id)kCGImagePropertyGPSDictionary];
			
			metadataAdjustments = (CFDictionaryRef)basicMetadata;
		}
		else if (metadataAmount == TLPhotoMetadataFull) {
			NSMutableDictionary* fullMetadata = [NSMutableDictionary dictionary];
			
			// add software name
			NSString* softwareName = [[self class] exportSoftwareName];
			if ([softwareName length]) {
				NSMutableDictionary* tiffMetadata = [NSMutableDictionary dictionary];
				[tiffMetadata setObject:softwareName forKey:(id)kCGImagePropertyTIFFSoftware];
				[fullMetadata setObject:tiffMetadata forKey:(id)kCGImagePropertyTIFFDictionary];
			}
			
			// add timestamp
			NSMutableDictionary* exifMetadata = [NSMutableDictionary dictionary];
			TLTimestampAddToPhotoExif((CFMutableDictionaryRef)exifMetadata, [self timestamp], [self location]);
			[fullMetadata setObject:exifMetadata forKey:(id)kCGImagePropertyExifDictionary];
			
			// set location
			NSMutableDictionary* gpsMetadata = [NSMutableDictionary dictionary];
			NSDictionary* originalGPS = [originalMetadata objectForKey:(id)kCGImagePropertyGPSDictionary];
			for (NSString* key in originalGPS) {
				[gpsMetadata setObject:[NSNull null] forKey:key];
			}
			TLLocationAddToPhotoGPS((CFMutableDictionaryRef)gpsMetadata, [self location]);
			[fullMetadata setObject:gpsMetadata forKey:(id)kCGImagePropertyGPSDictionary];
			
			metadataAdjustments = (CFDictionaryRef)fullMetadata;
		}
		CGImageDestinationAddImageFromSource(destination, imageSource, 0, metadataAdjustments);
	}
	
	bool wroteSuccessfully = CGImageDestinationFinalize(destination);
	if (!wroteSuccessfully) {
		if (err) *err = [NSError errorWithDomain:NSPOSIXErrorDomain code:EIO userInfo:nil];
		return NO;
	}
	
	return YES;
}


@end


static NSTimeZone* TLTimeGetZoneForLocation(TLLocation* location) {
	(void)location;
	[NSTimeZone resetSystemTimeZone];
	return [NSTimeZone systemTimeZone];
}

static NSDateFormatter* TLPhotoExifDateFormatter() {
	NSDateFormatter* exifDateFormatter = [[[NSDateFormatter alloc] init] autorelease];
	[exifDateFormatter setTimeStyle:NSDateFormatterFullStyle];
	[exifDateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
	return exifDateFormatter;
}

TLTimestamp* TLTimestampFromPhotoExif(CFDictionaryRef exifProperties) {
	if (!exifProperties) return nil;
	
	NSString* dateTime = (NSString*)CFDictionaryGetValue(exifProperties, kCGImagePropertyExifDateTimeOriginal);
	NSString* subseconds = (NSString*)CFDictionaryGetValue(exifProperties, kCGImagePropertyExifSubsecTimeOrginal);
	if (!dateTime) {
		dateTime = (NSString*)CFDictionaryGetValue(exifProperties, kCGImagePropertyExifDateTimeDigitized);
		subseconds = (NSString*)CFDictionaryGetValue(exifProperties, kCGImagePropertyExifSubsecTimeDigitized);
	}
	if (!dateTime) return nil;
	
	NSDateFormatter* exifFormat = TLPhotoExifDateFormatter();
	NSDate* date = [exifFormat dateFromString:dateTime];
	if (subseconds) {
		// TODO: add subseconds to date
	}
	
	return [TLTimestamp timestampWithTime:date
								 accuracy:TLTimestampAccuracyUnknown];
}

void TLTimestampAddToPhotoExif(CFMutableDictionaryRef exifProperties, TLTimestamp* timestamp, TLLocation* location) {
	if (!timestamp) return;
	
	NSDate* date = [timestamp time];
	if (location) {
		NSTimeZone* timeZone = TLTimeGetZoneForLocation(location);
		NSTimeInterval offset = [timeZone secondsFromGMTForDate:date];
		date = [date addTimeInterval:offset];
	}
	
	NSDateFormatter* exifFormat = TLPhotoExifDateFormatter();
	NSString* dateString = [exifFormat stringFromDate:date];
	if (!dateString) {
		NSLog(@"Could not add date to photo EXIF dictionary");
		return;
	}
	CFDictionarySetValue(exifProperties, kCGImagePropertyExifDateTimeOriginal, dateString);
	// TODO: add subseconds when available
}

TLLocation* TLLocationFromPhotoGPS(CFDictionaryRef gpsMetadata) {
	if (!gpsMetadata) return nil;
	NSNumber* latNumber = (id)CFDictionaryGetValue(gpsMetadata, kCGImagePropertyGPSLatitude);
	NSNumber* lonNumber = (id)CFDictionaryGetValue(gpsMetadata, kCGImagePropertyGPSLongitude);
	if (!latNumber || !lonNumber) return nil;
	
	NSString* latSign = (id)CFDictionaryGetValue(gpsMetadata, kCGImagePropertyGPSLatitudeRef);
	double latitude = [latNumber doubleValue];
	if ([latSign isEqualToString:@"S"]) {
		latitude = -latitude;
	}
	
	NSString* lonSign = (id)CFDictionaryGetValue(gpsMetadata, kCGImagePropertyGPSLongitudeRef);
	double longitude = [lonNumber doubleValue];
	if ([lonSign isEqualToString:@"W"]) {
		longitude = -longitude;
	}
	
	NSNumber* altNumber = (id)CFDictionaryGetValue(gpsMetadata, kCGImagePropertyGPSAltitude);
	NSNumber* altNegative = (id)CFDictionaryGetValue(gpsMetadata, kCGImagePropertyGPSAltitudeRef);
	double altitude = altNumber ? [altNumber doubleValue] : TLCoordinateAltitudeUnknown;
	if (altNumber && [altNegative boolValue]) {
		altitude = -altitude;
	}
	
	// TODO: check GPSDOP and convert to accuracy value(s) depending on MeasureMode
	TLCoordinateAccuracy accuracy = TLCoordinateAccuracyUnknown;
	
	return [TLLocation locationWithCoordinate:TLCoordinateMake(latitude, longitude)
						   horizontalAccuracy:accuracy
									 altitude:altitude
							 verticalAccuracy:accuracy];
}

void TLLocationAddToPhotoGPS(CFMutableDictionaryRef gpsMetadataCF, TLLocation* location) {
	if (!location) return;
	NSMutableDictionary* gpsMetadata = (NSMutableDictionary*)gpsMetadataCF;
	TLCoordinate coord = [location coordinate];
	[gpsMetadata setObject:@"WGS-84" forKey:(id)kCGImagePropertyGPSMapDatum];
	[gpsMetadata setObject:[NSNumber numberWithDouble:fabs(coord.lat)] forKey:(id)kCGImagePropertyGPSLatitude];
	[gpsMetadata setObject:(coord.lat < 0.0 ? @"S" : @"N") forKey:(id)kCGImagePropertyGPSLatitudeRef];
	[gpsMetadata setObject:[NSNumber numberWithDouble:fabs(coord.lon)] forKey:(id)kCGImagePropertyGPSLongitude];
	[gpsMetadata setObject:(coord.lon < 0.0 ? @"W" : @"E") forKey:(id)kCGImagePropertyGPSLongitudeRef];
	TLCoordinateAltitude altitude = [location altitude];
	if (altitude != TLCoordinateAltitudeUnknown) {
		[gpsMetadata setObject:[NSNumber numberWithDouble:fabs(altitude)] forKey:(id)kCGImagePropertyGPSAltitude];
		[gpsMetadata setObject:(altitude < 0.0 ? @"1" : @"0") forKey:(id)kCGImagePropertyGPSAltitudeRef];
	}
	// TODO: set GPSDOP if possible
}
