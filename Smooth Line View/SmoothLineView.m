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

#pragma mark Private Helper function
CGPoint midPoint(CGPoint p1, CGPoint p2);
@end

@implementation SmoothLineView {
@private
    CGMutablePathRef _path;
}

@synthesize myTransform = _myTransform;
@synthesize myScale = _myScale;

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
        _myTransform = CGAffineTransformIdentity;
        _myScale = 1.0;
        self.multipleTouchEnabled = YES;
        self.bzPath = [UIBezierPath bezierPathWithCGPath:_path];
    }
    
    return self;
}

- (id) initWithFrame:(CGRect)frame path:(UIBezierPath*)path andPathSnapshots:(NSArray*)snapshots
{
    self = [self initWithFrame:frame];
    
    if (self)
    {
        _path = CGPathCreateMutableCopy(path.CGPath);
        _pathSnapshots = snapshots != nil ? [snapshots mutableCopy] : [NSMutableArray new];
        self.bzPath = [UIBezierPath bezierPathWithCGPath:_path];
    }
    
    return self;
}

- (void)setMyScale:(CGFloat)myScale
{
    _myScale = myScale;
    
    if (_path)
    {
        CGAffineTransform transform = CGAffineTransformMakeScale(myScale, myScale);
        UIBezierPath* path = [self path];
        [path applyTransform:transform];
        [self setPath:path];
        [self setNeedsDisplay];
    }
}

- (void) setMyTransform:(CGAffineTransform)myTransform
{
    UIBezierPath* path = [self.pathSnapshots lastObject];
    [path applyTransform:_myTransform];
    
    _myTransform = myTransform;
    
    if (_path)
    {
        UIBezierPath* path = [self path];
        [path applyTransform:myTransform];
        [self setPath:path];
        [self setNeedsDisplay];
    }
}

- (void) setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    
    _bgColor = backgroundColor;
}

- (void) drawRect:(CGRect)rect {
    // clear rect
    //    UIColor* color = self.backgroundColor;
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
    NSLog(@"TOUCHES BEGAN COUNT: %@\n%@", @(touches.count), touches);
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
    NSLog(@"TOUCHES MOVED COUNT: %@\n%@", @(touches.count), touches);
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
        _path = CGPathCreateMutableCopy(self.bzPath.CGPath);
    }
    
    [self setNeedsDisplayInRect:CGPathGetBoundingBox(_path)];
}

- (void) touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    NSLog(@"TOUCHES ENDED COUNT: %@\n%@", @(touches.count), touches);
    if (event.allTouches.count == 1)
    {
        UIBezierPath* path = [UIBezierPath bezierPathWithCGPath:_path];
        if (!path.empty)
        {
            self.bzPath = path;
            [self.pathSnapshots addObject:@[self.bzPath, @(self.myScale)]];
        }
        else
        {
            NSLog(@"Path empty: %@", path);
        }
//        CGAffineTransform transform = CGAffineTransformMakeScale(1/self.myScale, 1/self.myScale);
//        UIBezierPath* pathSnap = [self path];
//        [pathSnap applyTransform:transform];
//        [self.pathSnapshots addObject:@[self.bzPath, @(self.myScale)]];
    }
}

#pragma mark interface

-(void) clear
{
    CGMutablePathRef oldPath = _path;
    CFRelease(oldPath);
    _path = CGPathCreateMutable();
    
    self.pathSnapshots = [NSMutableArray new];
    [self setNeedsDisplay];
}

- (UIBezierPath*) path
{
    return [UIBezierPath bezierPathWithCGPath:_path];
}

- (void) setPath:(UIBezierPath*) bezierPath
{
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
    CGMutablePathRef oldPath = _path;
    CGPathRelease(oldPath);
    
    [self.pathSnapshots removeLastObject];
    if (self.pathSnapshots.count > 0)
    {
        NSArray* a = [self.pathSnapshots lastObject];
        CGFloat scale = [(NSNumber*)a[1] floatValue];
//        CGFloat s = _myScale/scale;
        CGAffineTransform t1 = CGAffineTransformMakeScale(1/scale, 1/scale);
        CGAffineTransform t2 = CGAffineTransformMakeScale(_myScale, _myScale);
//        CGAffineTransform transform = CGAffineTransformMakeScale(_myScale/scale, _myScale/scale);
        CGAffineTransform transform = CGAffineTransformConcat(t1, t2);
        UIBezierPath* path = a[0];
        [path applyTransform:transform];
        
        [self setPath:path];
    }
    else
    {
        _path = CGPathCreateMutable();
    }
    
    [self setNeedsDisplay];
}

@end

