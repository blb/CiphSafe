// Interesting security issues are noted with XXX in comments
/* CSDocModel.m */

#import "CSDocModel.h"
#import "NSAttributedString_RWDA.h"
#import "NSData_compress.h"
#import "NSData_crypto.h"
#import "NSData_clear.h"

// Make identifiers in IB's config match these for easy use
NSString * const CSDocModelKey_Name = @"name";
NSString * const CSDocModelKey_Acct = @"account";
NSString * const CSDocModelKey_Passwd = @"password";
NSString * const CSDocModelKey_URL = @"url";
NSString * const CSDocModelKey_Notes = @"notes";

NSString * const CSDocModelDidChangeSortNotification =
   @"CSDocModelDidChangeSortNotification";
NSString * const CSDocModelDidAddEntryNotification = 
   @"CSDocModelDidAddEntryNotification";
NSString * const CSDocModelDidChangeEntryNotification =
   @"CSDocModelDidChangeEntryNotification";
NSString * const CSDocModelDidRemoveEntryNotification =
   @"CSDocModelDidRemoveEntryNotification";

NSString * const CSDocModelNotificationInfoKey_AddedName =
   @"CSDocModelNotificationInfoKey_AddedName";
NSString * const CSDocModelNotificationInfoKey_ChangedNameFrom =
   @"CSDocModelNotificationInfoKey_ChangedNameFrom";
NSString * const CSDocModelNotificationInfoKey_ChangedNameTo =
   @"CSDocModelNotificationInfoKey_ChangedNameTo";
NSString * const CSDocModelNotificationInfoKey_DeletedNames =
   @"CSDocModelNotificationInfoKey_DeletedName";

#define CSDOCMODEL_LOC_ADD NSLocalizedString( @"Add", @"" )
#define CSDOCMODEL_LOC_CHANGE NSLocalizedString( @"Change", @"" )
#define CSDOCMODEL_LOC_DELETE NSLocalizedString( @"Delete", @"" )

// Used to sort the array
int sortEntries( id dict1, id dict2, void *context );

@interface CSDocModel (InternalMethods)
- (NSMutableDictionary *) _findEntryWithName:(NSString *)name;
- (void) _setupSelf;
@end

@implementation CSDocModel

/*
 * Initialize an empty document
 */
- (id) init
{
   if( ( self = [ super init ] ) )
   {
      allEntries = [ [ NSMutableArray alloc ] initWithCapacity:25 ];
      [ self _setupSelf ];
   }

   return self;
}


/*
 * Initialize with the given data encrypted with the given key; if the key
 * doens't work, releases itself and returns nil
 */
- (id) initWithEncryptedData:(NSData *)encryptedData bfKey:(NSData *)bfKey
{
   NSData *iv, *ceData;
   NSMutableData *decryptedData, *uncompressedData;

   if( encryptedData == nil || bfKey == nil )
      return nil;

   self = [ super init ];
   if( self != nil )
   {
      // Separate into the IV and compressed & encrypted data
      iv = [ encryptedData subdataWithRange:NSMakeRange( 0, 8 ) ];
      ceData = [ encryptedData subdataWithRange:
                                  NSMakeRange( 8, [ encryptedData length ] - 8 ) ];

      decryptedData = [ ceData blowfishDecryptedDataWithKey:bfKey iv:iv ];
      if( decryptedData != nil )
      {
         uncompressedData = [ decryptedData uncompressedData ];
         [ decryptedData clearOutData ];
         if( uncompressedData != nil )
         {
            allEntries = [ NSUnarchiver unarchiveObjectWithData:uncompressedData ];
            [ uncompressedData clearOutData ];
            if( allEntries != nil )
            {
               [ allEntries retain ];
               [ self _setupSelf ];
               [ allEntries sortUsingFunction:sortEntries context:self ];
            }
         }
      }
      if( allEntries == nil )
      {
         [ self release ];
         self = nil;
      }
   }

   return self;
}


/*
 * Get data for the model, encrypted with the given key
 */
