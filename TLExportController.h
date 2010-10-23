//
//  TLExportController.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 12/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* const TLExportKMZType;

@interface TLExportController : NSObject {
@private
	NSSet* photos;
}

@property (nonatomic, copy) NSSet* photos;

- (BOOL)exportToKMZ:(NSURL*)kmzFile error:(NSError**)err;
- (NSArray*)exportToFolder:(NSURL*)folder error:(NSError**)err;

@end
