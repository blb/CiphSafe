/* CSWinCtrlPassphrase.h */

#import <Cocoa/Cocoa.h>

// Note types used with getEncryptionKeyWithNote:warnOnShortPassphrase:
extern NSString * const CSPassphraseNote_Save;
extern NSString * const CSPassphraseNote_Load;
extern NSString * const CSPassphraseNote_Change;

@interface CSWinCtrlPassphrase : NSWindowController
{
   NSWindow *parentWindow;
   id modalDelegate;
   SEL sheetEndSelector;

   // View without confirmed passphrase entry
   IBOutlet NSView *nonConfirmView;
   IBOutlet NSTextField *passphraseNote1;
   IBOutlet NSTextField *passphrasePhrase1;

   // View with confirmed passphrase entry
   IBOutlet NSView *confirmView;
   IBOutlet NSTextField *passphraseNote2;
   IBOutlet NSTextField *passphrasePhrase2;
   IBOutlet NSTextField *passphrasePhraseConfirm;
}

// Request a passphrase, app-modal
- (NSMutableData *) getEncryptionKeyWithNote:(NSString *)noteType
                    forDocumentNamed:(NSString *)docName;

// Request a passphrase, doc-modal
- (void) getEncryptionKeyWithNote:(NSString *)noteType
         inWindow:(NSWindow *)window
         modalDelegate:(id)delegate
         sendToSelector:(SEL)selector;

// Actions for the passphrase window
- (IBAction) passphraseAccept:(id)sender;
- (IBAction) passphraseCancel:(id)sender;

@end
