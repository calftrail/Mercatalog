//
//  TLMapLocationLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 11/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLMapLocationLayer.h"

#import "TLLocation.h"

#import "TLCocoaToolbag.h"
#import "TLGeometry.h"


static const NSUInteger TLMapLocationLayerOriginalAccuracyMask = NSAlternateKeyMask;

@interface TLMapLocationLayer ()
@property (nonatomic, copy) TLLocation* oldHomeBase;
@end


@implementation TLMapLocationLayer

#pragma mark Lifecycle

- (id)init {
	self = [super init];
	if (self) {
		// ...
	}
	return self;
}

- (void)dealloc {
	[homeBase release];
	[previewLocation release];
	[super dealloc];
}


#pragma mark Accessors

@synthesize delegate;
@synthesize homeBase;

- (void)setHomeBase:(TLLocation*)newHomeBase {
	[homeBase autorelease];
	homeBase = [newHomeBase copy];
	[self setNeedsDisplay];
}

@synthesize previewLocation;

- (void)setPreviewLocation:(TLLocation*)newPreviewLocation {
	[previewLocation autorelease];
	previewLocation = [newPreviewLocation copy];
	[self setNeedsDisplay];
}

@synthesize oldHomeBase;


#pragma mark Drawing

- (CGPathRef)homePathAtPoint:(CGPoint)homePoint
					withSize:(CGSize)mmSize
{
	CGFloat homeMillimeters = 3.0f;
	CGFloat homeWidth = homeMillimeters * 1.0f * mmSize.width;
	CGFloat homeHeight = homeMillimeters * 0.75f * mmSize.height;
	CGFloat homeLeftX = homePoint.x - homeWidth / 2.0f;
	CGFloat homeRightX = homePoint.x + homeWidth / 2.0f;
	CGFloat homeBaseY = homePoint.y - homeHeight / 2.0f;
	CGFloat gableBaseY = homePoint.y + homeHeight / 2.0f;
	CGFloat roofPeakY = homePoint.y + 2.0f * homeHeight / 2.0f;
	CGFloat roofPeakX = homePoint.x;
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, NULL, homeLeftX, gableBaseY);
	CGPathAddLineToPoint(path, NULL, homeLeftX, homeBaseY);
	CGPathAddLineToPoint(path, NULL, homeRightX, homeBaseY);
	CGPathAddLineToPoint(path, NULL, homeRightX, gableBaseY);
	CGPathAddLineToPoint(path, NULL, roofPeakX, roofPeakY);
	CGPathCloseSubpath(path);
	return TLCFAutorelease(path);
}

