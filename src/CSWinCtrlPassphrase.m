/*
 * Copyright © 2003,2006-2007,2011, Bryan L Blackburn.  All rights reserved.
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
#import "CSPrefsController.h"
#import "NSData_crypto.h"
#import "NSData_clear.h"


NSString * const CSPassphraseNote_Save = @"Passphrase hint";
NSString * const CSPassphraseNote_Load = @"Passphrase for file";
NSString * const CSPassphraseNote_Change = @"New passphrase";

// What's considered short
static const int CSWinCtrlPassphrase_ShortPassPhrase = 8;

// Defines for localized strings
#define CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN NSLocalizedString(@"Enter Again", @"")


@interface CSWinCtrlPassphrase (InternalMethods)
- (BOOL) doPassphrasesMatch;
- (NSMutableData *) generateKeyUsingConfirmationTab:(BOOL)useConfirmTab;
@end


@implementation CSWinCtrlPassphrase


#pragma mark -
#pragma mark Initialization
- (id) init
{
   self = [super initWithWindowNibName:@"CSPassphrase"];

   return self;
}


#pragma mark -
#pragma mark Button Handling
/*
 * Passphrase was accepted
 */
- (IBAction) passphraseAccept:(id)sender
{
   if(parentWindow == nil)   // Running app-modal
      [NSApp stopModal];
   else   // As a sheet
   {
      // Remove the sheet before starting a new one
      [NSApp endSheet:[self window]];
      [[self window] orderOut:self];
      if(![self doPassphrasesMatch])
      {
         // Ask for direction if the passphrases don't match
         NSBeginAlertSheet(NSLocalizedString(@"Passphrases Don't Match", @""),
                           CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN,
                           NSLocalizedString(@"Cancel", @""),
                           nil,
                           parentWindow,
                           self,
                           nil,
                           @selector(noMatchSheetDidDismiss:returnCode:contextInfo:),
                           NULL,
                           NSLocalizedString(@"The passphrases do not match; do you wish to enter again "
                                             @"or cancel?", @""));
      }
      else if(([[passphrasePhrase2 stringValue] length] < CSWinCtrlPassphrase_ShortPassPhrase))
      {
         // Warn if it is short
         NSBeginAlertSheet(NSLocalizedString(@"Short Passphrase", @""),
                           NSLocalizedString(@"Use It", @""),
                           CSWINCTRLPASSPHRASE_LOC_ENTERAGAIN,
                           nil,
                           parentWindow,
                           self,
                           nil,
                           @selector(shortPPSheetDidDismiss:returnCode:contextInfo:),
                           NULL,
                           NSLocalizedString(@"The entered passphrase is somewhat short, do you wish to " 
                                             @"use it anyway?", @""));
      }
      else   // All is well, send the key
         [modalDelegate performSelector:sheetEndSelector
                             withObject:[self generateKeyUsingConfirmationTab:YES]];
   }
}


/*
 * Passphrase not entered
 */
- (IBAction) passphraseCancel:(id)sender
{
   if(parentWindow == nil)   // Running app-modal
      [NSApp abortModal];
   else   // Sheet
   {
      [NSApp endSheet:[self window]];
      [[self window] orderOut:self];
      [[self generateKeyUsingConfirmationTab:YES] clearOutData];
      [modalDelegate performSelector:sheetEndSelector withObject:nil];
   }
}


#pragma mark -
#pragma mark Sheet Handling
/*
 * End of the "passphrases don't match" sheet
 */
- (void) noMatchSheetDidDismiss:(NSWindow *)sheet
                     returnCode:(int)returnCode
                    contextInfo:(void *)contextInfo
{
   if(returnCode == NSAlertDefaultReturn)   // Enter again
      [NSApp beginSheet:[self window]
         modalForWindow:parentWindow
          modalDelegate:self
         didEndSelector:nil
            contextInfo:NULL];
   else   // Cancel all together
   {
      [[self generateKeyUsingConfirmationTab:YES] clearOutData];
      [modalDelegate performSelector:sheetEndSelector withObject:nil];
   }
}


/*
 * End of the "short passphrase" warning sheet
 */
