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
// Interesting security issues are noted with XXX in comments
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
      _passphraseWindowController = [ [ CSWinCtrlPassphrase alloc ] init ];
   }

   return self;
}


/*
 * We need our own window controller...
 */
- (void) makeWindowControllers
{
   _mainWindowController = [ [ CSWinCtrlMain alloc ] init ];
   [ self addWindowController:_mainWindowController ];
   [ _mainWindowController release ];
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

   /*
    * If a filename was given and we don't yet have a key, or we're doing a
    * save as
    */
   if( fileName != nil &&
       ( _bfKey == nil || ![ fileName isEqualToString:[ self fileName ] ] ) )
   {
      // Setup to call [ self _saveToFile:... ] on successful passphrase request
      mySelector = @selector( _saveToFile:saveOperation:delegate:didSaveSelector:
                              contextInfo: );
      mySelSig = [ CSDocument instanceMethodSignatureForSelector:mySelector ];
      _getKeyInvocation = [ NSInvocation invocationWithMethodSignature:mySelSig ];
      [ _getKeyInvocation setTarget:self ];
      [ _getKeyInvocation setSelector:mySelector ];
      [ _getKeyInvocation retainArguments ];
      [ _getKeyInvocation setArgument:&fileName atIndex:2 ];
      [ _getKeyInvocation setArgument:&saveOperation atIndex:3 ];
      [ _getKeyInvocation setArgument:&delegate atIndex:4 ];
      [ _getKeyInvocation setArgument:&didSaveSelector atIndex:5 ];
      [ _getKeyInvocation setArgument:&contextInfo atIndex:6 ];
      [ _getKeyInvocation retain ];
      [ _passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Save
                                    inWindow:[ _mainWindowController window ]
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
   NSAssert( _bfKey != nil, @"key is nil" );

   return [ [ self _model ] encryptedDataWithKey:_bfKey ];
}


/*
 * For open
 */
- (BOOL) loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
   NSAssert( [ aType isEqualToString:CSDOCUMENT_NAME ], @"Unknown file type" );

   if( _docModel != nil )   // This'll happen on revert
   {
      [ CSWinCtrlChange closeOpenControllersForDocument:self ];
      [ _docModel release ];
      _docModel = nil;
   }
   
   // Loop through until we either successfully open it, or the user cancels
   while( _docModel == nil )
   {
      if( _bfKey == nil )
         [ self _setBFKey:[ _passphraseWindowController
                               getEncryptionKeyWithNote:CSPassphraseNote_Load
                               forDocumentNamed:[ self displayName ] ] ];

      if( _bfKey != nil )
      {
         _docModel = [ [ CSDocModel alloc ] initWithEncryptedData:data
                                            bfKey:_bfKey ];
         if( _docModel != nil )
            [ self _setupModel ];
         else
            [ self _setBFKey:nil ];
      }
      else
         break;   // User cancelled
   }

   return ( _docModel != nil );
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
   _getKeyInvocation = [ NSInvocation invocationWithMethodSignature:mySelSig ];
   [ _getKeyInvocation setTarget:self ];
   [ _getKeyInvocation setSelector:mySelector ];
   [ _getKeyInvocation setArgument:&self atIndex:2 ];
   [ _getKeyInvocation retain ];
   [ _passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Change
                                 inWindow:[ _mainWindowController window ]
                                 modalDelegate:self
                                 sendToSelector:@selector( _getKeyResult:) ];
}


/*
 * Return just the main window controller
 */
- (CSWinCtrlMain *) mainWindowController
{
   return _mainWindowController;
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
      retval = ( _bfKey != nil );
   else if( menuItemAction == @selector( revertDocumentToSaved: ) )
      retval = [ self isDocumentEdited ];
   else
      retval = [ super validateMenuItem:menuItem ];

   return retval;
}


/*
 * Copy the given rows to the given pasteboard (rows must be an array of
 * entry names)
 *
 * XXX Since these entries are being copied to a pasteboard (for drag/drop or
 * copy/paste), there's really no point in worrying about clearing out any
 * data, since it will become accessible to the system
 */
- (BOOL) copyNames:(NSArray *)names toPasteboard:(NSPasteboard *)pboard
{
   NSMutableArray *docArray;
   NSMutableAttributedString *rtfdStringRows;
   NSAttributedString *attrString, *attrEOL;
   NSEnumerator *nameEnumerator;
   int row;
   NSString *nextName, *acctString, *passwdString, *urlString, *categoryString;

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
      categoryString = [ self stringForKey:CSDocModelKey_Category atRow:row ];
      passwdString = [ self stringForKey:CSDocModelKey_Passwd atRow:row ];
      [ docArray addObject:[ NSDictionary dictionaryWithObjectsAndKeys:
                                             nextName,
                                                CSDocModelKey_Name,
                                             acctString,
                                                CSDocModelKey_Acct,
                                             passwdString,
                                                CSDocModelKey_Passwd,
                                             urlString,
                                                CSDocModelKey_URL,
                                             categoryString,
                                                CSDocModelKey_Category,
                                             [ self RTFDNotesAtRow:row ],
                                                CSDocModelKey_Notes,
                                             nil ] ];
      if( [ [ NSUserDefaults standardUserDefaults ]
            boolForKey:CSPrefDictKey_IncludePasswd ] )
         attrString = [ [ NSAttributedString alloc ] initWithString:
                           [ NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\t",
                              nextName, acctString, passwdString, urlString,
                              categoryString ] ];
      else
         attrString = [ [ NSAttributedString alloc ] initWithString:
                           [ NSString stringWithFormat:@"%@\t%@\t%@\t%@\t",
                              nextName, acctString, urlString, categoryString ] ];
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
                                                    NSStringPboardType,
                                                    nil ]
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
   unsigned index;
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
                category:[ entryDictionary objectForKey:CSDocModelKey_Category ]
                notesRTFD:[ entryDictionary objectForKey:CSDocModelKey_Notes ] ];
      }
      [ [ self undoManager ] setActionName:undoName ];
      retval = YES;
   }

   return retval;
}


