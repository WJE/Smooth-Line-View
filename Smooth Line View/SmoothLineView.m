//  The MIT License (MIT)
//
//  Copyright (c) 2013 Levi Nunnink
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//
//  Created by Levi Nunnink (@a_band) http://culturezoo.com
//  Copyright (C) Droplr Inc. All Rights Reserved
//

#import "SmoothLineView.h"
#import <QuartzCore/QuartzCore.h>

#define DEFAULT_COLOR               [UIColor blackColor]
#define DEFAULT_WIDTH               5.0f
#define DEFAULT_BACKGROUND_COLOR    [UIColor whiteColor]

#define USE_SYNCHRONIZED 1

//static const CGFloat kPointMinDistance = 5.0f;
//static const CGFloat kPointMinDistanceSquared = kPointMinDistance * kPointMinDistance;

@interface SmoothLineView ()
@property (nonatomic,assign) CGPoint currentPoint;
@property (nonatomic,assign) CGPoint previousPoint;
@property (nonatomic,assign) CGPoint previousPreviousPoint;

@property (nonatomic, strong) UIBezierPath* bzPath;
@property (nonatomic, strong) NSMutableArray* pathSnapshots;

@property (nonatomic, strong) UIColor *bgColor;

#pragma mark Private Helper function
CGPoint midPoint(CGPoint p1, CGPoint p2);
@end

@implementation SmoothLineView {
@private
    CGMutablePathRef _fullPath;
    CGMutablePathRef _drawnPath;
}

#pragma mark UIView lifecycle methods

+ (Class) layerClass
{
    return [CATiledLayer class];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        // NOTE: do not change the backgroundColor here, so it can be set in IB.
        _fullPath = CGPathCreateMutable();
        _drawnPath = CGPathCreateMutable();
        _lineWidth = DEFAULT_WIDTH;
        _lineColor = DEFAULT_COLOR;
        _empty = YES;
        _pathSnapshots = [NSMutableArray new];
    }
    
    return self;
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self)
    {
        self.backgroundColor = DEFAULT_BACKGROUND_COLOR;
        _fullPath = CGPathCreateMutable();
        _drawnPath = CGPathCreateMutable();
        _lineWidth = DEFAULT_WIDTH;
        _lineColor = DEFAULT_COLOR;
        _empty = YES;
        _pathSnapshots = [NSMutableArray new];
        self.multipleTouchEnabled = YES;
        self.bzPath = [UIBezierPath bezierPathWithCGPath:_fullPath];
    }
    
    return self;
}

-(void) dealloc
{
    CGPathRelease(_fullPath);
    CGPathRelease(_drawnPath);
}

- (void) updateWithTransform:(CGAffineTransform)transform
{
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
    UIBezierPath* path = [self path];
    [path applyTransform:transform];
    [self setPath:path];
    [self setNeedsDisplay];
    
    for (UIBezierPath* path in self.pathSnapshots)
    {
        [path applyTransform:transform];
    }
    }
}

- (void) setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    
    _bgColor = backgroundColor;
}

- (void) drawRect:(CGRect)rect
{
    // Empty drawRect for drawLayer
}

- (void) drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
    CGContextSaveGState(context);
    CGRect rect = CGContextGetClipBoundingBox(context);
    // we use an internal property because drawRect is called from a background thread
    // and throws a warning if you try to access [UIView backgroundColor] while
    // not on the main thread.
    CGContextSetFillColorWithColor(context, self.bgColor.CGColor);
    CGContextFillRect(context, rect);
    CGContextAddPath(context, _fullPath);
    CGContextAddPath(context, _drawnPath);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineWidth(context, self.lineWidth);
    CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor);
    
    CGContextStrokePath(context);
    
    if (self.renderAsArea)
    {
        CGContextAddPath(context, _fullPath);
        CGContextAddPath(context, _drawnPath);
        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
        CGContextSetAlpha(context, 0.2);
        CGContextFillPath(context);
    }
    CGContextRestoreGState(context);
    
    self.empty = NO;
        
    }
}

#pragma mark private Helper function

