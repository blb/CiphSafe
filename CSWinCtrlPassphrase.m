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

@interface CSWinCtrlPassphrase (InternalMethods)
- (NSMutableData *) _genKey;
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
   [ passphraseNote setStringValue:NSLocalizedString( noteType, nil ) ];
   parentWindow = nil;
   windowReturn = [ NSApp runModalForWindow:[ self window ] ];
   [ [ self window ] orderOut:self ];
   keyData = [ self _genKey ];
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
   [ passphraseNote setStringValue:NSLocalizedString( noteType, nil ) ];
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
      // Warn if it is short and the user pref is enabled
      if( ( [ [ passphrasePhrase stringValue ] length ] <
            CSWINCTRLPASSPHRASE_SHORT_PASSPHRASE ) &&
          [ [ NSUserDefaults standardUserDefaults ]
            boolForKey:CSPrefDictKey_WarnShort ] )
         NSBeginInformationalAlertSheet( CSWINCTRLPASSPHRASE_LOC_SHORTPHRASE,
            CSWINCTRLPASSPHRASE_LOC_USEIT, CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN, nil,
            parentWindow, self, nil,
            @selector( _shortPPSheetDidDismiss:returnCode:contextInfo: ),
            NULL, CSWINCTRLPASSPHRASE_LOC_PHRASEISSHORT );
      else
         [ modalDelegate performSelector:sheetEndSelector
                         withObject:[ self _genKey ] ];
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
      [ [ self _genKey ] clearOutData ];
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
                      withObject:[ self _genKey ] ];
   else   // Bring back the original sheet
      [ NSApp beginSheet:[ self window ] modalForWindow:parentWindow
              modalDelegate:self didEndSelector:nil contextInfo:NULL ];
}


/*
 * Generate the key from the passphrae in the window
 */
- (NSMutableData *) _genKey
{
   NSString *passphrase;
   NSData *passphraseData;
   NSMutableData *keyData;

   passphrase = [ passphrasePhrase stringValue ];
   // XXX Might setStringValue: leave any cruft around?
   [ passphrasePhrase setStringValue:@"" ];
   passphraseData = [ passphrase dataUsingEncoding:NSUnicodeStringEncoding ];
   keyData = [ passphraseData SHA1Hash ];
   [ passphraseData clearOutData ];
   passphraseData = nil;
   /*
    * XXX At this point, passphrase should be cleared, however, there is no
    * way, that I've yet found, to do that...here's hoping it gets released
    * and cleared soon...
    */
   passphrase = nil;

   return keyData;
}

@end
