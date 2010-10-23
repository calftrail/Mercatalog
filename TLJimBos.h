//
//  TLJimBos.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TLJimBos : NSObject {
	IBOutlet NSWindow* registrationWindow;
	IBOutlet NSTextField* nameField;
	IBOutlet NSTextField* emailField;
	IBOutlet NSTextField* registrationCode;
	IBOutlet NSButton* registerButton;
@private
}

+ (id)sharedRegistrar;

- (void)noteUse;
- (BOOL)isExpired;

- (IBAction)showDemoInformation:(id)sender;
- (IBAction)showRegistrationWindow:(id)sender;

- (IBAction)closeRegistrationWindow:(id)sender;
- (IBAction)buyMercatalog:(id)sender;
- (IBAction)contactCalfTrail:(id)sender;
- (IBAction)registerByForm:(id)sender;

- (BOOL)registerApplication:(NSString*)licenseKey
					   user:(NSString*)userName;

@end
