/*
 * Copyright © 2003,2006-2007, Bryan L Blackburn.  All rights reserved.
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
#import "CSPrefsController.h"
#import "CSAppController.h"
#import "CSWinCtrlAdd.h"
#import "CSWinCtrlChange.h"
#import "CSWinCtrlMain.h"
#import "CSWinCtrlPassphrase.h"
#import "NSArray_FOOC.h"
#import "NSAttributedString_RWDA.h"
#import "NSData_clear.h"


NSString * const CSDocument_Name = @"CiphSafe Document";
NSString * const CSDocumentXML_RootNode = @"document";
NSString * const CSDocumentXML_EntryNode = @"entry";


@interface CSDocument (InternalMethods)
- (CSDocModel *) model;
- (void) setBFKey:(NSMutableData *)newKey;
- (NSString *) uniqueNameForName:(NSString *)name;
@end


@implementation CSDocument

#pragma mark -
#pragma mark Initialization
/*
 * Register for notifications from the model and give it an undo manager
 */
- (void) setupModel
{
   NSAssert( docModel != nil, @"docModel is nil" );
   
   [ docModel setUndoManager:[ self undoManager ] ];
   NSNotificationCenter *defaultCenter = [ NSNotificationCenter defaultCenter ];
   [ defaultCenter addObserver:self
                      selector:@selector( updateViewForNotification: )
                          name:CSDocModelDidChangeSortNotification
                        object:docModel ];
   [ defaultCenter addObserver:self
                      selector:@selector( updateViewForNotification: )
                          name:CSDocModelDidAddEntryNotification
                        object:docModel ];
   [ defaultCenter addObserver:self
                      selector:@selector( updateViewForNotification: )
                          name:CSDocModelDidChangeEntryNotification
                        object:docModel ];
   [ defaultCenter addObserver:self
                      selector:@selector( updateViewForNotification: )
                          name:CSDocModelDidRemoveEntryNotification
                        object:docModel ];
   [ mainWindowController refreshWindow ];
}


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
   mainWindowController = [ [ [ CSWinCtrlMain alloc ] init ] autorelease ];
   [ self addWindowController:mainWindowController ];
}


#pragma mark -
#pragma mark Loading and Saving
/*
 * This simply calls super's saveToFile:... as we need to pass some object
 * to NSInvocation as the target, and super won't work
 */
- (void) superSaveToFile:(NSString *)fileName
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
 * Override this to allow us to get a passphrase when needed
 */
- (void) saveToFile:(NSString *)fileName
      saveOperation:(NSSaveOperationType)saveOperation
           delegate:(id)delegate
    didSaveSelector:(SEL)didSaveSelector
        contextInfo:(void *)contextInfo
{
   /*
    * If a filename was given and we don't yet have a key, or we're doing a
    * save as
    */
   if( fileName != nil && ( bfKey == nil || ![ fileName isEqualToString:[ [ self fileURL ] path ] ] ) )
   {
      // Setup to call [ self superSaveToFile:... ] on successful passphrase request
      SEL mySelector = @selector( superSaveToFile:saveOperation:delegate:didSaveSelector:contextInfo: );
      NSMethodSignature *mySelSig = [ CSDocument instanceMethodSignatureForSelector:mySelector ];
      getKeyInvocation = [ NSInvocation invocationWithMethodSignature:mySelSig ];
      [ getKeyInvocation setTarget:self ];
      [ getKeyInvocation setSelector:mySelector ];
      [ getKeyInvocation retainArguments ];
      [ getKeyInvocation setArgument:&fileName atIndex:2 ];
      [ getKeyInvocation setArgument:&saveOperation atIndex:3 ];
      [ getKeyInvocation setArgument:&delegate atIndex:4 ];
      [ getKeyInvocation setArgument:&didSaveSelector atIndex:5 ];
      [ getKeyInvocation setArgument:&contextInfo atIndex:6 ];
      [ getKeyInvocation retain ];
      [ passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Save
                                                   inWindow:[ mainWindowController window ]
                                              modalDelegate:self
                                             sendToSelector:@selector( getKeyResult:) ];
   }
   else
      [ super saveToFile:fileName
           saveOperation:saveOperation
                delegate:delegate
         didSaveSelector:didSaveSelector
             contextInfo:contextInfo ];
}


