//
//  TLTimelineLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineLayer.h"
#import "TLTimelineLayer+HostInternals.h"

#import "TLTimelineView.h"
#import "TLTimelineView+HostInternals.h"

@implementation TLTimelineLayer

- (void)setNeedsDisplay {
	[[self host] setLayerNeedsDisplay:self];
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)ctx;
	(void)timelineInfo;
}

@synthesize hidden;

- (void)setHidden:(BOOL)newHidden {
	if (newHidden == hidden) return;
	hidden = newHidden;
	[self setNeedsDisplay];
}

@synthesize active;

@end

@implementation TLTimelineLayer (TLTimelineLayerHostInternals)

- (TLTimelineView*)host {
	return host;
}

- (void)setHost:(TLTimelineView*)newHost {
	host = newHost;
}

@end