/*
 * Category information
 */
- (NSArray *) categories
{
   NSMutableArray *categories;
   int index;
   NSString *category;

   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_IncludeDefaultCategories ] )
      categories = [ NSMutableArray arrayWithObjects:
                                       CSDocModelCategory_General,
                                       CSDocModelCategory_Banking,
                                       CSDocModelCategory_Forum,
                                       CSDocModelCategory_Retail,
                                       CSDocModelCategory_OtherWeb,
                                       nil ];
   else
      categories = [ NSMutableArray arrayWithCapacity:10 ];
   for( index = 0; index < [ self entryCount ]; index++ )
   {
      category = [ self stringForKey:CSDocModelKey_Category atRow:index ];
      if( category != nil && ( [ category length ] > 0 ) &&
          ![ categories containsObject:category ] )
         [ categories addObject:category ];
   }

   return [ categories sortedArrayUsingSelector:
                          @selector( caseInsensitiveCompare: ) ];
}


/*
 * Proxy methods to the model
 */
/*
 * Number of rows/entries
 */
- (int) entryCount
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
- (NSString *) stringForKey:(NSString *)key atRow:(int)row
{
   return [ [ self _model ] stringForKey:key atRow:row ];
}


/*
 * Get the notes value for the given row
 */
- (NSData *) RTFDNotesAtRow:(int)row
{
   return [ [ self _model ] RTFDNotesAtRow:row ];
}


/*
 * Get the notes value (RTF version) for the given row
 */
- (NSData *) RTFNotesAtRow:(int)row
{
   return [ [ self _model ] RTFNotesAtRow:row ];
}


/*
 * Get the RTFD attributed string version of the notes
 */
- (NSAttributedString *) RTFDStringNotesAtRow:(int)row
{
   return [ [ self _model ] RTFDStringNotesAtRow:row ];
}


/*
 * Get the RTF attributed string version of the notes
 */
- (NSAttributedString *) RTFStringNotesAtRow:(int)row
{
   return [ [ self _model ] RTFStringNotesAtRow:row ];
}


/*
 * Find the row for a given name
 */
- (int) rowForName:(NSString *)name
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
         category:(NSString *)category
         notesRTFD:(NSData *)notes
{
   return [ [ self _model ] addEntryWithName:name
                            account:account
                            password:password
                            URL:url
                            category:category
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
         category:(NSString *)category
         notesRTFD:(NSData *)notes
{
   return [ [ self _model ] changeEntryWithName:name
                            newName:newName
                            account:account
                            password:password
                            URL:url
                            category:category
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
 * Return the row number of the first matching entry
 */
- (NSNumber *) firstRowBeginningWithString:(NSString *)findMe
               ignoreCase:(BOOL)ignoreCase
               forKey:(NSString *)key
{
   return [ [ self _model ] firstRowBeginningWithString:findMe
                            ignoreCase:ignoreCase
                            forKey:key ];
}


/*
 * Return an array (of NSNumber) of all matching entries
 */
- (NSArray *) rowsMatchingString:(NSString *)findMe
              ignoreCase:(BOOL)ignoreCase
              forKey:(NSString *)key
{
   return [ [ self _model ] rowsMatchingString:findMe
                            ignoreCase:ignoreCase
                            forKey:key ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ self _setBFKey:nil ];
   [ _passphraseWindowController release ];
   [ _docModel release ];
   [ super dealloc ];
}


/*
 * Return a name which doesn't yet exist (eg, 'name' would result in 'name' if
 * 'name' didn't already exist, 'name copy' if it did, then 'name copy #' if
 * 'name copy', etc)
 *
 * XXX Minor security issue here, as the autoreleased strings should be cleared
 * if they aren't used, but since this should really only be called when an
 * entry is dropped or copied, it's moot
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
   if( _docModel == nil )
   {
      _docModel = [ [ CSDocModel alloc ] init ];
      [ self _setupModel ];
   }

   return _docModel;
}


/*
 * Register for notifications from the model and give it an undo manager
 */
- (void) _setupModel
{
   NSNotificationCenter *defaultCenter;

   NSAssert( _docModel != nil, @"_docModel is nil" );

   [ _docModel setUndoManager:[ self undoManager ] ];
   defaultCenter = [ NSNotificationCenter defaultCenter ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidChangeSortNotification
                   object:_docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidAddEntryNotification
                   object:_docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidChangeEntryNotification
                   object:_docModel ];
   [ defaultCenter addObserver:self
                   selector:@selector( _updateViewForNotification: )
                   name:CSDocModelDidRemoveEntryNotification
                   object:_docModel ];
   [ _mainWindowController refreshWindow ];
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

   [ _mainWindowController refreshWindow ];
}


/*
 * Callback for the passphrase controller, when run document-modally; simply
 * invokes _getKeyInvocation if the user didn't hit cancel 
 */
- (void) _getKeyResult:(NSMutableData *)newKey
{
   NSAssert( _getKeyInvocation != nil, @"_getKeyInvocation is nil" );

   if( newKey != nil )
   {
      [ self _setBFKey:newKey ];
      [ _getKeyInvocation invoke ];
   }

   [ _getKeyInvocation release ];
   _getKeyInvocation = nil;
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
   if( ![ newKey isEqual:_bfKey ] )
   {
      [ newKey retain ];
      [ _bfKey clearOutData ];
      [ _bfKey release ];
      _bfKey = newKey;
   }
}

@end