/*
 * Override so we can make sure the document is saved with mode 0600, read/write only for owner.
 */
- (NSDictionary *) fileAttributesToWriteToURL:(NSURL *)absoluteURL
                                       ofType:(NSString *)typeName
                             forSaveOperation:(NSSaveOperationType)saveOperation
                          originalContentsURL:(NSURL *)absoluteOriginalContentsURL
                                        error:(NSError **)outError
{
   NSDictionary *attrDictionary = [ super fileAttributesToWriteToURL:absoluteURL
                                                              ofType:typeName
                                                    forSaveOperation:saveOperation
                                                 originalContentsURL:absoluteOriginalContentsURL
                                                               error:outError ];
   if( attrDictionary != nil )
   {
      NSMutableDictionary *newDictionary = [ NSMutableDictionary dictionaryWithDictionary:attrDictionary ];
      [ newDictionary setValue:[ NSNumber numberWithUnsignedLong:0600 ] forKey:NSFilePosixPermissions ];
      attrDictionary = newDictionary;
   }

   return attrDictionary;
}


/*
 * For save
 */
- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
   NSAssert( [ typeName isEqualToString:CSDocument_Name ], @"Unknown file type" );
   NSAssert( bfKey != nil, @"key is nil" );

   return [ [ self model ] encryptedDataWithKey:bfKey ];
}


/*
 * For open
 */
- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
   NSAssert( [ typeName isEqualToString:CSDocument_Name ], @"Unknown file type" );

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
         [ self setBFKey:[ passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Load
                                                              forDocumentNamed:[ self displayName ] ] ];
      if( bfKey != nil )
      {
         docModel = [ [ CSDocModel alloc ] initWithEncryptedData:data bfKey:bfKey ];
         if( docModel != nil )
            [ self setupModel ];
         else
            [ self setBFKey:nil ];
      }
      else
      {
         if( outError != NULL )
         {
            /* The error object must be set (even though this isn't a true error) or doing a cancel twice
            * will cause it to crash in the depths of NSDocumentController code
            */
            *outError = [ NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil ];
         }
         break;   // User cancelled
      }
   }

   return ( docModel != nil );
}


#pragma mark -
#pragma mark Configuration
/*
 * Accessor for the model, also creates when necessary
 */
- (CSDocModel *) model
{
   if( docModel == nil )
   {
      docModel = [ [ CSDocModel alloc ] init ];
      [ self setupModel ];
   }
   
   return docModel;
}


/*
 * Set the Blowfish key to be used
 */
- (void) setBFKey:(NSMutableData *)newKey
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


/*
 * Change the passphrase associated with the document
 */
- (IBAction) changePassphrase:(id)sender
{
   // Setup to call [ self saveDocument:self ] on successful passphrase request
   SEL mySelector = @selector( saveDocument: );
   NSMethodSignature *mySelSig = [ CSDocument instanceMethodSignatureForSelector:mySelector ];
   getKeyInvocation = [ NSInvocation invocationWithMethodSignature:mySelSig ];
   [ getKeyInvocation setTarget:self ];
   [ getKeyInvocation setSelector:mySelector ];
   [ getKeyInvocation setArgument:&self atIndex:2 ];
   [ getKeyInvocation retain ];
   [ passphraseWindowController getEncryptionKeyWithNote:CSPassphraseNote_Change
                                                inWindow:[ mainWindowController window ]
                                           modalDelegate:self
                                          sendToSelector:@selector( getKeyResult:) ];
}


