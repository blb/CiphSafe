/* CSDocument.m */

#import "CSDocument.h"
#import "CSDocModel.h"
#import "CSAppController.h"
#import "CSWinCtrlAdd.h"
#import "CSWinCtrlChange.h"
#import "NSArray_FOOC.h"
#import "NSAttributedString_RWDA.h"
#import "NSData_clear.h"

// Defines for localized strings
#define CSDOCUMENT_LOC_SUREDELROWS \
        NSLocalizedString( @"Are you sure you want to delete the selected rows?", \
                           @"" )
#define CSDOCUMENT_LOC_SUREDELONEROW \
        NSLocalizedString( @"Are you sure you want to delete the selected row?", \
                           @"" )
#define CSDOCUMENT_LOC_SURE NSLocalizedString( @"Are You Sure?", @"" )
#define CSDOCUMENT_LOC_DELETE NSLocalizedString( @"Delete", @"" )
#define CSDOCUMENT_LOC_CANCEL NSLocalizedString( @"Cancel", @"" )
#define CSDOCUMENT_LOC_PASTE NSLocalizedString( @"Paste", @"" )
#define CSDOCUMENT_LOC_DROP NSLocalizedString( @"Drop", @"" )
#define CSDOCUMENT_LOC_CUT NSLocalizedString( @"Cut", @"" )
#define CSDOCUMENT_LOC_CLEAR NSLocalizedString( @"Clear", @"" )
#define CSDOCUMENT_LOC_NAMECOPYN NSLocalizedString( @"%@ copy %d", @"" )
#define CSDOCUMENT_LOC_NAMECOPY NSLocalizedString( @"%@ copy", @"" )

#define CSDOCUMENT_NAME @"CiphSafe Document"

@interface CSDocument (InternalMethods)
- (BOOL) _copyRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
- (BOOL) _retrieveRowsFromPasteboard:(NSPasteboard *)pboard
         undoName:(NSString *)undoName;
- (NSString *) _uniqueNameForName:(NSString *)name;
- (void) _setSortingImageForColumn:(NSTableColumn *)tableColumn;
- (NSArray *) _getSelectedNames;
- (CSDocModel *) _model;
- (void) _setupModel;
- (void) _updateViewForNotification:(NSNotification *)notification;
- (NSMutableData *) _getEncryptionKeyWithNote:(NSString *)note warn:(BOOL)warn;
- (void) _setBFKey:(NSMutableData *)newKey;
@end

@implementation CSDocument

static NSString * const CSDocumentPboardType = @"CSDocumentPboardType";

/*
 * We need our own window controller...
 */
- (void) makeWindowControllers
{
   mainWindowController = [ [ NSWindowController alloc ]
                            initWithWindowNibName:@"CSDocument" owner:self ];
   [ mainWindowController setShouldCloseDocument:YES ];
   [ self addWindowController:mainWindowController ];
   [ mainWindowController release ];

   // These are used to add É in any cell too small to display its data
   textStorage = [ [ NSTextStorage alloc ] init ];
   layoutManager = [ [ NSLayoutManager alloc ] init ];
   textContainer = [ [ NSTextContainer alloc ] init ];
   [ layoutManager addTextContainer:textContainer ];
   [ textContainer release ];
   [ textStorage addLayoutManager:layoutManager ];
   [ layoutManager release ];
}


/*
 * Initial setup of the main document window
 */
- (void) windowControllerDidLoadNib:(NSWindowController *)windowController
{
   // When the main controller loads the NIB, we need to setup the table view
   if( windowController == mainWindowController )
   {
      [ documentView setDrawsGrid:NO ];
      [ documentView setDrawsGrid:YES ];
      [ documentView setDoubleAction:@selector( docViewEntry: ) ];
      previouslySelectedColumn = [ documentView tableColumnWithIdentifier:
                                                [ [ self _model ] sortKey ] ];
      [ documentView setHighlightedTableColumn:previouslySelectedColumn ];
      [ self _setSortingImageForColumn:previouslySelectedColumn ];
      /*
       * The table view is set as the initialFirstResponder, but we have to do
       * this anyway
       */
      [ [ mainWindowController window ] makeFirstResponder:documentView ];
      [ documentView reloadData ];
      [ documentView registerForDraggedTypes:
                        [ NSArray arrayWithObject:CSDocumentPboardType ] ];
   }
}


