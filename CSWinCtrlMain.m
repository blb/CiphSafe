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
#import "BLBTextField.h"

// Format strings for window and table view information saved in user defaults
#define CSWINCTRLMAIN_PREF_WINDOW @"CSWinCtrlMain Window %@"
#define CSWINCTRLMAIN_PREF_TABLE @"CSWinCtrlMain Table %@"
// Dictionary keys in saved table view information
#define CSWINCTRLMAIN_PREF_TABLE_NAME @"name"
#define CSWINCTRLMAIN_PREF_TABLE_WIDTH @"width"

// Localized strings
#define CSWINCTRLMAIN_LOC_SUREDELROWS \
           NSLocalizedString( @"Are you sure you want to delete the selected " \
                              @"rows?", @"" )
#define CSWINCTRLMAIN_LOC_SUREDELONEROW \
           NSLocalizedString( @"Are you sure you want to delete the selected " \
                              @"row?", @"" )
#define CSWINCTRLMAIN_LOC_SURE NSLocalizedString( @"Are You Sure?", @"" )
#define CSWINCTRLMAIN_LOC_DELETE NSLocalizedString( @"Delete", @"" )
#define CSWINCTRLMAIN_LOC_CANCEL NSLocalizedString( @"Cancel", @"" )
#define CSWINCTRLMAIN_LOC_DROP NSLocalizedString( @"Drop", @"" )
#define CSWINCTRLMAIN_LOC_PASTE NSLocalizedString( @"Paste", @"" )
#define CSWINCTRLMAIN_LOC_CUT NSLocalizedString( @"Cut", @"" )
#define CSWINCTRLMAIN_LOC_ONEENTRY \
           NSLocalizedString( @"1 entry, %d selected", @"" )
#define CSWINCTRLMAIN_LOC_NUMENTRIES \
           NSLocalizedString( @"%d entries, %d selected", @"" )
#define CSWINCTRLMAIN_LOC_INVALIDURL NSLocalizedString( @"Invalid URL", @"" )
#define CSWINCTRLMAIN_LOC_URLNOTVALID \
           NSLocalizedString( @"The URL entered is not a valid URL", @"" )
#define CSWINCTRLMAIN_LOC_SEARCH NSLocalizedString( @"search", @"" )
#define CSWINCTRLMAIN_LOC_FILTERED NSLocalizedString( @"filtered", @"" )
#define CSWINCTRLMAIN_LOC_NEEDCOL \
           NSLocalizedString( @"Need at least one column", @"" )
#define CSWINCTRLMAIN_LOC_NEEDCOLTEXT \
           NSLocalizedString( @"At least one column is needed in order to " \
           @"be useful", @"" )
#define CSWINCTRLMAIN_LOC_NEWCATEGORY NSLocalizedString( @"New Category…", @"" )

@interface CSWinCtrlMain (InternalMethods)
- (void) _setTableViewSpacing;
- (void) _loadSavedWindowState;
- (void) _saveWindowState;
- (BOOL) _loadSavedTableState;
- (void) _saveTableState;
- (void) _setupDefaultTableViewColumns;
- (void) _setDisplayOfColumnID:(NSString *)colID enabled:(BOOL)enabled;
- (void) _addTableColumnWithID:(NSString *)colID;
- (void) _updateCornerMenu;
- (void) _updateSetCategoryMenu;
- (void) _filterView;
- (void) _setSearchResultList:(NSArray *)newList;
- (void) _updateStatusField;
- (void) _deleteSheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
         contextInfo:(void *)contextInfo;
- (void) _setSortingImageForColumn:(NSTableColumn *)tableColumn;
- (NSArray *) _getSelectedNames;
- (NSArray *) _namesFromRows:(NSArray *)rows;
- (int) _rowForFilteredRow:(int)row;
- (int) _filteredRowForRow:(int)row;
@end

@implementation CSWinCtrlMain

static NSArray *cmmCopyFields;
static NSAttributedString *defaultSearchString;
static NSArray *columnSelectionArray;
static NSArray *searchWhatArray;