/*
 * Override so we can handle timeout-specific closes; save or discard changes if those options are set then
 * fall to super's implementation.
 */
- (void) canCloseDocumentWithDelegate:(id)delegate
                  shouldCloseSelector:(SEL)shouldCloseSelector
                          contextInfo:(void *)contextInfo
{
   CSAppController *appController = (CSAppController *) [ NSApp delegate ];
   if( [ appController closeAllFromTimeout ] )
   {
      int saveOption = [ [ NSUserDefaults standardUserDefaults ]
                         integerForKey:CSPrefDictKey_CloseAfterTimeoutSaveOption ];
      if( saveOption == CSPrefCloseAfterTimeoutSaveOption_Save )
         [ self saveDocument:self ];
      else if( saveOption == CSPrefCloseAfterTimeoutSaveOption_Discard )
         [ self updateChangeCount:NSChangeCleared ];
   }
   [ super canCloseDocumentWithDelegate:delegate
                    shouldCloseSelector:shouldCloseSelector
                            contextInfo:contextInfo ]; 
}


#pragma mark -
#pragma mark Queries
/*
 * Whether or not to keep a backup file (determined by user pref)
 */
- (BOOL) keepBackupFile
{
   return [ [ NSUserDefaults standardUserDefaults ] boolForKey:CSPrefDictKey_SaveBackup ];
}


/*
 * Return just the main window controller
 */
- (CSWinCtrlMain *) mainWindowController
{
   return mainWindowController;
}


/*
 * Category information
 */
- (NSArray *) categories
{
   NSMutableArray *categories;
   if( [ [ NSUserDefaults standardUserDefaults ] boolForKey:CSPrefDictKey_IncludeDefaultCategories ] )
   {
      NSString *defaultCategoriesValuesPath = [ [ NSBundle mainBundle ] pathForResource:@"DefaultCategories" 
                                                                                 ofType:@"plist" ];
      categories = [ NSMutableArray arrayWithContentsOfFile:defaultCategoriesValuesPath ];
   }
   else
      categories = [ NSMutableArray arrayWithCapacity:10 ];
   int index;
   for( index = 0; index < [ self entryCount ]; index++ )
   {
      NSString *category = [ self stringForKey:CSDocModelKey_Category atRow:index ];
      if( category != nil && ( [ category length ] > 0 ) && ![ categories containsObject:category ] )
         [ categories addObject:category ];
   }
   
   return [ categories sortedArrayUsingSelector:@selector( caseInsensitiveCompare: ) ];
}


#pragma mark -
#pragma mark Export
/*
 * Return CSV data for the given rows, wrapped in an NSData
 */
- (NSData *) generateCSVDataForIndexes:(NSIndexSet *)indexes withHeader:(BOOL)includeHeader
{
   NSMutableData *csvData = [ NSMutableData data ];
   if( includeHeader )
      [ csvData appendData:[ [ NSString stringWithFormat:@"\"%@\",\"%@\",\"%@\",\"%@\",\"%@\",\"%@\"\n",
                                                         NSLocalizedString( CSDocModelKey_Name, @"" ),
                                                         NSLocalizedString( CSDocModelKey_Acct, @"" ),
                                                         NSLocalizedString( CSDocModelKey_Passwd, @"" ),
                                                         NSLocalizedString( CSDocModelKey_URL, @"" ),
                                                         NSLocalizedString( CSDocModelKey_Category, @"" ),
                                                         NSLocalizedString( CSDocModelKey_Notes, @"" ) ]
                             dataUsingEncoding:NSUTF8StringEncoding ] ];
   unsigned int rowIndex;
   for( rowIndex = [ indexes firstIndex ];
        rowIndex != NSNotFound;
        rowIndex = [ indexes indexGreaterThanIndex:rowIndex ] )
   {
      NSArray *entryArray = [ [ self model ] stringArrayForEntryAtRow:rowIndex ];
      NSMutableString *entryString = [ NSMutableString string ];
      NSEnumerator *arrayEnum = [ entryArray objectEnumerator ];
      id entryField;
      while( ( entryField = [ arrayEnum nextObject ] ) != nil )
      {
         NSMutableString *newString = [ NSMutableString stringWithString:entryField ];
         [ newString replaceOccurrencesOfString:@"\""
                                     withString:@"\"\""
                                        options:0
                                          range:NSMakeRange( 0, [ newString length ] ) ];
         if( [ entryString length ] > 0 )
            [ entryString appendString:@"," ];
         if( [ newString length ] > 0 )
            [ entryString appendFormat:@"\"%@\"", newString ];
      }
      [ entryString appendString:@"\n" ];
      [ csvData appendData:[ entryString dataUsingEncoding:NSUTF8StringEncoding ] ];
   }

   return csvData;
}


