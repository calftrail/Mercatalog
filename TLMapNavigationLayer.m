//
//  TLMapNavigationLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 10/27/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLMapNavigationLayer.h"

#import "TLMapView.h"
#import "TLMapLayer+HostInternals.h"

#import "TLMercatalogStyler.h"
#import "TLMercatalogViewShared.h"

#include "TLProjectionInfo.h"
#include "TLProjectionGeometry.h"
#include "TLFloat.h"
#import "TLCocoaToolbag.h"

const NSTimeInterval TLNavigationDragDelay = 250.0 / 1000.0;
static const BOOL TLMapNavigationScrollMayPan = YES;
static const NSUInteger TLMapNavigationPanModifier = NSAlternateKeyMask;
static const CGFloat TLMapNavigationScrollZoomScale = 0.1f;

@interface TLMapNavigationLayer ()
@property (nonatomic, assign, getter=isDragging) BOOL dragging;

- (void)setHostProjection:(TLProjectionRef)proj;
- (void)setHostBounds:(TLBounds)bounds;

- (void)mapZoomedTo:(TLBounds)selectedBounds withInfo:(id < TLMapInfo >)mapInfo;
- (void)mapZoomedFrom:(CGPoint)anchorPoint
			 byAmount:(CGFloat)zoomPercent
			 withInfo:(id < TLMapInfo >)mapInfo;
- (void)mapPannedFrom:(CGPoint)mouseOnMapBegin to:(CGPoint)mouseOnMapEnd withInfo:(id < TLMapInfo >)mapInfo;

@end


/*
 Robinson for whole world
 Mercator tolerable for ±60º latitude, ideal to ±45º
 Stereographic tolerable for areas within ~30º radius from center
 */

enum {
	TLMapZoomWorld = 0,
	TLMapZoomHemisphere,
	TLMapZoomRegion,
	TLMapZoomLocal
};
typedef tl_uint_t TLMapViewZoomLevel;

static inline CGSize TLPointDifference(CGPoint a, CGPoint b);
static inline CGPoint TLBoundsGetCenter(TLBounds);
static TLMapViewZoomLevel TLMapViewClassifyBounds(TLBounds bounds, TLProjectionRef proj);
static TLProjectionRef TLMapViewCreateProjectionForZoom(TLMapViewZoomLevel level, TLCoordinate center);

#define TLMapViewPercentAdjustment 1.10
static const TLCoordinateDegrees TLMapViewMinWorldPercent = 0.5 * TLMapViewPercentAdjustment;
static const TLCoordinateDegrees TLMapViewMinHemispherePercent = 0.1 * TLMapViewPercentAdjustment;
static const TLCoordinateDegrees TLMapViewMinRegionPercent = 0.005 * TLMapViewPercentAdjustment;


@implementation TLMapNavigationLayer

#pragma mark Drawing

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLMapInfo >)mapInfo {
	if (![self isDragging] || initialClickWasHeld) return;
	
	TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
	CGFloat mmScale = TLSizeGetAverageWidth([mapInfo millimeterSize]);
	CGContextSetLineWidth(ctx, mmScale * [styler zoomBoxWidth]);
	
	bool zoomingOut = TLNavigationIsReverseZoom(dragStart, dragCurrent);
	CGFloat zoomBoxHue = 135.0f;
	CGContextSetFillColorWithColor(ctx, [styler zoomBoxFillColorWithHueDegrees:zoomBoxHue]);
	if (!zoomingOut) {
		TLBounds visibleBounds = CGContextGetClipBoundingBox(ctx);
		CGContextFillRect(ctx, visibleBounds);
	}
	
	CGContextSetStrokeColorWithColor(ctx, [styler zoomBoxStrokeColorWithHueDegrees:zoomBoxHue]);
	TLBounds selectionBounds = TLCGRectMakeFromPoints(dragStart, dragCurrent);
	if (!zoomingOut) {
		CGContextClearRect(ctx, selectionBounds);
	}
	else {
		CGContextFillRect(ctx, selectionBounds);
	}
	CGContextStrokeRect(ctx, selectionBounds);
}