/*
 * Override the saveDocument...: methods so we can request the passphrase
 * prior to save;
 */
- (IBAction) saveDocument:(id)sender
{
   if( bfKey == nil )
      [ self _setBFKey:[ self _getEncryptionKeyWithNote:CSPassphraseNote_Save
                              warn:[ [ NSUserDefaults standardUserDefaults ]
                                     boolForKey:CSPrefDictKey_WarnShort ] ] ];
   if( bfKey != nil )
      [ super saveDocument:sender ];
}

- (IBAction) saveDocumentAs:(id)sender
{
   [ self _setBFKey:[ self _getEncryptionKeyWithNote:CSPassphraseNote_Save
                           warn:[ [ NSUserDefaults standardUserDefaults ]
                                  boolForKey:CSPrefDictKey_WarnShort ] ] ];
   if( bfKey != nil )
      [ super saveDocumentAs:sender ];
}

- (IBAction) saveDocumentTo:(id)sender
{
   [ self _setBFKey:[ self _getEncryptionKeyWithNote:CSPassphraseNote_Save
                           warn:[ [ NSUserDefaults standardUserDefaults ]
                                  boolForKey:CSPrefDictKey_WarnShort ] ] ];
   if( bfKey != nil )
      [ super saveDocumentTo:sender ];
}


/*
 * For save
 */
- (NSData *) dataRepresentationOfType:(NSString *)aType
{
   NSAssert( [ aType isEqualToString:CSDOCUMENT_NAME ], @"Unknown file type" );
   NSAssert( bfKey != nil, @"key is nil" );

   return [ [ self _model ] encryptedDataWithKey:bfKey ];
}


/*
 * For open
 */
- (BOOL) loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
   BOOL inRevert;

   NSAssert( [ aType isEqualToString:CSDOCUMENT_NAME ], @"Unknown file type" );

   inRevert = NO;
   if( docModel != nil )   // This'll happen on revert
   {
      [ CSWinCtrlChange closeOpenControllersForDocument:self ];
      [ docModel release ];
      docModel = nil;
      inRevert = YES;
   }
   
   // Loop through until we either successfully open it, or the user cancels
   while( docModel == nil )
   {
      if( !inRevert )
         [ self _setBFKey:[ self _getEncryptionKeyWithNote:CSPassphraseNote_Load
                                 warn:NO ] ];

      if( bfKey != nil )
      {
         docModel = [ [ CSDocModel alloc ] initWithEncryptedData:data
                                           bfKey:bfKey ];
         if( docModel != nil )
            [ self _setupModel ];
         else
            [ self _setBFKey:nil ];
      }
      else
         break;   // User cancelled
   }

   return ( docModel != nil );
}


/*
 * Whether or not to keep a backup file (determined by user pref)
 */
- (BOOL) keepBackupFile
{
   return [ [ NSUserDefaults standardUserDefaults ]
            boolForKey:CSPrefDictKey_SaveBackup ];
}


/*
 * Open the window to add new entries, via CSWinCtrlAdd
 */
- (IBAction) docAddEntry:(id)sender
{
   CSWinCtrlAdd *winController;

   winController = [ [ self windowControllers ]
                     firstObjectOfClass:[ CSWinCtrlAdd class ] ];
   if( winController == nil )   // Doesn't exist yet
   {
      winController = [ [ CSWinCtrlAdd alloc ] init ];
      [ self addWindowController:winController ];
      [ winController release ];
   }
   [ winController showWindow:self ];
}


/*
 * Open a window for the selected rows, via CSWinCtrlChange
 */
