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
/* CSWinCtrlMain.m */

#import "CSWinCtrlMain.h"
#import "CSAppController.h"
#import "CSDocument.h"
#import "CSDocModel.h"

// Localized strings
#define CSWINCTRLMAIN_LOC_SUREDELROWS \
        NSLocalizedString( @"Are you sure you want to delete the selected " \
                           @"rows?", @"" )
#define CSWINCTRLMAIN_LOC_SUREDELONEROW \
        NSLocalizedString( @"Are you sure you want to delete the selected row?", \
                           @"" )
#define CSWINCTRLMAIN_LOC_SURE NSLocalizedString( @"Are You Sure?", @"" )
#define CSWINCTRLMAIN_LOC_DELETE NSLocalizedString( @"Delete", @"" )
#define CSWINCTRLMAIN_LOC_CANCEL NSLocalizedString( @"Cancel", @"" )
#define CSWINCTRLMAIN_LOC_DROP NSLocalizedString( @"Drop", @"" )
#define CSWINCTRLMAIN_LOC_PASTE NSLocalizedString( @"Paste", @"" )
#define CSWINCTRLMAIN_LOC_CUT NSLocalizedString( @"Cut", @"" )
#define CSWINCTRLMAIN_LOC_ONEENTRY NSLocalizedString( @"1 entry", @"" )
#define CSWINCTRLMAIN_LOC_NUMENTRIES NSLocalizedString( @"%d entries", @"" )
#define CSWINCTRLMAIN_LOC_INVALIDURL NSLocalizedString( @"Invalid URL", @"" )
#define CSWINCTRLMAIN_LOC_URLNOTVALID \
        NSLocalizedString( @"The URL entered is not a valid URL", @"" )

@interface CSWinCtrlMain (InternalMethods)
- (void) _deleteSheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
         contextInfo:(void *)contextInfo;
- (void) _setSortingImageForColumn:(NSTableColumn *)tableColumn;
- (NSArray *) _getSelectedNames;
- (NSArray *) _namesFromRows:(NSArray *)rows;
- (void) _copyEntryString:(NSString *)columnName;
@end

@implementation CSWinCtrlMain

- (id) init
{
   self = [ super initWithWindowNibName:@"CSDocument" ];
   if( self != nil )
   {
      [ self setShouldCloseDocument:YES ];
   }

   return self;
}


/*
 * Initial setup of the window
 */
- (void) awakeFromNib
{
   [ documentView setDrawsGrid:NO ];
   [ documentView setDrawsGrid:YES ];
   [ documentView setStripeColor:[ NSColor colorWithCalibratedRed:0.93
                                     green:0.95 blue:1.0 alpha:1.0 ] ];
   [ documentView setDoubleAction:@selector( doViewEntry: ) ];
   previouslySelectedColumn = [ documentView tableColumnWithIdentifier:
                                                [ [ self document ] sortKey ] ];
   [ documentView setHighlightedTableColumn:previouslySelectedColumn ];
   [ self _setSortingImageForColumn:previouslySelectedColumn ];
   /*
    * The table view is set as the initialFirstResponder, but we have to do
    * this anyway
    */
   [ [ self window ] makeFirstResponder:documentView ];
   [ self refreshWindow ];
   [ documentView registerForDraggedTypes:
                     [ NSArray arrayWithObject:CSDocumentPboardType ] ];
}


/*
 * Tell the document to do whatever to allow for a new entry
 */
- (IBAction) doAddEntry:(id)sender
{
   [ [ self document ] openAddEntryWindow ];
}


/*
 * Tell the document to view the certain entries
 */
- (IBAction) doViewEntry:(id)sender
{
   [ [ self document ] viewEntries:[ self _getSelectedNames ] ];
}


/*
 * Tell the document to delete certain entries
 */
- (IBAction) doDeleteEntry:(id)sender
{
   NSString *sheetQuestion;
   SEL delSelector;

   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_ConfirmDelete ] )
   {
      if( [ documentView numberOfSelectedRows ] > 1 )
         sheetQuestion = CSWINCTRLMAIN_LOC_SUREDELROWS;
      else
         sheetQuestion = CSWINCTRLMAIN_LOC_SUREDELONEROW;
      delSelector = @selector( _deleteSheetDidEnd:returnCode:contextInfo: );
      NSBeginCriticalAlertSheet( CSWINCTRLMAIN_LOC_SURE, CSWINCTRLMAIN_LOC_DELETE,
                                 CSWINCTRLMAIN_LOC_CANCEL, nil,
                                 [ self window ], self, delSelector, nil,
                                 NULL, sheetQuestion );
   }
   else
      [ [ self document ]
        deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
}


