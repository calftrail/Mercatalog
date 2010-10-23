//
//  TLOffsetTimestamp.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimestamp.h"


@interface TLOffsetTimestamp : TLTimestamp {
@private
	NSTimeInterval offset;
}

- (id)initWithTime:(NSDate*)theTime
		  accuracy:(NSTimeInterval)theAccuracy
			offset:(NSTimeInterval)theOffset;

+ (id)timestampWithTime:(NSDate*)theTime
			   accuracy:(NSTimeInterval)theAccuracy
				 offset:(NSTimeInterval)theOffset;

// this is what was added to get final (GMT) time
@property (nonatomic, assign) NSTimeInterval offset;

@end
