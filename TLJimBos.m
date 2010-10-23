//
//  TLJimBos.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TLJimBos.h"

#import <CommonCrypto/CommonDigest.h>

const NSUInteger TLJimBos_MaximumUseCount = 10;
static NSString* const TLJimBos_StorePage = @"http://calftrail.com/store";
static NSString* const TLJimBos_ContactAddress = @"support@calftrail.com";
static NSString* const TLJimBos_ContactSubject = @"Mercatalog feedback";
static NSString* const TLJimBos_ContactBody = @"";

static NSString* const TLJimBos_UserNameKey = @"com.calftrail.mercatalog.username";
static NSString* const TLJimBos_ProductKey = @"com.calftrail.mercatalog.productkey";


@interface TLJimBos ()
- (BOOL)isRegistered;
- (BOOL)checkKey:(NSString*)licenseKey;
- (NSString*)emailAddressFromKey:(NSString*)licenseKey;
@end


@implementation TLJimBos

+ (id)sharedRegistrar {
	static TLJimBos* sharedRegistrar = nil;
	if (!sharedRegistrar) {
		sharedRegistrar = [TLJimBos new];
		// http://www.cocoabuilder.com/archive/message/cocoa/2008/8/10/215295
		[[NSAppleEventManager sharedAppleEventManager] setEventHandler:sharedRegistrar
														   andSelector:@selector(handleURLEvent:reply:)
														 forEventClass:kInternetEventClass
															andEventID:kAEGetURL];
	}
	return sharedRegistrar;
}

