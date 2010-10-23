//
//  TLTimelineNavigationLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineInteractiveLayer.h"


@interface TLTimelineNavigationLayer : TLTimelineInteractiveLayer {
	id delegate;
	
	BOOL initialClickWasHeld;
	BOOL dragging;
	CGPoint dragStart;
	CGPoint dragCurrent;
}

@property (nonatomic, assign) id delegate;

@end

@interface NSObject (TLTimelineNavigationLayerDelegate)
- (void)timelineNavigationLayerDidIgnoreClick:(TLTimelineNavigationLayer*)navLayer;
@end