+ (void) initialize
{
   // Mapping from CMM tags for copy to field names
   cmmCopyFields = [ [ NSArray alloc ] initWithObjects:CSDocModelKey_Acct,
                                                       CSDocModelKey_Passwd,
                                                       CSDocModelKey_URL,
                                                       CSDocModelKey_Name,
                                                       CSDocModelKey_Notes,
                                                       nil ];
   defaultSearchString = [ [ NSAttributedString alloc ]
                           initWithString:CSWINCTRLMAIN_LOC_SEARCH
                           attributes:
                              [ NSDictionary dictionaryWithObjectsAndKeys:
                                                [ NSColor grayColor ],
                                                   NSForegroundColorAttributeName,
                                                nil ] ];
   // Mapping from corner menu tags to field names
   columnSelectionArray = [ [ NSArray alloc ] initWithObjects:
                                                 @"allColumns",
                                                 CSDocModelKey_Name,
                                                 CSDocModelKey_Acct,
                                                 CSDocModelKey_Passwd,
                                                 CSDocModelKey_URL,
                                                 CSDocModelKey_Category,
                                                 CSDocModelKey_Notes,
                                                 nil ];
   searchWhatArray = [ [ NSArray alloc ] initWithObjects:@"Search in:",
                                                         CSDocModelKey_Name,
                                                         CSDocModelKey_Acct,
                                                         CSDocModelKey_Passwd,
                                                         CSDocModelKey_URL,
                                                         CSDocModelKey_Category,
                                                         CSDocModelKey_Notes,
                                                         nil ];

}


/*
 * Simple setup, load the NIB, make our controller the bigboy
 */
- (id) init
{
   self = [ super initWithWindowNibName:@"CSDocument" ];
   if( self != nil )
      [ self setShouldCloseDocument:YES ];

   return self;
}


/*
 * Initial setup of the window
 */
- (void) awakeFromNib
{
   int index;

   if( [ [ self document ] fileName ] != nil )
   {
      [ self _loadSavedWindowState ];
      if( ![ self _loadSavedTableState ] )
         [ self _setupDefaultTableViewColumns ];
      [ self setShouldCascadeWindows:NO ];
   }
   else
      [ self _setupDefaultTableViewColumns ];

   [ self _updateCornerMenu ];
   [ _documentView setDrawsGrid:NO ];
   [ _documentView setDrawsGrid:YES ];
   [ _documentView setStripeColor:[ NSColor colorWithCalibratedRed:0.93
                                            green:0.95
                                            blue:1.0
                                            alpha:1.0 ] ];
   [ _documentView setDoubleAction:@selector( doViewEntry: ) ];
   _previouslySelectedColumn = [ _documentView tableColumnWithIdentifier:
                                                  [ [ self document ] sortKey ] ];
   [ _documentView setHighlightedTableColumn:_previouslySelectedColumn ];
   [ self _setSortingImageForColumn:_previouslySelectedColumn ];
   /*
    * The table view is set as the initialFirstResponder, but we have to do
    * this as well
    */
   [ [ self window ] makeFirstResponder:_documentView ];
   [ _documentView registerForDraggedTypes:
                      [ NSArray arrayWithObject:CSDocumentPboardType ] ];
   [ [ _documentView cornerView ] setMenu:_cmmTableHeader ];
   [ [ _documentView headerView ] setMenu:_cmmTableHeader ];
   [ self _setTableViewSpacing ];
   [ _documentSearch setObjectValue:defaultSearchString ];
   [ self refreshWindow ];
   [ _searchWhat setAutoenablesItems:NO ];
   [ [ _searchWhat itemAtIndex:0 ] setEnabled:NO ];
   for( index = 1; index < [ _searchWhat numberOfItems ]; index++ )
      [ [ _searchWhat itemAtIndex:index ] setEnabled:YES ];
   [ [ NSNotificationCenter defaultCenter ]
     addObserver:self
     selector:@selector( _prefsDidChange: )
     name:CSApplicationDidChangePrefs
     object:nil ];
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
      if( [ _documentView numberOfSelectedRows ] > 1 )
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
 * Reset the search field
 */
- (IBAction) doResetSearch:(id)sender
{
   _searchFieldModified = NO;
   [ _documentSearch setStringValue:@"" ];
   [ self refreshWindow ];
}


/*
 * Simple end modals
 */
- (IBAction) newCategoryOK:(id)sender
{
   [ NSApp stopModal ];
   [ _newCategoryWindow orderOut:self ];
}

- (IBAction) newCategoryCancel:(id)sender
{
   [ NSApp abortModal ];
   [ _newCategoryWindow orderOut:self ];
}


/*
 * Refresh all the views in the window
 */
- (void) refreshWindow
{
   [ self _updateSetCategoryMenu ];
   [ self _filterView ];
   [ _documentView reloadData ];
   [ _documentView deselectAll:self ];
   [ self _updateStatusField ];
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
       menuItemAction == @selector( cut: ) ||
       menuItemAction == @selector( doSetCategory: ) )
      retval = ( [ _documentView numberOfSelectedRows ] > 0 );
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
   if( _searchResultList != nil )
      return [ _searchResultList count ];
   else
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
      return [ [ self document ]
               RTFDStringNotesAtRow:[ self _rowForFilteredRow:rowIndex ] ];
   else
      return [ [ self document ]
               stringForKey:colID atRow:[ self _rowForFilteredRow:rowIndex ] ];
}