#pragma mark Accessors

@synthesize delegate;

@synthesize dragging;

- (void)setDragging:(BOOL)newDragging {
	dragging = newDragging;
	[self setNeedsDisplay];
}


#pragma mark Mouse event handling

- (BOOL)hitTest:(NSPoint)windowPoint
	   withEvent:(NSEvent*)mouseEventOrNil
	   withInfo:(id < TLMapInfo >)mapInfo
{
	(void)windowPoint;
	(void)mouseEventOrNil;
	(void)mapInfo;
	return YES;
}

- (void)mouseDown:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	initialClickWasHeld = NO;
	[self setDragging:NO];
	NSPoint dragInWindow = [mouseEvent locationInWindow];
	dragStart = [mapInfo convertWindowPointToMap:dragInWindow];
	dragCurrent = dragStart;
	[[NSCursor crosshairCursor] push];
	[self performSelector:@selector(checkClickHeld) withObject:nil afterDelay:TLNavigationDragDelay];
}

- (void)checkClickHeld {
	if ([self isDragging]) return;
	initialClickWasHeld = YES;
	[NSCursor pop];
	[[NSCursor closedHandCursor] push];
}

- (void)mouseDragged:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	NSPoint dragInWindow = [mouseEvent locationInWindow];
	dragCurrent = [mapInfo convertWindowPointToMap:dragInWindow];
	[self setDragging:YES];
	
	if (initialClickWasHeld) {
		// mouse deltaY is always flipped
		NSPoint dragInWindowPrevious = NSMakePoint((dragInWindow.x - [mouseEvent deltaX]),
												   (dragInWindow.y + [mouseEvent deltaY]));
		CGPoint mouseOnMapBegin = [mapInfo convertWindowPointToMap:dragInWindowPrevious];
		CGPoint mouseOnMapEnd = dragCurrent;
		[self mapPannedFrom:mouseOnMapBegin to:mouseOnMapEnd withInfo:mapInfo];
	}
}

- (void)mouseUp:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	[self setDragging:NO];
	NSPoint dragInWindow = [mouseEvent locationInWindow];
	dragCurrent = [mapInfo convertWindowPointToMap:dragInWindow];
	
	if (!initialClickWasHeld) {
		TLBounds selectedBounds = TLBoundsMakeFromPoints(dragStart, dragCurrent);
		if (TLFloatEqual(selectedBounds.size.width, 0.0) &&
			TLFloatEqual(selectedBounds.size.height, 0.0) &&
			[[self delegate] respondsToSelector:@selector(mapNavigationLayerDidIgnoreClick:)])
		{
			[[self delegate] mapNavigationLayerDidIgnoreClick:self];
		}
		else if (!TLFloatEqual(selectedBounds.size.width, 0.0) &&
				 !TLFloatEqual(selectedBounds.size.height, 0.0))
		{
			if (TLNavigationIsReverseZoom(dragStart, dragCurrent)) {
				TLBounds displayedBounds = [mapInfo visibleBounds];
				CGAffineTransform reverseZoom = TLTransformFromRectToRect(selectedBounds,
																		  displayedBounds,
																		  TLAspectIgnore);
				TLBounds reverseBounds = CGRectApplyAffineTransform(displayedBounds, reverseZoom);
				[self mapZoomedTo:reverseBounds withInfo:mapInfo];
			}
			else {
				[self mapZoomedTo:selectedBounds withInfo:mapInfo];
			}
		}
	}
	[NSCursor pop];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkClickHeld) object:nil];
}

- (BOOL)wantsScrollEvents {
	return YES;
}

