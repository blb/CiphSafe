/* CSDocument.m */

#import "CSDocument.h"
#import "CSDocModel.h"
#import "CSAppController.h"
#import "CSWinCtrlAdd.h"
#import "CSWinCtrlChange.h"
#import "CSWinCtrlMain.h"
#import "CSWinCtrlPassphrase.h"
#import "NSArray_FOOC.h"
#import "NSAttributedString_RWDA.h"
#import "NSData_clear.h"

// Defines for localized strings
#define CSDOCUMENT_LOC_NAMECOPYN NSLocalizedString( @"%@ copy %d", @"" )
#define CSDOCUMENT_LOC_NAMECOPY NSLocalizedString( @"%@ copy", @"" )

#define CSDOCUMENT_NAME @"CiphSafe Document"

#define CSDOCUMENT_GETKEYSTATE_NONE   0
#define CSDOCUMENT_GETKEYSTATE_SAVE   1
#define CSDOCUMENT_GETKEYSTATE_SAVEAS 2
#define CSDOCUMENT_GETKEYSTATE_SAVETO 3
#define CSDOCUMENT_GETKEYSTATE_CHANGE 4

@interface CSDocument (InternalMethods)
- (NSString *) _uniqueNameForName:(NSString *)name;
- (CSDocModel *) _model;
- (void) _setupModel;
- (void) _updateViewForNotification:(NSNotification *)notification;
- (void) _beginPassphraseSheetForState:(int)state note:(NSString *)note;
- (void) _getKeyResult:(NSMutableData *)newKey;
- (CSWinCtrlPassphrase *) _passphraseWindowController;
- (void) _setBFKey:(NSMutableData *)newKey;
@end

@implementation CSDocument

/*
 * We need our own window controller...
 */
- (void) makeWindowControllers
{
   mainWindowController = [ [ CSWinCtrlMain alloc ] init ];
   [ self addWindowController:mainWindowController ];
   [ mainWindowController release ];
}


/*
 * Override the saveDocument...: methods so we can request the passphrase
 * prior to save;
 */
- (IBAction) saveDocument:(id)sender
{
   if( bfKey == nil )
      [ self _beginPassphraseSheetForState:CSDOCUMENT_GETKEYSTATE_SAVE
             note:CSPassphraseNote_Save ];
   else
      [ super saveDocument:sender ];
}

- (IBAction) saveDocumentAs:(id)sender
{
   if( bfKey == nil )
      [ self _beginPassphraseSheetForState:CSDOCUMENT_GETKEYSTATE_SAVEAS
             note:CSPassphraseNote_Save ];
   else
      [ super saveDocumentAs:sender ];
}

