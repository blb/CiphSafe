/*
 * Copyright © 2003,2006, Bryan L Blackburn.  All rights reserved.
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


@implementation BLBTableView

/*
 * Set the cells to not draw a background, so the striping works nicely
 */
- (void) awakeFromNib
{
   NSArray *tableColumns = [ self tableColumns ];
   unsigned int index;
   for( index = 0; index < [ tableColumns count ]; index++ )
      [ [ [ tableColumns objectAtIndex:index ] dataCell ] setDrawsBackground:NO ];
}


/*
 * This routine does the actual stripe drawing, filling in every other row
 * of the table with some color for the background so you can follow the rows easier with
 * your eyes.  Shamelessly lifted from Apple's MP3 Player sample code.
 */
- (void) drawStripesInRect:(NSRect)clipRect
{
   float fullRowHeight = [ self rowHeight ] + [ self intercellSpacing ].height;
   float clipBottom = NSMaxY( clipRect );
   int firstStripe = clipRect.origin.y / fullRowHeight;
   if( firstStripe % 2 == 1 )
      firstStripe++;   // We're only interested in drawing the stripes
   
   // Set up first rect
   NSRect stripeRect = NSMakeRect( clipRect.origin.x,
                                   firstStripe * fullRowHeight,
                                   clipRect.size.width,
                                   fullRowHeight );
   
   // Set the color
   [ stripeColor set ];
   // ...and draw the stripes
   while( stripeRect.origin.y < clipBottom )
   {
      NSRectFill( stripeRect );
      stripeRect.origin.y += fullRowHeight * 2.0;
   }
}


/*
 * Make sure the cell is setup right
 */
- (void) addTableColumn:(NSTableColumn *)aColumn
{
   [ super addTableColumn:aColumn ];
   [ [ aColumn dataCell ] setDrawsBackground:NO ];
}


/*
 * Override so deselectAll: for a menu item is only enabled when something
 * is selected
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
   if( [ menuItem action ] == @selector( deselectAll: ) )
      return ( [ self numberOfSelectedRows ] > 0 );

   return YES;
}


/*
 * Set the stripe color (the one other than white)
 */
- (void) setStripeColor:(NSColor *)newStripeColor
{
   if( newStripeColor != stripeColor )
   {
      [ stripeColor autorelease ];
      stripeColor = [ newStripeColor retain ];
      [ self setNeedsDisplay:YES ];
   }
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
   if( stripeColor != nil )
      [ self drawStripesInRect:clipRect ];
   [ super highlightSelectionInClipRect:clipRect ];
}


/*
 * The delegate must implement contextualMenuForTableView:row:column: for this
 * to work
 */
- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
   SEL contextMenuSel = @selector( contextualMenuForTableView:row:column: );
   if( [ [ self delegate ] respondsToSelector:contextMenuSel ] )
   {
      NSPoint clickPoint = [ self convertPoint:[ theEvent locationInWindow ] fromView:nil ];
      int clickColumn = [ self columnAtPoint:clickPoint ];
      int clickRow = [ self rowAtPoint:clickPoint ];

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
   if( ![ [ self delegate ] respondsToSelector:@selector( tableView:didReceiveKeyDownEvent: ) ] ||
       ![ [ self delegate ] tableView:self didReceiveKeyDownEvent:theEvent ] )
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

@end