- (IBAction) docViewEntry:(id)sender
{
   NSArray *namesArray;
   unsigned index;
   CSWinCtrlChange *winController;

   namesArray = [ self _getSelectedNames ];
   for( index = 0; index < [ namesArray count ]; index++ )
   {
      winController = [ CSWinCtrlChange controllerForEntryName:
                                           [ namesArray objectAtIndex:index ]
                                        inDocument:self ];
      if( winController == nil )
      {
         winController = [ [ CSWinCtrlChange alloc ]
                           initForEntryName:[ namesArray objectAtIndex:index ] ];
         [ self addWindowController:winController ];
         [ winController release ];
      }
      [ winController showWindow:self ];
   }
}


/*
 * Delete the selected rows
 */
- (IBAction) docDeleteEntry:(id)sender
{
   NSString *sheetQuestion;
   SEL delSelector;

   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_ConfirmDelete ] )
   {
      if( [ documentView numberOfSelectedRows ] > 1 )
         sheetQuestion = CSDOCUMENT_LOC_SUREDELROWS;
      else
         sheetQuestion = CSDOCUMENT_LOC_SUREDELONEROW;
      delSelector = @selector( deleteSheetDidEnd:returnCode:contextInfo: );
      NSBeginCriticalAlertSheet( CSDOCUMENT_LOC_SURE, CSDOCUMENT_LOC_DELETE,
                                 CSDOCUMENT_LOC_CANCEL, nil,
                                 [ mainWindowController window ], self,
                                 delSelector, nil, NULL, sheetQuestion );
   }
   else
      [ self deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
}


/*
 * Called when the "really delete" sheet is done
 */
- (void) deleteSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )   // They said delete...
      [ self deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
}


/*
 * Change the passphrase associated with the document
 */
- (IBAction) docChangePassphrase:(id)sender
{
   NSMutableData *newKey;

   newKey = [ self _getEncryptionKeyWithNote:CSPassphraseNote_Change
                   warn:[ [ NSUserDefaults standardUserDefaults ]
                          boolForKey:CSPrefDictKey_WarnShort ] ];
   if( newKey != nil )
   {
      [ self _setBFKey:newKey ];
      [ self saveDocument:self ];
   }
}


/*
 * Enable certain menu items only when it makes sense
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
   SEL menuItemAction;
   BOOL retval;

   menuItemAction = [ menuItem action ];

   if( menuItemAction == @selector( docChangePassphrase: ) )
      retval = ( bfKey != nil );
   else if( menuItemAction == @selector( revertDocumentToSaved: ) )
      retval = [ self isDocumentEdited ];
   else if( menuItemAction == @selector( copy: ) ||
            menuItemAction == @selector( cut: ) )
      retval = ( [ documentView numberOfSelectedRows ] > 0 );
   else if( menuItemAction == @selector( paste: ) )
      retval = ( [ [ NSPasteboard generalPasteboard ]
                   availableTypeFromArray:
                      [ NSArray arrayWithObject:CSDocumentPboardType ] ] != nil );
   else
      retval = [ super validateMenuItem:menuItem ];

   return retval;
}


/*
 * Cut selected rows
 */
- (IBAction) cut:(id)sender
{
   [ self _copyRows:[ [ documentView selectedRowEnumerator ] allObjects ]
          toPasteboard:[ NSPasteboard generalPasteboard ] ];
   [ self deleteEntriesWithNamesInArray:[ self _getSelectedNames ] ];
   [ [ self undoManager ] setActionName:CSDOCUMENT_LOC_CUT ];
}


/*
 * Copy selected rows to the general pasteboard
 */
- (IBAction) copy:(id)sender
{
   [ self _copyRows:[ [ documentView selectedRowEnumerator ] allObjects ]
          toPasteboard:[ NSPasteboard generalPasteboard ] ];
}


/*
 * Paste rows from the general pasteboard
 */
- (IBAction) paste:(id)sender
{
   [ self _retrieveRowsFromPasteboard:[ NSPasteboard generalPasteboard ]
          undoName:CSDOCUMENT_LOC_PASTE ];
}


