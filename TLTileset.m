//
//  TLTileset.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTileset.h"

#import "TLCache.h"

static const tl_uint_t TLTilesetMasterWidth = 16200;
static const tl_uint_t TLTilesetMasterHeight = 8100;
static const tl_uint_t TLTilesetMaxLevel = 4;


static const TLCoordinateDegrees TLTilesetWorldWidth = 360.0;
static const TLCoordinateDegrees TLTilesetWorldHeight = 180.0;
TL_INLINE tl_uint_t TLTilesetLevelFactor(tl_uint_t level);


static CGContextRef TLTilesetContextFromImage(CFURLRef imageURL);

@implementation TLTileset

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) {
		tileCache = [TLCache new];
	}
	return self;
}

- (void)dealloc {
	[tileCache release];
	[super dealloc];
}


#pragma mark Accessors

- (TLCoordinateDegrees)minimumDegreesPerPixel {
	return TLTilesetWorldWidth / TLTilesetMasterWidth;
}

- (size_t)bytesPerPixel {
	return 4;
}

typedef struct {
	CGContextRef bitmap;
	CGPoint pixelCenter;
} TLTilesetBitmapInfo;

- (tl_uint_t)levelForScale:(TLCoordinateDegrees)degreesPerPixel {
	tl_uint_t level = 0;
	while (level + 1 < TLTilesetMaxLevel) {
		CGFloat levelWidth = TLTilesetMasterWidth / (CGFloat)TLTilesetLevelFactor(level);
		TLCoordinateDegrees levelDegreesPerPixel = TLTilesetWorldWidth / levelWidth;
		if (levelDegreesPerPixel <= degreesPerPixel) break;
		++level;
	}
	return level;
}

- (TLTilesetBitmapInfo)bitmapForCoordinate:(TLCoordinate)coord fromLevel:(tl_uint_t)tileLevel {
	const TLCoordinate origin = TLCoordinateMake(TLTilesetWorldHeight / 2.0,
												 -TLTilesetWorldWidth / 2.0);
	const tl_uint_t baseFactor = TLTilesetLevelFactor(0);
	const tl_uint_t paddedMasterWidth = TLNextPowerOfTwo(TLTilesetMasterWidth);
	const tl_uint_t paddedMasterHeight = TLNextPowerOfTwo(TLTilesetMasterHeight);
	const tl_uint_t tileWidth = paddedMasterWidth / baseFactor;
	const tl_uint_t tileHeight = paddedMasterHeight / baseFactor;
	
	CGFloat levelScale = 1.0f / (CGFloat)TLTilesetLevelFactor(tileLevel);
	CGFloat levelWidth = TLTilesetMasterWidth * levelScale;
	CGFloat levelHeight = TLTilesetMasterHeight * levelScale;
	double pixelsPerDegreeLon = levelWidth / TLTilesetWorldWidth;
	double pixelsPerDegreeLat = -levelHeight / TLTilesetWorldHeight;
	
	double levelX = (coord.lon - origin.lon) * pixelsPerDegreeLon;
	double levelY = (coord.lat - origin.lat) * pixelsPerDegreeLat;
	double tilePositionX = levelX / tileWidth;
	double tilePositionY = levelY / tileHeight;
	tl_uint_t tileIndexX = (tl_uint_t)tilePositionX;
	tl_uint_t tileIndexY = (tl_uint_t)tilePositionY;
	CGPoint pixelCenter = CGPointMake((CGFloat)(tileWidth * (tilePositionX - tileIndexX)),
									  (CGFloat)(tileHeight * (tilePositionY - tileIndexY)));
	
	tl_uint_t tileId[] = {tileLevel, tileIndexX, tileIndexY};
	NSData* tileKey = [NSData dataWithBytes:&tileId length:sizeof(tileId)];
	CGContextRef tileBitmap = (CGContextRef)[tileCache objectForKey:tileKey];
	if (!tileBitmap) {
		NSString* tileName = [NSString stringWithFormat:@"%02lu/%05lu-%05lu.png", tileLevel, tileIndexX, tileIndexY];
		NSString* tileBaseFolder = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Tiles"];
		NSString* tilePath = [tileBaseFolder stringByAppendingPathComponent:tileName];
		//printf("Fetching tile: '%s'\n", [tileName UTF8String]);
		tileBitmap = TLTilesetContextFromImage((CFURLRef)[NSURL fileURLWithPath:tilePath isDirectory:NO]);
		[tileCache setObject:(id)tileBitmap forKey:tileKey];
	}
	
	TLTilesetBitmapInfo info = {
		.bitmap = tileBitmap,
		.pixelCenter = pixelCenter
	};
	return info;
}

