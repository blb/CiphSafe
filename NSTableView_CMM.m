/* NSTableView_CMM.m */

#import "NSTableView_CMM.h"

@implementation NSTableView (withay_CMM)

/*
 * The delegate must conform to the NSTableView_withay_CMM protocol 
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
         conformsToProtocol:@protocol( NSTableView_withay_CMM ) ] )
      return [ [ self delegate ] contextualMenuForTableViewRow:clickRow ];

   return nil;
}

@end
