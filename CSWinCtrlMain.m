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
#define CSWINCTRLMAIN_LOC_NEWCATEGORY NSLocalizedString( @"New Category", @"" )


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
 * Do like it says
 */
- (void) setTableViewSpacing
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
   [ documentView setIntercellSpacing:newSpacing ];
}


/*
 * Load previously-saved window layout information, if any
 */
- (void) loadSavedWindowState
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
- (void) saveWindowState
{
   [ [ NSUserDefaults standardUserDefaults ]
     setObject:[ [ self window ] stringWithSavedFrame ]
        forKey:[ NSString stringWithFormat:CSWINCTRLMAIN_PREF_WINDOW,
           [ [ self document ] displayName ] ] ];
}


/*
 * Add a table column for the given column, if it isn't already there
 */
- (void) addTableColumnWithID:(NSString *)colID
{
   NSTableColumn *newColumn;
   
   if( [ documentView columnWithIdentifier:colID ] == -1 )
   {
      newColumn = [ [ NSTableColumn alloc ] initWithIdentifier:colID ];
      [ newColumn setEditable:NO ];
      [ newColumn setResizingMask:( NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask ) ];
      [ [ newColumn headerCell ] setStringValue:NSLocalizedString( colID, @"" ) ];
      [ documentView addTableColumn:[ newColumn autorelease ] ];
   }
}


/*
 * Load previously-saved table layout information, if any
 */
- (BOOL) loadSavedTableState
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
         [ self addTableColumnWithID:colName ];
         currentColIndex = [ documentView columnWithIdentifier:colName ];
         [ documentView moveColumn:currentColIndex toColumn:( index / 2 ) ];
         tableColumn = [ documentView tableColumnWithIdentifier:colName ];
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
- (void) saveTableState
{
   NSArray *tableColumns;
   NSMutableString *infoString;
   unsigned index;
   NSTableColumn *tableColumn;
   
   tableColumns = [ documentView tableColumns ];
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
 * Show or hide the given column
 */
- (void) setDisplayOfColumnID:(NSString *)colID enabled:(BOOL)enabled
{
   NSTableColumn *colToRemove;
   
   if( enabled )
      [ self addTableColumnWithID:colID ];
   else
   {
      colToRemove = [ [ documentView tableColumnWithIdentifier:colID ] retain ];
      [ documentView removeTableColumn:colToRemove ];
      if( [ previouslySelectedColumn isEqual:colToRemove ] )
         [ self tableView:documentView
      didClickTableColumn:[ [ documentView tableColumns ]
                                      objectAtIndex:0 ] ];
      [ colToRemove release ];
   }
   [ documentView sizeToFit ];
}


/*
 * Default layout for new documents
 */
- (void) setupDefaultTableViewColumns
{
   [ self setDisplayOfColumnID:@"name" enabled:YES ];
   [ self setDisplayOfColumnID:@"account" enabled:YES ];
   [ self setDisplayOfColumnID:@"url" enabled:YES ];
   [ self setDisplayOfColumnID:@"notes" enabled:YES ];
}


/*
 * Set menu state for the column selections
 */
- (void) updateCornerMenu
{
   unsigned index;
   
   for( index = 1; index < [ columnSelectionArray count ]; index++ )
   {
      if( [ documentView columnWithIdentifier:
         [ columnSelectionArray objectAtIndex:index ] ]
          >= 0 )
         [ [ cmmTableHeader itemWithTag:index ] setState:NSOnState ];
      else
         [ [ cmmTableHeader itemWithTag:index ] setState:NSOffState ];
   }
}


/*
 * Update list of possible categories for the menu
 */
- (void) updateSetCategoryMenu
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
                                    action:@selector( setCategory: )
                             keyEquivalent:@"" ];
      [ categoriesMenu addItem:[ NSMenuItem separatorItem ] ];
      [ categoriesMenu addItemWithTitle:CSWINCTRLMAIN_LOC_NEWCATEGORY
                                 action:@selector( setCategory: )
                          keyEquivalent:@"" ];
   }
}


