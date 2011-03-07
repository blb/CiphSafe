/*
 * Copyright © 2003,2006-2007,2011, Bryan L Blackburn.  All rights reserved.
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
#import "CSPrefsController.h"
#import "CSDocument.h"
#import "CSDocModel.h"


// Accessory view export type tags, make sure the match tag values as set in IB
const NSInteger CSWinCtrlMainExportType_CSV = 0;
const NSInteger CSWinCtrlMainExportType_XML = 1;

// Menu tag mappings
const NSInteger CSWinCtrlMainTag_All = 0;
const NSInteger CSWinCtrlMainTag_Name = 1;
const NSInteger CSWinCtrlMainTag_Acct = 2;
const NSInteger CSWinCtrlMainTag_Passwd = 3;
const NSInteger CSWinCtrlMainTag_URL = 4;
const NSInteger CSWinCtrlMainTag_Category = 5;
const NSInteger CSWinCtrlMainTag_Notes = 6;


NSString *CSWinCtrlMainSearch_All = @"all";


@interface CSWinCtrlMain (InternalMethods)
- (void) loadSavedWindowState;
- (BOOL) loadSavedTableState;
- (void) setupDefaultTableViewColumns;
- (void) updateCornerMenu;
- (void) setSortingImageForColumn:(NSTableColumn *)tableColumn;
- (void) setTableViewSpacing;
- (void) addTableColumnWithID:(NSString *)colID;
- (NSArray *) namesFromIndexes:(NSIndexSet *)indexes;
- (void) updateStatusField;
@end


@implementation CSWinCtrlMain

static NSArray *cmmCopyFields;
static NSArray *columnSelectionArray;
static NSArray *searchWhatArray;


#pragma mark -
#pragma mark Initialization
+ (void) initialize
{
   // Mapping from CMM tags for copy to field names
   cmmCopyFields = [[NSArray alloc] initWithObjects:CSDocModelKey_Acct,
                                                    CSDocModelKey_Passwd,
                                                    CSDocModelKey_URL,
                                                    CSDocModelKey_Name,
                                                    CSDocModelKey_Notes,
                                                    nil];
   // Mapping from corner menu tags to field names
   columnSelectionArray = [[NSArray alloc] initWithObjects:@"allColumns",
                                                           CSDocModelKey_Name,
                                                           CSDocModelKey_Acct,
                                                           CSDocModelKey_Passwd,
                                                           CSDocModelKey_URL,
                                                           CSDocModelKey_Category,
                                                           CSDocModelKey_Notes,
                                                           nil];
   searchWhatArray = [[NSArray alloc] initWithObjects:CSWinCtrlMainSearch_All,
                                                      CSDocModelKey_Name,
                                                      CSDocModelKey_Acct,
                                                      CSDocModelKey_Passwd,
                                                      CSDocModelKey_URL,
                                                      CSDocModelKey_Category,
                                                      CSDocModelKey_Notes,
                                                      nil];
}


/*
 * Simple setup, load the NIB, make our controller the bigboy
 */
- (id) init
{
   self = [super initWithWindowNibName:@"CSDocument"];
   if(self != nil)
   {
      [self setShouldCloseDocument:YES];
      searchResultList = nil;
   }

   return self;
}


/*
 * Initial setup of the window
 */
