/* CSWinCtrlMain.m */

#import "CSWinCtrlMain.h"
#import "CSAppController.h"
#import "CSDocument.h"
#import "CSDocModel.h"

// Localized strings
#define CSWINCTRLMAIN_LOC_SUREDELROWS \
        NSLocalizedString( @"Are you sure you want to delete the selected rows?", \
                           @"" )
#define CSWINCTRLMAIN_LOC_SUREDELONEROW \
        NSLocalizedString( @"Are you sure you want to delete the selected row?", \
                           @"" )
#define CSWINCTRLMAIN_LOC_SURE NSLocalizedString( @"Are You Sure?", @"" )
#define CSWINCTRLMAIN_LOC_DELETE NSLocalizedString( @"Delete", @"" )
#define CSWINCTRLMAIN_LOC_CANCEL NSLocalizedString( @"Cancel", @"" )
#define CSWINCTRLMAIN_LOC_DROP NSLocalizedString( @"Drop", @"" )
#define CSWINCTRLMAIN_LOC_PASTE NSLocalizedString( @"Paste", @"" )
#define CSWINCTRLMAIN_LOC_CUT NSLocalizedString( @"Cut", @"" )

@interface CSWinCtrlMain (InternalMethods)
- (void) _setSortingImageForColumn:(NSTableColumn *)tableColumn;
- (NSArray *) _getSelectedNames;
- (void) _copyEntryString:(NSString *)columnName;
@end

@implementation CSWinCtrlMain