/*
 * Update the matching list for the search, and tell the table view to update
 */
- (void) setSearchResultList:(NSArray *)newList
{
   [ newList retain ];
   [ searchResultList release ];
   searchResultList = newList;
}


/*
 * Filter the view of the document based on the search string
 */
- (void) filterView
{
   NSString *searchString;
   
   searchString = [ documentSearch stringValue ];
   if( searchFieldModified )
      [ self setSearchResultList:[ [ self document ]
                                    rowsMatchingString:searchString
                                            ignoreCase:YES
                                                forKey:[ searchWhatArray objectAtIndex:
                                                   [ searchWhat indexOfSelectedItem ] ] ] ];
   else
      [ self setSearchResultList:nil ];
}


/*
 * Update the status field with current information
 */
- (void) updateStatusField
{
   int entryCount, selectedCount;
   NSString *statusString;
   
   entryCount = [ self numberOfRowsInTableView:documentView ];
   selectedCount = [ documentView numberOfSelectedRows ];
   if( entryCount == 1 )
      statusString = [ NSString stringWithFormat:CSWINCTRLMAIN_LOC_ONEENTRY,
         selectedCount ];
   else
      statusString = [ NSString stringWithFormat:CSWINCTRLMAIN_LOC_NUMENTRIES,
         entryCount, selectedCount ];
   if( searchFieldModified )
      statusString = [ NSString stringWithFormat:@"%@ (%@)",
         statusString, CSWINCTRLMAIN_LOC_FILTERED ];
   [ documentStatus setStringValue:statusString ];
}


/*
 * Return the search-list row number for a given basic row number
 */
- (int) rowForFilteredRow:(int)row
{
   if( searchResultList != nil )
      return [ [ searchResultList objectAtIndex:row ] intValue ];
   else
      return row;
}


/*
 * Convert an array of row numbers to an array of names
 */
- (NSArray *) namesFromRows:(NSArray *)rows
{
   NSMutableArray *nameArray;
   NSEnumerator *rowEnumerator;
   id nextRow;
   
   nameArray = [ NSMutableArray arrayWithCapacity:[ rows count ] ];
   rowEnumerator = [ rows objectEnumerator ];
   while( ( nextRow = [ rowEnumerator nextObject ] ) != nil )
      [ nameArray addObject:[ [ self document ]
                              stringForKey:CSDocModelKey_Name
                                     atRow:[ self rowForFilteredRow:
                                        [ nextRow intValue ] ] ] ];
   
   return nameArray;
}


/*
 * Return an array of the names for selected rows in the table view
 */
- (NSArray *) getSelectedNames
{
   return [ self namesFromRows:[ [ documentView selectedRowEnumerator ]
      allObjects ] ];
}


/*
 * Called when the "really delete" sheet is done
 */
- (void) deleteSheetDidEnd:(NSWindow *)sheet
                returnCode:(int)returnCode
               contextInfo:(void *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // They said delete...
      [ [ self document ]
        deleteEntriesWithNamesInArray:[ self getSelectedNames ] ];
}


/*
 * Setup the given column to have the correct indicator image, and remove the
 * one from the previous column
 */
- (void) setSortingImageForColumn:(NSTableColumn *)tableColumn
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
 * Return the original row number for a filtered row number
 */
- (int) filteredRowForRow:(int)row
{
   unsigned index;
   
   if( searchResultList != nil )
   {
      for( index = 0; index < [ searchResultList count ]; index++ )
      {
         if( [ [ searchResultList objectAtIndex:index ] intValue ] == row )
            return index;
      }
      return -1;
   }
   else
      return row;
}


/*
 * Initial setup of the window
 */