/*
 * Return XML data for the document, with the notes field converter to plain text when plainText is YES
 */
- (NSXMLDocument *) xmlDocumentForIndexes:(NSIndexSet *)indexes plainText:(BOOL)plainText
{
   NSXMLElement *rootElement = [ NSXMLNode elementWithName:CSDocumentXML_RootNode ];
   NSArray *keyArray = [ NSArray arrayWithObjects:CSDocModelKey_Name, CSDocModelKey_Acct,
                                                  CSDocModelKey_Passwd, CSDocModelKey_URL,
                                                  CSDocModelKey_Category, CSDocModelKey_Notes, nil ];
   unsigned int rowIndex;
   for( rowIndex = [ indexes firstIndex ];
        rowIndex != NSNotFound;
        rowIndex = [ indexes indexGreaterThanIndex:rowIndex ] )
   {
      NSXMLElement *entryElement = [ NSXMLNode elementWithName:CSDocumentXML_EntryNode ];
      NSEnumerator *keyEnumerator = [ keyArray objectEnumerator ];
      id key;
      while( ( key = [ keyEnumerator nextObject ] ) != nil )
      {
         NSXMLNode *childElement;
         if( [ key isEqualToString:CSDocModelKey_Notes ] && !plainText )
         {
            childElement = [ NSXMLNode elementWithName:key ];
            [ childElement setObjectValue:[ [ self model ] RTFDNotesAtRow:rowIndex ] ];
         }
         else
            childElement = [ NSXMLNode elementWithName:key
                                           stringValue:[ [ self model ] stringForKey:key atRow:rowIndex ] ];
         [ entryElement addChild:childElement ];
      }
      [ rootElement addChild:entryElement ];
   }
   NSXMLDocument *xmlDoc = [ [ NSXMLDocument alloc ] initWithRootElement:rootElement ];
   [ xmlDoc setVersion:@"1.0" ];
   [ xmlDoc setCharacterEncoding:@"UTF-8" ];

   return [ xmlDoc autorelease ];
}


/*
 * Return data representation of the given entries as XML
 */
- (NSData *) generateXMLDataForIndexes:(NSIndexSet *)indexes
{
   return [ [ self xmlDocumentForIndexes:indexes plainText:YES ] XMLDataWithOptions:NSXMLNodePrettyPrint ];
}


/*
 * Handle the actual export
 */
- (void) exportPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
   if( returnCode == NSOKButton )
   {
      NSIndexSet *entriesToExport;
      if( exportIsSelectedItemsOnly )
         entriesToExport = [ mainWindowController selectedRowIndexes ];
      else
         entriesToExport = [ NSIndexSet indexSetWithIndexesInRange:NSMakeRange( 0, [ self entryCount ] ) ];
      NSData *myData = nil;
      if( [ mainWindowController exportType ] == CSWinCtrlMainExportType_CSV )
         myData = [ self generateCSVDataForIndexes:entriesToExport
                                        withHeader:[ mainWindowController exportCSVHeader ] ];
      else
         myData = [ self generateXMLDataForIndexes:entriesToExport ];
      NSDictionary *fileAttr = [ NSDictionary dictionaryWithObject:[ NSNumber numberWithUnsignedLong:0600 ]
                                                            forKey:NSFilePosixPermissions ];
      [ [ NSFileManager defaultManager ] createFileAtPath:[ sheet filename ]
                                                 contents:myData
                                               attributes:fileAttr ];
   }
}