/*
 * Table view methods
 */

/*
 * Handle the table view
 */
- (int) numberOfRowsInTableView:(NSTableView *)aTableView
{
   return [ [ self _model ] entryCount ];
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
      return [ self RTFDStringNotesAtRow:rowIndex ];
   else
      return [ self stringForKey:colID atRow:rowIndex ];
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
   if( [ [ [ self _model ] sortKey ] isEqualToString:tableID ] )
      [ [ self _model ] setSortAscending:![ [ self _model ] isSortAscending ] ];
   else   // Otherwise, set new sort key
      [ [ self _model ] setSortKey:tableID ascending:YES ];

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
   return [ self _copyRows:rows toPasteboard:pboard ];
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
   return [ self _retrieveRowsFromPasteboard:[ info draggingPasteboard ]
                 undoName:CSDOCUMENT_LOC_DROP ];
}


/*
 * Proxy methods to the model
 */
/*
 * Get the string value for some key at the given row
 */
- (NSString *) stringForKey:(NSString *)key atRow:(unsigned)row
{
   return [ [ self _model ] stringForKey:key atRow:row ];
}


/*
 * Get the notes value for the given row
 */
- (NSData *) RTFDNotesAtRow:(unsigned)row
{
   return [ [ self _model ] RTFDNotesAtRow:row ];
}


/*
 * Get the notes value for the given row
 */
- (NSData *) RTFNotesAtRow:(unsigned)row
{
   return [ [ self _model ] RTFNotesAtRow:row ];
}


/*
 */
- (NSAttributedString *) RTFDStringNotesAtRow:(unsigned)row
{
   return [ [ self _model ] RTFDStringNotesAtRow:row ];
}


/*
 */
- (NSAttributedString *) RTFStringNotesAtRow:(unsigned)row
{
   return [ [ self _model ] RTFStringNotesAtRow:row ];
}


/*
 * Find the row for a given name
 */
- (unsigned) rowForName:(NSString *)name
{
   return [ [ self _model ] rowForName:name ];
}


/*
 * Add the given entry
 */
- (BOOL) addEntryWithName:(NSString *)name account:(NSString *)account
         password:(NSString *)password URL:(NSString *)url
         notesRTFD:(NSData *)notes
{
   return [ [ self _model ] addEntryWithName:name account:account
                            password:password URL:url notesRTFD:notes ];
}


/*
 * Change the given entry
 */
- (BOOL) changeEntryWithName:(NSString *)name newName:(NSString *)newName
         account:(NSString *)account password:(NSString *)password
         URL:(NSString *)url notesRTFD:(NSData *)notes
{
   return [ [ self _model ] changeEntryWithName:name newName:newName
                            account:account password:password URL:url
                            notesRTFD:notes ];
}


/*
 * Delete all entries with the given names
 */
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray
{
   return [ [ self _model ] deleteEntriesWithNamesInArray:nameArray ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ self _setBFKey:nil ];
   [ docModel release ];
   [ textStorage release ];
   [ super dealloc ];
}


/*
 * Copy the given rows to the given pasteboard (rows must be an array of
 * objects which respond to unsignedIntValue for the row number)
 */
