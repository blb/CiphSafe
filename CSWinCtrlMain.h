/* CSWinCtrlMain.h */

#import <AppKit/AppKit.h>
#import "CSTableView.h"

@interface CSWinCtrlMain : NSWindowController <CSTableView_CMM>
{
   NSTableColumn *previouslySelectedColumn;

   IBOutlet CSTableView *documentView;
   IBOutlet NSButton *documentDeleteButton;
   IBOutlet NSButton *documentViewButton;
   IBOutlet NSTextField *documentStatus;
   IBOutlet NSMenu *contextualMenu;
}

// Actions from the main window
- (IBAction) doAddEntry:(id)sender;
- (IBAction) doViewEntry:(id)sender;
- (IBAction) doDeleteEntry:(id)sender;

// Actions from the contextual menu
- (IBAction) cmmCopyAccount:(id)sender;
- (IBAction) cmmCopyPassword:(id)sender;
- (IBAction) cmmCopyURL:(id)sender;
- (IBAction) cmmCopyName:(id)sender;
- (IBAction) cmmCopyNotes:(id)sender;

// Refresh the window and contents
- (void) refreshWindow;

@end