/*
 * Run the save panel for exporting
 */
- (void) startExportPanel
{
   NSSavePanel *savePanel = [ NSSavePanel savePanel ];
   [ savePanel setAccessoryView:[ mainWindowController exportAccessoryView ] ];
   [ savePanel setCanCreateDirectories:YES ];
   [ savePanel setAllowsOtherFileTypes:YES ];
   [ savePanel beginSheetForDirectory:nil
                                 file:nil
                       modalForWindow:[ self windowForSheet ]
                        modalDelegate:self
                       didEndSelector:@selector( exportPanelDidEnd:returnCode:contextInfo: )
                          contextInfo:NULL ];   
}


/*
 * Export entire document to some text-ish format
 */
- (IBAction) exportDocument:(id)sender
{
   exportIsSelectedItemsOnly = NO;
   [ self startExportPanel ];
}


/*
 * Export selected items to some text-ish format
 */
- (IBAction) exportSelectedItems:(id)sender
{
   exportIsSelectedItemsOnly = YES;
   [ self startExportPanel ];
}


#pragma mark -
#pragma mark Copy/Paste
/*
 * Copy the given rows to the given pasteboard
 *
 * XXX Since these entries are being copied to a pasteboard (for drag/drop or
 * copy/paste), there's really no point in worrying about clearing out any
 * data, since it will become accessible to the system
 */
- (BOOL) copyRows:(NSIndexSet *)rows toPasteboard:(NSPasteboard *)pboard
{
   /*
    * This generates several pasteboard types:
    *    CSDocumentPboardType - an archived NSMutableArray (docArray)
    *    NSRTFDPboardType - RTFData, as data
    *    NSRTFPboardType - RTF, as data
    *    NSTabularTextPboardType - simple string, each entry tab-delimited
    *    NSStringPboardType - same as NSTabularTextPboardType
    */
   NSMutableArray *docArray = [ NSMutableArray arrayWithCapacity:[ rows count ] ];
   NSAttributedString *attrEOL = [ [ NSAttributedString alloc ] initWithString:@"\n" ];
   NSMutableAttributedString *rtfdStringRows = [ [ NSMutableAttributedString alloc ] initWithString:@"" ];
   int row;
   for( row = [ rows firstIndex ]; row != NSNotFound; row = [ rows indexGreaterThanIndex:row ] )
   {
      NSString *nameString = [ self stringForKey:CSDocModelKey_Name atRow:row ];
      NSString *acctString = [ self stringForKey:CSDocModelKey_Acct atRow:row ];
      NSString *urlString = [ self stringForKey:CSDocModelKey_URL atRow:row ];
      NSString *categoryString = [ self stringForKey:CSDocModelKey_Category atRow:row ];
      NSString *passwdString = [ self stringForKey:CSDocModelKey_Passwd atRow:row ];
      NSData *notesData = [ self RTFDNotesAtRow:row ];
      [ docArray addObject:[ NSDictionary dictionaryWithObjectsAndKeys:
                                             nameString, CSDocModelKey_Name,
                                             acctString, CSDocModelKey_Acct,
                                             passwdString, CSDocModelKey_Passwd,
                                             urlString, CSDocModelKey_URL,
                                             categoryString, CSDocModelKey_Category,
                                             notesData, CSDocModelKey_Notes,
                                             nil ] ];
      NSAttributedString *attrString;
      if( [ [ NSUserDefaults standardUserDefaults ] boolForKey:CSPrefDictKey_IncludePasswd ] )
         attrString = [ [ NSAttributedString alloc ] initWithString:
            [ NSString stringWithFormat:@"%@\t%@\t%@\t%@\t%@\t",
                          nameString,
                          acctString,
                          passwdString,
                          urlString,
                          categoryString ] ];
      else
         attrString = [ [ NSAttributedString alloc ] initWithString:
            [ NSString stringWithFormat:@"%@\t%@\t%@\t%@\t",
                          nameString,
                          acctString,
                          urlString,
                          categoryString ] ];
      [ rtfdStringRows appendAttributedString:attrString ];
      [ attrString release ];
      [ rtfdStringRows appendAttributedString:[ self RTFDStringNotesAtRow:row ] ];
      [ rtfdStringRows appendAttributedString:attrEOL ];
   }

   [ pboard declareTypes:[ NSArray arrayWithObjects:CSDocumentPboardType,
                                      NSRTFDPboardType,
                                      NSRTFPboardType,
                                      NSTabularTextPboardType,
                                      NSStringPboardType,
                                      nil ]
                   owner:nil ];
   [ pboard setData:[ NSArchiver archivedDataWithRootObject:docArray ] forType:CSDocumentPboardType ];
   [ pboard setData:[ rtfdStringRows RTFDWithDocumentAttributes:NULL ] forType:NSRTFDPboardType ];
   [ pboard setData:[ rtfdStringRows RTFWithDocumentAttributes:NULL ] forType:NSRTFPboardType ];
   [ pboard setString:[ rtfdStringRows string ] forType:NSTabularTextPboardType ];
   [ pboard setString:[ rtfdStringRows string ] forType:NSStringPboardType ];
   [ rtfdStringRows release ];
   [ attrEOL release ];

   return YES;
}


