//
//  TLMapLocationLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLInteractiveMapLayer.h"

@class TLLocation;


@interface TLMapLocationLayer : TLInteractiveMapLayer {
@private
	id delegate;
	TLLocation* homeBase;
	TLLocation* previewLocation;
	
	NSPoint dragOffset;
	TLLocation* oldHomeBase;
}

@property (nonatomic, assign) id delegate;
@property (nonatomic, copy) TLLocation* homeBase;
@property (nonatomic, copy) TLLocation* previewLocation;

@end


@interface NSObject (TLMapLocationLayerDelegate)
- (void)mapLocationLayerDidSetHomeBase:(TLMapLocationLayer*)locationLayer;
@end