- (CGPathRef)crosshairPathAtPoint:(CGPoint)homePoint
						 withSize:(CGSize)mmSize
{
	CGFloat centerX = homePoint.x;
	CGFloat centerY = homePoint.y;
	const CGFloat gapMM = 1.0f;
	CGFloat gapX = gapMM * mmSize.width;
	CGFloat gapY = gapMM * mmSize.height;
	const CGFloat hairMM = 2.5f;
	CGFloat hairLengthX = hairMM * mmSize.width;
	CGFloat hairLengthY = hairMM * mmSize.height;
	
	CGMutablePathRef path = CGPathCreateMutable();
	CGPathMoveToPoint(path, NULL, centerX, centerY + gapY);
	CGPathAddLineToPoint(path, NULL, centerX, centerY + gapY + hairLengthY);
	CGPathMoveToPoint(path, NULL, centerX, centerY - gapY);
	CGPathAddLineToPoint(path, NULL, centerX, centerY - gapY - hairLengthY);
	CGPathMoveToPoint(path, NULL, centerX + gapX, centerY);
	CGPathAddLineToPoint(path, NULL, centerX + gapX + hairLengthX, centerY);
	CGPathMoveToPoint(path, NULL, centerX - gapX, centerY);
	CGPathAddLineToPoint(path, NULL, centerX - gapX - hairLengthX, centerY);
	return TLCFAutorelease(path);
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLMapInfo >)mapInfo {
	TLProjectionRef proj = [mapInfo projection];
	CGPoint homePoint = CGPointZero;
	TLProjectionError projErr = TLProjectionErrorNone;
	if ([self homeBase]) {
		TLCoordinate homeCoord = [homeBase originalCoordinate];
		homePoint = TLProjectionProjectCoordinate(proj, homeCoord, &projErr);
	}
	if ([self homeBase] && !projErr) {
		TLCoordinateAccuracy accuracy = [homeBase horizontalAccuracy];
		if (accuracy != TLCoordinateAccuracyUnknown) {
			CGColorRef accuracyColor = TLCGColorCreateGenericHSB(0.41667f, 0.5f, 1.0f, 0.5f);
			TLCFAutorelease(accuracyColor);
			CGGradientRef accuracyGradient = TLCGGradientCreateGaussian(accuracyColor, 1.0f, 3.0f);
			TLCFAutorelease(accuracyGradient);
			CGContextDrawRadialGradient(ctx, accuracyGradient,
										homePoint, 0.0f,
										homePoint, 3.0f * (CGFloat)accuracy, 0);
		}
		
		// draw home icon
		CGPathRef homePath = [self homePathAtPoint:homePoint
										  withSize:[mapInfo millimeterSize]];
		CGContextAddPath(ctx, homePath);
		CGColorRef homeColor = TLCGColorCreateGenericHSB(0.6806f, 0.85f, 0.75f, 0.75f);
		TLCFAutorelease(homeColor);
		CGContextSetFillColorWithColor(ctx, homeColor);
		CGContextFillPath(ctx);
		CGContextAddPath(ctx, homePath);
		CGColorRef outlineColor = TLCGColorCreateGenericHSB(0.58333f, 0.25f, 1.0f, 1.0f);
		TLCFAutorelease(outlineColor);
		CGContextSetStrokeColorWithColor(ctx, outlineColor);
		CGFloat outlineWidth = 0.1f * TLSizeGetAverageWidth([mapInfo millimeterSize]);
		CGContextSetLineWidth(ctx, outlineWidth);
		CGContextStrokePath(ctx);
	}
	
	projErr = TLProjectionErrorNone;
	CGPoint previewPoint = CGPointZero;
	if ([self previewLocation]) {
		TLCoordinate previewCoord = [previewLocation originalCoordinate];
		previewPoint = TLProjectionProjectCoordinate(proj, previewCoord, &projErr);
	}
	if ([self previewLocation] && !projErr) {
		TLCoordinateAccuracy accuracy = [previewLocation horizontalAccuracy];
		if (accuracy != TLCoordinateAccuracyUnknown) {
			CGColorRef accuracyColor = TLCGColorCreateGenericHSB(50.0f/360.0f, 0.85f, 0.8f, 0.5f);
			TLCFAutorelease(accuracyColor);
			CGGradientRef accuracyGradient = TLCGGradientCreateGaussian(accuracyColor, 1.0f, 3.0f);
			TLCFAutorelease(accuracyGradient);
			CGContextDrawRadialGradient(ctx, accuracyGradient,
										previewPoint, 0.0f,
										previewPoint, 3.0f * (CGFloat)accuracy, 0);
		}
		
		// draw crosshairs
		CGPathRef homePath = [self crosshairPathAtPoint:previewPoint
											   withSize:[mapInfo millimeterSize]];
		CGContextAddPath(ctx, homePath);
		CGColorRef crosshairColor = TLCGColorCreateGenericHSB(0.0f, 0.5f, 0.2f, 0.9f);
		TLCFAutorelease(crosshairColor);
		CGContextSetStrokeColorWithColor(ctx, crosshairColor);
		CGFloat crosshairWidth = 0.2f * TLSizeGetAverageWidth([mapInfo millimeterSize]);
		CGContextSetLineWidth(ctx, crosshairWidth);
		CGContextStrokePath(ctx);
	}
}


