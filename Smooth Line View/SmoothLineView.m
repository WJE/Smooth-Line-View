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
    CGMutablePathRef _path;
}

#pragma mark UIView lifecycle methods

+ (Class)layerClass
{
    return [CATiledLayer class];
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self)
    {
        // NOTE: do not change the backgroundColor here, so it can be set in IB.
        _path = CGPathCreateMutable();
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
        _path = CGPathCreateMutable();
        _lineWidth = DEFAULT_WIDTH;
        _lineColor = DEFAULT_COLOR;
        _empty = YES;
        _pathSnapshots = [NSMutableArray new];
        self.multipleTouchEnabled = YES;
        self.bzPath = [UIBezierPath bezierPathWithCGPath:_path];
    }
    
    return self;
}

- (id) initWithFrame:(CGRect)frame andExistingView:(SmoothLineView*)view;
{
    self = [self initWithFrame:frame];
    
    if (self)
    {
        _pathSnapshots = [view.pathSnapshots mutableCopy];
        self.renderAsArea = view.renderAsArea;
        [self setPath:view.path];
    }
    
    return self;
}

- (void) updateWithTransform:(CGAffineTransform)transform
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

- (void) setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    
    _bgColor = backgroundColor;
}

- (void) drawRect:(CGRect)rect {
    // clear rect
    // we use an internal property because drawRect is called from a background thread
    // and throws a warning if you try to access [UIView backgroundColor] while
    // not on the main thread.
    [self.bgColor set];
    UIRectFill(rect);
    
    // get the graphics context and draw the path
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextAddPath(context, _path);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineWidth(context, self.lineWidth);
    CGContextSetStrokeColorWithColor(context, self.lineColor.CGColor);
    
    CGContextStrokePath(context);
    
    if (self.renderAsArea)
    {
        CGContextAddPath(context, _path);
        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
        CGContextSetAlpha(context, 0.2);
        CGContextFillPath(context);
    }
    
    self.empty = NO;
}

-(void) dealloc
{
    CGPathRelease(_path);
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
        
        CGPathMoveToPoint(_path, NULL, self.currentPoint.x, self.currentPoint.y);
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
        CGPathAddQuadCurveToPoint(_path, NULL,
                                  self.previousPoint.x, self.previousPoint.y,
                                  mid2.x, mid2.y);
    }
    else
    {
        [self setPath:self.bzPath];
    }
    
    [self setNeedsDisplayInRect:CGPathGetBoundingBox(_path)];
}

- (void) touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if (event.allTouches.count == 1)
    {
        UIBezierPath* path = [UIBezierPath bezierPathWithCGPath:_path];
        if (!path.empty)
        {
            self.bzPath = path;
            [self.pathSnapshots addObject:self.bzPath];
        }
    }
}

#pragma mark interface

-(void) clear
{
    [self clearPath];
    
    self.pathSnapshots = [NSMutableArray new];
    [self setNeedsDisplay];
}

- (void) clearPath
{
    CGMutablePathRef oldPath = _path;
    CGPathRelease(oldPath);
    _path = CGPathCreateMutable();
    self.bzPath = [UIBezierPath bezierPathWithCGPath:_path];
}

- (UIBezierPath*) path
{
    return [UIBezierPath bezierPathWithCGPath:_path];
}

- (void) setPath:(UIBezierPath*) bezierPath
{
    NSAssert(bezierPath != nil, @"Bezier path should not be nil");
    CGMutablePathRef oldPath = _path;
    CGPathRelease(oldPath);
    _path = CGPathCreateMutableCopy(bezierPath.CGPath) ;
    self.bzPath = bezierPath;
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
    CGPathCloseSubpath(_path);
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