/*
 * Change the sorting
 */
- (void) tableView:(NSTableView*)tableView
         didClickTableColumn:(NSTableColumn *)tableColumn;
{
   NSString *colID;

   colID = [ tableColumn identifier ];
   // If the current sorting column is clicked, we reverse the order
   if( [ [ [ self document ] sortKey ] isEqualToString:colID ] )
      [ [ self document ] setSortAscending:![ [ self document ]
                                              isSortAscending ] ];
   else   // Otherwise, set new sort key
      [ [ self document ] setSortKey:colID ascending:YES ];

   [ _documentView setHighlightedTableColumn:tableColumn ];
   [ self _setSortingImageForColumn:tableColumn ];
}


/*
 * Enable/disable delete and view buttons depending on whether something
 * is selected
 */
- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
   BOOL enableState;

   if( [ _documentView numberOfSelectedRows ] == 0 )
      enableState = NO;
   else
      enableState = YES;

   [ _documentDeleteButton setEnabled:enableState ];
   [ _documentViewButton setEnabled:enableState ];
   [ self _updateStatusField ];
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
 * Handle keypresses in the table view by scrolling to the first entry whose
 * name begins with the key pressed
 */
- (BOOL) tableView:(BLBTableView *)tableView
         didReceiveKeyDownEvent:(NSEvent *)theEvent
{
   BOOL retval;
   NSNumber *rowForKey;
   int filteredRow;

   retval = NO;
   rowForKey = [ [ self document ]
                 firstRowBeginningWithString:[ theEvent characters ]
                 ignoreCase:YES
                 forKey:CSDocModelKey_Name ];
   if( rowForKey != nil )
   {
      filteredRow = [ self _filteredRowForRow:[ rowForKey intValue ] ];
      if( filteredRow >= 0 )
      {
         [ tableView selectRow:filteredRow byExtendingSelection:NO ];
         [ tableView scrollRowToVisible:filteredRow ];
         retval = YES;
      }
   }

   return retval;
}


/*
 * Set the category on a bunch of entries
 */
- (IBAction) doSetCategory:(id)sender
{
   NSMenu *categoriesMenu;
   NSString *category;
   NSArray *selectedNamesArray;
   CSDocument *document;
   unsigned index;

   categoriesMenu = [ [ [ NSApp delegate ] editMenuSetCategoryMenuItem ]
                      submenu ];
   // Last item is new category
   if( [ categoriesMenu indexOfItem:sender ] ==
       ( [ categoriesMenu numberOfItems ] - 1 ) )
   {
      if( [ NSApp runModalForWindow:_newCategoryWindow ] == NSRunStoppedResponse )
         category = [ _newCategory stringValue ];
      else
         category = nil;
   }
   else
      category = [ sender title ];
   selectedNamesArray = [ self _getSelectedNames ];
   document = [ self document ];
   if( category != nil )
   {
      for( index = 0; index < [ selectedNamesArray count ]; index++ )
      {
         [ document changeEntryWithName:[ selectedNamesArray objectAtIndex:index ]
                    newName:nil
                    account:nil
                    password:nil
                    URL:nil
                    category:category
                    notesRTFD:nil ];
      }
   }
}