- (BOOL) _copyRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
   NSMutableArray *docArray;
   NSMutableAttributedString *rtfdStringRows;
   NSAttributedString *attrString, *attrEOL;
   NSEnumerator *rowEnumerator;
   id rowNumber;
   int row;
   NSString *nameString, *acctString, *passwdString, *urlString;

   docArray = [ NSMutableArray arrayWithCapacity:10 ];
   attrEOL = [ [ NSAttributedString alloc ] initWithString:@"\n" ];
   rtfdStringRows = [ [ NSMutableAttributedString alloc ] initWithString:@"" ];
   rowEnumerator = [ rows objectEnumerator ];
   while( ( rowNumber = [ rowEnumerator nextObject ] ) != nil )
   {
      row = [ rowNumber unsignedIntValue ];
      nameString = [ self stringForKey:CSDocModelKey_Name atRow:row ];
      acctString = [ self stringForKey:CSDocModelKey_Acct atRow:row ];
      urlString = [ self stringForKey:CSDocModelKey_URL atRow:row ];
      passwdString = [ self stringForKey:CSDocModelKey_Passwd atRow:row ];
      [ docArray addObject:[ NSDictionary dictionaryWithObjectsAndKeys:
                                             nameString, CSDocModelKey_Name,
                                             acctString, CSDocModelKey_Acct,
                                             passwdString, CSDocModelKey_Passwd,
                                             urlString, CSDocModelKey_URL,
                                             [ self RTFDNotesAtRow:row ],
                                                CSDocModelKey_Notes, nil ] ];
      if( [ [ NSUserDefaults standardUserDefaults ]
                                     boolForKey:CSPrefDictKey_IncludePasswd ] )
         attrString = [ [ NSAttributedString alloc ] initWithString:
                           [ NSString stringWithFormat:@"%@\t%@\t%@\t%@\t",
                              nameString, acctString, passwdString, urlString ] ];
      else
         attrString = [ [ NSAttributedString alloc ] initWithString:
                           [ NSString stringWithFormat:@"%@\t%@\t%@\t",
                              nameString, acctString, urlString ] ];
      [ rtfdStringRows appendAttributedString:attrString ];
      [ attrString release ];
      [ rtfdStringRows appendAttributedString:[ self RTFDStringNotesAtRow:row ] ];
      [ rtfdStringRows appendAttributedString:attrEOL ];
   }

   [ attrEOL release ];
   [ pboard declareTypes:[ NSArray arrayWithObjects:CSDocumentPboardType,
                                                    NSRTFDPboardType,
                                                    NSRTFPboardType,
                                                    NSTabularTextPboardType,
                                                    NSStringPboardType, nil ]
            owner:nil ];
   [ pboard setData:[ NSArchiver archivedDataWithRootObject:docArray ]
            forType:CSDocumentPboardType ];
   [ pboard setData:[ rtfdStringRows RTFDWithDocumentAttributes:NULL ]
            forType:NSRTFDPboardType ];
   [ pboard setData:[ rtfdStringRows RTFWithDocumentAttributes:NULL ]
            forType:NSRTFPboardType ];
   [ pboard setString:[ rtfdStringRows string ] forType:NSTabularTextPboardType ];
   [ pboard setString:[ rtfdStringRows string ] forType:NSStringPboardType ];
   [ rtfdStringRows release ];

   return YES;
}


/*
 * Grab rows from the given pasteboard
 */
- (BOOL) _retrieveRowsFromPasteboard:(NSPasteboard *)pboard
         undoName:(NSString *)undoName
{
   NSArray *rowsArray;
   int index;
   NSDictionary *rowDictionary;

   rowsArray = [ NSUnarchiver unarchiveObjectWithData:
                                 [ pboard dataForType:CSDocumentPboardType ] ];
   if( rowsArray != nil && [ rowsArray count ] > 0 )
   {
      for( index = 0; index < [ rowsArray count ]; index++ )
      {
         rowDictionary = [ rowsArray objectAtIndex:index ];
         [ self addEntryWithName:[ self _uniqueNameForName:
                                [ rowDictionary objectForKey:CSDocModelKey_Name ] ]
                account:[ rowDictionary objectForKey:CSDocModelKey_Acct ]
                password:[ rowDictionary objectForKey:CSDocModelKey_Passwd ]
                URL:[ rowDictionary objectForKey:CSDocModelKey_URL ]
                notesRTFD:[ rowDictionary objectForKey:CSDocModelKey_Notes ] ];
      }
      [ [ self undoManager ] setActionName:undoName ];
   }

   return YES;
}


/*
 * Return a name which doesn't yet exist (eg, 'name' would result in 'name' if
 * 'name' didn't already exist, 'name copy' if it did, then 'name copy #' if
 * 'name copy', etc)
 */
