/*
 * Copyright © 2003,2006-2007, Bryan L Blackburn.  All rights reserved.
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
#import "CSPrefsController.h"


@implementation CSWinCtrlAdd

#pragma mark -
#pragma mark Initialization
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
   [ self clear:self ];
}


#pragma mark -
#pragma mark Button Handling
/*
 * Clear out all the fields
 */
- (IBAction) clear:(id)sender
{
   // XXX If there's a way to clear out a control's data space, we'd do that here
   [ nameText setStringValue:@"" ];
   [ accountText setStringValue:@"" ];
   [ passwordText setStringValue:@"" ];
   [ urlText setStringValue:@"" ];
   [ category selectItemAtIndex:0 ];
   [ notes setString:@"" ];
   [ [ notes undoManager ] removeAllActions ];
   [ mainButton setEnabled:NO ];
   [ [ self window ] setDocumentEdited:NO ];
}


/*
 * Add the entry from data given
 */
- (IBAction) add:(id)sender
{
   NSRange fullNotesRange = NSMakeRange( 0, [ [ notes textStorage ] length ] );
   if( [ [ self document ] addEntryWithName:[ nameText stringValue ]
                                    account:[ accountText stringValue ]
                                   password:[ passwordText stringValue ]
                                        URL:[ urlText stringValue ]
                                   category:[ category stringValue ]
                                  notesRTFD:[ notes RTFDFromRange:fullNotesRange ] ] )
   {
      [ self clear:self ];
      if( ![ [ NSUserDefaults standardUserDefaults ] boolForKey:CSPrefDictKey_CloseAdd ] )
      {
         // We queue it here as doing it immediately won't work
         [ [ NSRunLoop currentRunLoop ]
           performSelector:@selector( makeFirstResponder: )
                    target:[ self window ]
                  argument:nameText
                     order:9999
                     modes:[ NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, nil ] ];
      }
      else
         [ [ self window ] performClose:self ];
   }
   else
      NSBeginInformationalAlertSheet( CSWINCTRLENTRY_LOC_ENTRYEXISTS,
                                      nil,
                                      nil,
                                      nil,
                                      [ self window ],
                                      nil,
                                      nil,
                                      nil,
                                      NULL,
                                      CSWINCTRLENTRY_LOC_ENTRYEXISTSRENAME );
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * We don't want to have the file represented (icon) in the title bar
 */
- (void) synchronizeWindowTitleWithDocumentName
{
   [ [ self window ] setTitle:[ NSString stringWithFormat:NSLocalizedString( @"Add to %@", @"" ),
      [ [ self document ] displayName ] ] ];
}


#pragma mark -
#pragma mark Flagging Changes
/*
 * Fields have changed when they are not empty
 */
- (BOOL) nameChanged
{
   return ( [ [ nameText stringValue ] length ] > 0 );
}

- (BOOL) accountChanged
{
   return ( [ [ accountText stringValue ] length ] > 0 );
}

- (BOOL) passwordChanged
{
   return ( [ [ passwordText stringValue ] length ] > 0 );
}

- (BOOL) urlChanged
{
   return ( [ [ urlText stringValue ] length ] > 0 );
}

- (BOOL) categoryChanged
{
   return [ category indexOfSelectedItem ] != 0;
}

- (BOOL) notesChanged
{
   return ( [ [ notes textStorage ] length ] > 0 );
}

@end