- (void*)pixelForCoordinate:(TLCoordinate)coord degreesPerPixel:(TLCoordinateDegrees)scale {
	tl_uint_t level = [self levelForScale:scale];
	TLTilesetBitmapInfo bitmapInfo = [self bitmapForCoordinate:coord fromLevel:level];
	
	CGContextRef sourceBitmap = bitmapInfo.bitmap;
    if (!sourceBitmap) {
        return NULL;
    }
	void* sourceBuffer = CGBitmapContextGetData(sourceBitmap);
	NSAssert(sourceBuffer, @"Source tile must provide memory access");
	size_t sourceBytesPerPixel = TLCGBitmapContextGetBytesPerPixel(sourceBitmap);
	size_t sourceRowWidth = CGBitmapContextGetBytesPerRow(sourceBitmap) / sourceBytesPerPixel;
	size_t sourcePixelCount = sourceRowWidth * CGBitmapContextGetHeight(sourceBitmap);
	
	CGPoint sourcePoint = bitmapInfo.pixelCenter;
	tl_uint_t sourceIdx = TLTableIndex(sourcePoint.x, sourcePoint.y, sourceRowWidth);
	void* pixelPtr = NULL;
	if (sourceIdx < sourcePixelCount) {
		pixelPtr = sourceBuffer + (sourceBytesPerPixel * sourceIdx);
	}
	return pixelPtr;
}

@end


CGContextRef TLCGContextCreateMemoryBacked(size_t width, size_t height) {
    const size_t bitsPerComponent = 8;
    const size_t bytesPerPixel = 4;
    
    size_t bytesPerRow = width * bytesPerPixel;
    size_t byteCount = height * bytesPerRow;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    if (!colorSpace) {
        return NULL;
    }
    
    // Allocate memory for image data.
    void* bitmapData = malloc(byteCount);
    if (!bitmapData) {
        CGColorSpaceRelease(colorSpace);
        return NULL;
    }
    
    CGContextRef context = CGBitmapContextCreate(bitmapData,
                                                 width, height,
                                                 bitsPerComponent, bytesPerRow,
                                                 colorSpace, kCGImageAlphaPremultipliedFirst);
    if (!context) {
        free(bitmapData);
    }
    CGColorSpaceRelease(colorSpace);
    
    return context;
}

void TLCGContextSmartRelease(CGContextRef ctx) {
    void* contextMemory = CGBitmapContextGetData(ctx);
    CFIndex origRetainCount = CFGetRetainCount(ctx);
    CGContextRelease(ctx);
    if (contextMemory && origRetainCount == 1) {
        //NSCAssert(origRetainCount==1, @"Caller is not sole owner of smart-released context's memory");
        free(contextMemory);
    }
}

size_t TLCGBitmapContextGetBytesPerPixel(CGContextRef context) {
    NSCAssert(!(CGBitmapContextGetBitsPerPixel(context) % 8), @"Bits per pixel not evenly divisible by 8.");
    return (CGBitmapContextGetBitsPerPixel(context) / 8);
}

tl_uint_t TLTilesetLevelFactor(tl_uint_t level) {
	return 1 << (TLTilesetMaxLevel - level);
}

CGContextRef TLTilesetContextFromImage(CFURLRef imageURL) {
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imageURL, NULL);
    if (!imageSource || !CGImageSourceGetCount(imageSource)) {
        return NULL;
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    CFRelease(imageSource);
	CGRect imageRect = CGRectMake(0.0f, 0.0f, CGImageGetWidth(image), CGImageGetHeight(image));
	CGContextRef context = TLCGContextCreateMemoryBacked(imageRect.size.width, imageRect.size.height);
	CGContextDrawImage(context, imageRect, image);
	return (CGContextRef)[(id)context autorelease];
}

