/*
 * Copyright © 2003, Bryan L Blackburn.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. Neither the names Bryan L Blackburn, Withay.com, nor the names of
 *    any contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRYAN L BLACKBURN ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
/* BLBMenuCornerView.m */

#import "BLBMenuCornerView.h"

@interface BLBMenuCornerView (InternalMethods)
- (void) _setupGraphic;
- (void) _fillRect:(NSRect)aRect
         fromColor:(NSColor *)startColor
         toColor:(NSColor *)endColor;
@end

@implementation BLBMenuCornerView

// Variables for drawing our fancy button
// viewSides and viewColors are to draw the borders, to make it stand out
static NSRectEdge viewSides[] = { NSMaxYEdge, NSMinYEdge, NSMaxYEdge };
static NSColor *viewColors[ 3 ];
// The bottom of the button starts with these colors
static NSColor *selectedStartColor, *unselectedStartColor;
// The middle reaches these colors
static NSColor *selectedMiddleColor, *unselectedMiddleColor;
// The top ends with these colors
static NSColor *selectedEndColor, *unselectedEndColor;

+ (void) initialize
{
   viewColors[ 0 ] = [ [ NSColor colorWithCalibratedRed:0
                                 green:0.3
                                 blue:0.75
                                 alpha:1 ] retain ];
   viewColors[ 1 ] = [ [ NSColor colorWithCalibratedRed:0.4
                                 green:0.58
                                 blue:0.75
                                 alpha:1 ] retain ];
   viewColors[ 2 ] = [ [ NSColor colorWithCalibratedRed:0.82
                                 green:0.89
                                 blue:0.96
                                 alpha:1 ] retain ];
   unselectedStartColor = [ [ NSColor colorWithCalibratedRed:0.73
                                      green:0.99
                                      blue:1
                                      alpha:1 ] retain ];
   selectedStartColor = [ [ NSColor colorWithCalibratedRed:0.6
                                    green:0.91
                                    blue:1
                                    alpha:1 ] retain ];
   unselectedMiddleColor = [ [ NSColor colorWithCalibratedRed:0.41
                                       green:0.66
                                       blue:0.92
                                       alpha:1 ] retain ];
   selectedMiddleColor = [ [ NSColor colorWithCalibratedRed:0.31
                                     green:0.60
                                     blue:0.89
                                     alpha:1 ] retain ];
   unselectedEndColor = [ [ NSColor colorWithCalibratedRed:0.69
                                    green:0.81
                                    blue:0.93
                                    alpha:1 ] retain ];
   selectedEndColor = [ [ NSColor colorWithCalibratedRed:0.66
                                  green:0.77
                                  blue:0.92
                                  alpha:1 ] retain ];
}


/*
 * Simple init, setup our graphic
 */
- (id) initWithFrame:(NSRect)frame
{
   self = [ super initWithFrame:frame ];
   if( self != nil )
      [ self _setupGraphic ];

   return self;
}


/*
 * Draw the border, then fill the button itself with two color gradients for
 * a nice Aqua look; finally, draw the graphic
 */
- (void) drawRect:(NSRect)rect
{
   NSRect finalRect, firstHalf, secondHalf;

   if( !NSEqualRects( _lastRect, [ self frame ] ) )
      [ self _setupGraphic ];
   [ [ NSColor whiteColor ] set ];
   NSRectFill( rect );
   finalRect = NSDrawColorTiledRects( [ self bounds ], rect, viewSides, 
                                      viewColors, 3 );
   NSDivideRect( finalRect, &firstHalf, &secondHalf,
                 ceil( finalRect.size.height / 2 ), NSMinYEdge );
   if( _isMouseDown )
   {
      [ self _fillRect:firstHalf
             fromColor:selectedStartColor
             toColor:selectedMiddleColor ];
      [ self _fillRect:secondHalf
             fromColor:selectedMiddleColor
             toColor:selectedEndColor ];
   }
   else
   {
      [ self _fillRect:firstHalf
             fromColor:unselectedStartColor
             toColor:unselectedMiddleColor ];
      [ self _fillRect:secondHalf
             fromColor:unselectedMiddleColor
             toColor:unselectedEndColor ];
   }

   [ [ NSColor blackColor ] set ];
   [ _displayedGraphic fill ];
}