#pragma mark Mouse handling

- (BOOL)hitTest:(NSPoint)windowPoint
	  withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLMapInfo >)mapInfo
{
	(void)mouseEventOrNil;
	if (![self homeBase]) return NO;
	TLProjectionError projErr = TLProjectionErrorNone;
	CGPoint homePoint = TLProjectionProjectCoordinate([mapInfo projection],
													  [[self homeBase] originalCoordinate],
													  &projErr);
	if (projErr) return NO;
	
	CGPoint mouseOnMap = [mapInfo convertWindowPointToMap:windowPoint];
	CGPathRef homePath = [self homePathAtPoint:homePoint
									  withSize:[mapInfo millimeterSize]];
	return CGPathContainsPoint(homePath, NULL, mouseOnMap, false);
}

- (void)mouseDown:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	TLProjectionError projErr = TLProjectionErrorNone;
	CGPoint homePoint = TLProjectionProjectCoordinate([mapInfo projection],
													  [[self homeBase] originalCoordinate],
													  &projErr);
	if (projErr) return;
	
	NSPoint homeInWindow = [mapInfo convertMapPointToWindow:homePoint];
	NSPoint mouseInWindow = [mouseEvent locationInWindow];
	dragOffset = NSMakePoint(mouseInWindow.x - homeInWindow.x,
							 mouseInWindow.y - homeInWindow.y);
	
	[self setOldHomeBase:[self homeBase]];
}

- (TLLocation*)homeLocationWithCoordinate:(TLCoordinate)homeCoord
									event:(NSEvent*)event
								  mapInfo:(id < TLMapInfo >)mapInfo
{
	TLCoordinateAccuracy accuracy = TLCoordinateAccuracyUnknown;
	if ([event modifierFlags] & TLMapLocationLayerOriginalAccuracyMask) {
		accuracy = [[self oldHomeBase] horizontalAccuracy];
	}
	else {
		CGPathRef homePath = [self homePathAtPoint:CGPointZero
										  withSize:[mapInfo millimeterSize]];
		CGRect pathBounds = CGPathGetBoundingBox(homePath);
		accuracy = TLSizeGetAverageWidth(pathBounds.size) / 2.0;
	}
	return [TLLocation locationWithCoordinate:homeCoord
						   horizontalAccuracy:accuracy];
}

- (void)mouseDragged:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	NSPoint mouseInWindow = [mouseEvent locationInWindow];
	NSPoint homeInWindow = NSMakePoint(mouseInWindow.x - dragOffset.x, 
									   mouseInWindow.y - dragOffset.y);
	CGPoint homePoint = [mapInfo convertWindowPointToMap:homeInWindow];
	
	TLProjectionError projErr = TLProjectionErrorNone;
	TLCoordinate homeCoord = TLProjectionUnprojectPoint([mapInfo projection],
														homePoint,
														&projErr);
	if (projErr) return;
	
	TLLocation* newHomeBase = [self homeLocationWithCoordinate:homeCoord
														 event:mouseEvent
													   mapInfo:mapInfo];
	[self setHomeBase:newHomeBase];
}

- (void)flagsChanged:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)event {
	if (!oldHomeBase) return;
	TLCoordinate homeCoord = [[self homeBase] originalCoordinate];
	TLLocation* newHomeBase = [self homeLocationWithCoordinate:homeCoord
														 event:event
													   mapInfo:mapInfo];
	[self setHomeBase:newHomeBase];
}

- (void)mouseUp:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	(void)mapInfo;
	(void)mouseEvent;
	if ([[self delegate] respondsToSelector:@selector(mapLocationLayerDidSetHomeBase:)]) {
		[[self delegate] mapLocationLayerDidSetHomeBase:self];
	}
	[self setOldHomeBase:nil];
	dragOffset = NSZeroPoint;
}


@end