- (void) awakeFromNib
{
   int index;

   if( [ [ self document ] fileName ] != nil )
   {
      [ self loadSavedWindowState ];
      if( ![ self loadSavedTableState ] )
         [ self setupDefaultTableViewColumns ];
      [ self setShouldCascadeWindows:NO ];
   }
   else
      [ self setupDefaultTableViewColumns ];

   [ self updateCornerMenu ];
   [ documentView setDrawsGrid:NO ];
   [ documentView setDrawsGrid:YES ];
   [ documentView setStripeColor:[ NSColor colorWithCalibratedRed:0.93
                                            green:0.95
                                            blue:1.0
                                            alpha:1.0 ] ];
   [ documentView setDoubleAction:@selector( viewEntry: ) ];
   previouslySelectedColumn = [ documentView tableColumnWithIdentifier:
                                                  [ [ self document ] sortKey ] ];
   [ documentView setHighlightedTableColumn:previouslySelectedColumn ];
   [ self setSortingImageForColumn:previouslySelectedColumn ];
   /*
    * The table view is set as the initialFirstResponder, but we have to do
    * this as well
    */
   [ [ self window ] makeFirstResponder:documentView ];
   [ documentView registerForDraggedTypes:
                      [ NSArray arrayWithObject:CSDocumentPboardType ] ];
   [ [ documentView cornerView ] setMenu:cmmTableHeader ];
   [ [ documentView headerView ] setMenu:cmmTableHeader ];
   [ self setTableViewSpacing ];
   [ documentSearch setObjectValue:defaultSearchString ];
   [ self refreshWindow ];
   [ searchWhat setAutoenablesItems:NO ];
   [ [ searchWhat itemAtIndex:0 ] setEnabled:NO ];
   for( index = 1; index < [ searchWhat numberOfItems ]; index++ )
      [ [ searchWhat itemAtIndex:index ] setEnabled:YES ];
   [ [ NSNotificationCenter defaultCenter ]
     addObserver:self
     selector:@selector( prefsDidChange: )
     name:CSApplicationDidChangePrefs
     object:nil ];
}


/*
 * Tell the document to do whatever to allow for a new entry
 */
- (IBAction) addEntry:(id)sender
{
   [ [ self document ] openAddEntryWindow ];
}


/*
 * Tell the document to view the certain entries
 */
- (IBAction) viewEntry:(id)sender
{
   [ [ self document ] viewEntries:[ self getSelectedNames ] ];
}


/*
 * Tell the document to delete certain entries
 */
- (IBAction) deleteEntry:(id)sender
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
        deleteEntriesWithNamesInArray:[ self getSelectedNames ] ];
}


/*
 * Reset the search field
 */
- (IBAction) resetSearch:(id)sender
{
   searchFieldModified = NO;
   [ documentSearch setStringValue:@"" ];
   [ self refreshWindow ];
}


/*
 * Simple end modals
 */
- (IBAction) newCategoryOK:(id)sender
{
   [ NSApp stopModal ];
   [ newCategoryWindow orderOut:self ];
}

- (IBAction) newCategoryCancel:(id)sender
{
   [ NSApp abortModal ];
   [ newCategoryWindow orderOut:self ];
}


/*
 * Refresh all the views in the window
 */
- (void) refreshWindow
{
   [ self updateSetCategoryMenu ];
   [ self filterView ];
   [ documentView reloadData ];
   [ documentView deselectAll:self ];
   [ self updateStatusField ];
}


/*
 * Cut selected rows
 */
- (IBAction) cut:(id)sender
{
   [ [ self document ]
     copyNames:[ self getSelectedNames ]
     toPasteboard:[ NSPasteboard generalPasteboard ] ];
   [ [ self document ] deleteEntriesWithNamesInArray:[ self getSelectedNames ] ];
   [ [ [ self document ] undoManager ] setActionName:CSWINCTRLMAIN_LOC_CUT ];
   [ [ NSApp delegate ] notePBChangeCount ];
}


