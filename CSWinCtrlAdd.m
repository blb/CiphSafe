// Interesting security issues are noted with XXX in comments
/* CSWinCtrlAdd.m */

#import "CSWinCtrlAdd.h"
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
   [ nameText setStringValue:@"" ];
   [ accountText setStringValue:@"" ];
   [ passwordText setStringValue:@"" ];
   [ urlText setStringValue:@"" ];
   [ notes setString:@"" ];
   [ [ notes undoManager ] removeAllActions ];
   [ mainButton setEnabled:NO ];
   [ [ self window ] setDocumentEdited:NO ];
}


/*
 * Add the entry from data given
 */
- (IBAction) doAdd:(id)sender
{
   NSRange fullNotesRange;

   fullNotesRange = NSMakeRange( 0, [ [ notes textStorage ] length ] );
   if( [ [ self document ] addEntryWithName:[ nameText stringValue ]
                           account:[ accountText stringValue ]
                           password:[ passwordText stringValue ]
                           URL:[ urlText stringValue ]
                           notesRTFD:[ notes RTFDFromRange:fullNotesRange ] ] )
   {
      [ self doClear:self ];
      if( ![ [ NSUserDefaults standardUserDefaults ] 
             boolForKey:CSPrefDictKey_CloseAdd ] )
      {
         // We queue it here as doing it immediately won't work
         [ [ NSRunLoop currentRunLoop ]
           performSelector:@selector( makeFirstResponder: )
           target:[ self window ]
           argument:nameText
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

- (BOOL) notesChanged
{
   return ( [ [ notes textStorage ] length ] > 0 );
}

@end