- (NSData *) encryptedDataWithKey:(NSData *)bfKey
{
   NSData *iv, *archivedData, *ceData;
   NSMutableData *compressedData, *ivAndData;

   iv = [ NSData randomDataOfLength:8 ];
   archivedData = [ NSArchiver archivedDataWithRootObject:allEntries ];
   compressedData = [ archivedData compressedData ];
   [ archivedData clearOutData ];
   ceData = [ compressedData blowfishEncryptedDataWithKey:bfKey iv:iv ];
   [ compressedData clearOutData ];
   ivAndData = [ NSMutableData dataWithCapacity:[ iv length ] +
                                                [ ceData length ] ];
   [ ivAndData appendData:iv ];
   [ ivAndData appendData:ceData ];

   return ivAndData;
}


/*
 * Set the undo manager used by the model (if any)
 */
- (void) setUndoManager:(NSUndoManager *)newManager
{
   [ newManager retain ];
   [ undoManager release ];
   undoManager = newManager;
}


/*
 * Retrieve the current undo manager
 */
- (NSUndoManager *) undoManager
{
   return undoManager;
}


/*
 * Set by which key to sort (one of the CSDocDictKey_* strings)
 */
- (void) setSortKey:(NSString *)newSortKey
{
   [ self setSortKey:newSortKey ascending:sortAscending ];
}


/*
 * Return the current sort key
 */
- (NSString *) sortKey
{
   return sortKey;
}


/*
 * Set if the sort is ascending or descending
 */
- (void) setSortAscending:(BOOL)sortAsc
{
   [ self setSortKey:sortKey ascending:sortAsc ];
}


/*
 * Return whether sort is ascending
 */
- (BOOL) isSortAscending
{
   return sortAscending;
}


/*
 * Set both sort key and ascending/descending
 */
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc
{
   sortKey = newSortKey;
   sortAscending = sortAsc;
   [ allEntries sortUsingFunction:sortEntries context:self ];
   [ [ NSNotificationCenter defaultCenter ]
     postNotificationName:CSDocModelDidChangeSortNotification
     object:self ];
}


/*
 * Return total number of entries
 */
- (unsigned) entryCount
{
   return [ allEntries count ];
}


/*
 * Return the value for the given key on the given row
 */
- (NSString *) stringForKey:(NSString *)key atRow:(unsigned)row
{
   return [ [ allEntries objectAtIndex:row ] objectForKey:key ];
}


/*
 * Return the RTFD for the notes on the given row
 */
- (NSData *) RTFDNotesAtRow:(unsigned)row
{
   return [ [ allEntries objectAtIndex:row ] objectForKey:CSDocModelKey_Notes ];
}


/*
 * Return the RTF version for the notes on the given row
 */
- (NSData *) RTFNotesAtRow:(unsigned)row
{
   return [ [ self RTFDStringNotesAtRow:row ] RTFWithDocumentAttributes:NULL ];
}


/*
 * Return an attributed string with the RTFD notes on the given row
 */
- (NSAttributedString *) RTFDStringNotesAtRow:(unsigned)row
{
   return [ [ [ NSAttributedString alloc ] initWithRTFD:[ self RTFDNotesAtRow:row ]
                                           documentAttributes:NULL ]
            autorelease ];
}


/*
 * Return an attributed string with the RTF notes on the given row
 */
- (NSAttributedString *) RTFStringNotesAtRow:(unsigned)row
{
   return [ [ [ NSAttributedString alloc ] initWithRTF:[ self RTFNotesAtRow:row ]
                                           documentAttributes:NULL ]
            autorelease ];
}


/*
 * Return the row number for the given name, -1 if not found
 */
- (unsigned) rowForName:(NSString *)name
{
   unsigned index;
   unsigned rowNum;

   rowNum = -1;
   for( index = 0; index < [ allEntries count ] && rowNum == -1; index++ )
   {
      if( [ [ [ allEntries objectAtIndex:index ] objectForKey:CSDocModelKey_Name ]
            isEqualToString:name ] )
         rowNum = index;
   }

   return rowNum;
}


