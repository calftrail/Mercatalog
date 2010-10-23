//
//  TLTrackLayer.m
//  Mercatalog
//
//  Created by Nathan Vander Wilt on 9/29/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "TLTrackLayer.h"

#import "TLTrack.h"
#import "TLWaypoint.h"
#import "TLLocation.h"
#include "TLProjectionGeometry.h"
#import "TLMercatalogStyler.h"

@implementation TLTrackLayer

@synthesize dataSource;

- (void)reloadData {
	[self setNeedsDisplay];
}

- (CGPathRef)createPathForTrack:(TLTrack*)track
				 withProjection:(TLProjectionRef)proj
			significantDistance:(CGFloat)sigDist
{
	
	TLMutableCoordPolygonRef trackCoordPolyline = TLCoordPolygonCreateMutable([[track waypoints] count]);
	if (!trackCoordPolyline) return NULL;
	for (TLWaypoint* waypoint in [track waypoints]) {
		TLCoordinate coord = [[waypoint location] coordinate];
		TLCoordPolygonAppendCoordinate(trackCoordPolyline, coord);
	}
	TLMultiCoordPolygonRef trackMultiPoly = TLMultiCoordPolygonCreateFromPolygon(trackCoordPolyline);
	TLCoordPolygonRelease(trackCoordPolyline);
	if (!trackMultiPoly) return NULL;
	TLMultiPolygonRef projectedTrack = TLProjectedPolylineCreate(trackMultiPoly, proj, sigDist);
	TLMultiCoordPolygonRelease(trackMultiPoly);
	if (!projectedTrack) return NULL;
	
	// make path from projected segments
	tl_uint_t segmentsCount = TLMultiPolygonGetCount(projectedTrack);
	CGMutablePathRef path = CGPathCreateMutable();
	for (tl_uint_t segmentIdx = 0; segmentIdx < segmentsCount; ++segmentIdx) {
		TLPolygonRef segment = TLMultiPolygonGetPolygon(projectedTrack, segmentIdx);
		tl_uint_t numSegmentVertices = TLPolygonGetCount(segment);
		if (!numSegmentVertices) continue;
		CGPoint currentPoint = TLPolygonGetPoint(segment, 0);
		CGPathMoveToPoint(path, NULL, currentPoint.x, currentPoint.y);
		for (tl_uint_t ptIdx = 1; ptIdx < numSegmentVertices; ++ptIdx) {
			currentPoint = TLPolygonGetPoint(segment, ptIdx);
			CGPathAddLineToPoint(path, NULL, currentPoint.x, currentPoint.y);
		}
	}
	CFRelease(projectedTrack);
	
	return path;
}

- (void)drawInContext:(CGContextRef)ctx withInfo:(id < TLMapInfo >)mapInfo {
	TLProjectionRef proj = [mapInfo projection];
	NSArray* tracks = nil;
	if ([dataSource respondsToSelector:@selector(trackLayer:tracksInBounds:underProjection:)]) {
		CGRect boundsToDraw = CGContextGetClipBoundingBox(ctx);
		tracks = [dataSource trackLayer:self
						 tracksInBounds:boundsToDraw
						underProjection:proj];
	}
	
	TLMercatalogStyler* styler = [TLMercatalogStyler defaultStyler];
	CGContextSetStrokeColorWithColor(ctx, [styler trackColor]);
	CGFloat sigDist = TLSizeGetAverageWidth([mapInfo significantVisualSize]);
	CGFloat millimeterFactor = TLSizeGetAverageWidth([mapInfo millimeterSize]);
	CGContextSetLineWidth(ctx, [styler trackWidth] * millimeterFactor);
	CGContextSetLineCap(ctx, [styler trackLineCap]);
	
	for (TLTrack* track in tracks) {
		CGPathRef trackPath = [self createPathForTrack:track
										withProjection:proj
								   significantDistance:sigDist];
		CGContextAddPath(ctx, trackPath);
		CGPathRelease(trackPath);
		CGContextStrokePath(ctx);
	}
}

@end