/*
 * Grab rows from the given pasteboard
 */
- (BOOL) retrieveEntriesFromPasteboard:(NSPasteboard *)pboard
                              undoName:(NSString *)undoName
{
   BOOL retval = NO;
   NSArray *entryArray = [ NSUnarchiver unarchiveObjectWithData:[ pboard dataForType:CSDocumentPboardType ] ];
   if( entryArray != nil && [ entryArray count ] > 0 )
   {
      NSMutableArray *nameArray = [ NSMutableArray arrayWithCapacity:[ entryArray count ] ];
      NSEnumerator *entryEnumerator = [ entryArray objectEnumerator ];
      id entryDictionary;
      while( ( entryDictionary = [ entryEnumerator nextObject ] ) != nil )
      {
         NSString *uniqueName = [ self uniqueNameForName:[ entryDictionary objectForKey:CSDocModelKey_Name ] ];
         [ nameArray addObject:uniqueName ];
         [ [ self model ] addBulkEntryWithName:uniqueName
                                       account:[ entryDictionary objectForKey:CSDocModelKey_Acct ]
                                      password:[ entryDictionary objectForKey:CSDocModelKey_Passwd ]
                                           URL:[ entryDictionary objectForKey:CSDocModelKey_URL ]
                                      category:[ entryDictionary objectForKey:CSDocModelKey_Category ]
                                     notesRTFD:[ entryDictionary objectForKey:CSDocModelKey_Notes ] ];
      }
      [ [ self model ] registerAddForNamesInArray:nameArray ];
      [ [ self undoManager ] setActionName:undoName ];
      retval = YES;
   }

   return retval;
}


#pragma mark -
#pragma mark Proxied Methods to the Model
/*
 * Proxy methods to the model
 */
/*
 * Number of rows/entries
 */
- (int) entryCount
{
   return [ [ self model ] entryCount ];
}


/*
 * Set the model's sort key
 */
- (void) setSortKey:(NSString *)newSortKey
{
   [ [ self model ] setSortKey:newSortKey ];
}


/*
 * Return the model's sort key
 */
