//
//  TLExportController.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLExportController.h"

#import "TLPhoto.h"
#import "TLLocation.h"
#import "TLTimestamp.h"
#import "TLCocoaToolbag.h"

NSString* const TLExportKMZType = @"com.google.earth.kmz";


@implementation TLExportController

@synthesize photos;

- (NSMapTable*)namesForPhotos:(NSSet*)thePhotos inDirectory:(NSURL*)folder {
	(void)folder;
	
	NSMutableSet* existingNames = [NSMutableSet set];
	NSArray* directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[folder path]
																					 error:NULL];
	for (NSString* file in directoryContents) {
		NSString* fileExtension = [file pathExtension];
		if ([fileExtension isEqualToString:@"jpg"] || [fileExtension isEqualToString:@"JPG"]) {
			NSString* name = [[file lastPathComponent] stringByDeletingPathExtension];
			[existingNames addObject:name];
		}
	}
	
	NSMapTable* photoNames = [NSMapTable mapTableWithStrongToStrongObjects];
	for (TLPhoto* photo in thePhotos) {
		NSString* originalName = [[[photo path] lastPathComponent] stringByDeletingPathExtension];
		NSString* proposedName = originalName;
		NSUInteger count = 0;
		const NSUInteger maxTries = 1000000;
		while ([existingNames containsObject:proposedName] && count < maxTries) {
			++count;
			proposedName = [originalName stringByAppendingFormat:@"-%lu", (long unsigned)count];
		}
		NSString* finalName = [proposedName stringByAppendingPathExtension:@"jpg"];
		[photoNames setObject:finalName forKey:photo];
	}
	return photoNames;
}

- (void)doExportToFolder:(NSDictionary*)exportInfo {
	NSMapTable* photoNames = [exportInfo objectForKey:@"photoNames"];
	NSURL* folder = [exportInfo objectForKey:@"folder"];
	for (TLPhoto* photo in photoNames) {
		NSAutoreleasePool* looPPool = [NSAutoreleasePool new];
		NSString* photoFilename = [photoNames objectForKey:photo];
		NSString* fullPath = [[folder path] stringByAppendingPathComponent:photoFilename];
		(void)[photo saveToPath:fullPath
						   size:0
				   withMetadata:TLPhotoMetadataFull
						  error:NULL];
		[looPPool drain];
	}
}

- (NSArray*)exportToFolder:(NSURL*)folder error:(NSError**)err {
	(void)err;
	
	NSMapTable* photoNames = [self namesForPhotos:[self photos] inDirectory:folder];
	NSDictionary* exportInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								photoNames, @"photoNames", folder, @"folder", nil];
	[self performSelector:@selector(doExportToFolder:) withObject:exportInfo afterDelay:0.1];
	return TLNSMapTableAllObjects(photoNames);
}



#pragma mark KMZ export

static NSString* const TLKMZHeader = (@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
									  @"<kml xmlns=\"http://www.opengis.net/kml/2.2\"><Document>\n");
static NSString* const TLKMZFooter = @"</Document></kml>";

static NSString* const TLKMZPlacemarkFormat = (@"<Placemark>"
											   @"<Point>%S</Point>"		// coordinates tag
											   @"<TimeStamp><when>%S</when></TimeStamp>"	// ISO 8601
											   @"<StyleMap>"
											   @"<Pair><key>normal</key>%S</Pair>"		// style tag
											   @"<Pair><key>highlight</key>%S</Pair>"	// style tag
											   @"</StyleMap>"
											   @"<description><![CDATA[%S]]></description>"
											   @"</Placemark>\n");

static NSString* const TLKMZCoordinatesFormat = @"<coordinates>%.6f,%.6f</coordinates>";	// lon, lat
static NSString* const TLKMZCoordinatesAltitudeFormat = @"<coordinates>%.6f,%.6f,%.2f</coordinates>";	// lon, lat, alt

static NSString* const TLKMZStyleFormat = (@"<Style>"
										   @"<IconStyle>"
										   @"<scale>%.2f</scale>"
										   @"<Icon><href>%S</href></Icon>"
										   @"</IconStyle>"
										   @"<BalloonStyle>"
										   @"<text>$[description]</text>"
										   @"</BalloonStyle>"
										   @"</Style>");

static NSString* const TLKMZDescriptionFormat = @"<img src=\"%S\"/>";