- (void) shortPPSheetDidDismiss:(NSWindow *)sheet
                     returnCode:(int)returnCode
                    contextInfo:(void *)contextInfo
{
   if(returnCode == NSAlertDefaultReturn)   // Use it
      [modalDelegate performSelector:sheetEndSelector
                          withObject:[self generateKeyUsingConfirmationTab:YES]];
   else   // Bring back the original sheet
      [NSApp beginSheet:[self window]
         modalForWindow:parentWindow
          modalDelegate:self
         didEndSelector:nil
            contextInfo:NULL];
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * Size the window to fit the given frame
 */
- (void) setAndSizeWindowForView:(NSView *)theView
{
   NSWindow *myWindow = [self window];
   NSRect contentRect = [NSWindow contentRectForFrameRect:[myWindow frame]
                                                styleMask:[myWindow styleMask]];
   contentRect.origin.y += contentRect.size.height - [theView frame].size.height;
   contentRect.size = [theView frame].size;
   [myWindow setFrame:[NSWindow frameRectForContentRect:contentRect styleMask:[myWindow styleMask]]
              display:NO];
   [myWindow setContentView:theView];
}


/*
 * Return whether or not the passphrases match
 */
- (BOOL) doPassphrasesMatch
{
   // XXX This may leave stuff around, but there's no way around it
   return [[passphrasePhrase2 stringValue] isEqualToString:[passphrasePhraseConfirm stringValue]];
}


/*
 * Generate the key from the passphrase in the window; this does not verify
 * passphrases match on the confirm tab
 */
- (NSMutableData *) generateKeyUsingConfirmationTab:(BOOL)useConfirmTab
{
   NSString *passphrase;
   if(useConfirmTab)
   {
      passphrase = [passphrasePhrase2 stringValue];
      // XXX Might setStringValue: leave any cruft around?
      [passphrasePhrase2 setStringValue:@""];
      // XXX Again, anything left behind from setStringValue:?
      [passphrasePhraseConfirm setStringValue:@""];
   }
   else
   {
      passphrase = [passphrasePhrase1 stringValue];
      // XXX And again, setStringValue:?
      [passphrasePhrase1 setStringValue:@""];
   }
   
   NSData *passphraseData = [passphrase dataUsingEncoding:NSUnicodeStringEncoding];
   const unsigned char *dataBytes = [passphraseData bytes];
   /*
    * When CiphSafe was originally written, and PowerPC was the only architecture, this innocent-looking
    * use of dataUsingEncoding: above was safe.  Now, however, with Intel-based Macs, this returns a
    * little endian representation, and will cause it to fail with older documents.  We need to detect
    * this and reverse bytes to put it into big endian.
    */
   if(dataBytes[0] == 0xFF && dataBytes[1] == 0xFE)
   {
      NSMutableData *newData = [NSMutableData dataWithLength:[passphraseData length]];
      unsigned char *newBytes = [newData mutableBytes];
      unsigned int position;
      for(position = 0; position < [passphraseData length]; position += 2)
      {
         newBytes[position] = dataBytes[position + 1];
         newBytes[position + 1] = dataBytes[position];
      }
      [passphraseData clearOutData];
      passphraseData = newData;
   }
   int pdLen = [passphraseData length];
   NSData *dataFirst = [passphraseData subdataWithRange:NSMakeRange(0, pdLen / 2)];
   NSData *dataSecond = [passphraseData subdataWithRange:NSMakeRange(pdLen / 2, pdLen - pdLen / 2)];
   [passphraseData clearOutData];
   /*
    * XXX At this point, passphrase should be cleared, however, there is no way,
    * that I've yet found, to do that...here's hoping it gets released and the
    * memory reused soon...
    */
   passphrase = nil;
   
   NSMutableData *keyData = [dataFirst SHA1Hash];
   [dataFirst clearOutData];
   NSMutableData *tmpData = [dataSecond SHA1Hash];
   [dataSecond clearOutData];
   [keyData appendData:tmpData];
   [tmpData clearOutData];
   
   return keyData;
}


/*
 * Get an encryption key, making the window application-modal;
 * noteType is one of the CSPassphraseNote_* variables
 */
- (NSMutableData *) getEncryptionKeyWithNote:(NSString *)noteType
                            forDocumentNamed:(NSString *)docName
{
   [[self window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"Enter passphrase for %@", @""),
                                                      docName]];
   [passphraseNote1 setStringValue:NSLocalizedString(noteType, nil)];
   [self setAndSizeWindowForView:nonConfirmView];
   NSArray *runModeArray = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil];
   [[NSRunLoop currentRunLoop] performSelector:@selector(makeFirstResponder:)
                                        target:[self window]
                                      argument:passphrasePhrase1
                                         order:9999
                                         modes:runModeArray];
   parentWindow = nil;
   int windowReturn = [NSApp runModalForWindow:[self window]];
   [[self window] orderOut:self];
   NSMutableData *keyData = [self generateKeyUsingConfirmationTab:NO];
   if(windowReturn == NSRunAbortedResponse)
   {
      [keyData clearOutData];
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
   [[self window] setTitle:@""];
   [passphraseNote2 setStringValue:NSLocalizedString(noteType, nil)];
   [self setAndSizeWindowForView:confirmView];
   NSArray *runModeArray = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil];
   [[NSRunLoop currentRunLoop] performSelector:@selector(makeFirstResponder:)
                                        target:[self window]
                                      argument:passphrasePhrase2
                                         order:9999
                                         modes:runModeArray];
   parentWindow = window;
   modalDelegate = delegate;
   sheetEndSelector = selector;
   [NSApp beginSheet:[self window]
      modalForWindow:parentWindow
       modalDelegate:self
      didEndSelector:nil
         contextInfo:NULL];
}

@end