/*
 * Refresh all the views in the window
 */
- (void) refreshWindow
{
   int entryCount;

   [ documentView reloadData ];
   [ documentView deselectAll:self ];
   entryCount = [ [ self document ] entryCount ];
   if( entryCount == 1 )
      [ documentStatus setStringValue:CSWINCTRLMAIN_LOC_ONEENTRY ];
   else
      [ documentStatus setStringValue:[ NSString stringWithFormat:
                                                    CSWINCTRLMAIN_LOC_NUMENTRIES,
                                                    entryCount ] ];
}


/*
 * Cut selected rows
 */
- (IBAction) cut:(id)sender
{
   [ [ self document ]
     copyNames:[ self _getSelectedNames ]
     toPasteboard:[ NSPasteboard generalPasteboard ] ];
   [ [ self document ] deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
   [ [ [ self document ] undoManager ] setActionName:CSWINCTRLMAIN_LOC_CUT ];
   [ [ NSApp delegate ] notePBChangeCount ];
}


/*
 * Copy selected rows to the general pasteboard
 */
- (IBAction) copy:(id)sender
{
   [ [ self document ]
     copyNames:[ self _getSelectedNames ]
     toPasteboard:[ NSPasteboard generalPasteboard ] ];
   [ [ NSApp delegate ] notePBChangeCount ];
}


/*
 * Paste rows from the general pasteboard
 */
- (IBAction) paste:(id)sender
{
   [ [ self document ] retrieveEntriesFromPasteboard:
                          [ NSPasteboard generalPasteboard ]
                       undoName:CSWINCTRLMAIN_LOC_PASTE ];
}


/*
 * Enable/disable certain menu items, as necessary
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
   SEL menuItemAction;
   BOOL retval;

   menuItemAction = [ menuItem action ];
   if( menuItemAction == @selector( copy: ) ||
       menuItemAction == @selector( cut: ) )
      retval = ( [ documentView numberOfSelectedRows ] > 0 );
   else if( menuItemAction == @selector( paste: ) )
      retval = ( [ [ NSPasteboard generalPasteboard ]
                   availableTypeFromArray:
                      [ NSArray arrayWithObject:CSDocumentPboardType ] ] != nil );
   else
      retval = YES;

   return retval;
}


/*
 * Table view methods
 */

/*
 * Handle the table view
 */
- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
   return [ [ self document ] entryCount ];
}


/*
 * Return the proper value
 */
- (id) tableView:(NSTableView *)aTableView
       objectValueForTableColumn:(NSTableColumn *)aTableColumn
       row:(int)rowIndex
{
   NSString *colID;

   colID = [ aTableColumn identifier ];
   if( [ colID isEqualToString:CSDocModelKey_Notes ] )
      return [ [ self document ] RTFDStringNotesAtRow:rowIndex ];
   else
      return [ [ self document ] stringForKey:colID atRow:rowIndex ];
}


/*
 * Change the sorting
 */
- (void) tableView:(NSTableView*)tableView
         didClickTableColumn:(NSTableColumn *)tableColumn;
{
   NSString *tableID;

   tableID = [ tableColumn identifier ];
   if( [ tableID isEqualToString:CSDocModelKey_Notes ] )
      return;   // Don't sort on notes

   // If the current sorting column is clicked, we reverse the order
   if( [ [ [ self document ] sortKey ] isEqualToString:tableID ] )
      [ [ self document ] setSortAscending:![ [ self document ]
                                              isSortAscending ] ];
   else   // Otherwise, set new sort key
      [ [ self document ] setSortKey:tableID ascending:YES ];

   [ documentView setHighlightedTableColumn:tableColumn ];
   [ self _setSortingImageForColumn:tableColumn ];
}


/*
 * Enable/disable delete and view buttons depending on whether something
 * is selected
 */
- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
   BOOL enableState;

   if( [ documentView numberOfSelectedRows ] == 0 )
      enableState = NO;
   else
      enableState = YES;

   [ documentDeleteButton setEnabled:enableState ];
   [ documentViewButton setEnabled:enableState ];
}


/*
 * Support dragging of tableview rows
 */
