/* CSDocument_CMM.h */

#import <Cocoa/Cocoa.h>
#import "CSDocument.h"
#import "CSTableView.h"

@interface CSDocument (CMM) <CSTableView_CMM>

// Actions from the contextual menu
- (IBAction) cmmCopyAccount:(id)sender;
- (IBAction) cmmCopyPassword:(id)sender;
- (IBAction) cmmCopyURL:(id)sender;
- (IBAction) cmmCopyName:(id)sender;
- (IBAction) cmmCopyNotes:(id)sender;

@end