/*
 * Contextual menu methods
 */
/*
 * Provide the contextual menu for the table view; select the view for good
 * visual feedback
 */
- (NSMenu *) contextualMenuForTableView:(BLBTableView *)tableView
             row:(int)row
             column:(int)column
{
   [ tableView selectRow:row byExtendingSelection:NO ];

   return _contextualMenu;
}


/*
 * Copy the entry's field according to which menu was used to get here (ie
 * through the cmmCopyField mapping and the menu tags)
 */
- (IBAction) cmmCopyField:(id)sender
{
   NSString *fieldName;
   NSPasteboard *generalPB;
   int selectedRow;

   fieldName = [ cmmCopyFields objectAtIndex:[ sender tag ] ];
   generalPB = [ NSPasteboard generalPasteboard ];
   selectedRow = [ self _rowForFilteredRow:[ _documentView selectedRow ] ];
   if( [ fieldName isEqual:CSDocModelKey_Notes ] )
   {
      [ generalPB declareTypes:[ NSArray arrayWithObjects:NSRTFDPboardType,
                                                          NSRTFPboardType,
                                                          nil ]
                  owner:nil ];

      [ generalPB setData:[ [ self document ] RTFDNotesAtRow:selectedRow ]
                          forType:NSRTFDPboardType ];
      [ generalPB setData:[ [ self document ] RTFNotesAtRow:selectedRow ]
                          forType:NSRTFPboardType ];
   }
   else
   {
      [ generalPB declareTypes:[ NSArray arrayWithObject:NSStringPboardType ]
                  owner:nil ];
      [ generalPB setString:[ [ self document ] stringForKey:fieldName
                                                atRow:selectedRow ]
                  forType:NSStringPboardType ];
   }
   [ [ NSApp delegate ] notePBChangeCount ];
}


/*
 * Open the URL from the selected row
 */
- (IBAction) cmmOpenURL:(id)sender
{
   BOOL urlIsInvalid;
   int selectedRow;
   NSURL *theURL;

   urlIsInvalid = YES;
   selectedRow = [ self _rowForFilteredRow:[ _documentView selectedRow ] ];
   theURL = [ NSURL URLWithString:[ [ self document ]
                                    stringForKey:CSDocModelKey_URL
                                    atRow:selectedRow ] ];
   if( theURL != nil && [ [ NSWorkspace sharedWorkspace ] openURL:theURL ] )
      urlIsInvalid = NO;

   if( urlIsInvalid )
      NSBeginInformationalAlertSheet( CSWINCTRLMAIN_LOC_INVALIDURL,
                                      nil, nil, nil, [ self window ], nil, nil,
                                      nil, nil, CSWINCTRLMAIN_LOC_URLNOTVALID );
}


/*
 * Select/unselect a column for display (we determine which from the sender)
 */
- (IBAction) cornerSelectField:(id)sender
{
   unsigned index;
   BOOL enabled;

   if( [ sender tag ] == 0 )   // Show all columns
   {
      for( index = 1; index < [ columnSelectionArray count ]; index++ )
         [ self _setDisplayOfColumnID:[ columnSelectionArray objectAtIndex:index ]
                enabled:YES ];
   }
   else
   {
      enabled = !( [ sender state ] == NSOnState );
      if( [ [ _documentView tableColumns ] count ] > 1 || enabled )
         [ self _setDisplayOfColumnID:
                   [ columnSelectionArray objectAtIndex:[ sender tag ] ]
                enabled:enabled ];
      else
         NSBeginCriticalAlertSheet( CSWINCTRLMAIN_LOC_NEEDCOL, nil, nil, nil,
                                    [ self window ], nil, nil, nil, NULL,
                                    CSWINCTRLMAIN_LOC_NEEDCOLTEXT );
   }
   [ self _updateCornerMenu ];
}


