// Interesting security issues are noted with XXX in comments
/* CSWinCtrlPassphrase.m */

#import "CSWinCtrlPassphrase.h"
#import "CSAppController.h"
#import "NSData_crypto.h"
#import "NSData_clear.h"

NSString * const CSPassphraseNote_Save = @"Passphrase hint";
NSString * const CSPassphraseNote_Load = @"Passphrase for file";
NSString * const CSPassphraseNote_Change = @"New passphrase";

// What's considered short
#define CSWINCTRLPASSPHRASE_SHORT_PASSPHRASE 8

#define CSWINCTRLPASSPHRASE_TABVIEW_NOCONFIRM @"noconfirm"
#define CSWINCTRLPASSPHRASE_TABVIEW_CONFIRM @"confirm"

// Defines for localized strings
#define CSWINCTRLPASSPHRASE_LOC_SHORTPHRASE \
        NSLocalizedString( @"Short Passphrase", "short passphrase" )
#define CSWINCTRLPASSPHRASE_LOC_PHRASEISSHORT \
        NSLocalizedString( @"The entered passphrase is somewhat short, do " \
                           @"you wish to use it anyway?", @"" )
#define CSWINCTRLPASSPHRASE_LOC_USEIT NSLocalizedString( @"Use It", @"" )
#define CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN NSLocalizedString( @"Enter Again", @"" )
#define CSWINCTRLPASSPHRASE_LOC_WINTITLE \
        NSLocalizedString( @"Enter passphrase for %@", @"" )
#define CSWINCTRLPASSPHRASE_LOC_DONTMATCH \
        NSLocalizedString( @"Passphrases Don't Match", @"" )
#define CSWINCTRLPASSPHRASE_LOC_NOMATCH \
        NSLocalizedString( @"The passphrases do not match; do you wish to enter " \
                           @"again or cancel?", @"" )
#define CSWINCTRLPASSPHRASE_LOC_CANCEL NSLocalizedString( @"Cancel", @"" )

@interface CSWinCtrlPassphrase (InternalMethods)
- (BOOL) _doPassphrasesMatch;
- (NSMutableData *) _genKeyForConfirm:(BOOL)useConfirmTab;
@end

@implementation CSWinCtrlPassphrase

- (id) init
{
   self = [ super initWithWindowNibName:@"CSPassphrase" ];

   return self;
}


/*
 * Get an encryption key, making the window application-modal;
 * noteType is one of the CSPassphraseNote_* variables
 */
- (NSMutableData *) getEncryptionKeyWithNote:(NSString *)noteType
                    forDocumentNamed:(NSString *)docName
{
   int windowReturn;
   NSMutableData *keyData;

   [ [ self window ] setTitle:[ NSString stringWithFormat:
                                            CSWINCTRLPASSPHRASE_LOC_WINTITLE,
                                            docName ] ];
   [ passphraseNote1 setStringValue:NSLocalizedString( noteType, nil ) ];
   [ tabView selectTabViewItemWithIdentifier:
                CSWINCTRLPASSPHRASE_TABVIEW_NOCONFIRM ];
   parentWindow = nil;
   windowReturn = [ NSApp runModalForWindow:[ self window ] ];
   [ [ self window ] orderOut:self ];
   keyData = [ self _genKeyForConfirm:NO ];
   if( windowReturn == NSRunAbortedResponse )
   {
      [ keyData clearOutData ];
      keyData = nil;
   }

   return keyData;
}


/*
 * Get an encryption key, making the window a sheet attached to the given window
 * noteType is one of the CSPassphraseNote_* variables
 */
- (void) getEncryptionKeyWithNote:(NSString *)noteType
         inWindow:(NSWindow *)window
         modalDelegate:(id)delegate
         sendToSelector:(SEL)selector
{
   [ [ self window ] setTitle:@"" ];
   [ passphraseNote2 setStringValue:NSLocalizedString( noteType, nil ) ];
   [ tabView selectTabViewItemWithIdentifier:CSWINCTRLPASSPHRASE_TABVIEW_CONFIRM ];
   parentWindow = window;
   modalDelegate = delegate;
   sheetEndSelector = selector;
   [ NSApp beginSheet:[ self window ] modalForWindow:parentWindow
           modalDelegate:self didEndSelector:nil contextInfo:NULL ];
}


/*
 * Passphrase was accepted; warn if it's pretty short
 */
