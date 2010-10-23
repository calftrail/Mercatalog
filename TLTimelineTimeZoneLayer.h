//
//  TLTimelineTimeZoneLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/5/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineInteractiveLayer.h"


@interface TLTimelineTimeZoneLayer : TLTimelineInteractiveLayer {
@private
	BOOL isDragging;
	NSTimeInterval dragTimeOffset;
	CGFloat dragMouseOffsetY;
}

@end