- (NSString *) sortKey
{
   return [ [ self model ] sortKey ];
}


/*
 * Set model's sort is/isn't ascending
 */
- (void) setSortAscending:(BOOL)sortAsc
{
   [ [ self model ] setSortAscending:sortAsc ];
}


/*
 * Is model's sort ascending?
 */
- (BOOL) isSortAscending
{
   return [ [ self model ] isSortAscending ];
}


/*
 * Set model's sort key and ascending state
 */
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc
{
   [ [ self model ] setSortKey:newSortKey ascending:sortAsc ];
}


/*
 * Get the string value for some key at the given row
 */
- (NSString *) stringForKey:(NSString *)key atRow:(int)row
{
   return [ [ self model ] stringForKey:key atRow:row ];
}


/*
 * Get the notes value for the given row
 */
- (NSData *) RTFDNotesAtRow:(int)row
{
   return [ [ self model ] RTFDNotesAtRow:row ];
}


/*
 * Get the notes value (RTF version) for the given row
 */
- (NSData *) RTFNotesAtRow:(int)row
{
   return [ [ self model ] RTFNotesAtRow:row ];
}


/*
 * Get the RTFD attributed string version of the notes
 */
- (NSAttributedString *) RTFDStringNotesAtRow:(int)row
{
   return [ [ self model ] RTFDStringNotesAtRow:row ];
}


/*
 * Get the RTF attributed string version of the notes
 */
- (NSAttributedString *) RTFStringNotesAtRow:(int)row
{
   return [ [ self model ] RTFStringNotesAtRow:row ];
}


/*
 * Find the row for a given name
 */
- (int) rowForName:(NSString *)name
{
   return [ [ self model ] rowForName:name ];
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
   return [ [ self model ] addEntryWithName:name
                                    account:account
                                   password:password
                                        URL:url
                                   category:category
                                  notesRTFD:notes ];
}


/*
 * Change the given entry; this does a bit more than simply proxy to the model in order to update the
 * selections in the main window so those changed remain selected.
 */
- (BOOL) changeEntryWithName:(NSString *)name
                     newName:(NSString *)newName
                     account:(NSString *)account
                    password:(NSString *)password
                         URL:(NSString *)url
                    category:(NSString *)category
                   notesRTFD:(NSData *)notes
{
   NSMutableArray *selectedNames = [ NSMutableArray arrayWithArray:[ mainWindowController getSelectedNames ] ];
   if( newName != nil && ![ name isEqualToString:newName ] )
      [ selectedNames replaceObjectAtIndex:[ selectedNames indexOfObject:name ]
                                withObject:newName ];
   BOOL changeSuccessful = [ [ self model ] changeEntryWithName:name
                                                        newName:newName
                                                        account:account
                                                       password:password
                                                            URL:url
                                                       category:category
                                                      notesRTFD:notes ];
   if( changeSuccessful )
      [ mainWindowController selectNames:selectedNames ];

   return changeSuccessful;
}


/*
 * Delete all entries with the given names
 */
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray
{
   return [ [ self model ] deleteEntriesWithNamesInArray:nameArray ];
}


/*
 * Return the row number of the first matching entry
 */