- (void)scrollWheel:(id < TLMapInfo >)mapInfo withEvent:(NSEvent*)mouseEvent {
	NSPoint mouseInWindow = [mouseEvent locationInWindow];
	CGPoint mouseOnMap = [mapInfo convertWindowPointToMap:mouseInWindow];
	BOOL panRequested = TLBooleanCast([mouseEvent modifierFlags] & TLMapNavigationPanModifier);
	if (TLMapNavigationScrollMayPan && panRequested) {
		NSPoint scrollInWindow = NSMakePoint(mouseInWindow.x - [mouseEvent deltaX],
											 mouseInWindow.y + [mouseEvent deltaY]);
		CGPoint scrollInMap = [mapInfo convertWindowPointToMap:scrollInWindow];
		[self mapPannedFrom:scrollInMap to:mouseOnMap withInfo:mapInfo];
	}
	else {
		// scrolling down (negative delta) should zoom out
		CGFloat zoomPercent = TLMapNavigationScrollZoomScale * [mouseEvent deltaY];
		[self mapZoomedFrom:mouseOnMap byAmount:zoomPercent withInfo:mapInfo];
	}
}


#pragma mark Host handling

- (void)setHostProjection:(TLProjectionRef)proj {
	[[self host] setProjection:proj];
	// NOTE: the following line is to make sure bounds are still valid after changing projection
	[self setHostBounds:[[self host] desiredBounds]];
}

- (void)setHostBounds:(TLBounds)bounds {
	TLProjectionName hostProjName = TLProjectionGetName([[self host] projection]);
	if (TLProjectionNamesEqual(hostProjName, TLProjectionNameRobinson)) {
		TLBounds maxBounds = TLProjectionInfoDefaultBounds([[self host] projection]);
		bounds = CGRectIntersection(maxBounds, bounds);
	}
	TLBounds minBounds = TLCGRectMakeAroundPoint(TLCGRectGetCenter(bounds), 2.0f, 2.0f);
	bounds = CGRectUnion(minBounds, bounds);
	[[self host] setDesiredBounds:bounds];
}


#pragma mark Projection handling

- (void)mapZoomedFrom:(CGPoint)anchorPoint
			   byAmount:(CGFloat)zoomPercent
			   withInfo:(id < TLMapInfo >)mapInfo
{
	// find anchor coordinate
	TLProjectionRef oldProj = [mapInfo projection];
	TLProjectionError err = TLProjectionErrorNone;
	TLCoordinate anchorCoord = TLProjectionUnprojectPoint(oldProj, anchorPoint, &err);
	if (err) return;
	
	// find "selected" bounds
	CGFloat scaleFactor = NAN;
	if (zoomPercent < 0.0f) {
		scaleFactor = 1.0f - zoomPercent;
	}
	else {
		scaleFactor = 1.0f / (1.0f + zoomPercent);
	}
	CGAffineTransform zoom = CGAffineTransformMakeTranslation(anchorPoint.x, anchorPoint.y);
	zoom = CGAffineTransformScale(zoom, scaleFactor, scaleFactor);
	zoom = CGAffineTransformTranslate(zoom, -anchorPoint.x, -anchorPoint.y);
	TLBounds zoomedBounds = CGRectApplyAffineTransform([mapInfo visibleBounds], zoom);
	
	// determine appropriate projection
	TLMapViewZoomLevel newZoomLevel = TLMapViewClassifyBounds(zoomedBounds, oldProj);
	TLCoordinate zoomCenter = TLProjectionUnprojectPoint(oldProj, TLBoundsGetCenter(zoomedBounds), &err);
	if (err) return;
	TLProjectionRef newProj = TLMapViewCreateProjectionForZoom(newZoomLevel, zoomCenter);
	
	// determine appropriate bounds
	CGPoint newAnchorPoint = TLProjectionProjectCoordinate(newProj, anchorCoord, &err);
	if (err) {
		TLProjectionRelease(newProj);
		return;
	}
	TLBounds oldBounds = [mapInfo visibleBounds];
	CGFloat anchorTravelX = (anchorPoint.x - oldBounds.origin.x) / oldBounds.size.width;
	CGFloat anchorTravelY = (anchorPoint.y - oldBounds.origin.y) / oldBounds.size.height;
	CGFloat newOriginX = newAnchorPoint.x - (anchorTravelX * zoomedBounds.size.width);
	CGFloat newOriginY = newAnchorPoint.y - (anchorTravelY * zoomedBounds.size.height);
	TLBounds newBounds = CGRectMake(newOriginX, newOriginY, zoomedBounds.size.width, zoomedBounds.size.height);
	
	[self setHostBounds:newBounds];
	[self setHostProjection:newProj];
	TLProjectionRelease(newProj);
}

