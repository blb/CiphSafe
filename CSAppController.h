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

// Note types used with getEncryptionKeyWithNote:warnOnShortPassphrase:
extern NSString * const CSPassphraseNote_Save;
extern NSString * const CSPassphraseNote_Load;
extern NSString * const CSPassphraseNote_Change;

// Name of our internal pasteboard type
extern NSString * const CSDocumentPboardType;

@interface CSAppController : NSObject
{
   BOOL shouldWarnOnShortPhrase;

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

   // Passphrase window
   IBOutlet NSWindow *passphraseWindow;
   IBOutlet NSTextField *passphraseNote;
   IBOutlet NSTextField *passphrasePhrase;
}

// Actions for the prefs window
- (IBAction) openPrefs:(id)sender;
- (IBAction) prefsSave:(id)sender;
- (IBAction) prefsCancel:(id)sender;

// Called when a document needs a passphrase
- (NSMutableData *) getEncryptionKeyWithNote:(NSString *)noteType
                    warnOnShortPassphrase:(BOOL)shouldWarn
                    forDocumentNamed:(NSString *)docName;

// Actions for the passphrase window
- (IBAction) passphraseAccept:(id)sender;
- (IBAction) passphraseCancel:(id)sender;

@end
