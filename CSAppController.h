/* CSAppController.h */

#import <Cocoa/Cocoa.h>

// Identifiers for preferences
extern NSString * const CSPrefDictKey_SaveBackup;
extern NSString * const CSPrefDictKey_CloseAdd;
extern NSString * const CSPrefDictKey_CloseEdit;
extern NSString * const CSPrefDictKey_ConfirmDelete;
extern NSString * const CSPrefDictKey_ClearClipboard;
extern NSString * const CSPrefDictKey_WarnShort;
extern NSString * const CSPrefDictKey_CreateNew;
extern NSString * const CSPrefDictKey_GenSize;
extern NSString * const CSPrefDictKey_AlphanumOnly;
extern NSString * const CSPrefDictKey_IncludePasswd;

// Name of our internal pasteboard type
extern NSString * const CSDocumentPboardType;

@interface CSAppController : NSObject
{
   // Preferences window
   IBOutlet NSWindow *prefsWindow;
   // Interface tab
   IBOutlet NSButton *prefsCloseAdd;
   IBOutlet NSButton *prefsCloseEdit;
   IBOutlet NSButton *prefsConfirmDelete;
   IBOutlet NSButton *prefsWarnShort;
   IBOutlet NSButton *prefsCreateNew;
   IBOutlet NSButton *prefsIncludePasswd;
   // Generated passwords tab
   IBOutlet NSTextField *prefsGenSize;
   IBOutlet NSButton *prefsAlphanumOnly;
   // Miscellaneous tab
   IBOutlet NSButton *prefsKeepBackup;
   IBOutlet NSButton *prefsClearClipboard;
}

// Actions for the prefs window
- (IBAction) openPrefs:(id)sender;
- (IBAction) prefsSave:(id)sender;
- (IBAction) prefsCancel:(id)sender;

@end
