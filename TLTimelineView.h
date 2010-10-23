//
//  TLTimelineView.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 3/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLTimelineLayer;
@class TLTimelineInteractiveLayer;

#define CHECKPROTOCOL
#ifdef CHECKPROTOCOL
// NOTE: this is to get protocol check despite compiler bug rdar://problem/6284845
#import "TLTimelineInfo.h"
@interface TLTimelineView : NSView < TLTimelineInfo > {
#undef CHECKPROTOCOL
#else
@interface TLTimelineView : NSView {
#endif /* CHECKPROTOCOL */
@private
	NSMutableArray* layers;
	NSMapTable* layerTrackingManagers;
	
	NSTimeZone* timeZone;
	NSDate* startDate;
	NSDate* endDate;
	
	NSEvent* eventForDrag;
	__weak TLTimelineInteractiveLayer* currentMouseLayer;
	
	CGSize cachedScreenSizeInMillimeters;
}

- (void)addLayer:(TLTimelineLayer*)layer;

@property (nonatomic, copy) NSTimeZone* timeZone;
@property (nonatomic, copy) NSDate* startDate;
@property (nonatomic, copy) NSDate* endDate;

@end