- (void)dealloc {
	[[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
	[super dealloc];
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event reply:(NSAppleEventDescriptor *)replyEvent {
	(void)replyEvent;
	
	NSString* urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSURL* url = [NSURL URLWithString:urlString];
	//NSLog(@"Received URL: %@\n", url);
	
	if (![[url scheme] isEqualToString:@"x-com-calftrail-license-mercatalog"]) {
		return;
	}
	
	NSString* licenseKey = [[url resourceSpecifier] stringByReplacingOccurrencesOfString:@"//" withString:@""];
	NSString* userName = NSFullUserName();
	
	BOOL registered = [self registerApplication:licenseKey user:userName];
	if (registered && registrationWindow) {
		[self closeRegistrationWindow:self];
	}
	
	if (registered) {
		[self showRegistrationWindow:self];
	}
	else {
		NSAlert* registrationError = [[NSAlert new] autorelease];
		[registrationError setAlertStyle:NSWarningAlertStyle];
		[registrationError setMessageText:@"Automatic registration failed!"];
		[registrationError setInformativeText:
		 @"Mercatalog could not be registered through the link you just clicked. "
		 @"You can try registering using the manual window, or contact us if you are having trouble. "
		 @"Sorry for the inconvenience."];
		(void)[registrationError addButtonWithTitle:@"OK"];
		NSButton* contact = [registrationError addButtonWithTitle:@"Contact Calf Trail"];
		[contact setBezelStyle:NSRoundRectBezelStyle];
		
		NSInteger button = [registrationError runModal];
		if (button == NSAlertSecondButtonReturn) {
			[self contactCalfTrail:self];
		}
		else {
			[self showRegistrationWindow:self];
		}
	}
}

static NSString* const TLJimBos_DaysUsedKey = @"TLMercatalogDates";

- (NSSet*)daysUsed {
	//return nil;
	//return [NSSet setWithObjects:@"1", nil];
	//return [NSSet setWithObjects:@"1", @"2", nil];
	//return [NSSet setWithObjects:@"1", @"2", @"3", nil];
	
	NSArray* daysArray = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_DaysUsedKey];
	return daysArray ? [NSSet setWithArray:daysArray] : [NSSet set];
}

- (void)setDaysUsed:(NSSet*)newDaysUsed {
	NSArray* daysArray = [newDaysUsed allObjects];
	[[NSUserDefaults standardUserDefaults] setObject:daysArray forKey:TLJimBos_DaysUsedKey];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)noteUse {
	if ([self isRegistered]) return;
	NSDateFormatter* dateFormatter = [[NSDateFormatter new] autorelease];
	[dateFormatter setDateFormat:@"yyyy-MM-dd"];
	NSDate* today = [NSDate date];
	NSString* dayString = [dateFormatter stringFromDate:today];
	
	NSMutableSet* newDaysUsed = [NSMutableSet setWithSet:[self daysUsed]];
	[newDaysUsed addObject:dayString];
	[self setDaysUsed:newDaysUsed];
}

- (IBAction)contactCalfTrail:(id)sender {
	(void)sender;
	//http://www.ietf.org/rfc/rfc2368
	NSString* mailString = [NSString stringWithFormat:@"mailto:%@?subject=%@&body=%@",
							TLJimBos_ContactAddress, TLJimBos_ContactSubject, TLJimBos_ContactBody];
	NSString* encodedMailString = [mailString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL* mailURL = [NSURL URLWithString:encodedMailString];
	[[NSWorkspace sharedWorkspace] openURL:mailURL];
}

- (IBAction)buyMercatalog:(id)sender {
	(void)sender;
	NSURL* storeURL = [NSURL URLWithString:TLJimBos_StorePage];
	[[NSWorkspace sharedWorkspace] openURL:storeURL];
}

- (IBAction)showDemoInformation:(id)sender {
	(void)sender;
	
	if ([self isRegistered]) return;
	
	NSUInteger maximumUseCount = TLJimBos_MaximumUseCount;
	NSUInteger useCount = [[self daysUsed] count];
	[self noteUse];
	
	// TODO: localize
	NSAlert* demoInfo = [[NSAlert new] autorelease];
	[demoInfo setAlertStyle:NSWarningAlertStyle];
	if (!useCount) {	// first time
		[demoInfo setMessageText:@"Thanks for trying Mercatalog!"];
		NSString* info = [NSString stringWithFormat:
						  @"You are using a demo version of Mercatalog, allowing %lu days of unrestricted use. "
						  @"When it expires, you will need to purchase a registration code to continue exporting photos.",
						  (long unsigned)maximumUseCount];
		[demoInfo setInformativeText:info];
	}
	else if (useCount == maximumUseCount) {	// last day
		[demoInfo setMessageText:@"Last day of demo."];
		[demoInfo setInformativeText:
		 @"This is the last day you can use the export features in Mercatalog. "
		 @"We hope this application has been useful, and appreciate your feedback. "];
	}
	else if (useCount > maximumUseCount) {	// expired
		[demoInfo setMessageText:@"Mercatalog demo has expired."];
		[demoInfo setInformativeText:
		 @"This demo of Mercatalog has expired, so export will no longer work. "
		 @"Please purchase a license, or let us know how Mercatalog could better serve your needs. "];		
	}
	else {	// usually
		NSUInteger daysLeft = 1 + maximumUseCount - useCount;
		[demoInfo setMessageText:@"We hope you are enjoying Mercatalog!"];
		NSString* info = [NSString stringWithFormat:
						  @"This demo has %lu days of unrestricted use remaining. "
						  @"You may buy a license now, or continue using this demo. ",
						  (long unsigned)daysLeft];
		[demoInfo setInformativeText:info];
	}
	
	[demoInfo addButtonWithTitle:@"Use demo"];
	if (useCount) {
		NSButton* buy = [demoInfo addButtonWithTitle:@"Purchase"];
		[buy setBezelStyle:NSRoundRectBezelStyle];
		NSButton* contact = [demoInfo addButtonWithTitle:@"Contact Calf Trail"];
		[contact setBezelStyle:NSRoundRectBezelStyle];
	}
	
	NSInteger button = [demoInfo runModal];
	if (button == NSAlertFirstButtonReturn) {
		// use demo
	}
	else if (button == NSAlertSecondButtonReturn) {
		[self buyMercatalog:self];
	}
	else if (button == NSAlertThirdButtonReturn) {
		[self contactCalfTrail:self];
	}
}

- (BOOL)isExpired {
	if (![self isRegistered]) {
		[self noteUse];
		if ([[self daysUsed] count] > TLJimBos_MaximumUseCount) {
			return YES;
		}
	}
	return NO;
}

- (IBAction)showRegistrationWindow:(id)sender {
	(void)sender;
	NSString* userName = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_UserNameKey];
	if ([self isRegistered]) {
		[NSBundle loadNibNamed:@"ThankYou" owner:self];
		[nameField setStringValue:userName];
		
		NSString* licenseKey = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_ProductKey];
		NSString* emailAddress = [self emailAddressFromKey:licenseKey];
		[emailField setStringValue:emailAddress];
	}
	else {
		[NSBundle loadNibNamed:@"Registration" owner:self];
		if (!userName) {
			userName = NSFullUserName();
		}
		[nameField setStringValue:userName];
	}
	[registrationWindow makeKeyAndOrderFront:self];
}

- (IBAction)registerByForm:(id)sender {
	(void)sender;
	
	NSString* licenseKey = [registrationCode stringValue];
	NSString* userName = [nameField stringValue];
	BOOL registered = [self registerApplication:licenseKey user:userName];
	if (!registered) {
		NSBeep();
		[registerButton setEnabled:NO];
	}
	else {
		[self closeRegistrationWindow:self];
		[self showRegistrationWindow:self];
	}
}

- (void)controlTextDidChange:(NSNotification*)changeNotification {
	if ([changeNotification object] != registrationCode) return;
	
	NSString* licenseKey = [registrationCode stringValue];
	if ([self checkKey:licenseKey]) {
		[registerButton setEnabled:YES];
	}
	else {
		[registerButton setEnabled:NO];
	}
}

- (void)cleanupWindow {
	registrationWindow = nil;
	nameField = nil;
	emailField = nil;
	registrationCode = nil;
	registerButton = nil;
}

- (void)windowWillClose:(NSNotification *)notification {
	(void)notification;
	[self cleanupWindow];
}

- (IBAction)closeRegistrationWindow:(id)sender {
	(void)sender;
	[registrationWindow close];
}

- (NSString*)createLicenseKeyWithEmail:(NSString*)email productCode:(NSString*)productCode secret:(NSString*)secret {
	NSString* stringToHash = [NSString stringWithFormat:@"%@%@%@", email, productCode, secret];
	
	const char* cStringToHash = [stringToHash UTF8String];
	unsigned char hash[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1(cStringToHash, (CC_LONG)strlen(cStringToHash), hash);
	
	NSString* hashString = [NSString stringWithFormat:
							@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
							hash[0], hash[1], hash[2], hash[3],
							hash[4], hash[5], hash[6], hash[7],
							hash[8], hash[9], hash[10], hash[11],
							hash[12], hash[13], hash[14], hash[15],
							hash[16], hash[17], hash[18], hash[19], hash[20] ];
	return [NSString stringWithFormat:@"%@%@%@",
			email,
			@"@@",
			hashString];
}

- (NSString*)emailAddressFromKey:(NSString*)licenseKey {
	NSArray* sections = [licenseKey componentsSeparatedByString:@"@@"];
	NSString* emailAddress = nil;
	if ([sections count]) {
		emailAddress = [sections objectAtIndex:0];
	}
	return emailAddress;
}

- (BOOL)licenseKeyIsValid:(NSString*)licenseKey productCode:(NSString*)productCode secret:(NSString*)secret {
	BOOL result = NO;
	NSString* emailAddress = [self emailAddressFromKey:licenseKey];
	if (emailAddress) {
		NSString* generatedLicense = [self createLicenseKeyWithEmail:emailAddress
														 productCode:productCode
															  secret:secret];
		if ([generatedLicense isEqualToString:licenseKey]) {
			result = YES;
		}
	}
	return result;
}

- (BOOL)checkKey:(NSString*)licenseKey {
	if (!licenseKey) return NO;
	
	static NSString* const productCode = @"mercatalog-1.0";
	static NSString* const secret = @"pleasesupportourworkandfamilies";
	NSString* extraSecret = [NSString stringWithFormat:@"%c%c%c%s%c", 'C', 'T', 'S', "llc", '1'];
	NSString* fullSecret = [secret stringByAppendingString:extraSecret];
	return [self licenseKeyIsValid:licenseKey productCode:productCode secret:fullSecret];
}

- (BOOL)isRegistered {
	NSString* licenseKey = [[NSUserDefaults standardUserDefaults] objectForKey:TLJimBos_ProductKey];
	return [self checkKey:licenseKey];
}

- (BOOL)registerApplication:(NSString*)licenseKey
					   user:(NSString*)userName
{
	[[NSUserDefaults standardUserDefaults] setObject:userName forKey:TLJimBos_UserNameKey];
	[[NSUserDefaults standardUserDefaults] setObject:licenseKey forKey:TLJimBos_ProductKey];
	BOOL saved = [[NSUserDefaults standardUserDefaults] synchronize];
	if (!saved) {
		NSLog(@"Could not save user defaults O_o");
		return NO;
	}
	
	BOOL valid = [self isRegistered];
	if (!valid) {
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:TLJimBos_ProductKey];
	}
	return valid;
}

@end