/*
 * This happens when the search text field is focused; we simply clear the
 * search field if it hasn't been modified yet (clearing the gray "search")
 */
- (void) textFieldDidBecomeFirstResponder:(BLBTextField *)textField
{
   if( [ textField isEqual:_documentSearch ] && !_searchFieldModified )
      [ _documentSearch setStringValue:@"" ];
}


/*
 * When the search field value is changed; set that the field is modified if
 * it has, setup filtering, and refresh the view
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
   NSString *searchString;

   if( [ [ aNotification object ] isEqual:_documentSearch ] )
   {
      searchString = [ _documentSearch stringValue ];
      if( searchString != nil && [ searchString length ] > 0 )
         _searchFieldModified = YES;
      else
         _searchFieldModified = NO;
      [ self _filterView ];
      [ self refreshWindow ];
   }
}


/*
 * Only reliable way to know when we're going away and we still have a
 * reference to the document (sometimes [ self document ] works in
 * windowWillClose:, sometimes it doesn't)
 */
- (void) setDocument:(NSDocument *)document
{
   if( [ self document ] != nil && document == nil &&
       [ [ self document ] fileName ] != nil )
   {
      [ self _saveWindowState ];
      [ self _saveTableState ];
      [ [ NSUserDefaults standardUserDefaults ] synchronize ];
   }
   [ super setDocument:document ];
}


/*
 * Update set category menu when we are key (since it now applies to us)
 */
- (void) windowDidBecomeKey:(NSNotification *)aNotification
{
   [ self _updateSetCategoryMenu ];
}


/*
 * Cleanup
 */
- (void) windowWillClose:(NSNotification *)notification
{
   [ self _setSearchResultList:nil ];
}


/*
 * When preferences change
 */
- (void) _prefsDidChange:(NSNotification *)aNotification
{
   [ self _updateSetCategoryMenu ];
   [ self _setTableViewSpacing ];
}


/*
 * Do like it says
 */
- (void) _setTableViewSpacing
{
   NSSize newSpacing;

   switch( [ [ NSUserDefaults standardUserDefaults ]
             integerForKey:CSPrefDictKey_CellSpacing ] )
   {
      case 0:   // Small
         newSpacing = NSMakeSize( 3, 2 );
         break;

      case 1:   // Medium
         newSpacing = NSMakeSize( 5, 2 );
         break;

      case 2:   // Large
         newSpacing = NSMakeSize( 7, 3 );
         break;
   }
   [ _documentView setIntercellSpacing:newSpacing ];
}


/*
 * Load previously-saved window layout information, if any
 */
- (void) _loadSavedWindowState
{
   NSString *windowFrameString;

   windowFrameString = [ [ NSUserDefaults standardUserDefaults ]
                         stringForKey:[ NSString stringWithFormat:
                                            CSWINCTRLMAIN_PREF_WINDOW,
                                            [ [ self document ] displayName ] ] ];
   if( windowFrameString != nil )
      [ [ self window ] setFrameFromString:windowFrameString ];
}


/*
 * Save window layout information
 */
- (void) _saveWindowState
{
   [ [ NSUserDefaults standardUserDefaults ]
     setObject:[ [ self window ] stringWithSavedFrame ]
     forKey:[ NSString stringWithFormat:CSWINCTRLMAIN_PREF_WINDOW,
                                           [ [ self document ] displayName ] ] ];
}


/*
 * Load previously-saved table layout information, if any
 */
- (BOOL) _loadSavedTableState
{
   BOOL retval;
   NSString *tableInfoString, *colName;
   NSArray *partsArray;
   unsigned index;
   int currentColIndex;
   NSTableColumn *tableColumn;

   retval = NO;
   tableInfoString = [ [ NSUserDefaults standardUserDefaults ]
                      stringForKey:[ NSString stringWithFormat:
                                            CSWINCTRLMAIN_PREF_TABLE,
                                            [ [ self document ] displayName ] ] ];
   // Loop through rearranging columns and setting each column's size
   if( tableInfoString != nil && [ tableInfoString length ] > 0 )
   {
      partsArray = [ tableInfoString componentsSeparatedByString:@" " ];
      for( index = 0; index < [ partsArray count ]; index += 2 )
      {
         colName = [ partsArray objectAtIndex:index ];
         [ self _addTableColumnWithID:colName ];
         currentColIndex = [ _documentView columnWithIdentifier:colName ];
         [ _documentView moveColumn:currentColIndex toColumn:( index / 2 ) ];
         tableColumn = [ _documentView tableColumnWithIdentifier:colName ];
         [ tableColumn setWidth:[ [ partsArray objectAtIndex:( index + 1 ) ]
                                  floatValue ] ];
      }
      retval = YES;
   }

   return retval;
}