/*
 * Add a new entry with the given data; returns YES if all went okay, NO if
 * an entry with that name already exists.
 */
- (BOOL) addEntryWithName:(NSString *)name account:(NSString *)account
         password:(NSString *)password URL:(NSString *)url
         notesRTFD:(NSData *)notes
{
   // If it already exists, we're outta here
   if( [ self rowForName:name ] != -1 )
      return NO;

   [ allEntries addObject:[ NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                   name, CSDocModelKey_Name,
                                                   account, CSDocModelKey_Acct,
                                                   password, CSDocModelKey_Passwd,
                                                   url, CSDocModelKey_URL,
                                                   notes, CSDocModelKey_Notes,
                                                   nil ] ];
   if( undoManager != nil )
   {
      [ undoManager registerUndoWithTarget:self
                    selector:@selector( deleteEntryWithName: )
                    object:name ];
      if( ![ undoManager isUndoing ] && ![ undoManager isRedoing ] )
         [ undoManager setActionName:CSDOCMODEL_LOC_ADD ];
   }

   [ allEntries sortUsingFunction:sortEntries context:self ];
   [ [ NSNotificationCenter defaultCenter ]
      postNotificationName:CSDocModelDidAddEntryNotification
      object:self
      userInfo:[ NSDictionary dictionaryWithObject:name
                              forKey:CSDocModelNotificationInfoKey_AddedName ] ];

   return YES;
}


/*
 * Change the entry with the given name with the new values; skips any nil values
 * (use an empty string to clear something out); returns YES if successful, NO
 * if an entry with newName already exists or an entry with the given name
 * doesn't exist
 *
 * XXX One security issue here is we cannot clear out the old data, as it needs to
 * go into the undo manager
 */
- (BOOL) changeEntryWithName:(NSString *)name newName:(NSString *)newName
         account:(NSString *)account password:(NSString *)password
         URL:(NSString *)url notesRTFD:(NSData *)notes
{
   NSMutableDictionary *theEntry;
   NSString *realNewName;   // This will be the name of the end result

   theEntry = [ self _findEntryWithName:name ];
   /*
    * If theEntry is nil, we can't change it...
    * Also, if newName is not the same as name, and newName is already present,
    * we can't change
    */
   if( theEntry == nil ||
       ( ![ name isEqualToString:newName ] && [ self rowForName:newName ] != -1 ) )
      return NO;

   realNewName = ( newName != nil ? newName : name );
   if( undoManager != nil )
   {
      [ [ undoManager prepareWithInvocationTarget:self ]
        changeEntryWithName:realNewName
        newName:name
        account:[ theEntry objectForKey:CSDocModelKey_Acct ]
        password:[ theEntry objectForKey:CSDocModelKey_Passwd ]
        URL:[ theEntry objectForKey:CSDocModelKey_URL ]
        notesRTFD:[ theEntry objectForKey:CSDocModelKey_Notes ] ];
      if( ![ undoManager isUndoing ] && ![ undoManager isRedoing ] )
         [ undoManager setActionName:CSDOCMODEL_LOC_CHANGE ];
   }

   if( newName != nil )
      [ theEntry setObject:newName forKey:CSDocModelKey_Name ];
   if( account != nil )
      [ theEntry setObject:account forKey:CSDocModelKey_Acct ];
   if( password != nil )
      [ theEntry setObject:password forKey:CSDocModelKey_Passwd ];
   if( url != nil )
      [ theEntry setObject:url forKey:CSDocModelKey_URL ];
   if( notes != nil )
      [ theEntry setObject:notes forKey:CSDocModelKey_Notes ];

   [ allEntries sortUsingFunction:sortEntries context:self ];
   [ [ NSNotificationCenter defaultCenter ]
     postNotificationName:CSDocModelDidChangeEntryNotification
     object:self
     userInfo:[ NSDictionary dictionaryWithObjectsAndKeys:
                          name, CSDocModelNotificationInfoKey_ChangedNameFrom,
                          realNewName, CSDocModelNotificationInfoKey_ChangedNameTo,
                          nil ] ];

   return YES;
}


