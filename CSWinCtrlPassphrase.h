/*
 * Copyright © 2003,2006, Bryan L Blackburn.  All rights reserved.
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
