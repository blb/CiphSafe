/*
 * Copyright © 2003, Bryan L Blackburn.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * 3. Neither the names Bryan L Blackburn, Withay.com, nor the names of
 *    any contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY BRYAN L BLACKBURN ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
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
#define CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN \
           NSLocalizedString( @"Enter Again", @"" )
#define CSWINCTRLPASSPHRASE_LOC_WINTITLE \
           NSLocalizedString( @"Enter passphrase for %@", @"" )
#define CSWINCTRLPASSPHRASE_LOC_DONTMATCH \
           NSLocalizedString( @"Passphrases Don't Match", @"" )
#define CSWINCTRLPASSPHRASE_LOC_NOMATCH \
           NSLocalizedString( @"The passphrases do not match; do you wish to " \
                              @"enter again or cancel?", @"" )
#define CSWINCTRLPASSPHRASE_LOC_CANCEL NSLocalizedString( @"Cancel", @"" )

@interface CSWinCtrlPassphrase (InternalMethods)
- (void) _setAndSizeWindowForView:(NSView *)theView;
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
   [ _passphraseNote1 setStringValue:NSLocalizedString( noteType, nil ) ];
   [ self _setAndSizeWindowForView:_nonConfirmView ];
   _parentWindow = nil;
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
   [ _passphraseNote2 setStringValue:NSLocalizedString( noteType, nil ) ];
   [ self _setAndSizeWindowForView:_confirmView ];
   _parentWindow = window;
   _modalDelegate = delegate;
   _sheetEndSelector = selector;
   [ NSApp beginSheet:[ self window ]
           modalForWindow:_parentWindow
           modalDelegate:self
           didEndSelector:nil
           contextInfo:NULL ];
}


/*
 * Passphrase was accepted
 */
- (IBAction) passphraseAccept:(id)sender
{
   if( _parentWindow == nil )   // Running app-modal
      [ NSApp stopModal ];
   else   // As a sheet
   {
      // Remove the sheet before starting a new one
      [ NSApp endSheet:[ self window ] ];
      [ [ self window ] orderOut:self ];
      if( ![ self _doPassphrasesMatch ] )
      {
         // Ask for direction if the passphrases don't match
         NSBeginAlertSheet( CSWINCTRLPASSPHRASE_LOC_DONTMATCH,
            CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN, CSWINCTRLPASSPHRASE_LOC_CANCEL,
            nil, _parentWindow, self, nil,
            @selector( _noMatchSheetDidDismiss:returnCode:contextInfo: ),
            NULL, CSWINCTRLPASSPHRASE_LOC_NOMATCH );
      }
      else if( ( [ [ _passphrasePhrase2 stringValue ] length ] <
                 CSWINCTRLPASSPHRASE_SHORT_PASSPHRASE ) &&
               [ [ NSUserDefaults standardUserDefaults ]
                 boolForKey:CSPrefDictKey_WarnShort ] )
      {
         // Warn if it is short and the user pref is enabled
         NSBeginAlertSheet( CSWINCTRLPASSPHRASE_LOC_SHORTPHRASE,
            CSWINCTRLPASSPHRASE_LOC_USEIT, CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN,
            nil, _parentWindow, self, nil,
            @selector( _shortPPSheetDidDismiss:returnCode:contextInfo: ),
            NULL, CSWINCTRLPASSPHRASE_LOC_PHRASEISSHORT );
      }
      else   // All is well, send the key
         [ _modalDelegate performSelector:_sheetEndSelector
                          withObject:[ self _genKeyForConfirm:YES ] ];
   }
}


/*
 * Passphrase not entered
 */
- (IBAction) passphraseCancel:(id)sender
{
   if( _parentWindow == nil )   // Running app-modal
      [ NSApp abortModal ];
   else   // Sheet
   {
      [ NSApp endSheet:[ self window ] ];
      [ [ self window ] orderOut:self ];
      [ [ self _genKeyForConfirm:YES ] clearOutData ];
      [ _modalDelegate performSelector:_sheetEndSelector withObject:nil ];
   }
}


