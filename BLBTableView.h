/* BLBTableView.h */

#import <Cocoa/Cocoa.h>

// Implement this to provide a contextual menu
@protocol BLBTableView_CMM
- (NSMenu *) contextualMenuForTableViewRow:(int)row;
@end

@interface BLBTableView : NSTableView
{
   NSColor *stripeColor;
}

// Set the stripe color
- (void) setStripeColor:(NSColor *)newStripeColor;

@end
