//
//  TLGPXWaypoint.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 3/17/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLGPXWaypoint.h"


@implementation TLGPXWaypoint

- (id)initWithParent:(TLGPXNode*)theParent
		  forElement:(NSString*)elementName
		namespaceURI:(NSString*)namespaceURI
	   qualifiedName:(NSString*)qualifiedName
		  attributes:(NSDictionary*)attributes
{
	self = [super initWithParent:theParent
					  forElement:elementName
					namespaceURI:namespaceURI
				   qualifiedName:qualifiedName
					  attributes:attributes];
	if (self) {
		coordinate.lat = [[attributes valueForKey:@"lat"] doubleValue];
		coordinate.lon = [[attributes valueForKey:@"lon"] doubleValue];
		elevation = TLCoordinateAltitudeUnknown;
	}
	return self;
}

- (void)dealloc {
	[time release];
	[name release];
	[super dealloc];
}


#pragma mark Parsing out of XML

- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI
 qualifiedName:(NSString*)qualifiedName
	attributes:(NSDictionary*)attributeDict
{
	(void)parser;
	(void)namespaceURI;
	(void)qualifiedName;
	(void)attributeDict;
	if ([elementName isEqualToString:@"time"] ||
		[elementName isEqualToString:@"name"] ||
		[elementName isEqualToString:@"ele"] ||
		[elementName isEqualToString:@"hdop"] ||
		[elementName isEqualToString:@"vdop"] ||
		[elementName isEqualToString:@"pdop"])
	{
		[self setGatheringCharacters:YES];
	}
}

static NSDate* TLNSDateFromStandardString(NSString* str) {
	NSDateFormatter* formatISO8601 = [[[NSDateFormatter alloc] init] autorelease];
	[formatISO8601 setTimeStyle:NSDateFormatterFullStyle];
	[formatISO8601 setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
	NSDate* date = [formatISO8601 dateFromString:str];
	if (!date) {
		NSDateFormatter* formatISO8601milliseconds = [[[NSDateFormatter alloc] init] autorelease];
		[formatISO8601milliseconds setTimeStyle:NSDateFormatterFullStyle];
		[formatISO8601milliseconds setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSS'Z'"];
		date = [formatISO8601milliseconds dateFromString:str];
	}
	return date;
}

- (void)parser:(NSXMLParser*)parser didEndElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI
 qualifiedName:(NSString*)qualifiedName
{
	if ([elementName isEqualToString:@"time"]) {
		time = [TLNSDateFromStandardString([self gatheredCharacters]) copy];
		if (!time) NSLog(@"Could not convert string '%@' to a date!", [self gatheredCharacters]);
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"ele"]) {
		elevation = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"name"]) {
		name = [[self gatheredCharacters] copy];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"hdop"]) {
		horizontalDOP = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"vdop"]) {
		verticalDOP = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else if ([elementName isEqualToString:@"pdop"]) {
		positionDOP = [[self gatheredCharacters] doubleValue];
		[self setGatheringCharacters:NO];
	}
	else {
		[super parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qualifiedName];
	}
}


#pragma mark Accessors

@synthesize name;
@synthesize time;
@synthesize coordinate;
@synthesize elevation;
@synthesize horizontalDOP;
@synthesize verticalDOP;
@synthesize positionDOP;

@end