/*
 * Size the window to fit the given frame
 */
- (void) _setAndSizeWindowForView:(NSView *)theView
{
   NSWindow *myWindow;
   NSRect contentRect;

   myWindow = [ self window ];
   contentRect = [ NSWindow contentRectForFrameRect:[ myWindow frame ]
                             styleMask:[ myWindow styleMask ] ];
   contentRect.origin.y += contentRect.size.height -
                           [ theView frame ].size.height;
   contentRect.size = [ theView frame ].size;
   [ myWindow setFrame:[ NSWindow frameRectForContentRect:contentRect
                                  styleMask:[ myWindow styleMask ] ]
              display:NO ];
   [ myWindow setContentView:theView ];
}


/*
 * End of the "passphrases don't match" sheet
 */
- (void) _noMatchSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void  *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // Enter again
      [ NSApp beginSheet:[ self window ]
              modalForWindow:_parentWindow
              modalDelegate:self
              didEndSelector:nil
              contextInfo:NULL ];
   else   // Cancel all together
   {
      [ [ self _genKeyForConfirm:YES ] clearOutData ];
      [ _modalDelegate performSelector:_sheetEndSelector withObject:nil ];
   }
}


/*
 * End of the "short passphrase" warning sheet
 */
- (void) _shortPPSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void  *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // Use it
      [ _modalDelegate performSelector:_sheetEndSelector
                       withObject:[ self _genKeyForConfirm:YES ] ];
   else   // Bring back the original sheet
      [ NSApp beginSheet:[ self window ]
              modalForWindow:_parentWindow
              modalDelegate:self
              didEndSelector:nil
              contextInfo:NULL ];
}


/*
 * Return whether or not the passphrases match
 */
- (BOOL) _doPassphrasesMatch
{
   // XXX This may leave stuff around, but there's no way around it
   return [ [ _passphrasePhrase2 stringValue ]
            isEqualToString:[ _passphrasePhraseConfirm stringValue ] ];
}


/*
 * Generate the key from the passphrase in the window; this does not verify
 * passphrases match on the confirm tab
 */
- (NSMutableData *) _genKeyForConfirm:(BOOL)useConfirmTab
{
   NSString *passphrase;
   NSData *passphraseData, *dataFirst, *dataSecond;
   NSMutableData *keyData, *tmpData;
   int pdLen;

   if( useConfirmTab )
   {
      passphrase = [ _passphrasePhrase2 stringValue ];
      // XXX Might setStringValue: leave any cruft around?
      [ _passphrasePhrase2 setStringValue:@"" ];
      // XXX Again, anything left behind from setStringValue:?
      [ _passphrasePhraseConfirm setStringValue:@"" ];
   }
   else
   {
      passphrase = [ _passphrasePhrase1 stringValue ];
      // XXX And again, setStringValue:?
      [ _passphrasePhrase1 setStringValue:@"" ];
   }

   passphraseData = [ passphrase dataUsingEncoding:NSUnicodeStringEncoding ];
   pdLen = [ passphraseData length ];
   dataFirst = [ passphraseData subdataWithRange:NSMakeRange( 0, pdLen / 2 ) ];
   dataSecond = [ passphraseData subdataWithRange:
                                    NSMakeRange( pdLen / 2, pdLen - pdLen / 2 ) ];
   /*
    * XXX At this point, passphrase should be cleared, however, there is no way,
    * that I've yet found, to do that...here's hoping it gets released and the
    * memory reused soon...
    */
   passphrase = nil;

   keyData = [ dataFirst SHA1Hash ];
   tmpData = [ dataSecond SHA1Hash ];
   [ keyData appendData:tmpData ];
   [ tmpData clearOutData ];
   [ dataFirst clearOutData ];
   [ dataSecond clearOutData ];
   [ passphraseData clearOutData ];

   return keyData;
}

@end
