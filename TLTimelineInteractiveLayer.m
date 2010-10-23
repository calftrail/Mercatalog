//
//  TLTimelineInteractiveLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTimelineInteractiveLayer.h"
#import "TLTimelineLayer+HostInternals.h"

#import "TLTimelineView.h"
#import "TLTimelineView+HostInternals.h"


@implementation TLTimelineInteractiveLayer

#pragma mark Mouse event handling

- (BOOL)hitTest:(NSPoint)windowPoint withEvent:(NSEvent*)mouseEventOrNil withInfo:(id < TLTimelineInfo >)timelineInfo; {
	(void)windowPoint;
	(void)mouseEventOrNil;
	(void)timelineInfo;
	return NO;
}

- (void)mouseDown:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEvent;
	(void)timelineInfo;
}

- (void)mouseDragged:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEvent;
	(void)timelineInfo;
}

- (void)mouseUp:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEvent;
	(void)timelineInfo;
}

- (NSPoint)mouseLocationInWindow {
	NSAssert([self host], @"Host must be set to get mouse location");
	return [[self host] mouseLocationInWindow];
}

- (BOOL)wantsScrollEvents {
	return NO;
}

- (void)scrollWheel:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEvent;
	(void)timelineInfo;
}

- (void)flagsChanged:(NSEvent*)event withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)event;
	(void)timelineInfo;
}


#pragma mark Tracking zones

- (NSArray*)activeTrackingZones {
	return [[self host] activeTrackingZonesForLayer:self];
}

- (void)setActiveTrackingZones:(NSArray*)newTrackingZones {
	[[self host] setActiveTrackingZones:newTrackingZones forLayer:self];
}

- (void)mouseEntered:(NSEvent*)mouseEventOrNil trackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEventOrNil;
	(void)zone;
	(void)timelineInfo;
}

- (void)mouseMoved:(NSEvent*)mouseEventOrNil inTrackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEventOrNil;
	(void)zone;
	(void)timelineInfo;
}

- (void)mouseExited:(NSEvent*)mouseEventOrNil trackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)mouseEventOrNil;
	(void)zone;
	(void)timelineInfo;
}


#pragma mark Drag source (internal)

- (NSPasteboard*)dragPasteboard {
	return [[self host] dragPasteboardForLayer:self];
}

- (void)dragWithImage:(CGImageRef)image anchor:(CGPoint)imagePoint slideBack:(BOOL)shouldSlideBack {
	[[self host] dragFromLayer:self withImage:image anchor:imagePoint slideBack:shouldSlideBack];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal {
	// wrap renamed layer method
	return [self dragSourceOperationMaskForLocal:isLocal];
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation {
	(void)anImage;
	(void)aPoint;
	// wrap refactored layer method
	[self dragEndedWithOperation:operation];
}


#pragma mark Drag source (default implementations)

- (NSDragOperation)dragSourceOperationMaskForLocal:(BOOL)isLocal {
	(void)isLocal;
	return NSDragOperationNone;
}

- (NSArray*)namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination {
	// NOTE: subclass *must* override if promise drag possible
	[self doesNotRecognizeSelector:_cmd];
	
	// suppress compiler warnings
	(void)dropDestination;
	return nil;
}

- (void)dragEndedWithOperation:(NSDragOperation)operation {
	(void)operation;
}


#pragma mark Drag destination

@synthesize registeredDropTypes;

- (void)setRegisteredDropTypes:(NSArray*)newRegisteredDropTypes {
	[registeredDropTypes autorelease];
	registeredDropTypes = [newRegisteredDropTypes copy];
	[[self host] updateDropTypesForLayer:self];
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	return NSDragOperationNone;
}

- (BOOL)wantsPeriodicDraggingUpdates:(id < TLTimelineInfo >)timelineInfo {
	(void)timelineInfo;
	return NO;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	return NSDragOperationNone;
}

- (void)draggingExited:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;	
}

- (BOOL)prepareForDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	return NO;
}

- (BOOL)performDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
	return NO;
}

- (void)concludeDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
}

- (void)draggingEnded:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo {
	(void)dropInfo;
	(void)timelineInfo;
}

@end
