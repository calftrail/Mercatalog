//
//  TLMapNavigationLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/27/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLInteractiveMapLayer.h"


@interface TLMapNavigationLayer : TLInteractiveMapLayer {
@private
	id delegate;
	
	BOOL initialClickWasHeld;
	BOOL dragging;
	CGPoint dragStart;
	CGPoint dragCurrent;
}

@property (nonatomic, assign) id delegate;

- (IBAction)zoomCompletelyOut:(id)sender;

@end


@interface NSObject (TLMapNavigationLayerDelegate)
- (void)mapNavigationLayerDidIgnoreClick:(TLMapNavigationLayer*)navLayer;
@end
