//
//  TLTileset.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLCoordinate.h"

@class TLCache;

@interface TLTileset : NSObject {
@private
	TLCache* tileCache;
}

- (TLCoordinateDegrees)minimumDegreesPerPixel;

- (size_t)bytesPerPixel;
- (void*)pixelForCoordinate:(TLCoordinate)coord degreesPerPixel:(TLCoordinateDegrees)scale;

@end

CGContextRef TLCGContextCreateMemoryBacked(size_t width, size_t height);
size_t TLCGBitmapContextGetBytesPerPixel(CGContextRef context);
void TLCGContextSmartRelease(CGContextRef ctx);
