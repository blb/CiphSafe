/* CSTableView.h */

#import <Cocoa/Cocoa.h>

@protocol CSTableView_CMM
- (NSMenu *) contextualMenuForTableViewRow:(int)row;
@end

@interface CSTableView : NSTableView
{
}

@end
