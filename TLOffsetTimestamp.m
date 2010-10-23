//
//  TLOffsetTimestamp.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLOffsetTimestamp.h"


@implementation TLOffsetTimestamp


#pragma mark Archiving

static NSString* const TLOffsetTimestampOffsetKey = @"TLOffsetTimestamp_Offset";

- (void)encodeWithCoder:(NSCoder*)encoder {
	[super encodeWithCoder:encoder];
	[encoder encodeDouble:offset forKey:TLOffsetTimestampOffsetKey];
}

- (id)initWithCoder:(NSCoder*)coder {
	self = [super initWithCoder:coder];
	if (self) {
		offset = [coder decodeDoubleForKey:TLOffsetTimestampOffsetKey];
	}
    return self;
}


#pragma mark Lifecycle

- (id)initWithTime:(NSDate*)theTime
		  accuracy:(NSTimeInterval)theAccuracy
			offset:(NSTimeInterval)theOffset
{
	self = [super initWithTime:theTime accuracy:theAccuracy];
	if (self) {
		offset = theOffset;
	}
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (id)copyWithZone:(NSZone*)zone {
	return [[TLOffsetTimestamp allocWithZone:zone] initWithTime:[self time]
													   accuracy:[self accuracy]
														 offset:[self offset]];
}


#pragma mark Convenience creators

+ (id)timestampWithTime:(NSDate*)theTime
			   accuracy:(NSTimeInterval)theAccuracy
				 offset:(NSTimeInterval)theOffset
{
	TLOffsetTimestamp* timestamp = [[[self class] alloc] initWithTime:theTime
															 accuracy:theAccuracy
															   offset:theOffset];
	return [timestamp autorelease];
}


@synthesize offset;

@end
