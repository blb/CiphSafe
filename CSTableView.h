/* CSTableView.h */

#import <Cocoa/Cocoa.h>

// Implement this to provide a contextual menu
@protocol CSTableView_CMM
- (NSMenu *) contextualMenuForTableViewRow:(int)row;
@end

@interface CSTableView : NSTableView
{
   NSColor *stripeColor;
}

// Set the stripe color
- (void) setStripeColor:(NSColor *)newStripeColor;

@end
