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
/* CSWinCtrlEntry.h */

#import <Cocoa/Cocoa.h>

// Defines for localized strings
#define CSWINCTRLENTRY_LOC_ENTRYEXISTS \
        NSLocalizedString( @"Entry Already Exists", @"" )
#define CSWINCTRLENTRY_LOC_ENTRYEXISTSRENAME \
        NSLocalizedString( @"An entry with that name already exists, enter " \
                           @"another name", @"" )

@interface CSWinCtrlEntry : NSWindowController
{
   NSUndoManager *_notesUM;
   NSUndoManager *_otherUM;

   IBOutlet NSTextField *_nameText;
   IBOutlet NSTextField *_accountText;
   IBOutlet NSTextField *_passwordText;
   IBOutlet NSTextField *_urlText;
   IBOutlet NSComboBox *_category;
   IBOutlet NSTextView *_notes;
   IBOutlet NSButton *_mainButton;
}

// Gererate an random password
- (IBAction) doGenerate:(id)sender;

// Open the URL from the URL field
- (IBAction) doOpenURL:(id)sender;

// Our implementation of whether the data is dirty
- (void) updateDocumentEditedStatus;

// Methods to make it a data source for category combo boxes
- (int) numberOfItemsInComboBox:(NSComboBox *)aComboBox;
- (id) comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index;
- (unsigned int) comboBox:(NSComboBox *)aComboBox
                 indexOfItemWithStringValue:(NSString *)aString;

/*
 * Used by updateDocumentEditedStatus to determine if data is dirty; overridden
 * in subclasses
 */
- (BOOL) nameChanged;
- (BOOL) accountChanged;
- (BOOL) passwordChanged;
- (BOOL) urlChanged;
- (BOOL) categoryChanged;
- (BOOL) notesChanged;

@end
