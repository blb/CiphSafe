/* CSDocument_CMM.m */

#import "CSDocument_CMM.h"
#import "CSDocModel.h"

@interface CSDocument (CMM_InternalMethods)
- (void) _copyEntryString:(NSString *)columnName;
@end

@implementation CSDocument (CMM)

/*
 * Contextual menu methods
 */

/*
 * Provide the contextual menu for the table view; select the view for good
 * visual feedback
 */
- (NSMenu *) contextualMenuForTableViewRow:(int)row
{
   [ documentView selectRow:row byExtendingSelection:NO ];

   return contextualMenu;
}


/*
 * Copy the account to the pasteboard
 */
- (IBAction) cmmCopyAccount:(id)sender
{
   [ self _copyEntryString:CSDocModelKey_Acct ];
}



/*
 * Copy the password to the pasteboard
 */
- (IBAction) cmmCopyPassword:(id)sender
{
   [ self _copyEntryString:CSDocModelKey_Passwd ];
}


/*
 * Copy URL
 */
- (IBAction) cmmCopyURL:(id)sender
{
   [ self _copyEntryString:CSDocModelKey_URL ];
}


/*
 * Copy Name
 */
- (IBAction) cmmCopyName:(id)sender
{
   [ self _copyEntryString:CSDocModelKey_Name ];
}


/*
 * Provide the RTF and RTFD data from the notes field
 */
- (IBAction) cmmCopyNotes:(id)sender
{
   NSPasteboard *generalPasteboard;

   generalPasteboard = [ NSPasteboard generalPasteboard ];
   [ generalPasteboard declareTypes:[ NSArray arrayWithObjects:NSRTFDPboardType,
                                                               NSRTFPboardType,
                                                               nil ]
     owner:nil ];

   [ generalPasteboard setData:
                          [ self RTFDNotesAtRow:[ documentView selectedRow ] ]
                       forType:NSRTFDPboardType ];
   [ generalPasteboard setData:[ self RTFNotesAtRow:[ documentView selectedRow ] ]
                       forType:NSRTFPboardType ];
}


/*
 * Copy the entry's column of the correct row to the pasteboard as a string
 */
- (void) _copyEntryString:(NSString *)columnName
{
   NSPasteboard *generalPB;

   generalPB = [ NSPasteboard generalPasteboard ];
   [ generalPB declareTypes:[ NSArray arrayWithObject:NSStringPboardType ]
               owner:nil ];
   [ generalPB setString:[ self stringForKey:columnName
                                atRow:[ documentView selectedRow ] ]
               forType:NSStringPboardType ];
}

@end