- (void)mapZoomedTo:(TLBounds)selection withInfo:(id < TLMapInfo >)mapInfo {
	TLProjectionRef oldProj = [mapInfo projection];
	
	CGPoint selectionCenter = TLBoundsGetCenter(selection);
	TLProjectionError err = TLProjectionErrorNone;
	TLCoordinate newCenter = TLProjectionUnprojectPoint(oldProj, selectionCenter, &err);
	if (err) return;
	
	// determine appropriate projection
	TLMapViewZoomLevel newZoomLevel = TLMapViewClassifyBounds(selection, oldProj);
	TLProjectionRef newProj = TLMapViewCreateProjectionForZoom(newZoomLevel, newCenter);
	
	// determine appropriate bounds
	err = TLProjectionErrorNone;
	CGPoint newCenterPoint = TLProjectionProjectCoordinate(newProj, newCenter, &err);
	if (err) {
		TLProjectionRelease(newProj);
		return;
	}
	TLBounds newBounds = TLCGRectMakeAroundPoint(newCenterPoint,
												 selection.size.width,
												 selection.size.height);
	[self setHostBounds:newBounds];
	[self setHostProjection:newProj];
	TLProjectionRelease(newProj);
}

- (void)mapPannedFrom:(CGPoint)dragOrigin to:(CGPoint)dragDestination withInfo:(id < TLMapInfo >)mapInfo {
	// determine new projection
	TLBounds oldBounds = [mapInfo visibleBounds];
	TLProjectionRef oldProj = [mapInfo projection];
	TLProjectionError err = TLProjectionErrorNone;
	TLCoordinate originalCoord = TLProjectionUnprojectPoint(oldProj, dragOrigin, &err);
	if (err) return;
	TLCoordinate destinationCoord = TLProjectionUnprojectPoint(oldProj, dragDestination, &err);
	if (err) return;
	TLCoordinateDegrees dLat = destinationCoord.lat - originalCoord.lat;
	TLCoordinateDegrees dLon = destinationCoord.lon - originalCoord.lon;
	TLCoordinate oldProjCenter = TLProjectionInfoGetCenter(oldProj);
	TLCoordinateDegrees shiftedLat = TLCoordinateLatitudeClampToRange(oldProjCenter.lat - dLat);
	TLCoordinateDegrees shiftedLon = TLCoordinateLongitudeAdjustToRange(oldProjCenter.lon - dLon);
	TLCoordinate shiftedCenterCoord = TLCoordinateMake(shiftedLat, shiftedLon);
	TLMapViewZoomLevel zoomLevel = TLMapViewClassifyBounds(oldBounds, oldProj);
	TLProjectionRef newProj = TLMapViewCreateProjectionForZoom(zoomLevel, shiftedCenterCoord);
	
	// determine new bounds (originalCoord must be under dragDestination now)
	CGPoint newAnchorPoint = TLProjectionProjectCoordinate(newProj, originalCoord, &err);
	if (err) {
		TLProjectionRelease(newProj);
		return;
	}
	CGFloat anchorTravelX = (dragDestination.x - oldBounds.origin.x) / oldBounds.size.width;
	CGFloat anchorTravelY = (dragDestination.y - oldBounds.origin.y) / oldBounds.size.height;
	CGSize newSize = oldBounds.size;
	CGFloat newOriginX = newAnchorPoint.x - (anchorTravelX * newSize.width);
	CGFloat newOriginY = newAnchorPoint.y - (anchorTravelY * newSize.height);
	TLBounds newBounds = CGRectMake(newOriginX, newOriginY, newSize.width, newSize.height);
	
	[self setHostProjection:newProj];
	[self setHostBounds:newBounds];
	TLProjectionRelease(newProj);
}

