/* NSTableView_CMM.h */

#import <AppKit/AppKit.h>

@protocol NSTableView_withay_CMM
- (NSMenu *) contextualMenuForTableViewRow:(int)row;
@end

@interface NSTableView (withay_CMM)

- (NSMenu *) menuForEvent:(NSEvent *)theEvent;

@end