- (IBAction) passphraseAccept:(id)sender
{
   if( parentWindow == nil )   // Running app-modal
      [ NSApp stopModal ];
   else   // As a sheet
   {
      [ NSApp endSheet:[ self window ] ];
      [ [ self window ] close ];
      if( ![ self _doPassphrasesMatch ] )
      {
         // Ask for direction if the passphrases don't match
         NSBeginAlertSheet( CSWINCTRLPASSPHRASE_LOC_DONTMATCH,
            CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN, CSWINCTRLPASSPHRASE_LOC_CANCEL,
            nil, parentWindow, self, nil,
            @selector( _noMatchSheetDidDismiss:returnCode:contextInfo: ),
            NULL, CSWINCTRLPASSPHRASE_LOC_NOMATCH );
      }
      else if( ( [ [ passphrasePhrase2 stringValue ] length ] <
                 CSWINCTRLPASSPHRASE_SHORT_PASSPHRASE ) &&
               [ [ NSUserDefaults standardUserDefaults ]
                 boolForKey:CSPrefDictKey_WarnShort ] )
      {
         // Warn if it is short and the user pref is enabled
         NSBeginAlertSheet( CSWINCTRLPASSPHRASE_LOC_SHORTPHRASE,
            CSWINCTRLPASSPHRASE_LOC_USEIT, CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN, nil,
            parentWindow, self, nil,
            @selector( _shortPPSheetDidDismiss:returnCode:contextInfo: ),
            NULL, CSWINCTRLPASSPHRASE_LOC_PHRASEISSHORT );
      }
      else   // All is well, send the key
         [ modalDelegate performSelector:sheetEndSelector
                         withObject:[ self _genKeyForConfirm:YES ] ];
   }
}


/*
 * Passphrase not entered
 */
- (IBAction) passphraseCancel:(id)sender
{
   if( parentWindow == nil )   // Running app-modal
      [ NSApp abortModal ];
   else   // Sheet
   {
      [ NSApp endSheet:[ self window ] ];
      [ [ self window ] close ];
      [ [ self _genKeyForConfirm:YES ] clearOutData ];
      [ modalDelegate performSelector:sheetEndSelector withObject:nil ];
   }
}


/*
 * End of the "passphrases don't match" sheet
 */
- (void) _noMatchSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void  *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // Enter again
      [ NSApp beginSheet:[ self window ] modalForWindow:parentWindow
              modalDelegate:self didEndSelector:nil contextInfo:NULL ];
   else   // Cancel all together
   {
      [ [ self _genKeyForConfirm:YES ] clearOutData ];
      [ modalDelegate performSelector:sheetEndSelector withObject:nil ];
   }
}


/*
 * End of the "short passphrase" warning sheet
 */
- (void) _shortPPSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void  *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // Use it
      [ modalDelegate performSelector:sheetEndSelector
                      withObject:[ self _genKeyForConfirm:YES ] ];
   else   // Bring back the original sheet
      [ NSApp beginSheet:[ self window ] modalForWindow:parentWindow
              modalDelegate:self didEndSelector:nil contextInfo:NULL ];
}


/*
 * Return whether or not the passphrases match
 */
- (BOOL) _doPassphrasesMatch
{
   // XXX This may leave stuff around, but there's no way around it
   return [ [ passphrasePhrase2 stringValue ]
            isEqualToString:
               [ passphrasePhraseConfirm stringValue ] ];
}


/*
 * Generate the key from the passphrae in the window; this does not verify
 * passphrases match on the confirm tab
 */
- (NSMutableData *) _genKeyForConfirm:(BOOL)useConfirmTab
{
   NSString *passphrase;
   NSData *passphraseData;
   NSMutableData *keyData;

   if( useConfirmTab )
   {
      passphrase = [ passphrasePhrase2 stringValue ];
      // XXX Might setStringValue: leave any cruft around?
      [ passphrasePhrase2 setStringValue:@"" ];
      // XXX Again, anything left behind from setStringValue:?
      [ passphrasePhraseConfirm setStringValue:@"" ];
   }
   else
   {
      passphrase = [ passphrasePhrase1 stringValue ];
      // XXX And again, setStringValue:?
      [ passphrasePhrase1 setStringValue:@"" ];
   }

   passphraseData = [ passphrase dataUsingEncoding:NSUnicodeStringEncoding ];
   /*
    * XXX At this point, passphrase (and possibly confirmPhrase) should be cleared,
    * however, there is no way, that I've yet found, to do that...here's hoping
    * it gets released and the memory reused soon...
    */
   passphrase = nil;

   keyData = [ passphraseData SHA1Hash ];
   [ passphraseData clearOutData ];
   passphraseData = nil;

   return keyData;
}

@end