- (NSNumber *) firstRowBeginningWithString:(NSString *)findMe
                                ignoreCase:(BOOL)ignoreCase
                                    forKey:(NSString *)key
{
   return [ [ self model ] firstRowBeginningWithString:findMe
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
   return [ [ self model ] rowsMatchingString:findMe
                                   ignoreCase:ignoreCase
                                       forKey:key ];
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * Called on model notifications so we can redo the table view
 */
- (void) updateViewForNotification:(NSNotification *)notification
{
   CSWinCtrlChange *changeController;
   /*
    * Need to keep change windows synchronized on changes and remove them
    * on deletes, as undo/redo will change them outside our control
    */
   if( [ [ notification name ] isEqualToString:CSDocModelDidChangeEntryNotification ] )
   {
      NSString *oldName = [ [ notification userInfo ]
                            objectForKey:CSDocModelNotificationInfoKey_ChangedNameFrom ];
      changeController = [ CSWinCtrlChange controllerForEntryName:oldName inDocument:self ];
      if( changeController != nil )
         [ changeController setEntryName:[ [ notification userInfo ]
                                           objectForKey:CSDocModelNotificationInfoKey_ChangedNameTo ] ];
   }
   else if( [ [ notification name ] isEqualToString:CSDocModelDidRemoveEntryNotification ] )
   {
      NSArray *deletedNames = [ [ notification userInfo ]
                                objectForKey:CSDocModelNotificationInfoKey_DeletedNames ];
      NSEnumerator *nameEnumerator = [ deletedNames objectEnumerator ];
      id deletedName;
      while( ( deletedName = [ nameEnumerator nextObject ] ) != nil )
      {
         changeController = [ CSWinCtrlChange controllerForEntryName:deletedName inDocument:self ];
         if( changeController != nil )
            [ [ changeController window ] performClose:self ];
      }
   }
   
   [ mainWindowController refreshWindow ];
}


/*
 * Callback for the passphrase controller, when run document-modally; simply
 * invokes getKeyInvocation if the user didn't hit cancel 
 */
- (void) getKeyResult:(NSMutableData *)newKey
{
   NSAssert( getKeyInvocation != nil, @"getKeyInvocation is nil" );
   
   if( newKey != nil )
   {
      [ self setBFKey:newKey ];
      [ getKeyInvocation invoke ];
   }
   
   [ getKeyInvocation release ];
   getKeyInvocation = nil;
}


/*
 * Open the window to add new entries, via CSWinCtrlAdd
 */
- (void) openAddEntryWindow
{
   CSWinCtrlAdd *winController = [ [ self windowControllers ] firstObjectOfClass:[ CSWinCtrlAdd class ] ];
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
   NSEnumerator *nameEnumerator = [ namesArray objectEnumerator ];
   id oneName;
   while( ( oneName = [ nameEnumerator nextObject ] ) != nil )
   {
      CSWinCtrlChange *winController = [ CSWinCtrlChange controllerForEntryName:oneName
                                                                     inDocument:self ];
      if( winController == nil )
      {
         winController = [ [ CSWinCtrlChange alloc ] initForEntryName:oneName ];
         [ self addWindowController:winController ];
         [ winController release ];
      }
      [ winController showWindow:self ];
   }
}


/*
 * Enable certain menu items only when it makes sense
 */
- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem
{
   SEL itemAction = [ anItem action ];
   
   if( itemAction == @selector( changePassphrase: ) )
      return ( bfKey != nil );
   else if( itemAction == @selector( revertDocumentToSaved: ) )
   {
      if( [ self isDocumentEdited ] )
         return [ super validateUserInterfaceItem:anItem ];
      else
         return NO;
   }
   else if( itemAction == @selector( exportSelectedItems: ) )
      return ( [ [ [ self mainWindowController ] selectedRowIndexes ] count ] > 0 );
   else if( itemAction == @selector( exportDocument: ) )
      return ( [ self entryCount ] > 0 );
   else
      return [ super validateUserInterfaceItem:anItem ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ self setBFKey:nil ];
   [ passphraseWindowController release ];
   [ docModel release ];
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
- (NSString *) uniqueNameForName:(NSString *)name
{
   NSString *uniqueName = name;
   int index;
   for( index = 0; [ self rowForName:uniqueName ] != -1; index++ )
   {
      if( index )
         uniqueName = [ NSString stringWithFormat:NSLocalizedString( @"%@ copy %d", @"" ), name, index ];
      else
         uniqueName = [ NSString stringWithFormat:NSLocalizedString( @"%@ copy", @"" ), name ];
   }
   
   return uniqueName;
}

@end