- (id) init
{
   self = [ super initWithWindowNibName:@"CSDocument" ];
   if( self != nil )
   {
      [ self setShouldCloseDocument:YES ];
      // These are used to add É in any cell too small to display its data
      textStorage = [ [ NSTextStorage alloc ] init ];
      layoutManager = [ [ NSLayoutManager alloc ] init ];
      textContainer = [ [ NSTextContainer alloc ] init ];
      [ layoutManager addTextContainer:textContainer ];
      [ textContainer release ];
      [ textStorage addLayoutManager:layoutManager ];
      [ layoutManager release ];
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
   [ documentView setDoubleAction:@selector( docViewEntry: ) ];
   previouslySelectedColumn = [ documentView tableColumnWithIdentifier:
                                                [ [ self document ] sortKey ] ];
   [ documentView setHighlightedTableColumn:previouslySelectedColumn ];
   [ self _setSortingImageForColumn:previouslySelectedColumn ];
   /*
    * The table view is set as the initialFirstResponder, but we have to do
    * this anyway
    */
   [ [ self window ] makeFirstResponder:documentView ];
   [ documentView reloadData ];
   [ documentView registerForDraggedTypes:
                     [ NSArray arrayWithObject:CSDocumentPboardType ] ];
}


/*
 * Tell the document to do whatever to allow for a new entry
 */
- (IBAction) docAddEntry:(id)sender
{
   [ [ self document ] openAddEntryWindow ];
}


/*
 * Tell the document to view the certain entries
 */
- (IBAction) docViewEntry:(id)sender
{
   [ [ self document ] viewEntries:[ self _getSelectedNames ] ];
}


/*
 * Tell the document to delete certain entries
 */
- (IBAction) docDeleteEntry:(id)sender
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
      delSelector = @selector( deleteSheetDidEnd:returnCode:contextInfo: );
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
 * Called when the "really delete" sheet is done
 */
- (void) deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // They said delete...
      [ [ self document ]
        deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
}


/*
 * Refresh all the views in the window
 */
- (void) refreshWindow
{
   [ documentView reloadData ];
   [ documentView deselectAll:self ];
}


/*
 * Cut selected rows
 */
- (IBAction) cut:(id)sender
{
   [ [ self document ]
     copyRows:[ [ documentView selectedRowEnumerator ] allObjects ]
     toPasteboard:[ NSPasteboard generalPasteboard ] ];
   [ [ self document ] deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
   [ [ [ self document ] undoManager ] setActionName:CSWINCTRLMAIN_LOC_CUT ];
}


/*
 * Copy selected rows to the general pasteboard
 */
- (IBAction) copy:(id)sender
{
   [ [ self document ]
     copyRows:[ [ documentView selectedRowEnumerator ] allObjects ]
     toPasteboard:[ NSPasteboard generalPasteboard ] ];
}


/*
 * Paste rows from the general pasteboard
 */
- (IBAction) paste:(id)sender
{
   [ [ self document ] retrieveRowsFromPasteboard:[ NSPasteboard generalPasteboard ]
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
      [ [ self document ] setSortAscending:![ [ self document ] isSortAscending ] ];
   else   // Otherwise, set new sort key
      [ [ self document ] setSortKey:tableID ascending:YES ];

   [ documentView setHighlightedTableColumn:tableColumn ];
   [ self _setSortingImageForColumn:tableColumn ];
}


/*
 * Make sure cells don't draw the background, otherwise the striping will
 * look funny; also denote if a string is too long to be shown completely
 */
- (void) tableView:(NSTableView *)tableView willDisplayCell:(id)theCell
         forTableColumn:(NSTableColumn *)tableColumn row:(int)rowIndex
{
   NSAttributedString *cellAttrString;
   float cellWidth;
   int lastGlyph;
   NSRange glyphRange, characterRange;
   NSMutableAttributedString *newString;

   [ theCell setDrawsBackground:NO ];

   cellAttrString = [ theCell attributedStringValue ];
   cellWidth = [ tableColumn width ];
   // Use an ellipsis to denote strings longer than the cell can show when needed
   if( [ cellAttrString size ].width > cellWidth )
   {
      [ textStorage setAttributedString:cellAttrString ];
      lastGlyph = [ layoutManager glyphIndexForPoint:NSMakePoint( cellWidth, 0 )
                                  inTextContainer:textContainer ];
      glyphRange = NSMakeRange( 0, lastGlyph - 1 );
      characterRange = [ layoutManager characterRangeForGlyphRange:glyphRange
                                       actualGlyphRange:NULL ];
      newString = [ [ NSMutableAttributedString alloc ]
                    initWithAttributedString:
                       [ cellAttrString attributedSubstringFromRange:
                                           characterRange ] ];
      [ [ newString mutableString ] appendString:@"É" ];
      // Remove the foreground color, otherwise it seems to get out of sync
      [ newString removeAttribute:NSForegroundColorAttributeName
                  range:NSMakeRange( 0, [ [ newString string ] length ] ) ];
      [ theCell setAttributedStringValue:newString ];
      [ newString release ];
   }
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
- (BOOL) tableView:(NSTableView *)tv writeRows:(NSArray *)rows
         toPasteboard:(NSPasteboard *)pboard
{
   return [ [ self document ] copyRows:rows toPasteboard:pboard ];
}


/*
 * We copy on drops (the registerForDraggedTypes sets up for only
 * CSDocumentPboardType)
 */
- (NSDragOperation) tableView:(NSTableView*)tv
                    validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row
                    proposedDropOperation:(NSTableViewDropOperation)op
{
   return NSDragOperationCopy;
}


/*
 * Accept a drop
 */
- (BOOL) tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info
         row:(int)row dropOperation:(NSTableViewDropOperation)op
{
   return [ [ self document ] retrieveRowsFromPasteboard:[ info draggingPasteboard ]
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
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ textStorage release ];
   [ super dealloc ];
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
   if( previouslySelectedColumn != tableColumn )
      [ documentView setIndicatorImage:nil
                     inTableColumn:previouslySelectedColumn ];
   previouslySelectedColumn = tableColumn;
}


/*
 * Return an array of the names for selected rows in the table view
 */
- (NSArray *) _getSelectedNames
{
   NSMutableArray *selectedNames;
   NSEnumerator *rowEnumerator;
   NSNumber *rowNumber;

   selectedNames = [ NSMutableArray arrayWithCapacity:10 ];
   rowEnumerator = [ documentView selectedRowEnumerator ];
   while( ( rowNumber = [ rowEnumerator nextObject ] ) != nil )
   {
      [ selectedNames addObject:[ [ self document ]
                                  stringForKey:CSDocModelKey_Name
                                  atRow:[ rowNumber unsignedIntValue ] ] ];
   }

   return selectedNames;
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
}

@end
