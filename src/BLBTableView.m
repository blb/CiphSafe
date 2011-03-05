/*
 * Copyright © 2003,2006-2007,2011, Bryan L Blackburn.  All rights reserved.
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

#pragma mark -
#pragma mark Initialization
/*
 * Set the cells to not draw a background, so the striping works nicely
 */
- (void) awakeFromNib
{
   NSEnumerator *columnEnumerator = [[self tableColumns] objectEnumerator];
   id column;
   while((column = [columnEnumerator nextObject]) != nil)
      [[column dataCell] setDrawsBackground:NO];
}


#pragma mark -
#pragma mark Stripe Handling
/*
 * This routine does the actual stripe drawing, filling in every other row
 * of the table with some color for the background so you can follow the rows easier with
 * your eyes.  Shamelessly lifted from Apple's MP3 Player sample code.
 */
- (void) drawStripesInRect:(NSRect)clipRect
{
   CGFloat fullRowHeight = [self rowHeight] + [self intercellSpacing].height;
   CGFloat clipBottom = NSMaxY(clipRect);
   NSInteger firstStripe = clipRect.origin.y / fullRowHeight;
   if(firstStripe % 2 == 1)
      firstStripe++;   // We're only interested in drawing the stripes
   
   // Set up first rect
   NSRect stripeRect = NSMakeRect(clipRect.origin.x,
                                  firstStripe * fullRowHeight,
                                  clipRect.size.width,
                                  fullRowHeight);
   
   // Set the color
   [stripeColor set];
   // ...and draw the stripes
   while(stripeRect.origin.y < clipBottom)
   {
      NSRectFill(stripeRect);
      stripeRect.origin.y += fullRowHeight * 2.0;
   }
}


/*
 * Make sure the cell is setup right
 */
- (void) addTableColumn:(NSTableColumn *)aColumn
{
   [super addTableColumn:aColumn];
   [[aColumn dataCell] setDrawsBackground:NO];
}


/*
 * Set the stripe color (the one other than white)
 */
- (void) setStripeColor:(NSColor *)newStripeColor
{
   if(newStripeColor != stripeColor)
   {
      [stripeColor autorelease];
      stripeColor = [newStripeColor retain];
      [self setNeedsDisplay:YES];
   }
}


/*
 * Add the call to draw striped background
 */
- (void) highlightSelectionInClipRect:(NSRect)clipRect
{
   if(stripeColor != nil)
      [self drawStripesInRect:clipRect];
   [super highlightSelectionInClipRect:clipRect];
}


#pragma mark -
#pragma mark Additional Delegations
/*
 * The delegate must implement contextualMenuForBLBTableView:row:column: for this
 * to work
 */
- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
   if([[self delegate] respondsToSelector:@selector(contextualMenuForBLBTableView:row:column:)])
   {
      NSPoint clickPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
      NSInteger clickColumn = [self columnAtPoint:clickPoint];
      NSInteger clickRow = [self rowAtPoint:clickPoint];

      if(clickColumn >= 0 && clickRow >= 0)
         return [[self delegate] contextualMenuForBLBTableView:self
                                                           row:clickRow
                                                        column:clickColumn];
   }

   return nil;
}


/*
 * Allow delegate to handle keydown events, if it wants
 */
- (void) keyDown:(NSEvent *)theEvent
{
   if(![[self delegate] respondsToSelector:@selector(blbTableView:didReceiveKeyDownEvent:)]
      || ![[self delegate] blbTableView:self didReceiveKeyDownEvent:theEvent])
      [super keyDown:theEvent];
}


/*
 * Notify delegate when a drop operation is complete
 */
- (void) draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
   [super draggedImage:anImage endedAt:aPoint operation:operation];
   if([[self delegate] respondsToSelector:@selector(blbTableView:completedDragAtPoint:operation:)])
      [[self delegate] blbTableView:self completedDragAtPoint:aPoint operation:operation];
}


#pragma mark -
#pragma mark Finalization
/*
 * Cleanup
 */
- (void) dealloc
{
   [self setStripeColor:nil];
   [super dealloc];
}

@end
