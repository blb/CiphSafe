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
 * Set the stripe color (the one other than white)
 */
- (void) setStripeColor:(NSColor *)newStripeColor
{
   [ newStripeColor retain ];
   [ stripeColor release ];
   stripeColor = newStripeColor;
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
 * The delegate must conform to the BLBTableView_CMM protocol for this to work
 */
- (NSMenu *) menuForEvent:(NSEvent *)theEvent
{
   NSPoint clickPoint;
   int clickColumn, clickRow;

   clickPoint = [ self convertPoint:[ theEvent locationInWindow ] fromView:nil ];
   clickColumn = [ self columnAtPoint:clickPoint ];
   clickRow = [ self rowAtPoint:clickPoint ];

   if( clickColumn >= 0 && clickRow >= 0 &&
       [ [ self delegate ]
         conformsToProtocol:@protocol( BLBTableView_CMM ) ] )
      return [ [ self delegate ] contextualMenuForTableViewRow:clickRow ];

   return nil;
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
   [ stripeColor set ];
   // ...and draw the stripes
   while( stripeRect.origin.y < clipBottom )
   {
      NSRectFill( stripeRect );
      stripeRect.origin.y += fullRowHeight * 2.0;
   }
}

@end