/*
 * Copy selected rows to the general pasteboard
 */
- (IBAction) copy:(id)sender
{
   [ [ self document ]
     copyNames:[ self getSelectedNames ]
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
       menuItemAction == @selector( setCategory: ) )
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
   if( searchResultList != nil )
      return [ searchResultList count ];
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
               RTFDStringNotesAtRow:[ self rowForFilteredRow:rowIndex ] ];
   else
      return [ [ self document ]
               stringForKey:colID atRow:[ self rowForFilteredRow:rowIndex ] ];
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

   [ documentView setHighlightedTableColumn:tableColumn ];
   [ self setSortingImageForColumn:tableColumn ];
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
   [ self updateStatusField ];
}


/*
 * Support dragging of tableview rows
 */
- (BOOL) tableView:(NSTableView *)tv
         writeRows:(NSArray *)rows
         toPasteboard:(NSPasteboard *)pboard
{
   return [ [ self document ] copyNames:[ self namesFromRows:rows ]
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
      filteredRow = [ self filteredRowForRow:[ rowForKey intValue ] ];
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
- (IBAction) setCategory:(id)sender
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
      if( [ NSApp runModalForWindow:newCategoryWindow ] == NSRunStoppedResponse )
         category = [ newCategory stringValue ];
      else
         category = nil;
   }
   else
      category = [ sender title ];
   selectedNamesArray = [ self getSelectedNames ];
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

   return contextualMenu;
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
   selectedRow = [ self rowForFilteredRow:[ documentView selectedRow ] ];
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
   selectedRow = [ self rowForFilteredRow:[ documentView selectedRow ] ];
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
         [ self setDisplayOfColumnID:[ columnSelectionArray objectAtIndex:index ]
                enabled:YES ];
   }
   else
   {
      enabled = !( [ sender state ] == NSOnState );
      if( [ [ documentView tableColumns ] count ] > 1 || enabled )
         [ self setDisplayOfColumnID:
                   [ columnSelectionArray objectAtIndex:[ sender tag ] ]
                enabled:enabled ];
      else
         NSBeginCriticalAlertSheet( CSWINCTRLMAIN_LOC_NEEDCOL, nil, nil, nil,
                                    [ self window ], nil, nil, nil, NULL,
                                    CSWINCTRLMAIN_LOC_NEEDCOLTEXT );
   }
   [ self updateCornerMenu ];
}


/*
 * This happens when the search text field is focused; we simply clear the
 * search field if it hasn't been modified yet (clearing the gray "search")
 */
- (void) textFieldDidBecomeFirstResponder:(BLBTextField *)textField
{
   if( [ textField isEqual:documentSearch ] && !searchFieldModified )
      [ documentSearch setStringValue:@"" ];
}


/*
 * When the search field value is changed; set that the field is modified if
 * it has, setup filtering, and refresh the view
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
   NSString *searchString;

   if( [ [ aNotification object ] isEqual:documentSearch ] )
   {
      searchString = [ documentSearch stringValue ];
      if( searchString != nil && [ searchString length ] > 0 )
         searchFieldModified = YES;
      else
         searchFieldModified = NO;
      [ self filterView ];
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
      [ self saveWindowState ];
      [ self saveTableState ];
      [ [ NSUserDefaults standardUserDefaults ] synchronize ];
   }
   [ super setDocument:document ];
}


/*
 * Update set category menu when we are key (since it now applies to us)
 */
- (void) windowDidBecomeKey:(NSNotification *)aNotification
{
   [ self updateSetCategoryMenu ];
}


/*
 * Cleanup
 */
- (void) windowWillClose:(NSNotification *)notification
{
   [ self setSearchResultList:nil ];
}


/*
 * When preferences change
 */
- (void) prefsDidChange:(NSNotification *)aNotification
{
   [ self updateSetCategoryMenu ];
   [ self setTableViewSpacing ];
}

@end
