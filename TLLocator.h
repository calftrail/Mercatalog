//
//  TLLocator.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLLocation;
@class TLTimestamp;


@interface TLLocator : NSObject {
@private
	NSManagedObjectContext* modelContext;
}

+ (TLLocation*)defaultHomeBase;

@property (nonatomic, retain) NSManagedObjectContext* modelContext;

- (TLLocation*)locationAtTimestamp:(TLTimestamp*)targetTimestamp;
- (NSMapTable*)locateTimestamps:(NSMapTable*)timestampObjects;
- (NSSet*)trackTimestampsAtLocation:(TLLocation*)targetLocation;

@end
