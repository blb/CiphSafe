/* CSDocument_CMM.h */

#import <Cocoa/Cocoa.h>
#import "CSDocument.h"
#import "NSTableView_CMM.h"

@interface CSDocument (CMM) <NSTableView_withay_CMM>

// Actions from the contextual menu
- (IBAction) cmmCopyAccount:(id)sender;
- (IBAction) cmmCopyPassword:(id)sender;
- (IBAction) cmmCopyURL:(id)sender;
- (IBAction) cmmCopyName:(id)sender;
- (IBAction) cmmCopyNotes:(id)sender;

@end