- (IBAction) saveDocumentTo:(id)sender
{
   if( bfKey == nil )
      [ self _beginPassphraseSheetForState:CSDOCUMENT_GETKEYSTATE_SAVETO
             note:CSPassphraseNote_Save ];
   else
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
         [ self _setBFKey:[ [ self _passphraseWindowController ]
                            getEncryptionKeyWithNote:CSPassphraseNote_Load
                            forDocumentNamed:[ self displayName ] ] ];

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
- (void) openAddEntryWindow
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
 * Open a window for the given array of names, via CSWinCtrlChange
 */
- (void) viewEntries:(NSArray *)namesArray
{
   unsigned index;
   CSWinCtrlChange *winController;

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
 * Change the passphrase associated with the document
 */
- (IBAction) docChangePassphrase:(id)sender
{
   [ self _beginPassphraseSheetForState:CSDOCUMENT_GETKEYSTATE_CHANGE
          note:CSPassphraseNote_Change ];
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
   else
      retval = [ super validateMenuItem:menuItem ];

   return retval;
}


/*
 * Copy the given rows to the given pasteboard (rows must be an array of
 * objects which respond to unsignedIntValue for the row number)
 */
- (BOOL) copyNames:(NSArray *)names toPasteboard:(NSPasteboard *)pboard
{
   NSMutableArray *docArray;
   NSMutableAttributedString *rtfdStringRows;
   NSAttributedString *attrString, *attrEOL;
   NSEnumerator *nameEnumerator;
   int row;
   NSString *nextName, *acctString, *passwdString, *urlString;

   docArray = [ NSMutableArray arrayWithCapacity:10 ];
   attrEOL = [ [ NSAttributedString alloc ] initWithString:@"\n" ];
   rtfdStringRows = [ [ NSMutableAttributedString alloc ] initWithString:@"" ];
   nameEnumerator = [ names objectEnumerator ];
   while( ( nextName = [ nameEnumerator nextObject ] ) != nil )
   {
      row = [ self rowForName:nextName ];
      acctString = [ self stringForKey:CSDocModelKey_Acct atRow:row ];
      urlString = [ self stringForKey:CSDocModelKey_URL atRow:row ];
      passwdString = [ self stringForKey:CSDocModelKey_Passwd atRow:row ];
      [ docArray addObject:[ NSDictionary dictionaryWithObjectsAndKeys:
                                             nextName, CSDocModelKey_Name,
                                             acctString, CSDocModelKey_Acct,
                                             passwdString, CSDocModelKey_Passwd,
                                             urlString, CSDocModelKey_URL,
                                             [ self RTFDNotesAtRow:row ],
                                                CSDocModelKey_Notes, nil ] ];
      if( [ [ NSUserDefaults standardUserDefaults ]
                                     boolForKey:CSPrefDictKey_IncludePasswd ] )
         attrString = [ [ NSAttributedString alloc ] initWithString:
                           [ NSString stringWithFormat:@"%@\t%@\t%@\t%@\t",
                              nextName, acctString, passwdString, urlString ] ];
      else
         attrString = [ [ NSAttributedString alloc ] initWithString:
                           [ NSString stringWithFormat:@"%@\t%@\t%@\t",
                              nextName, acctString, urlString ] ];
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
- (BOOL) retrieveEntriesFromPasteboard:(NSPasteboard *)pboard
         undoName:(NSString *)undoName
{
   BOOL retval;
   NSArray *entryArray;
   int index;
   NSDictionary *entryDictionary;

   retval = NO;
   entryArray = [ NSUnarchiver unarchiveObjectWithData:
                                  [ pboard dataForType:CSDocumentPboardType ] ];
   if( entryArray != nil && [ entryArray count ] > 0 )
   {
      for( index = 0; index < [ entryArray count ]; index++ )
      {
         entryDictionary = [ entryArray objectAtIndex:index ];
         [ self addEntryWithName:
                   [ self _uniqueNameForName:
                             [ entryDictionary objectForKey:CSDocModelKey_Name ] ]
                   account:[ entryDictionary objectForKey:CSDocModelKey_Acct ]
                   password:[ entryDictionary objectForKey:CSDocModelKey_Passwd ]
                   URL:[ entryDictionary objectForKey:CSDocModelKey_URL ]
                   notesRTFD:[ entryDictionary objectForKey:CSDocModelKey_Notes ] ];
      }
      [ [ self undoManager ] setActionName:undoName ];
      retval = YES;
   }

   return retval;
}


/*
 * Proxy methods to the model
 */
/*
 * Number of rows/entries
 */
- (unsigned) entryCount
{
   return [ [ self _model ] entryCount ];
}


/*
 * Set the model's sort key
 */
- (void) setSortKey:(NSString *)newSortKey
{
   [ [ self _model ] setSortKey:newSortKey ];
}


/*
 * Return the model's sort key
 */
- (NSString *) sortKey
{
   return [ [ self _model ] sortKey ];
}


/*
 * Set model's sort is/isn't ascending
 */
- (void) setSortAscending:(BOOL)sortAsc
{
   [ [ self _model ] setSortAscending:sortAsc ];
}


/*
 * Is model's sort ascending?
 */
- (BOOL) isSortAscending
{
   return [ [ self _model ] isSortAscending ];
}


/*
 * Set model's sort key and ascending state
 */
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc
{
   [ [ self _model ] setSortKey:newSortKey ascending:sortAsc ];
}


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
   [ passphraseWindowController release ];
   [ docModel release ];
   [ super dealloc ];
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
   [ mainWindowController refreshWindow ];
}


/*
 * Run the passphrase sheet for the given state and note
 */
- (void) _beginPassphraseSheetForState:(int)state note:(NSString *)note
{
   getKeyState = state;
   [ [ self _passphraseWindowController ]
     getEncryptionKeyWithNote:note
     inWindow:[ mainWindowController window ]
     modalDelegate:self
     sendToSelector:@selector( _getKeyResult:) ];
}


/*
 * Callback for the passphrase controller, when run document-modally (is
 * modally a word?)
 */
- (void) _getKeyResult:(NSMutableData *)newKey
{
   NSAssert( getKeyState != CSDOCUMENT_GETKEYSTATE_NONE,
             @"getKeyState is none, but our callback has been called" );

   if( newKey != nil )
   {
      [ self _setBFKey:newKey ];
      switch( getKeyState )
      {
         case CSDOCUMENT_GETKEYSTATE_SAVE:
            [ super saveDocument:self ];
            break;

         case CSDOCUMENT_GETKEYSTATE_SAVEAS:
            [ super saveDocumentAs:self ];
            break;

         case CSDOCUMENT_GETKEYSTATE_SAVETO:
            [ super saveDocumentTo:self ];
            break;

         case CSDOCUMENT_GETKEYSTATE_CHANGE:
            [ super saveDocument:self ];
            break;
      }
   }
   getKeyState = CSDOCUMENT_GETKEYSTATE_NONE;
}


/*
 * Return (creating if necessary) passphrase window controller
 */
- (CSWinCtrlPassphrase *) _passphraseWindowController
{
   /*
    * We don't add passphraseWindowController to NSDocument' list so we
    * can keep it around, but hidden, when necessary
    */
   if( passphraseWindowController == nil )
      passphraseWindowController = [ [ CSWinCtrlPassphrase alloc ] init ];

   return passphraseWindowController;
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