/*
 * Save table layout information
 */
- (void) _saveTableState
{
   NSArray *tableColumns;
   NSMutableString *infoString;
   unsigned index;
   NSTableColumn *tableColumn;

   tableColumns = [ _documentView tableColumns ];
   infoString = [ NSMutableString stringWithCapacity:70 ];
   for( index = 0; index < [ tableColumns count ]; index++ )
   {
      tableColumn = [ tableColumns objectAtIndex:index ];
      if( index == 0 )
         [ infoString appendFormat:@"%@ %f", [ tableColumn identifier ],
                                             [ tableColumn width ] ];
      else
         [ infoString appendFormat:@" %@ %f", [ tableColumn identifier ],
                                              [ tableColumn width ] ];
   }
   [ [ NSUserDefaults standardUserDefaults ]
     setObject:infoString
     forKey:[ NSString stringWithFormat:CSWINCTRLMAIN_PREF_TABLE,
                                           [ [ self document ] displayName ] ] ];
}


/*
 * Default layout for new documents
 */
- (void) _setupDefaultTableViewColumns
{
   [ self _setDisplayOfColumnID:@"name" enabled:YES ];
   [ self _setDisplayOfColumnID:@"account" enabled:YES ];
   [ self _setDisplayOfColumnID:@"url" enabled:YES ];
   [ self _setDisplayOfColumnID:@"notes" enabled:YES ];
}


/*
 * Show or hide the given column
 */
- (void) _setDisplayOfColumnID:(NSString *)colID enabled:(BOOL)enabled
{
   NSTableColumn *colToRemove;

   if( enabled )
      [ self _addTableColumnWithID:colID ];
   else
   {
      colToRemove = [ [ _documentView tableColumnWithIdentifier:colID ] retain ];
      [ _documentView removeTableColumn:colToRemove ];
      if( [ _previouslySelectedColumn isEqual:colToRemove ] )
         [ self tableView:_documentView
                didClickTableColumn:[ [ _documentView tableColumns ]
                                      objectAtIndex:0 ] ];
      [ colToRemove release ];
   }
   [ _documentView sizeToFit ];
}


/*
 * Add a table column for the given column, if it isn't already there
 */
- (void) _addTableColumnWithID:(NSString *)colID
{
   NSTableColumn *newColumn;

   if( [ _documentView columnWithIdentifier:colID ] == -1 )
   {
      newColumn = [ [ NSTableColumn alloc ] initWithIdentifier:colID ];
      [ newColumn setEditable:NO ];
      [ newColumn setResizable:YES ];
      [ [ newColumn headerCell ] setStringValue:NSLocalizedString( colID, @"" ) ];
      [ _documentView addTableColumn:[ newColumn autorelease ] ];
   }
}


/*
 * Set menu state for the column selections
 */
- (void) _updateCornerMenu
{
   unsigned index;

   for( index = 1; index < [ columnSelectionArray count ]; index++ )
   {
      if( [ _documentView columnWithIdentifier:
                             [ columnSelectionArray objectAtIndex:index ] ]
          >= 0 )
         [ [ _cmmTableHeader itemWithTag:index ] setState:NSOnState ];
      else
         [ [ _cmmTableHeader itemWithTag:index ] setState:NSOffState ];
   }
}


/*
 * Update list of possible categories for the menu
 */