/*
 * I am
 */
- (BOOL) isOpaque
{
   return YES;
}


/*
 * Show menu on mouse down
 */
- (void) mouseDown:(NSEvent *)theEvent
{
   _isMouseDown = YES;
   [ self setNeedsDisplay:YES ];
   [ NSMenu popUpContextMenu:_menuToDisplay withEvent:theEvent forView:self ];
   _isMouseDown = NO;
   [ self setNeedsDisplay:YES ];
}


/*
 * Simple set accessor
 */
- (void) setMenuToDisplay:(NSMenu *)newMenu
{
   [ newMenu retain ];
   [ _menuToDisplay release ];
   _menuToDisplay = newMenu;
}


/*
 * Simple get accessor
 */
- (NSMenu *) menuToDisplay
{
   return _menuToDisplay;
}


/*
 * Setup our fancy little graphic
 */
- (void) _setupGraphic
{
   NSRect myBounds;

   _lastRect = [ self frame ];
   [ _displayedGraphic release ];
   _displayedGraphic = [ [ NSBezierPath alloc ] init ];
   // modify to account for borders
   myBounds = [ self bounds ];
   myBounds.size.height -= 3;
   myBounds.origin.y += 1;
   [ _displayedGraphic setLineWidth:0 ];
   [ _displayedGraphic moveToPoint:
                          NSMakePoint( 1.5, ( myBounds.size.height / 2 ) + 1 ) ];
   [ _displayedGraphic relativeLineToPoint:NSMakePoint( 5, -3 ) ];
   [ _displayedGraphic relativeLineToPoint:NSMakePoint( 0, 6 ) ];
   [ _displayedGraphic closePath ];
   [ _displayedGraphic moveToPoint:
                          NSMakePoint( myBounds.size.width - 1.5,
                                       ( myBounds.size.height / 2 ) + 1 ) ];
   [ _displayedGraphic relativeLineToPoint:NSMakePoint( -5, -3 ) ];
   [ _displayedGraphic relativeLineToPoint:NSMakePoint( 0, 6 ) ];
   [ _displayedGraphic closePath ];
}


/*
 * Fill the given rect with a color gradient starting with startColor and going
 * to the end color
 */
- (void) _fillRect:(NSRect)aRect
         fromColor:(NSColor *)startColor
         toColor:(NSColor *)endColor
{
   NSRect remaining, onePiece;
   NSColor *currentColor;
   float rDelta, gDelta, bDelta, aDelta;

   remaining = aRect; 

   rDelta = ( [ endColor redComponent ] - [ startColor redComponent ] ) /
            aRect.size.height;
   gDelta = ( [ endColor greenComponent ] - [ startColor greenComponent ] ) /
            aRect.size.height;
   bDelta = ( [ endColor blueComponent ] - [ startColor blueComponent ] ) /
            aRect.size.height;
   aDelta = ( [ endColor alphaComponent ] - [ startColor alphaComponent ] ) /
            aRect.size.height;
   currentColor = startColor;

   while( remaining.size.height > 0 )
   {
      NSDivideRect( remaining, &onePiece, &remaining, 1, NSMinYEdge );
      [ currentColor set ];
      NSRectFill( onePiece );
      currentColor = [ NSColor
                          colorWithCalibratedRed:
                             ( [ currentColor redComponent ] + rDelta )
                          green:( [ currentColor greenComponent ] + gDelta )
                          blue:( [ currentColor blueComponent ] + bDelta )
                          alpha:( [ currentColor alphaComponent ] + aDelta ) ];
   }
}

@end
