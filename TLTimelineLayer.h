//
//  TLTimelineLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineInfo.h"

@class TLTimelineView;

@interface TLTimelineLayer : NSObject {
@private
	TLTimelineView* host;
	BOOL active;
	BOOL hidden;
}

@property (nonatomic, assign, getter=isHidden) BOOL hidden;

@property (nonatomic, assign, getter=isActive) BOOL active;

- (void)setNeedsDisplay;
- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo;

@end
