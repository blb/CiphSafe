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

@interface CSDocument (InternalMethods)
- (NSString *) _uniqueNameForName:(NSString *)name;
- (CSDocModel *) _model;
- (void) _setupModel;
- (void) _updateViewForNotification:(NSNotification *)notification;
- (void) _getKeyResult:(NSMutableData *)newKey;
- (void) _saveToFile:(NSString *)fileName
         saveOperation:(NSSaveOperationType)saveOperation
         delegate:(id)delegate
         didSaveSelector:(SEL)didSaveSelector
         contextInfo:(void *)contextInfo;
- (void) _setBFKey:(NSMutableData *)newKey;
@end

@implementation CSDocument

- (id) init
{
   self = [ super init ];
   if( self != nil )
   {
      // Note this window controller is NOT added to NSDocument's list
      passphraseWindowController = [ [ CSWinCtrlPassphrase alloc ] init ];
   }

   return self;
}


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
 * Override this to allow us to get a passphrase when needed
 */
- (void) saveToFile:(NSString *)fileName
         saveOperation:(NSSaveOperationType)saveOperation
         delegate:(id)delegate
         didSaveSelector:(SEL)didSaveSelector
         contextInfo:(void *)contextInfo
{
   SEL mySelector;
   NSMethodSignature *mySelSig;

   // If a filename was given and we don't yet have a key, or we're doing a save as
   if( fileName != nil &&
       ( bfKey == nil || ![ fileName isEqualToString:[ self fileName ] ] ) )
   {
      // Setup to call [ self _saveToFile:... ] on successful passphrase request
      mySelector = @selector( _saveToFile:saveOperation:delegate:didSaveSelector:
                              contextInfo: );
      mySelSig = [ CSDocument instanceMethodSignatureForSelector:mySelector ];
      saveToFileInvocation = [ NSInvocation invocationWithMethodSignature:
                                               mySelSig ];
      [ saveToFileInvocation setTarget:self ];
      [ saveToFileInvocation setSelector:mySelector ];
      [ saveToFileInvocation retainArguments ];
      [ saveToFileInvocation setArgument:&fileName atIndex:2 ];
      [ saveToFileInvocation setArgument:&saveOperation atIndex:3 ];
      [ saveToFileInvocation setArgument:&delegate atIndex:4 ];
      [ saveToFileInvocation setArgument:&didSaveSelector atIndex:5 ];
      [ saveToFileInvocation setArgument:&contextInfo atIndex:6 ];
      [ saveToFileInvocation retain ];
      [ passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Save
                                   inWindow:[ mainWindowController window ]
                                   modalDelegate:self
                                   sendToSelector:@selector( _getKeyResult:) ];
   }
   else
      [ super saveToFile:fileName
              saveOperation:saveOperation
              delegate:delegate
              didSaveSelector:didSaveSelector
              contextInfo:contextInfo ];
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
   NSAssert( [ aType isEqualToString:CSDOCUMENT_NAME ], @"Unknown file type" );

   if( docModel != nil )   // This'll happen on revert
   {
      [ CSWinCtrlChange closeOpenControllersForDocument:self ];
      [ docModel release ];
      docModel = nil;
   }
   
   // Loop through until we either successfully open it, or the user cancels
   while( docModel == nil )
   {
      if( bfKey == nil )
         [ self _setBFKey:[ passphraseWindowController
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
- (IBAction) doChangePassphrase:(id)sender
{
   SEL mySelector;
   NSMethodSignature *mySelSig;

   // Setup to call [ self saveDocument:self ] on successful passphrase request
   mySelector = @selector( saveDocument: );
   mySelSig = [ CSDocument instanceMethodSignatureForSelector:mySelector ];
   saveToFileInvocation = [ NSInvocation invocationWithMethodSignature:mySelSig ];
   [ saveToFileInvocation setTarget:self ];
   [ saveToFileInvocation setSelector:mySelector ];
   [ saveToFileInvocation setArgument:&self atIndex:2 ];
   [ saveToFileInvocation retain ];
   [ passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Change
                                inWindow:[ mainWindowController window ]
                                modalDelegate:self
                                sendToSelector:@selector( _getKeyResult:) ];
}


/*
 * Enable certain menu items only when it makes sense
 */
- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
   SEL menuItemAction;
   BOOL retval;

   menuItemAction = [ menuItem action ];

   if( menuItemAction == @selector( doChangePassphrase: ) )
      retval = ( bfKey != nil );
   else if( menuItemAction == @selector( revertDocumentToSaved: ) )
      retval = [ self isDocumentEdited ];
   else
      retval = [ super validateMenuItem:menuItem ];

   return retval;
}


/*
 * Copy the given rows to the given pasteboard (rows must be an array of
 * entry names)
 */
- (BOOL) copyNames:(NSArray *)names toPasteboard:(NSPasteboard *)pboard
{
   NSMutableArray *docArray;
   NSMutableAttributedString *rtfdStringRows;
   NSAttributedString *attrString, *attrEOL;
   NSEnumerator *nameEnumerator;
   int row;
   NSString *nextName, *acctString, *passwdString, *urlString;

   /*
    * This generates several pasteboard types:
    *    CSDocumentPboardType - an archived NSMutableArray (docArray)
    *    NSRTFDPboardType - RTFData, as data
    *    NSRTFPboardType - RTF, as data
    *    NSTabularTextPboardType - simple string, each entry tab-delimited
    *    NSStringPboardType - same as NSTabularTextPboardType
    */
   docArray = [ NSMutableArray arrayWithCapacity:10 ];
   attrEOL = [ [ NSAttributedString alloc ] initWithString:@"\n" ];
   rtfdStringRows = [ [ NSMutableAttributedString alloc ] initWithString:@"" ];
   nameEnumerator = [ names objectEnumerator ];
   while( ( nextName = [ nameEnumerator nextObject ] ) != nil )
   {
      /*
       * Here we generate an array of dictionaries for the CSDocumentPboardType
       * and an attributed string to generate the RTFD/RTF/string types
       */
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
- (BOOL) addEntryWithName:(NSString *)name
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         notesRTFD:(NSData *)notes
{
   return [ [ self _model ] addEntryWithName:name
                            account:account
                            password:password
                            URL:url
                            notesRTFD:notes ];
}


/*
 * Change the given entry
 */
- (BOOL) changeEntryWithName:(NSString *)name
         newName:(NSString *)newName
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         notesRTFD:(NSData *)notes
{
   return [ [ self _model ] changeEntryWithName:name
                            newName:newName
                            account:account
                            password:password
                            URL:url
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
                   name:CSDocModelDidChangeSortNotification
                   object:docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidAddEntryNotification
                   object:docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidChangeEntryNotification
                   object:docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidRemoveEntryNotification
                   object:docModel ];
   [ mainWindowController refreshWindow ];
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
      // Get the change controller for the entry which has been changed
      changeController = [ CSWinCtrlChange controllerForEntryName:
                    [ [ notification userInfo ]
                      objectForKey:CSDocModelNotificationInfoKey_ChangedNameFrom ]
                      inDocument:self ];
      // If there is one, we tell it to update the entry it represents
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
 * Callback for the passphrase controller, when run document-modally (is
 * modally a word?); simply invokes saveToFileInvocation is the user didn't
 * hit cancel 
 */
- (void) _getKeyResult:(NSMutableData *)newKey
{
   NSAssert( saveToFileInvocation != nil, @"saveToFileInvocation is nil" );

   if( newKey != nil )
   {
      [ self _setBFKey:newKey ];
      [ saveToFileInvocation invoke ];
   }

   [ saveToFileInvocation release ];
   saveToFileInvocation = nil;
}


/*
 * This simply calls super's saveToFile:... as we need to pass some object
 * to NSInvocation as the target, and super won't work
 */
- (void) _saveToFile:(NSString *)fileName
         saveOperation:(NSSaveOperationType)saveOperation
         delegate:(id)delegate
         didSaveSelector:(SEL)didSaveSelector
         contextInfo:(void *)contextInfo
{
   [ super saveToFile:fileName
           saveOperation:saveOperation
           delegate:delegate
           didSaveSelector:didSaveSelector
           contextInfo:contextInfo ];
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
   if( ![ newKey isEqual:bfKey ] )
   {
      [ newKey retain ];
      [ bfKey clearOutData ];
      [ bfKey release ];
      bfKey = newKey;
   }
}

@end
