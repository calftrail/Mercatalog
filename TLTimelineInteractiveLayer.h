//
//  TLTimelineInteractiveLayer.h
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/14/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TLTimelineLayer.h"

#import "TLTrackingZone.h"

@interface TLTimelineInteractiveLayer : TLTimelineLayer {
@private
	NSArray* registeredDropTypes;
}

// mouse events
- (BOOL)hitTest:(NSPoint)windowPoint
	  withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)mouseDown:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)mouseDragged:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)mouseUp:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo;
- (NSPoint)mouseLocationInWindow;

- (BOOL)wantsScrollEvents;
- (void)scrollWheel:(NSEvent*)mouseEvent withInfo:(id < TLTimelineInfo >)timelineInfo;

- (void)flagsChanged:(NSEvent*)event withInfo:(id < TLTimelineInfo >)timelineInfo;

// tracking zone events
@property (nonatomic, copy) NSArray* activeTrackingZones;
- (void)mouseEntered:(NSEvent*)mouseEventOrNil trackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)mouseMoved:(NSEvent*)mouseEventOrNil inTrackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)mouseExited:(NSEvent*)mouseEventOrNil trackingZone:(TLTrackingZone*)zone withInfo:(id < TLTimelineInfo >)timelineInfo;

// drag and drop source
- (NSPasteboard*)dragPasteboard;
- (void)dragWithImage:(CGImageRef)image anchor:(CGPoint)imagePoint slideBack:(BOOL)shouldSlideBack;
- (NSDragOperation)dragSourceOperationMaskForLocal:(BOOL)isLocal;
- (NSArray*)namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination;
- (void)dragEndedWithOperation:(NSDragOperation)operation;

// drag and drop destination
@property (nonatomic, copy) NSArray* registeredDropTypes;
- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;
- (BOOL)wantsPeriodicDraggingUpdates:(id < TLTimelineInfo >)timelineInfo;
- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)draggingExited:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;
- (BOOL)prepareForDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;
- (BOOL)performDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)concludeDropOperation:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;
- (void)draggingEnded:(id < NSDraggingInfo >)dropInfo withInfo:(id < TLTimelineInfo >)timelineInfo;

@end