- (BOOL) tableView:(NSTableView *)tv
         writeRows:(NSArray *)rows
         toPasteboard:(NSPasteboard *)pboard
{
   return [ [ self document ] copyNames:[ self _namesFromRows:rows ]
                              toPasteboard:pboard ];
}


/*
 * We copy on drops (the registerForDraggedTypes sets up for only
 * CSDocumentPboardType)
 */
- (NSDragOperation) tableView:(NSTableView*)tv
                    validateDrop:(id <NSDraggingInfo>)info
                    proposedRow:(int)row
                    proposedDropOperation:(NSTableViewDropOperation)op
{
   return NSDragOperationCopy;
}


/*
 * Accept a drop
 */
- (BOOL) tableView:(NSTableView*)tv
         acceptDrop:(id <NSDraggingInfo>)info
         row:(int)row
         dropOperation:(NSTableViewDropOperation)op
{
   return [ [ self document ] retrieveEntriesFromPasteboard:
                                 [ info draggingPasteboard ]
                              undoName:CSWINCTRLMAIN_LOC_DROP ];
}


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

   [ generalPasteboard setData:[ [ self document ]
                                 RTFDNotesAtRow:[ documentView selectedRow ] ]
                       forType:NSRTFDPboardType ];
   [ generalPasteboard setData:[ [ self document ]
                                 RTFNotesAtRow:[ documentView selectedRow ] ]
                       forType:NSRTFPboardType ];
   [ [ NSApp delegate ] notePBChangeCount ];
}


/*
 * Open the URL from the selected row
 */
- (IBAction) cmmOpenURL:(id)sender
{
   BOOL urlIsInvalid;
   NSURL *theURL;

   urlIsInvalid = YES;
   theURL = [ NSURL URLWithString:[ [ self document ]
                                    stringForKey:CSDocModelKey_URL
                                    atRow:[ documentView selectedRow ] ] ];
   if( theURL != nil && [ [ NSWorkspace sharedWorkspace ] openURL:theURL ] )
      urlIsInvalid = NO;

   if( urlIsInvalid )
      NSBeginInformationalAlertSheet( CSWINCTRLMAIN_LOC_INVALIDURL,
                                      nil, nil, nil, [ self window ], nil, nil,
                                      nil, nil, CSWINCTRLMAIN_LOC_URLNOTVALID );
}


/*
 * Called when the "really delete" sheet is done
 */
- (void) _deleteSheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
         contextInfo:(void *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // They said delete...
      [ [ self document ]
        deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
}


/*
 * Setup the given column to have the correct indicator image, and remove the
 * one from the previous column
 */
- (void) _setSortingImageForColumn:(NSTableColumn *)tableColumn
{
   if( [ [ self document ] isSortAscending ] )
      [ documentView setIndicatorImage:[ NSImage imageNamed:@"sortArrowUp" ]
                     inTableColumn:tableColumn ];
   else
      [ documentView setIndicatorImage:[ NSImage imageNamed:@"sortArrowDown" ]
                     inTableColumn:tableColumn ];
   if( ![ previouslySelectedColumn isEqual:tableColumn ] )
      [ documentView setIndicatorImage:nil
                     inTableColumn:previouslySelectedColumn ];
   previouslySelectedColumn = tableColumn;
}


/*
 * Return an array of the names for selected rows in the table view
 */
- (NSArray *) _getSelectedNames
{
   return [ self _namesFromRows:[ [ documentView selectedRowEnumerator ]
                                  allObjects ] ];
}


/*
 * Convert an array of row numbers to an array of names
 */
- (NSArray *) _namesFromRows:(NSArray *)rows
{
   NSMutableArray *nameArray;
   NSEnumerator *rowEnumerator;
   id nextRow;

   nameArray = [ NSMutableArray arrayWithCapacity:[ rows count ] ];
   rowEnumerator = [ rows objectEnumerator ];
   while( ( nextRow = [ rowEnumerator nextObject ] ) != nil )
      [ nameArray addObject:[ [ self document ]
                              stringForKey:CSDocModelKey_Name
                              atRow:[ nextRow unsignedIntValue ] ] ];

   return nameArray;
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
   [ generalPB setString:[ [ self document ] stringForKey:columnName
                                             atRow:[ documentView selectedRow ] ]
               forType:NSStringPboardType ];
   [ [ NSApp delegate ] notePBChangeCount ];
}

@end