- (void) awakeFromNib
{
   // Load window/table info from prefs when opening a document, otherwise use defaults
   if([[self document] fileURL] != nil)
   {
      [self loadSavedWindowState];
      if(![self loadSavedTableState])
         [self setupDefaultTableViewColumns];
      [self setShouldCascadeWindows:NO];
   }
   else
      [self setupDefaultTableViewColumns];
   
   [self updateCornerMenu];
   [documentView setDoubleAction:@selector(viewEntry:)];
   previouslySelectedColumn = [documentView tableColumnWithIdentifier:[[self document] sortKey]];
   [documentView setHighlightedTableColumn:previouslySelectedColumn];
   [self setSortingImageForColumn:previouslySelectedColumn];
   
   // The table view is set as the initialFirstResponder, but we have to do this as well
   [[self window] makeFirstResponder:documentView];
   
   [documentView registerForDraggedTypes:[NSArray arrayWithObject:CSDocumentPboardType]];
   
   // The corner view and header view both offer the menu for selecting what columns to show
   [[documentView cornerView] setMenu:cmmTableHeader];
   [[documentView headerView] setMenu:cmmTableHeader];
   
   [self setTableViewSpacing];
   [self refreshWindow];
   
   // Load last-used search key from prefs, or All if none
   NSUserDefaults *stdDefaults = [NSUserDefaults standardUserDefaults];
   NSString *currentSearchKey = [stdDefaults stringForKey:CSPrefDictKey_CurrentSearchKey];
   if(currentSearchKey == nil)
   {
      [[searchField cell] setPlaceholderString:NSLocalizedString(CSWinCtrlMainSearch_All, nil)];
      currentSearchCategory = CSWinCtrlMainTag_All;
   }
   else
   {
      [[searchField cell] setPlaceholderString:NSLocalizedString(currentSearchKey, nil)];
      currentSearchCategory = [searchWhatArray indexOfObject:currentSearchKey];
   }
   [[searchCategoryMenu itemWithTag:currentSearchCategory] setState:NSOnState];
   
   // Load stripe color from prefs, or the default blue if none
   id tableAltBackgroundPref = [stdDefaults objectForKey:CSPrefDictKey_TableAltBackground];
   if(tableAltBackgroundPref == nil)
      [documentView setStripeColor:[NSColor colorWithCalibratedRed:0.93
                                                             green:0.95
                                                              blue:1.0
                                                             alpha:1.0]];
   else
      [documentView setStripeColor:[NSUnarchiver unarchiveObjectWithData:tableAltBackgroundPref]];
   
   [documentView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
   [documentView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
   
   // Finally, listen for changes to certain prefs
   [stdDefaults addObserver:self forKeyPath:CSPrefDictKey_CellSpacing options:0 context:NULL];
   [stdDefaults addObserver:self forKeyPath:CSPrefDictKey_TableAltBackground options:0 context:NULL];
   [stdDefaults addObserver:self forKeyPath:CSPrefDictKey_IncludeDefaultCategories options:0 context:NULL];
   
   tableIsDragging = NO;
}


#pragma mark -
#pragma mark Configuration State Handling
/*
 * Method to return a good, hopefully-unique string to use as a key into the prefs for saving a window
 */
- (NSString *) windowPrefKey
{
   return [NSString stringWithFormat:@"CSWinCtrlMain Window %@", [[self document] displayName]];
}


/*
 * Load previously-saved window layout information, if any
 */
- (void) loadSavedWindowState
{
   NSString *windowFrameString = [[NSUserDefaults standardUserDefaults]
                                  stringForKey:[self windowPrefKey]];
   if(windowFrameString != nil)
      [[self window] setFrameFromString:windowFrameString];
}


/*
 * Save window layout information
 */
- (void) saveWindowState
{
   [[NSUserDefaults standardUserDefaults] setObject:[[self window] stringWithSavedFrame]
                                             forKey:[self windowPrefKey]];
}


/*
 * Method to return a good, hopefully-unique string to use as a key into the prefs for saving a table view
 */
- (NSString *) tableViewPrefKey
{
   return [NSString stringWithFormat:@"CSWinCtrlMain Table %@", [[self document] displayName]];
}


/*
 * Load previously-saved table layout information, if any
 */
- (BOOL) loadSavedTableState
{
   NSString *tableInfoString = [[NSUserDefaults standardUserDefaults]
                                stringForKey:[self tableViewPrefKey]];
   // Loop through rearranging columns and setting each column's size
   if(tableInfoString != nil && [tableInfoString length] > 0)
   {
      NSArray *partsArray = [tableInfoString componentsSeparatedByString:@" "];
      NSInteger index;
      for(index = 0; index < [partsArray count]; index += 2)
      {
         NSString *colName = [partsArray objectAtIndex:index];
         [self addTableColumnWithID:colName];
         NSInteger currentColIndex = [documentView columnWithIdentifier:colName];
         [documentView moveColumn:currentColIndex toColumn:(index / 2)];
         NSTableColumn *tableColumn = [documentView tableColumnWithIdentifier:colName];
         [tableColumn setWidth:[[partsArray objectAtIndex:(index + 1)] doubleValue]];
      }
      return YES;
   }
   
   return NO;
}


/*
 * Save table layout information
 */
- (void) saveTableState
{
   NSArray *tableColumns = [documentView tableColumns];
   NSMutableString *infoString = [NSMutableString stringWithCapacity:70];
   NSInteger index;
   for(index = 0; index < [tableColumns count]; index++)
   {
      NSTableColumn *tableColumn = [tableColumns objectAtIndex:index];
      if(index == 0)
         [infoString appendFormat:@"%@ %f", [tableColumn identifier], [tableColumn width]];
      else
         [infoString appendFormat:@" %@ %f", [tableColumn identifier], [tableColumn width]];
   }
   [[NSUserDefaults standardUserDefaults] setObject:infoString
                                             forKey:[self tableViewPrefKey]];
}


#pragma mark -
#pragma mark Searching
/*
 * Update the matching list for the search, and tell the table view to update
 */
- (void) setSearchResultList:(NSArray *)newList
{
   if(newList != searchResultList)
   {
      [searchResultList autorelease];
      searchResultList = [newList retain];
   }
}


/*
 * Filter the view of the document based on the search string
 */
- (void) filterView
{
   NSString *searchString = [searchField stringValue];
   if(searchString != nil && [searchString length] > 0)
   {
      NSString *searchKey = [searchWhatArray objectAtIndex:currentSearchCategory];
      if([searchKey isEqualToString:CSWinCtrlMainSearch_All])   // For all, use a nil key
         searchKey = nil;
      [self setSearchResultList:[[self document] rowsMatchingString:searchString
                                                         ignoreCase:YES
                                                             forKey:searchKey]];
   }
   else
      [self setSearchResultList:nil];
}


/*
 * Return the search-list row number for a given basic row number
 */
- (NSInteger) rowForFilteredRow:(NSInteger)row
{
   if(searchResultList != nil)
      return [[searchResultList objectAtIndex:row] integerValue];
   else
      return row;
}


/*
 * Return the original row number for a filtered row number
 */
- (NSInteger) filteredRowForRow:(NSInteger)row
{
   if(searchResultList != nil)
   {
      NSInteger index;
      for(index = 0; index < [searchResultList count]; index++)
      {
         if([[searchResultList objectAtIndex:index] integerValue] == row)
            return index;
      }
      return -1;
   }
   else
      return row;
}


/*
 * Select which category to search
 */
- (IBAction) limitSearch:(id)sender
{
   NSMenuItem *previousCategoryItem = [[sender menu] itemWithTag:currentSearchCategory];
   [previousCategoryItem setState:NSOffState];
   currentSearchCategory = [sender tag];
   [sender setState:NSOnState];
   NSString *searchCategoryString = [searchWhatArray objectAtIndex:currentSearchCategory];
   [[searchField cell] setPlaceholderString:NSLocalizedString(searchCategoryString, nil)];
   [[NSUserDefaults standardUserDefaults] setObject:searchCategoryString
                                             forKey:CSPrefDictKey_CurrentSearchKey];
   [self refreshWindow];
}


#pragma mark -
#pragma mark Selection Handling
/*
 * Return a set of the selected row indices
 */
- (NSIndexSet *) selectedRowIndexes
{
   return [documentView selectedRowIndexes];
}


/*
 * Return an array of the names for selected rows in the table view
 */
- (NSArray *) getSelectedNames
{
   return [self namesFromIndexes:[self selectedRowIndexes]];
}


/*
 * Select all rows with names in the given array
 */
- (void) selectNames:(NSArray *)names
{
   NSMutableIndexSet *rowIndex = [NSMutableIndexSet indexSet];
   NSEnumerator *nameEnumerator = [names objectEnumerator];
   id rowName;
   while((rowName = [nameEnumerator nextObject]) != nil)
      [rowIndex addIndex:[[self document] rowForName:rowName]];
   [documentView selectRowIndexes:rowIndex byExtendingSelection:NO];
}


#pragma mark -
#pragma mark Button Handling
/*
 * Tell the document to do whatever to allow for a new entry
 */
- (IBAction) addEntry:(id)sender
{
   [[self document] openAddEntryWindow];
}


/*
 * Tell the document to view the certain entries
 */
- (IBAction) viewEntry:(id)sender
{
   [[self document] viewEntries:[self getSelectedNames]];
}


/*
 * Tell the document to delete certain entries
 */
- (IBAction) delete:(id)sender
{
   [[self document] deleteEntriesWithNamesInArray:[self getSelectedNames]];
}


#pragma mark -
#pragma mark Copy/Paste
/*
 * Cut selected rows
 */
- (IBAction) cut:(id)sender
{
   [[self document] copyRows:[self selectedRowIndexes] toPasteboard:[NSPasteboard generalPasteboard]];
   [[self document] deleteEntriesWithNamesInArray:[self getSelectedNames]];
   [[[self document] undoManager] setActionName:NSLocalizedString(@"Cut", @"")];
   [[NSApp delegate] notePBChangeCount];
}


/*
 * Copy selected rows to the general pasteboard
 */
- (IBAction) copy:(id)sender
{
   [[self document] copyRows:[self selectedRowIndexes] toPasteboard:[NSPasteboard generalPasteboard]];
   [[NSApp delegate] notePBChangeCount];
}


/*
 * Paste rows from the general pasteboard
 */
- (IBAction) paste:(id)sender
{
   [[self document] retrieveEntriesFromPasteboard:[NSPasteboard generalPasteboard]
                                         undoName:NSLocalizedString(@"Paste", @"")];
}


#pragma mark -
#pragma mark TableView Handling
/*
 * Table view methods
 */

/*
 * Do like it says
 */
- (void) setTableViewSpacing
{
   NSInteger cellSpacing = [[NSUserDefaults standardUserDefaults] integerForKey:CSPrefDictKey_CellSpacing];
   NSSize newSpacing = NSMakeSize(3.0, 2.0);   // The default is small
   if(cellSpacing == CSPrefCellSpacingOption_Medium)
      newSpacing = NSMakeSize(5.0, 2.0);
   else if(cellSpacing == CSPrefCellSpacingOption_Large)
      newSpacing = NSMakeSize(7.0, 3.0);
   [documentView setIntercellSpacing:newSpacing];
}


/*
 * Add a table column for the given column, if it isn't already there
 */
- (void) addTableColumnWithID:(NSString *)colID
{
   if([documentView columnWithIdentifier:colID] == -1)
   {
      NSTableColumn *newColumn = [[NSTableColumn alloc] initWithIdentifier:colID];
      [newColumn setEditable:NO];
      [newColumn setResizingMask:(NSTableColumnAutoresizingMask | NSTableColumnUserResizingMask)];
      [[newColumn headerCell] setStringValue:NSLocalizedString(colID, @"")];
      [documentView addTableColumn:newColumn];
      [newColumn release];
   }
}


/*
 * Show or hide the given column
 */
- (void) setDisplayOfColumnID:(NSString *)colID enabled:(BOOL)enabled
{
   if(enabled)
      [self addTableColumnWithID:colID];
   else
   {
      NSTableColumn *colToRemove = [[documentView tableColumnWithIdentifier:colID] retain];
      [documentView removeTableColumn:colToRemove];
      if([previouslySelectedColumn isEqual:colToRemove])
         [self tableView:documentView didClickTableColumn:[[documentView tableColumns] objectAtIndex:0]];
      [colToRemove release];
   }
   [documentView sizeToFit];
}


/*
 * Default layout for new documents
 */
- (void) setupDefaultTableViewColumns
{
   [self setDisplayOfColumnID:CSDocModelKey_Name enabled:YES];
   [self setDisplayOfColumnID:CSDocModelKey_Acct enabled:YES];
   [self setDisplayOfColumnID:CSDocModelKey_URL enabled:YES];
   [self setDisplayOfColumnID:CSDocModelKey_Notes enabled:YES];
   // Without resizing, the columns are oddly sized...
   NSEnumerator *colEnum = [[documentView tableColumns] objectEnumerator];
   id aColumn;
   while((aColumn = [colEnum nextObject]) != nil)
      [aColumn setWidth:10.0];
   [documentView sizeToFit];
}


/*
 * Set menu state for the column selections
 */
- (void) updateCornerMenu
{
   NSInteger index;
   for(index = 1; index < [columnSelectionArray count]; index++)
   {
      if([documentView columnWithIdentifier:[columnSelectionArray objectAtIndex:index]] >= 0)
         [[cmmTableHeader itemWithTag:index] setState:NSOnState];
      else
         [[cmmTableHeader itemWithTag:index] setState:NSOffState];
   }
}


/*
 * Handle the table view
 */
- (NSInteger) numberOfRowsInTableView:(NSTableView *)aTableView
{
   if(searchResultList != nil)
      return [searchResultList count];
   else
      return [[self document] entryCount];
}


/*
 * Return the proper value
 */
- (id) tableView:(NSTableView *)aTableView
       objectValueForTableColumn:(NSTableColumn *)aTableColumn
       row:(NSInteger)rowIndex
{
   NSString *colID = [aTableColumn identifier];
   if([colID isEqualToString:CSDocModelKey_Notes])
      return [[self document] RTFDStringNotesAtRow:[self rowForFilteredRow:rowIndex]];
   else
      return [[self document] stringForKey:colID atRow:[self rowForFilteredRow:rowIndex]];
}


/*
 * Change the sorting
 */
- (void) tableView:(NSTableView*)tableView
         didClickTableColumn:(NSTableColumn *)tableColumn;
{
   NSString *colID = [tableColumn identifier];
   // If the current sorting column is clicked, we reverse the order
   if([[[self document] sortKey] isEqualToString:colID])
      [[self document] setSortAscending:![[self document] isSortAscending]];
   else   // Otherwise, set new sort key
      [[self document] setSortKey:colID ascending:YES];

   [documentView setHighlightedTableColumn:tableColumn];
   [self setSortingImageForColumn:tableColumn];
}


/*
 * Enable/disable delete and view buttons depending on whether something
 * is selected
 */
- (void) tableViewSelectionDidChange:(NSNotification *)aNotification
{
   BOOL enableState = ([documentView numberOfSelectedRows] != 0);
   [documentDeleteButton setEnabled:enableState];
   [documentViewButton setEnabled:enableState];
   [self updateStatusField];
}


/*
 * Support dragging of tableview rows
 */
- (BOOL) tableView:(NSTableView *)aTableView
         writeRowsWithIndexes:(NSIndexSet *)rowIndexes
         toPasteboard:(NSPasteboard*)pboard
{
   tableIsDragging = YES;
   dragNamesArray = [[self namesFromIndexes:rowIndexes] retain];
   return [[self document] copyRows:rowIndexes toPasteboard:pboard];
}


/*
 * Handle moving of data during a drag
 */
- (void) blbTableView:(BLBTableView *)tableView
 completedDragAtPoint:(NSPoint)aPoint
            operation:(NSDragOperation)operation
{
   if(operation == NSDragOperationMove)
   {
      [[self document] deleteEntriesWithNamesInArray:dragNamesArray];
      [[[self document] undoManager] setActionName:NSLocalizedString(@"Move", @"")];
      [[NSApp delegate] notePBChangeCount];
   }
   [dragNamesArray release];
   dragNamesArray = nil;
   tableIsDragging = NO;
}


/*
 * We copy on drops (the registerForDraggedTypes sets up for only
 * CSDocumentPboardType)
 */
- (NSDragOperation) tableView:(NSTableView*)tv
                    validateDrop:(id <NSDraggingInfo>)info
                    proposedRow:(NSInteger)row
                    proposedDropOperation:(NSTableViewDropOperation)op
{
   if(tableIsDragging)
      return NSDragOperationNone;
   else if([info draggingSourceOperationMask] == NSDragOperationGeneric)
      return NSDragOperationMove;
   else
      return NSDragOperationCopy;
}


/*
 * Accept a drop
 */
- (BOOL) tableView:(NSTableView*)tv
         acceptDrop:(id <NSDraggingInfo>)info
         row:(NSInteger)row
         dropOperation:(NSTableViewDropOperation)op
{
   return [[self document] retrieveEntriesFromPasteboard:[info draggingPasteboard]
                                                undoName:NSLocalizedString(@"Drop", @"")];
}


/*
 * Handle keypresses in the table view by scrolling to the first entry whose
 * name begins with the key pressed; spacebar is a pagedown equivalent
 */
- (BOOL) blbTableView:(BLBTableView *)tableView
   didReceiveKeyDownEvent:(NSEvent *)theEvent
{
   if([[theEvent characters] characterAtIndex:0] == ' ')
   {
      NSSize contentViewSize = [[tableView enclosingScrollView] contentSize];
      CGFloat amtToKeepVisible = [[tableView enclosingScrollView] verticalPageScroll];
      [tableView scrollRectToVisible:NSOffsetRect([tableView visibleRect],
                                                  0.0,
                                                  contentViewSize.height - amtToKeepVisible)];
      return YES;
   }
   else
   {
      NSNumber *rowForKey = [[self document] firstRowBeginningWithString:[theEvent characters]
                                                              ignoreCase:YES
                                                                  forKey:CSDocModelKey_Name];
      if(rowForKey != nil)
      {
         NSInteger filteredRow = [self filteredRowForRow:[rowForKey integerValue]];
         if(filteredRow >= 0)
         {
            [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:filteredRow]
                   byExtendingSelection:NO];
            [tableView scrollRowToVisible:filteredRow];
            return YES;
         }
      }
   }

   return NO;
}


/*
 * Select/unselect a column for display (we determine which from the sender)
 */
- (IBAction) cornerSelectField:(id)sender
{
   if([sender tag] == 0)   // Show all columns
   {
      NSInteger index;
      for(index = 1; index < [columnSelectionArray count]; index++)
         [self setDisplayOfColumnID:[columnSelectionArray objectAtIndex:index] enabled:YES];
   }
   else
   {
      BOOL enabled = ([sender state] != NSOnState);
      if([[documentView tableColumns] count] > 1 || enabled)
         [self setDisplayOfColumnID:[columnSelectionArray objectAtIndex:[sender tag]] enabled:enabled];
      else
         NSBeginCriticalAlertSheet(
            NSLocalizedString(@"Need at least one column", @""),
            nil,
            nil,
            nil,
            [self window],
            nil,
            nil,
            nil,
            NULL,
            NSLocalizedString(@"At least one column is needed in order to be useful", @""));
   }
   [self updateCornerMenu];
}


#pragma mark -
#pragma mark Menu Handling
/*
 * Set the category on a bunch of entries
 */
- (IBAction) setCategory:(id)sender
{
   NSArray *categories = [[self document] valueForKey:@"categories"];
   NSString *category;
   if([categories containsObject:[sender title]])
      category = [sender title];
   else
   {
      if([NSApp runModalForWindow:newCategoryWindow] == NSRunStoppedResponse)
         category = [newCategory stringValue];
      else
         category = nil;
   }

   if(category != nil)
   {
      NSEnumerator *selectedNamesEnumerator = [[self getSelectedNames] objectEnumerator];
      id nextName;
      while((nextName = [selectedNamesEnumerator nextObject]) != nil)
      {
         [[self document] changeEntryWithName:nextName
                                      newName:nil
                                      account:nil
                                     password:nil
                                          URL:nil
                                     category:category
                                    notesRTFD:nil];
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
- (NSMenu *) contextualMenuForBLBTableView:(BLBTableView *)tableView
                                       row:(NSInteger)row
                                    column:(NSInteger)column
{
   [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

   return contextualMenu;
}


/*
 * Copy the entry's field according to which menu was used to get here (ie
 * through the cmmCopyField mapping and the menu tags)
 */
- (IBAction) cmmCopyField:(id)sender
{
   NSString *fieldName = [cmmCopyFields objectAtIndex:[sender tag]];
   NSPasteboard *generalPB = [NSPasteboard generalPasteboard];
   NSInteger selectedRow = [self rowForFilteredRow:[documentView selectedRow]];
   if([fieldName isEqual:CSDocModelKey_Notes])
   {
      [generalPB declareTypes:[NSArray arrayWithObjects:NSRTFDPboardType, NSRTFPboardType, nil]
                        owner:nil];
      [generalPB setData:[[self document] RTFDNotesAtRow:selectedRow] forType:NSRTFDPboardType];
      [generalPB setData:[[self document] RTFNotesAtRow:selectedRow] forType:NSRTFPboardType];
   }
   else
   {
      [generalPB declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
      [generalPB setString:[[self document] stringForKey:fieldName atRow:selectedRow]
                   forType:NSStringPboardType];
   }
   [[NSApp delegate] notePBChangeCount];
}


/*
 * Open the URL from the selected row
 */
- (IBAction) cmmOpenURL:(id)sender
{
   NSInteger selectedRow = [self rowForFilteredRow:[documentView selectedRow]];
   NSURL *theURL = [NSURL URLWithString:[[self document] stringForKey:CSDocModelKey_URL
                                                                atRow:selectedRow]];
   if(theURL == nil || ![[NSWorkspace sharedWorkspace] openURL:theURL])
      NSBeginInformationalAlertSheet(NSLocalizedString(@"Invalid URL", @""),
                                     nil,
                                     nil,
                                     nil,
                                     [self window],
                                     nil,
                                     nil,
                                     nil,
                                     nil,
                                     NSLocalizedString(@"The URL entered is not a valid URL", @""));
}


/*
 * Enable/disable certain menu items, as necessary
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
   SEL menuItemAction = [menuItem action];
   if(menuItemAction == @selector(copy:) || menuItemAction == @selector(cut:)
      || menuItemAction == @selector(setCategory:) || menuItemAction == @selector(delete:))
      return ([documentView numberOfSelectedRows] > 0);
   else if(menuItemAction == @selector(paste:))
      return ([[NSPasteboard generalPasteboard] 
               availableTypeFromArray:[NSArray arrayWithObject:CSDocumentPboardType]] != nil);
   else if(menuItemAction == @selector(cmmCopyField:)
           || menuItemAction == @selector(cmmOpenURL:))
   {
      NSInteger selectedRow = [self rowForFilteredRow:[documentView selectedRow]];
      NSString *fieldName = nil;
      if(menuItemAction == @selector(cmmOpenURL:))
         fieldName = CSDocModelKey_URL;
      else
         fieldName = [cmmCopyFields objectAtIndex:[menuItem tag]];
      NSString *fieldValue = [[self document] stringForKey:fieldName atRow:selectedRow];
      if(fieldValue != nil && [fieldValue length] > 0)
         return YES;
      else
         return NO;
   }
   
   return YES;
}


#pragma mark -
#pragma mark Export Handling
/*
 * Return the export accessory view from the NIB
 */
- (NSView *) exportAccessoryView
{
   return exportAccessoryView;
}


/*
 * Return the export accessory view's popup button's selection (see the CSWinCtrlMainExportType_*
 * constants)
 */
- (NSInteger) exportType
{
   return [exportType selectedTag];
}


/*
 * Return if the export CSV header checkbox is checked
 */
- (BOOL) exportCSVHeader
{
   return ([exportCSVHeader state] == NSOnState);
}


/*
 * Enable/disable the CSV-specific checkbox
 */
- (IBAction) exportTypeChanged:(id)sender
{
   if([[sender selectedItem] tag] == CSWinCtrlMainExportType_CSV)
      [exportCSVHeader setEnabled:YES];
   else
      [exportCSVHeader setEnabled:NO];
}


#pragma mark -
#pragma mark Window Handling
/*
 * Update set category menu when we are key (since it now applies to us)
 */
- (void) windowDidBecomeKey:(NSNotification *)aNotification
{
   NSArray *categories = [[self document] valueForKey:@"categories"];
   [[NSApp delegate] updateSetCategoryMenuWithCategories:categories action:@selector(setCategory:)];
}


/*
 * Cleanup
 */
- (void) windowWillClose:(NSNotification *)notification
{
   [self setSearchResultList:nil];
   NSUserDefaults *stdDefaults = [NSUserDefaults standardUserDefaults];
   [stdDefaults removeObserver:self forKeyPath:CSPrefDictKey_CellSpacing];
   [stdDefaults removeObserver:self forKeyPath:CSPrefDictKey_TableAltBackground];
   [stdDefaults removeObserver:self forKeyPath:CSPrefDictKey_IncludeDefaultCategories];
}


/*
 * Refresh all the views in the window
 */
- (void) refreshWindow
{
   NSArray *categories = [[self document] valueForKey:@"categories"];
   [[NSApp delegate] updateSetCategoryMenuWithCategories:categories action:@selector(setCategory:)];
   [self filterView];
   [documentView reloadData];
   [documentView deselectAll:self];
   [self updateStatusField];
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * When the search field value is changed; set that the field is modified if
 * it has, setup filtering, and refresh the view
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
   if([[aNotification object] isEqual:searchField])
      [self refreshWindow];
}


/*
 * Only reliable way to know when we're going away and we still have a
 * reference to the document (sometimes [self document] works in
                              * windowWillClose:, sometimes it doesn't)
 */
- (void) setDocument:(NSDocument *)document
{
   if([self document] != nil && document == nil && [[self document] fileURL] != nil)
   {
      [self saveWindowState];
      [self saveTableState];
      [[NSUserDefaults standardUserDefaults] synchronize];
   }
   [super setDocument:document];
}


/*
 * Update the status field with current information
 */
- (void) updateStatusField
{
   NSInteger entryCount = [self numberOfRowsInTableView:documentView];
   NSInteger selectedCount = [documentView numberOfSelectedRows];
   NSString *statusString;
   if(entryCount == 1)
      statusString = [NSString stringWithFormat:NSLocalizedString(@"1 entry, %ld selected", @""),
                                                (long) selectedCount];
   else
      statusString = [NSString stringWithFormat:NSLocalizedString(@"%ld entries, %ld selected", @""),
                                                (long) entryCount,
                                                (long) selectedCount];
   if(searchResultList != nil)
      statusString = [NSString stringWithFormat:@"%@ (%@)",
                                                statusString,
                                                NSLocalizedString(@"filtered", @"")];
   [documentStatus setStringValue:statusString];
}


/*
 * Convert an index set of row numbers to an array of names
 */
- (NSArray *) namesFromIndexes:(NSIndexSet *)indexes
{
   NSMutableArray *nameArray = [NSMutableArray arrayWithCapacity:[indexes count]];
   NSInteger rowIndex;
   for(rowIndex = [indexes firstIndex];
       rowIndex != NSNotFound;
       rowIndex = [indexes indexGreaterThanIndex:rowIndex])
   {
      [nameArray addObject:[[self document] stringForKey:CSDocModelKey_Name
                                                   atRow:[self rowForFilteredRow:rowIndex]]];
   }
   
   return nameArray;
}


/*
 * Setup the given column to have the correct indicator image, and remove the
 * one from the previous column
 */
- (void) setSortingImageForColumn:(NSTableColumn *)tableColumn
{
   if([[self document] isSortAscending])
      [documentView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"]
                        inTableColumn:tableColumn];
   else
      [documentView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"]
                        inTableColumn:tableColumn];
   if(![previouslySelectedColumn isEqual:tableColumn])
      [documentView setIndicatorImage:nil inTableColumn:previouslySelectedColumn];
   previouslySelectedColumn = tableColumn;
}


/*
 * Handle when certain observed items are updated
 */
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object 
                        change:(NSDictionary *)change
                       context:(void *)context
{
   if([keyPath isEqualToString:CSPrefDictKey_CellSpacing])
      [self setTableViewSpacing];
   else if([keyPath isEqualToString:CSPrefDictKey_IncludeDefaultCategories])
   {
      NSArray *categories = [[self document] valueForKey:@"categories"];
      [[NSApp delegate] updateSetCategoryMenuWithCategories:categories action:@selector(setCategory:)];
   }
   else if([keyPath isEqualToString:CSPrefDictKey_TableAltBackground])
   {
      NSColor *stripeColor = [NSUnarchiver unarchiveObjectWithData:
                                              [[NSUserDefaults standardUserDefaults]
                                               objectForKey:CSPrefDictKey_TableAltBackground]];
      [documentView setStripeColor:stripeColor];
   }
}


/*
 * Simple end modals
 */
- (IBAction) newCategoryOK:(id)sender
{
   [NSApp stopModal];
   [newCategoryWindow orderOut:self];
}

- (IBAction) newCategoryCancel:(id)sender
{
   [NSApp abortModal];
   [newCategoryWindow orderOut:self];
}

@end
