/* CSWinCtrlMain.h */

#import <AppKit/AppKit.h>
#import "CSTableView.h"

@interface CSWinCtrlMain : NSWindowController <CSTableView_CMM>
{
   NSTableColumn *previouslySelectedColumn;

   IBOutlet NSTableView *documentView;
   IBOutlet NSMenu *contextualMenu;
   IBOutlet NSButton *documentDeleteButton;
   IBOutlet NSButton *documentViewButton;
}

// Actions from the main window
- (IBAction) docAddEntry:(id)sender;
- (IBAction) docViewEntry:(id)sender;
- (IBAction) docDeleteEntry:(id)sender;

// Actions from the contextual menu
- (IBAction) cmmCopyAccount:(id)sender;
- (IBAction) cmmCopyPassword:(id)sender;
- (IBAction) cmmCopyURL:(id)sender;
- (IBAction) cmmCopyName:(id)sender;
- (IBAction) cmmCopyNotes:(id)sender;

// Refresh the window and contents
- (void) refreshWindow;

@end