- (void) _updateSetCategoryMenu
{
   NSMenu *categoriesMenu;
   NSEnumerator *oldItemsEnum, *currentCategoriesEnum;
   id oldItem;
   NSString *newItem;

   if( [ [ self window ] isKeyWindow ] )
   {
      categoriesMenu = [ [ [ NSApp delegate ] editMenuSetCategoryMenuItem ]
                         submenu ];
      oldItemsEnum = [ [ categoriesMenu itemArray ] objectEnumerator ];
      while( ( oldItem = [ oldItemsEnum nextObject ] ) != nil )
         [ categoriesMenu removeItem:oldItem ];
      currentCategoriesEnum = [ [ [ self document ] categories ]
                                objectEnumerator ];
      while( ( newItem = [ currentCategoriesEnum nextObject ] ) != nil )
         [ categoriesMenu addItemWithTitle:newItem
                          action:@selector( doSetCategory: )
                          keyEquivalent:@"" ];
      [ categoriesMenu addItem:[ NSMenuItem separatorItem ] ];
      [ categoriesMenu addItemWithTitle:CSWINCTRLMAIN_LOC_NEWCATEGORY
                       action:@selector( doSetCategory: )
                       keyEquivalent:@"" ];
   }
}


/*
 * Filter the view of the document based on the search string
 */
- (void) _filterView
{
   NSString *searchString;

   searchString = [ _documentSearch stringValue ];
   if( _searchFieldModified )
      [ self _setSearchResultList:[ [ self document ]
                                    rowsMatchingString:searchString
                                    ignoreCase:YES
                                    forKey:[ searchWhatArray objectAtIndex:
                                        [ _searchWhat indexOfSelectedItem ] ] ] ];
   else
      [ self _setSearchResultList:nil ];
}


/*
 * Update the matching list for the search, and tell the table view to update
 */
- (void) _setSearchResultList:(NSArray *)newList
{
   [ newList retain ];
   [ _searchResultList release ];
   _searchResultList = newList;
}


/*
 * Update the status field with current information
 */
- (void) _updateStatusField
{
   int entryCount, selectedCount;
   NSString *statusString;

   entryCount = [ self numberOfRowsInTableView:_documentView ];
   selectedCount = [ _documentView numberOfSelectedRows ];
   if( entryCount == 1 )
      statusString = [ NSString stringWithFormat:CSWINCTRLMAIN_LOC_ONEENTRY,
                                                 selectedCount ];
   else
      statusString = [ NSString stringWithFormat:CSWINCTRLMAIN_LOC_NUMENTRIES,
                                                 entryCount, selectedCount ];
   if( _searchFieldModified )
      statusString = [ NSString stringWithFormat:@"%@ (%@)",
                                   statusString, CSWINCTRLMAIN_LOC_FILTERED ];
   [ _documentStatus setStringValue:statusString ];
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
      [ _documentView setIndicatorImage:[ NSImage imageNamed:@"sortArrowUp" ]
                      inTableColumn:tableColumn ];
   else
      [ _documentView setIndicatorImage:[ NSImage imageNamed:@"sortArrowDown" ]
                      inTableColumn:tableColumn ];
   if( ![ _previouslySelectedColumn isEqual:tableColumn ] )
      [ _documentView setIndicatorImage:nil
                      inTableColumn:_previouslySelectedColumn ];
   _previouslySelectedColumn = tableColumn;
}


/*
 * Return an array of the names for selected rows in the table view
 */
- (NSArray *) _getSelectedNames
{
   return [ self _namesFromRows:[ [ _documentView selectedRowEnumerator ]
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
                              atRow:[ self _rowForFilteredRow:
                                              [ nextRow intValue ] ] ] ];

   return nameArray;
}


/*
 * Return the search-list row number for a given basic row number
 */
- (int) _rowForFilteredRow:(int)row
{
   if( _searchResultList != nil )
      return [ [ _searchResultList objectAtIndex:row ] intValue ];
   else
      return row;
}


/*
 * Return the original row number for a filtered row number
 */
- (int) _filteredRowForRow:(int)row
{
   unsigned index;

   if( _searchResultList != nil )
   {
      for( index = 0; index < [ _searchResultList count ]; index++ )
      {
         if( [ [ _searchResultList objectAtIndex:index ] intValue ] == row )
            return index;
      }
      return -1;
   }
   else
      return row;
}

@end
