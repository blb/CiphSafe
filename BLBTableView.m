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
/* BLBTableView.m */

#import "BLBTableView.h"

@interface BLBTableView (InternalMethods)
- (void) _drawStripesInRect:(NSRect)clipRect;
@end

@implementation BLBTableView

/*
 * Set the cells to not draw a background, so the striping works nicely
 */
- (void) awakeFromNib
{
   NSArray *tableColumns;
   int index;

   tableColumns = [ self tableColumns ];
   for( index = 0; index < [ tableColumns count ]; index++ )
      [ [ [ tableColumns objectAtIndex:index ] dataCell ] setDrawsBackground:NO ];
}


/*
 * Override so deselectAll: for a menu item is only enabled when something
 * is selected
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
   BOOL retval;

   retval = YES;
   if( [ menuItem action ] == @selector( deselectAll: ) )
      retval = ( [ self numberOfSelectedRows ] > 0 );

   return retval;
}


/*
 * Set the stripe color (the one other than white)
 */
- (void) setStripeColor:(NSColor *)newStripeColor
{
   [ newStripeColor retain ];
   [ _stripeColor release ];
   _stripeColor = newStripeColor;
}


/*
 * Allow dragging into other Cocoa apps
 */
- (NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)flag
{
   if( flag )
      return NSDragOperationEvery;
   else
      return NSDragOperationCopy;
}


/*
 * Add the call to draw striped background
 */
- (void) highlightSelectionInClipRect:(NSRect)clipRect
{
   if( _stripeColor != nil )
      [ self _drawStripesInRect:clipRect ];
   [ super highlightSelectionInClipRect:clipRect ];
}


/*
 * Draw only vertical lines for the grid
 */
- (void) drawGridInClipRect:(NSRect)aRect
{
   int index;
   NSRect columnRect;
   float xPos;

   [ [ self gridColor ] set ];
   for( index = 0; index < [ self numberOfColumns ]; index++ )
   {
      columnRect = [ self rectOfColumn:index ];
      xPos = columnRect.origin.x + columnRect.size.width - 1;
      NSFrameRect( NSMakeRect( xPos, aRect.origin.y, 1, aRect.size.height ) );
   }
}


/*
 * The delegate must implement contextualMenuForTableView:row:column: for this
 * to work
 */
- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
   SEL contextMenuSel;
   NSPoint clickPoint;
   int clickColumn, clickRow;

   contextMenuSel = @selector( contextualMenuForTableView:row:column: );
   if( [ [ self delegate ] respondsToSelector:contextMenuSel ] )
   {
      clickPoint = [ self convertPoint:[ theEvent locationInWindow ]
                          fromView:nil ];
      clickColumn = [ self columnAtPoint:clickPoint ];
      clickRow = [ self rowAtPoint:clickPoint ];

      if( clickColumn >= 0 && clickRow >= 0 )
         return [ [ self delegate ] contextualMenuForTableView:self
                                    row:clickRow
                                    column:clickColumn ];
   }

   return nil;
}


/*
 * Allow delegate to handle keydown events, if it wants
 */
- (void) keyDown:(NSEvent *)theEvent
{
   BOOL sendToSuper;
   SEL didReceiveSel = @selector( tableView:didReceiveKeyDownEvent: );

   sendToSuper = YES;
   if( [ [ self delegate ] respondsToSelector:didReceiveSel ] &&
       [ [ self delegate ] tableView:self didReceiveKeyDownEvent:theEvent ] )
      sendToSuper = NO;
   if( sendToSuper )
      [ super keyDown:theEvent ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ self setStripeColor:nil ];
   [ super dealloc ];
}


/*
 * This routine does the actual blue stripe drawing, filling in every other row
 * of the table with a blue background so you can follow the rows easier with
 * your eyes.  Shamelessly lifted from Apple's MP3 Player sample code.
 */
- (void) _drawStripesInRect:(NSRect)clipRect
{
   NSRect stripeRect;
   float fullRowHeight, clipBottom;
   int firstStripe;

   fullRowHeight = [ self rowHeight ] + [ self intercellSpacing ].height;
   clipBottom = NSMaxY( clipRect );
   firstStripe = clipRect.origin.y / fullRowHeight;
   if( firstStripe % 2 == 1 )
      firstStripe++;   // We're only interested in drawing the stripes

   // Set up first rect
   stripeRect.origin.x = clipRect.origin.x;
   stripeRect.origin.y = firstStripe * fullRowHeight;
   stripeRect.size.width = clipRect.size.width;
   stripeRect.size.height = fullRowHeight;

   // Set the color
   [ _stripeColor set ];
   // ...and draw the stripes
   while( stripeRect.origin.y < clipBottom )
   {
      NSRectFill( stripeRect );
      stripeRect.origin.y += fullRowHeight * 2.0;
   }
}

@end