- (NSString*)exportKMZInfoForPhoto:(TLPhoto*)photo
					 intoDirectory:(NSString*)directory
							 error:(NSError**)err
{
	NSString* basePhotoName = [NSString stringWithFormat:@"%lu", [photo uniqueID]];
	
	const NSUInteger iconSize = 64;
	const NSUInteger mediumSize = 400;
	
	// export photos
	NSError* internalError = nil;
	NSString* iconFile = [[basePhotoName stringByAppendingString:@"-icon"] stringByAppendingPathExtension:@"jpg"];
	NSString* iconFullPath = [directory stringByAppendingPathComponent:iconFile];
	(void)[photo saveToPath:iconFullPath
					   size:iconSize
			   withMetadata:TLPhotoMetadataNone
					  error:&internalError];
	if (internalError) {
		if (err) *err = internalError;
		return nil;
	}
	
	NSString* mediumFile = [[basePhotoName stringByAppendingString:@"-medium"] stringByAppendingPathExtension:@"jpg"];
	NSString* mediumFullPath = [directory stringByAppendingPathComponent:mediumFile];
	(void)[photo saveToPath:mediumFullPath
					   size:mediumSize
			   withMetadata:TLPhotoMetadataNone
					  error:&internalError];
	if (internalError) {
		if (err) *err = internalError;
		return nil;
	}
	
	// generate KMZ reference
	NSString* coordinatesTag = nil;
	if ([[photo location] altitude] == TLCoordinateAltitudeUnknown) {
		TLCoordinate coord = [[photo location] coordinate];
		coordinatesTag = [NSString stringWithFormat:TLKMZCoordinatesFormat, coord.lon, coord.lat];
	}
	else {
		TLCoordinate coord = [[photo location] coordinate];
		TLCoordinateAltitude altitude = [[photo location] altitude];
		coordinatesTag = [NSString stringWithFormat:TLKMZCoordinatesAltitudeFormat,
						  coord.lon, coord.lat, altitude];
	}
	
	NSDateFormatter* sISO8601 = [[NSDateFormatter new] autorelease];
	[sISO8601 setTimeStyle:NSDateFormatterFullStyle];
	[sISO8601 setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	NSString* timeStamp = [sISO8601 stringFromDate:[[photo timestamp] time]];
	
	NSString* normalStyle = [NSString stringWithFormat:TLKMZStyleFormat,
							 1.0, [iconFile cStringUsingEncoding:NSUTF16StringEncoding]];
	NSString* highlightStyle = [NSString stringWithFormat:TLKMZStyleFormat,
								1.1, [iconFile cStringUsingEncoding:NSUTF16StringEncoding]];
	
	NSString* description = [NSString stringWithFormat:TLKMZDescriptionFormat,
							 [mediumFile cStringUsingEncoding:NSUTF16StringEncoding]];
	
	NSString* photoPlacemark = [NSString stringWithFormat:TLKMZPlacemarkFormat,
								[coordinatesTag cStringUsingEncoding:NSUTF16StringEncoding],
								[timeStamp cStringUsingEncoding:NSUTF16StringEncoding],
								[normalStyle cStringUsingEncoding:NSUTF16StringEncoding],
								[highlightStyle cStringUsingEncoding:NSUTF16StringEncoding],
								[description cStringUsingEncoding:NSUTF16StringEncoding]];
	
	//printf("%s\n", [photoPlacemark UTF8String]);
	return photoPlacemark;
}

- (BOOL)exportToKMZ:(NSURL*)kmzFile error:(NSError**)err {
	// export goes in temporary folder first
	NSString* tempFolder = TLFileTemporaryPathFromPattern(@"com.calftrail.mercatalog.kmz-export-XXXXX");
	if (!tempFolder) {
		if (err) *err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
		return NO;
	}
	
	NSError* internalError = nil;
	(void)[[NSFileManager defaultManager] createDirectoryAtPath:tempFolder
									withIntermediateDirectories:NO
													 attributes:nil
														  error:&internalError];
	if (internalError) {
		if (err) *err = internalError;
		return NO;
	}
	
	NSMutableString* kmzString = [NSMutableString string];
	[kmzString appendString:TLKMZHeader];
	for (TLPhoto* photo in [self photos]) {
		NSString* photoInfo = [self exportKMZInfoForPhoto:photo intoDirectory:tempFolder error:&internalError];
		if (internalError) {
			if (err) *err = internalError;
			return NO;
		}
		[kmzString appendString:photoInfo];
	}
	[kmzString appendString:TLKMZFooter];
	
	NSString* kmlPath = [tempFolder stringByAppendingPathComponent:@"doc.kml"];
	(void)[kmzString writeToFile:kmlPath atomically:YES encoding:NSUTF8StringEncoding error:&internalError];
	
	if (!internalError) {
		(void)TLFileZip(tempFolder, [kmzFile path], &internalError);
	}
	(void)[[NSFileManager defaultManager] removeItemAtPath:tempFolder error:NULL];
	
	if (internalError) {
		if (err) *err = internalError;
		return NO;
	}
	
	return YES;
}

@end
