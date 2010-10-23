//
//  TLGPXFile.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 3/17/08.
//  Copyright 2008 Calf Trail Software, LLC. All rights reserved.
//

#import "TLGPXFile.h"

@implementation TLGPXFile

- (id)initGPXFileWithContentsOfURL:(NSURL*)url error:(NSError**)error {
	(void)error; /* TODO: better error handling, including NSAssert1 in waypoint date */
	self = [super init];
	if (self) {
		tracks = [[NSMutableArray array] retain];
		waypoints = [[NSMutableArray array] retain];
		NSXMLParser* parser = [[NSXMLParser alloc] initWithContentsOfURL:url];
		[parser setDelegate:self];
		//(void)[parser parse];
		BOOL success = [parser parse];
		if (!success) {
			printf("Parse error: %s\n (For url: %s)\n", [[[parser parserError] localizedDescription] UTF8String], [[url description] UTF8String]);
		}
	}
	return self;
}

- (void)dealloc {
	[tracks release];
	[waypoints release];
	[super dealloc];
}

- (void)parser:(NSXMLParser*)parser didStartElement:(NSString*)elementName
  namespaceURI:(NSString*)namespaceURI
 qualifiedName:(NSString*)qualifiedName
	attributes:(NSDictionary*)attributeDict
{
	(void)namespaceURI; // TODO: check namespaceURI equal to GPX/1/1 ?
	(void)qualifiedName;
	if ([elementName isEqualToString:@"trk"]) {
		TLGPXTracklog* newTrack = [[TLGPXTracklog alloc] initWithParent:self
															 forElement:elementName
														   namespaceURI:namespaceURI
														  qualifiedName:qualifiedName
															 attributes:attributeDict];
		[parser setDelegate:newTrack];
		[tracks addObject:[newTrack autorelease]];
	}
	else if ([elementName isEqualToString:@"wpt"]) {
		TLGPXWaypoint* newWaypoint = [[TLGPXWaypoint alloc] initWithParent:self
																forElement:elementName
															  namespaceURI:namespaceURI
															 qualifiedName:qualifiedName
																attributes:attributeDict];
		[parser setDelegate:newWaypoint];
		[waypoints addObject:[newWaypoint autorelease]];
	}
}

- (NSArray*)tracks { return tracks; }
- (NSArray*)waypoints { return waypoints; }

@end