- (NSString *) _uniqueNameForName:(NSString *)name
{
   NSString *uniqueName;
   int index;

   uniqueName = name;
   for( index = 0; [ self rowForName:uniqueName ] != -1; index++ )
   {
      if( index )
         uniqueName = [ NSString stringWithFormat:CSDOCUMENT_LOC_NAMECOPYN, name,
                                                  index ];
      else
         uniqueName = [ NSString stringWithFormat:CSDOCUMENT_LOC_NAMECOPY, name ];
   }

   return uniqueName;
}


/*
 * Setup the given column to have the correct indicator image, and remove the
 * one from the previous column
 */
- (void) _setSortingImageForColumn:(NSTableColumn *)tableColumn
{
   if( [ [ self _model ] isSortAscending ] )
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
      [ selectedNames addObject:[ self stringForKey:CSDocModelKey_Name
                                       atRow:[ rowNumber unsignedIntValue ] ] ];
   }

   return selectedNames;
}


/*
 * Accessor for the model, also creates when necessary
 */
- (CSDocModel *) _model
{
   if( docModel == nil )
   {
      docModel = [ [ CSDocModel alloc ] init ];
      [ self _setupModel ];
   }

   return docModel;
}


/*
 * Register for notifications from the model and give it an undo manager
 */
- (void) _setupModel
{
   NSNotificationCenter *defaultCenter;

   NSAssert( docModel != nil, @"docModel is nil" );

   [ docModel setUndoManager:[ self undoManager ] ];
   defaultCenter = [ NSNotificationCenter defaultCenter ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidChangeSortNotification object:docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidAddEntryNotification object:docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidChangeEntryNotification object:docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidRemoveEntryNotification object:docModel ];
}


/*
 * Called on model notifications so we can redo the table view
 */
- (void) _updateViewForNotification:(NSNotification *)notification
{
   NSArray *namesArray;
   unsigned index;
   CSWinCtrlChange *changeController;

   /*
    * Need to keep change windows synchronized on changes and remove them
    * on deletes, as undo/redo will change them outside our control
    */
   if( [ [ notification name ]
         isEqualToString:CSDocModelDidChangeEntryNotification ] )
   {
      changeController = [ CSWinCtrlChange controllerForEntryName:
                    [ [ notification userInfo ]
                      objectForKey:CSDocModelNotificationInfoKey_ChangedNameFrom ]
                      inDocument:self ];
      if( changeController != nil )
         [ changeController setEntryName:[ [ notification userInfo ]
                  objectForKey:CSDocModelNotificationInfoKey_ChangedNameTo ] ];
   }
   else if( [ [ notification name ]
              isEqualToString:CSDocModelDidRemoveEntryNotification ] )
   {
      namesArray = [ [ notification userInfo ]
                     objectForKey:CSDocModelNotificationInfoKey_DeletedNames ];
      for( index = 0; index < [ namesArray count ]; index++ )
      {
         changeController = [ CSWinCtrlChange controllerForEntryName:
                                                [ namesArray objectAtIndex:index ]
                                             inDocument:self ];
         if( changeController != nil )
            [ [ changeController window ] performClose:self ];
      }
   }
   [ documentView reloadData ];
   [ documentView deselectAll:self ];
}


/*
 * Call out to the passphrase window controller to prompt for a passphrase
 */
- (NSMutableData *) _getEncryptionKeyWithNote:(NSString *)note warn:(BOOL)warn
{
   return [ [ NSApp delegate ] 
            getEncryptionKeyWithNote:note warnOnShortPassphrase:warn
            forDocumentNamed:[ self displayName ] ];
}


/*
 * Set the Blowfish key to be used
 */
- (void) _setBFKey:(NSMutableData *)newKey
{
   /*
    * Normally, we could just retain, release, and set, but since we clear, we
    * have to check stuff first
   */
   if( newKey != bfKey && ![ newKey isEqual:bfKey ] )
   {
      [ newKey retain ];
      [ bfKey clearOutData ];
      [ bfKey release ];
      bfKey = newKey;
   }
}

@end
