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
/* CSWinCtrlAdd.m */

#import "CSWinCtrlAdd.h"
#import "CSDocModel.h"
#import "CSDocument.h"
#import "CSAppController.h"

// Defines for localized strings
#define CSWINCTRLADD_LOC_ADDTO NSLocalizedString( @"Add to %@", @"" )

@implementation CSWinCtrlAdd

- (id) init
{
   self = [ super initWithWindowNibName:@"CSDocumentAdd" ];

   return self;
}


/*
 * Setup the window
 */
- (void) awakeFromNib
{
   [ super awakeFromNib ];
   [ self doClear:self ];
}


/*
 * We don't want to have the file represented (icon) in the title bar
 */
- (void) synchronizeWindowTitleWithDocumentName
{
   [ [ self window ] setTitle:[ NSString stringWithFormat:CSWINCTRLADD_LOC_ADDTO,
                                            [ [ self document ] displayName ] ] ];
}


/*
 * Clear out all the fields
 */
- (IBAction) doClear:(id)sender
{
   // XXX If there's a way to clear out a control's data space, we'd do that here
   [ _nameText setStringValue:@"" ];
   [ _accountText setStringValue:@"" ];
   [ _passwordText setStringValue:@"" ];
   [ _urlText setStringValue:@"" ];
   [ _category setStringValue:CSDocModelCategory_General ];
   [ _notes setString:@"" ];
   [ [ _notes undoManager ] removeAllActions ];
   [ _mainButton setEnabled:NO ];
   [ [ self window ] setDocumentEdited:NO ];
}


/*
 * Add the entry from data given
 */
- (IBAction) doAdd:(id)sender
{
   NSRange fullNotesRange;

   fullNotesRange = NSMakeRange( 0, [ [ _notes textStorage ] length ] );
   if( [ [ self document ] addEntryWithName:[ _nameText stringValue ]
                           account:[ _accountText stringValue ]
                           password:[ _passwordText stringValue ]
                           URL:[ _urlText stringValue ]
                           category:[ _category stringValue ]
                           notesRTFD:[ _notes RTFDFromRange:fullNotesRange ] ] )
   {
      [ self doClear:self ];
      if( ![ [ NSUserDefaults standardUserDefaults ] 
             boolForKey:CSPrefDictKey_CloseAdd ] )
      {
         // We queue it here as doing it immediately won't work
         [ [ NSRunLoop currentRunLoop ]
           performSelector:@selector( makeFirstResponder: )
           target:[ self window ]
           argument:_nameText
           order:9999
           modes:[ NSArray arrayWithObject:NSDefaultRunLoopMode ] ];
      }
      else
         [ [ self window ] performClose:self ];
   }
   else
      NSBeginInformationalAlertSheet( CSWINCTRLENTRY_LOC_ENTRYEXISTS,
                                      nil, nil, nil, [ self window ],
                                      nil, nil, nil, NULL,
                                      CSWINCTRLENTRY_LOC_ENTRYEXISTSRENAME );
}


/*
 * Fields have changed when they are not empty
 */
- (BOOL) nameChanged
{
   return ( [ [ _nameText stringValue ] length ] > 0 );
}

- (BOOL) accountChanged
{
   return ( [ [ _accountText stringValue ] length ] > 0 );
}

- (BOOL) passwordChanged
{
   return ( [ [ _passwordText stringValue ] length ] > 0 );
}

- (BOOL) urlChanged
{
   return ( [ [ _urlText stringValue ] length ] > 0 );
}

- (BOOL) categoryChanged
{
   return ![ [ _category stringValue ]
             isEqualToString:CSDocModelCategory_General ];
}

- (BOOL) notesChanged
{
   return ( [ [ _notes textStorage ] length ] > 0 );
}

@end
