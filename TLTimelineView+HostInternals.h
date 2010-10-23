//
//  TLTimelineView+HostInternals.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLTimelineLayer;
@class TLTimelineInteractiveLayer;

@interface TLTimelineView (TLTimelineViewHostInternals)

- (void)setLayerNeedsDisplay:(TLTimelineLayer*)layer;

- (NSArray*)activeTrackingZonesForLayer:(TLTimelineInteractiveLayer*)layer;
- (void)setActiveTrackingZones:(NSArray*)trackingZones forLayer:(TLTimelineInteractiveLayer*)layer;

- (NSPasteboard*)dragPasteboardForLayer:(TLTimelineInteractiveLayer*)layer;
- (void)dragFromLayer:(TLTimelineInteractiveLayer*)layer
			withImage:(CGImageRef)dragImage
			   anchor:(CGPoint)imagePoint
			slideBack:(BOOL)shouldSlideBack;

- (void)updateDropTypesForLayer:(TLTimelineInteractiveLayer*)layer;

- (NSPoint)mouseLocationInWindow;

@end
