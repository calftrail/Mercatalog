//
//  TLMercatalogAppDelegate.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 8/9/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TLMercatalogProjectController;


@interface TLMercatalogAppDelegate : NSObject {
@private
	TLMercatalogProjectController* projectController;
}

- (IBAction)showAcknowledgements:(id)sender;
- (IBAction)showRegistration:(id)sender;

@end