- (IBAction)zoomCompletelyOut:(id)sender {
	(void)sender;
	TLProjectionRef oldProj = [[self host] projection];
	TLCoordinate oldCenter = TLProjectionInfoGetCenter(oldProj);
	TLProjectionRef newProj = TLMapViewCreateProjectionForZoom(TLMapZoomWorld, oldCenter);
	if (!newProj) return;
	
	TLBounds defaultBounds = TLProjectionInfoDefaultBounds(newProj);
	[self setHostProjection:newProj];
	[self setHostBounds:defaultBounds];
	TLProjectionRelease(newProj);
}

@end


#pragma mark Helper functions

CGSize TLPointDifference(CGPoint a, CGPoint b) {
	return CGSizeMake(b.x - a.x, b.y - a.y);
}

CGPoint TLBoundsGetCenter(TLBounds bounds) {
	return CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

static inline double TLBoundsGetArea(TLBounds bounds) {
	return bounds.size.width * bounds.size.height;
}

static double TLProjectionInfoGetScaledArea(TLProjectionRef proj) {
	TLProjectionGeoidRef geoid = TLProjectionGetPlanetModel(proj);
	// NOTE: this ignores ellipsoidal shaped geoid differences
	TLProjectionGeoidMeters geoidRadius = TLProjectionGeoidGetEquatorialRadius(geoid);
	// NOTE: this code assumes that the projection's scale factor is unchangeable
	TLProjectionGeoidMeters scaledRadius = 1.0 * geoidRadius;
	return 4.0 * M_PI * scaledRadius * scaledRadius;
}

static double TLBoundsEstimatePercentArea(TLBounds bounds, TLProjectionRef proj) {
	double totalArea = TLProjectionInfoGetScaledArea(proj);
	double estimatedBoundsArea = TLBoundsGetArea(bounds);
	return (estimatedBoundsArea / totalArea);
}

TLMapViewZoomLevel TLMapViewClassifyBounds(TLBounds bounds, TLProjectionRef proj) {
	double percentCovered = TLBoundsEstimatePercentArea(bounds, proj);
	//printf("Selection covers %f%%\n", percentCovered * 100.0);
	
	TLMapViewZoomLevel zoomLevel = TLMapZoomLocal;
	if (percentCovered > TLMapViewMinWorldPercent) {
		zoomLevel = TLMapZoomWorld;
	}
	else if (percentCovered > TLMapViewMinHemispherePercent) {
		zoomLevel = TLMapZoomHemisphere;
	}
	else if (percentCovered > TLMapViewMinRegionPercent) {
		zoomLevel = TLMapZoomRegion;
	}
	else {
		zoomLevel = TLMapZoomLocal;
	}
	return zoomLevel;
}

TLProjectionRef TLMapViewCreateProjectionForZoom(TLMapViewZoomLevel level, TLCoordinate center) {
	TLProjectionName projName = NULL;
	if (level == TLMapZoomWorld) {
		projName = TLProjectionNameRobinson;
	}
	else if (level == TLMapZoomHemisphere || level == TLMapZoomRegion) {
		if ( fabs(center.lat) < 50.0 ) {
			projName = TLProjectionNameMercator;
		}
		else {
			projName = TLProjectionNameStereographic;
		}
	}
	else if (level == TLMapZoomLocal) {
		if ( fabs(center.lat) < 35.0 ) {
			projName = TLProjectionNameMercator;
		}
		else {
			projName = TLProjectionNameStereographic;
		}
	}
	NSCAssert(projName, @"Unknown zoom level");
	
	TLProjectionGeoidRef projGeoid = TLProjectionGeoidWGS84;
	TLMutableProjectionParametersRef projParams = TLProjectionParametersCreateMutable();
	TLProjectionParametersSetLatitudeOfOrigin(projParams, center.lat);
	TLProjectionParametersSetLongitudeOfOrigin(projParams, center.lon);
	
	TLProjectionError err = TLProjectionErrorNone;
	TLProjectionRef proj = TLProjectionCreate(projName, projGeoid, projParams, &err);
	TLProjectionParametersRelease(projParams);
	if (err && proj) {
		TLProjectionRelease(proj);
		proj = NULL;
	}
	return proj;
}

bool TLNavigationIsReverseZoom(CGPoint startPoint, CGPoint endPoint) {
	return (startPoint.x > endPoint.x);
}