/*
 * Delete all entries given by the names in the array; returns number of entries
 * actually deleted (it, obviously, can't delete entries which aren't present).
 *
 * XXX One security issue here is we cannot clear out the data prior to deletion,
 * as it needs to go into the undo manager, as well as the names going into the
 * notification
 */
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray
{
   unsigned index, numDeleted;
   NSMutableDictionary *theEntry;

   for( index = numDeleted = 0; index < [ nameArray count ]; index++ )
   {
      theEntry = [ self _findEntryWithName:[ nameArray objectAtIndex:index ] ];
      if( theEntry != nil )
      {
         numDeleted++;
         [ theEntry retain ];   // Hold for the undo manager
         [ allEntries removeObject:theEntry ];
         if( undoManager != nil )
         {
            [ [ undoManager prepareWithInvocationTarget:self ]
              addEntryWithName:[ theEntry objectForKey:CSDocModelKey_Name ]
              account:[ theEntry objectForKey:CSDocModelKey_Acct ]
              password:[ theEntry objectForKey:CSDocModelKey_Passwd ]
              URL:[ theEntry objectForKey:CSDocModelKey_URL ]
              notesRTFD:[ theEntry objectForKey:CSDocModelKey_Notes ] ];
            if( ![ undoManager isUndoing ] && ![ undoManager isRedoing ] )
               [ undoManager setActionName:CSDOCMODEL_LOC_DELETE ];
         }
         [ theEntry release ];   // Undo manager now has it
      }
   }

   if( numDeleted > 0 )
   {
      [ allEntries sortUsingFunction:sortEntries context:self ];
      [ [ NSNotificationCenter defaultCenter ]
        postNotificationName:CSDocModelDidRemoveEntryNotification
        object:self
        userInfo:[ NSDictionary dictionaryWithObject:nameArray
                             forKey:CSDocModelNotificationInfoKey_DeletedNames ] ];
   }

   return numDeleted;
}


/*
 * Delete the entry with the given name; returns TRUE if successful, FALSE if
 * no entry with the given name
 */
- (BOOL) deleteEntryWithName:(NSString *)name
{
   return [ self deleteEntriesWithNamesInArray:[ NSArray arrayWithObject:name ] ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   // XXX Should clean allEntries
   [ allEntries release ];
   [ undoManager release ];
   [ super dealloc ];
}


/*
 * Return the entry for the given name, or nil if not found
 */
- (NSMutableDictionary *) _findEntryWithName:(NSString *)name
{
   NSEnumerator *enumerator;
   NSMutableDictionary *anEntry;

   enumerator = [ allEntries objectEnumerator ];
   while( ( ( anEntry = [ enumerator nextObject ] ) != nil ) &&
          ![ [ anEntry objectForKey:CSDocModelKey_Name ] isEqualToString:name ] )
      ;   // Just loop through...

   return anEntry;
}


/*
 * Setup our configuration
 */
- (void) _setupSelf
{
   sortKey = CSDocModelKey_Name;
   sortAscending = YES;
#if !defined(DEBUG)
   [ NSData setCompressLogging:NO ];
   [ NSData setCryptoLogging:NO ];
#endif
}


/*
 * Return sort order based on proper key and ascending/descending; context
 * is the CSDocModel's self
 */
int sortEntries( id dict1, id dict2, void *context )
{
   CSDocModel *objSelf;
   NSString *value1, *value2;

   objSelf = (CSDocModel *) context;
   if( [ objSelf isSortAscending ] )
   {
      value1 = [ dict1 objectForKey:[ objSelf sortKey ] ];
      value2 = [ dict2 objectForKey:[ objSelf sortKey ] ];
   }
   else
   {
      value1 = [ dict2 objectForKey:[ objSelf sortKey ] ];
      value2 = [ dict1 objectForKey:[ objSelf sortKey ] ];
   }

   return [ value1 compare:value2 ];
}

@end