CGPoint midPoint(CGPoint p1, CGPoint p2) {
    return CGPointMake((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5);
}

#pragma mark Touch event handlers

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (event.allTouches.count == 1)
    {
        UITouch *touch = [touches anyObject];
        
        // initializes our point records to current location
        self.previousPoint = [touch previousLocationInView:self];
        self.previousPreviousPoint = [touch previousLocationInView:self];
        self.currentPoint = [touch locationInView:self];
        
#if USE_SYNCHRONIZED
        @synchronized (self)
#endif
        {
        CGPathMoveToPoint(_drawnPath, NULL, self.currentPoint.x, self.currentPoint.y);
        }
        LogMessage(INFO, @"Move to Point: (%@, %@)", @(self.currentPoint.x), @(self.currentPoint.y));
    }
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (event.allTouches.count == 1)
    {
        UITouch *touch = [touches anyObject];
        
        /*
         CGPoint point = [touch locationInView:self];
         
         // if the finger has moved less than the min dist ...
         CGFloat dx = point.x - self.currentPoint.x;
         CGFloat dy = point.y - self.currentPoint.y;
         
         if ((dx * dx + dy * dy) < kPointMinDistanceSquared) {
         // ... then ignore this movement
         return;
         }
         */
        
        // update points: previousPrevious -> mid1 -> previous -> mid2 -> current
        self.previousPreviousPoint = self.previousPoint;
        self.previousPoint = [touch previousLocationInView:self];
        self.currentPoint = [touch locationInView:self];
        
        CGPoint mid2 = midPoint(self.currentPoint, self.previousPoint);
        
        // to represent the finger movement, add a quadratic bezier path
        // from current point to mid2, using previous as a control point
#if USE_SYNCHRONIZED
        @synchronized (self)
#endif
        {
        CGPathAddQuadCurveToPoint(_drawnPath, NULL,
                                  self.previousPoint.x, self.previousPoint.y,
                                  mid2.x, mid2.y);
        }
        LogMessage(INFO, @"Quad Curve to Point: (%@, %@), CP (%@, %@)", @(mid2.x), @(mid2.y), @(self.previousPoint.x), @(self.previousPoint.y));
    }
    
    [self setNeedsDisplayInRect:CGPathGetBoundingBox(_drawnPath)];
}

- (void) touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
        if (event.allTouches.count == 1)
        {
            UIBezierPath* drawnPath = [UIBezierPath bezierPathWithCGPath:_drawnPath];
            UIBezierPath* fullPath = [UIBezierPath bezierPathWithCGPath:_fullPath];
            LogMessage(INFO, @"Touch Ended - Path: %@", drawnPath);
            if (!drawnPath.empty && (drawnPath.bounds.size.width != 0 && drawnPath.bounds.size.height != 0))
            {
                [fullPath appendPath:drawnPath];
                CGMutablePathRef oldPath = _fullPath;
                CGPathRelease(oldPath);
                _fullPath = CGPathCreateMutableCopy(fullPath.CGPath);
                self.bzPath = fullPath;
                [self.pathSnapshots addObject:self.bzPath];
            }
            
            CGMutablePathRef oldPath = _drawnPath;
            CGPathRelease(oldPath);
            _drawnPath = CGPathCreateMutable();
        }
    }
}

- (void) replaceCGPathsWithNewPath:(UIBezierPath*)path
{
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
    CGMutablePathRef oldPath = _fullPath;
    CGPathRelease(oldPath);
    _fullPath = path == nil ? CGPathCreateMutable() : CGPathCreateMutableCopy(path.CGPath);
    
    oldPath = _drawnPath;
    CGPathRelease(oldPath);
    _drawnPath = CGPathCreateMutable();
    }
}

#pragma mark interface

- (void) clearDrawing
{
    [self replaceCGPathsWithNewPath:nil];
    
    [self setNeedsDisplay];
}

-(void) clear
{
    [self clearPath];
    
    self.pathSnapshots = [NSMutableArray new];
    [self setNeedsDisplay];
}

- (void) clearPath
{
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
        [self replaceCGPathsWithNewPath:nil];
        self.bzPath = [UIBezierPath bezierPathWithCGPath:_fullPath];
    }
}

- (UIBezierPath*) path
{
    return self.bzPath;
}

- (void) setPath:(UIBezierPath*) bezierPath
{
    NSAssert(bezierPath != nil, @"Bezier path should not be nil");
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
        [self replaceCGPathsWithNewPath:bezierPath];
        self.bzPath = [bezierPath copy];
    }
}

- (BOOL) didChange
{
    return !self.path.isEmpty
    && (self.path.bounds.size.width > 0 || self.path.bounds.size.height > 0);
}

- (void) closeSubpath
{
    //
    // According to documentation, when a path is filled, all inner subpaths
    // are implicitly closed so the the fill rule can be applied.
    //
    // https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIBezierPath_class/#//apple_ref/occ/instm/UIBezierPath/fill
    //  | This method fills the path using the current fill color and drawing properties. If the path contains any open subpaths, this method implicitly closes them before painting the fill region.
    //
#if USE_SYNCHRONIZED
    @synchronized (self)
#endif
    {
    CGPathCloseSubpath(_fullPath);
    }
    [self setNeedsDisplay];
}

- (void) undo
{
    [self.pathSnapshots removeLastObject];
    if (self.pathSnapshots.count > 0)
    {
        UIBezierPath* path = [self.pathSnapshots lastObject];
        [self setPath:path];
    }
    else
    {
        [self clearPath];
    }
    
    [self setNeedsDisplay];
}

@end

