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
      _allEntries = [ [ NSMutableArray alloc ] initWithCapacity:25 ];
      _entryASCache = [ [ NSMutableDictionary alloc ] initWithCapacity:25 ];
      [ self _setupSelf ];
   }

   return self;
}


/*
 * Initialize with the given data encrypted with the given key; if the key
 * doesn't work, releases itself and returns nil
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
      ceData = [ encryptedData subdataWithRange:NSMakeRange( 8,
                                                 [ encryptedData length ] - 8 ) ];

      decryptedData = [ ceData blowfishDecryptedDataWithKey:bfKey iv:iv ];
      if( decryptedData != nil )
      {
         uncompressedData = [ decryptedData uncompressedData ];
         [ decryptedData clearOutData ];
         if( uncompressedData != nil )
         {
            _allEntries = [ NSUnarchiver unarchiveObjectWithData:
                                            uncompressedData ];
            [ uncompressedData clearOutData ];
            if( _allEntries != nil )
            {
               [ _allEntries retain ];
               _entryASCache = [ [ NSMutableDictionary alloc ]
                                 initWithCapacity:[ _allEntries count ] ];
               [ self _setupSelf ];
               [ _allEntries sortUsingFunction:sortEntries context:self ];
            }
         }
      }
      if( _allEntries == nil )
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
   archivedData = [ NSArchiver archivedDataWithRootObject:_allEntries ];
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
   [ _undoManager release ];
   _undoManager = newManager;
}


/*
 * Retrieve the current undo manager
 */
- (NSUndoManager *) undoManager
{
   return _undoManager;
}


/*
 * Set by which key to sort (one of the CSDocDictKey_* strings)
 */
- (void) setSortKey:(NSString *)newSortKey
{
   [ self setSortKey:newSortKey ascending:_sortAscending ];
}


/*
 * Return the current sort key
 */
- (NSString *) sortKey
{
   return _sortKey;
}


/*
 * Set if the sort is ascending or descending
 */
- (void) setSortAscending:(BOOL)sortAsc
{
   [ self setSortKey:_sortKey ascending:sortAsc ];
}


/*
 * Return whether sort is ascending
 */
- (BOOL) isSortAscending
{
   return _sortAscending;
}


/*
 * Set both sort key and ascending/descending
 */
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc
{
   _sortKey = newSortKey;
   _sortAscending = sortAsc;
   [ _allEntries sortUsingFunction:sortEntries context:self ];
   [ [ NSNotificationCenter defaultCenter ]
     postNotificationName:CSDocModelDidChangeSortNotification
     object:self ];
}


/*
 * Return total number of entries
 */
- (int) entryCount
{
   return [ _allEntries count ];
}


/*
 * Return the value for the given key on the given row
 */
- (NSString *) stringForKey:(NSString *)key atRow:(int)row
{
   return [ [ _allEntries objectAtIndex:row ] objectForKey:key ];
}


/*
 * Return the RTFD for the notes on the given row
 */
- (NSData *) RTFDNotesAtRow:(int)row
{
   return [ [ _allEntries objectAtIndex:row ] objectForKey:CSDocModelKey_Notes ];
}


/*
 * Return the RTF version for the notes on the given row
 *
 * XXX Note this returns an autoreleased NSData with possibly sensitive
 * information
 */
- (NSData *) RTFNotesAtRow:(int)row
{
   return [ [ self RTFDStringNotesAtRow:row ] RTFWithDocumentAttributes:NULL ];
}


/*
 * Return an attributed string with the RTFD notes on the given row; this
 * string is cached as it is quite popular...
 *
 * XXX Note this returns an autoreleased NSString with possibly sensitive
 * information
 */
- (NSAttributedString *) RTFDStringNotesAtRow:(int)row
{
   NSAttributedString *rtfdString;

   rtfdString = [ _entryASCache objectForKey:
                             [ self stringForKey:CSDocModelKey_Name atRow:row ] ];
   if( rtfdString == nil )
   {
      rtfdString = [ [ NSAttributedString alloc ]
                       initWithRTFD:[ self RTFDNotesAtRow:row ]
                     documentAttributes:NULL ];
      [ _entryASCache setObject:rtfdString
                      forKey:[ self stringForKey:CSDocModelKey_Name atRow:row ] ];
      [ rtfdString release ];
   }

   return rtfdString;
}


/*
 * Return an attributed string with the RTF notes on the given row
 *
 * XXX Note this returns an autoreleased NSString with possibly sensitive
 * information
 */
- (NSAttributedString *) RTFStringNotesAtRow:(int)row
{
   return [ [ [ NSAttributedString alloc ]
              initWithRTF:[ self RTFNotesAtRow:row ] documentAttributes:NULL ]
            autorelease ];
}


/*
 * Return the row number for the given name, -1 if not found
 */
- (int) rowForName:(NSString *)name
{
   int index;
   int rowNum;

   rowNum = -1;
   for( index = 0; index < [ _allEntries count ] && rowNum == -1; index++ )
   {
      if( [ [ [ _allEntries objectAtIndex:index ]
              objectForKey:CSDocModelKey_Name ]
            isEqualToString:name ] )
         rowNum = index;
   }

   return rowNum;
}


/*
 * Add a new entry with the given data; returns YES if all went okay, NO if
 * an entry with that name already exists.
 *
 * XXX Note that the name of the added entry will live on in the undo manager
 * and is also given to the notification center
 */
- (BOOL) addEntryWithName:(NSString *)name
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         notesRTFD:(NSData *)notes
{
   // If it already exists, we're outta here
   if( [ self rowForName:name ] != -1 )
      return NO;

   [ _allEntries addObject:[ NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                    name,
                                                       CSDocModelKey_Name,
                                                    account,
                                                       CSDocModelKey_Acct,
                                                    password,
                                                       CSDocModelKey_Passwd,
                                                    url,
                                                       CSDocModelKey_URL,
                                                    notes,
                                                       CSDocModelKey_Notes,
                                                    nil ] ];
   if( _undoManager != nil )
   {
      [ _undoManager registerUndoWithTarget:self
                     selector:@selector( deleteEntryWithName: )
                     object:name ];
      if( ![ _undoManager isUndoing ] && ![ _undoManager isRedoing ] )
         [ _undoManager setActionName:CSDOCMODEL_LOC_ADD ];
   }

   [ _allEntries sortUsingFunction:sortEntries context:self ];
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
 * XXX Note that the changed entry will live on in the undo manager
 * and both the old and new names are given to the notification center
 */
- (BOOL) changeEntryWithName:(NSString *)name
         newName:(NSString *)newName
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         notesRTFD:(NSData *)notes
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
       ( ![ name isEqualToString:newName ] &&
         [ self rowForName:newName ] != -1 ) )
      return NO;

   [ _entryASCache removeObjectForKey:name ];
   realNewName = ( newName != nil ? newName : name );
   if( _undoManager != nil )
   {
      [ [ _undoManager prepareWithInvocationTarget:self ]
        changeEntryWithName:realNewName
        newName:name
        account:[ theEntry objectForKey:CSDocModelKey_Acct ]
        password:[ theEntry objectForKey:CSDocModelKey_Passwd ]
        URL:[ theEntry objectForKey:CSDocModelKey_URL ]
        notesRTFD:[ theEntry objectForKey:CSDocModelKey_Notes ] ];
      if( ![ _undoManager isUndoing ] && ![ _undoManager isRedoing ] )
         [ _undoManager setActionName:CSDOCMODEL_LOC_CHANGE ];
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

   [ _allEntries sortUsingFunction:sortEntries context:self ];
   [ [ NSNotificationCenter defaultCenter ]
     postNotificationName:CSDocModelDidChangeEntryNotification
     object:self
     userInfo:[ NSDictionary dictionaryWithObjectsAndKeys:
                                name,
                                   CSDocModelNotificationInfoKey_ChangedNameFrom,
                                realNewName,
                                   CSDocModelNotificationInfoKey_ChangedNameTo,
                                nil ] ];

   return YES;
}


/*
 * Delete all entries given by the names in the array; returns number of entries
 * actually deleted (it, obviously, can't delete entries which aren't present).
 *
 * XXX Note that the deleted entries will live on in the undo manager
 * and the names are also given to the notification center
 */
- (int) deleteEntriesWithNamesInArray:(NSArray *)nameArray
{
   int index, numDeleted;
   NSMutableDictionary *theEntry;

   for( index = numDeleted = 0; index < [ nameArray count ]; index++ )
   {
      theEntry = [ self _findEntryWithName:[ nameArray objectAtIndex:index ] ];
      if( theEntry != nil )
      {
         numDeleted++;
         [ _entryASCache removeObjectForKey:[ nameArray objectAtIndex:index ] ];
         [ theEntry retain ];   // Hold for the undo manager
         [ _allEntries removeObject:theEntry ];
         if( _undoManager != nil )
         {
            [ [ _undoManager prepareWithInvocationTarget:self ]
              addEntryWithName:[ theEntry objectForKey:CSDocModelKey_Name ]
              account:[ theEntry objectForKey:CSDocModelKey_Acct ]
              password:[ theEntry objectForKey:CSDocModelKey_Passwd ]
              URL:[ theEntry objectForKey:CSDocModelKey_URL ]
              notesRTFD:[ theEntry objectForKey:CSDocModelKey_Notes ] ];
            if( ![ _undoManager isUndoing ] && ![ _undoManager isRedoing ] )
               [ _undoManager setActionName:CSDOCMODEL_LOC_DELETE ];
         }
         [ theEntry release ];   // Undo manager now has it
      }
   }

   if( numDeleted > 0 )
   {
      [ _allEntries sortUsingFunction:sortEntries context:self ];
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
 * Return the row number of the first matching entry
 */
- (NSNumber *) firstRowBeginningWithString:(NSString *)findMe
               ignoreCase:(BOOL)ignoreCase
               forKey:(NSString *)key
{
   unsigned compareOptions;
   NSNumber *retval;
   NSRange searchRange;
   int index;

   compareOptions = 0;
   retval = nil;
   searchRange = NSMakeRange( 0, [ findMe length ] );
   if( ignoreCase )
      compareOptions = NSCaseInsensitiveSearch;
   for( index = 0; index < [ _allEntries count ] && retval == nil; index++ )
   {
      if( [ [ [ _allEntries objectAtIndex:index ] objectForKey:key ]
            compare:findMe options:compareOptions range:searchRange ]
          == NSOrderedSame )
         retval = [ NSNumber numberWithInt:index ];
   }

   return retval;
}


/*
 * Return an array (of elements supporting intValue message) of all
 * matching entries
 */
- (NSArray *) rowsMatchingString:(NSString *)findMe
              ignoreCase:(BOOL)ignoreCase
              forKey:(NSString *)key
{
   unsigned compareOptions;
   NSMutableArray *retval;
   int index;
   NSString *stringToSearch;
   NSRange searchResult;

   compareOptions = 0;
   retval = [ NSMutableArray arrayWithCapacity:10 ];
   if( ignoreCase )
      compareOptions = NSCaseInsensitiveSearch;
   for( index = 0; index < [ _allEntries count ]; index++ )
   {
      if( [ key isEqualToString:CSDocModelKey_Notes ] )
         stringToSearch = [ [ self RTFDStringNotesAtRow:index ] string ];
      else
         stringToSearch = [ [ _allEntries objectAtIndex:index ]
                            objectForKey:key ];
      searchResult = [ stringToSearch rangeOfString:findMe
                                      options:compareOptions ];
      if( searchResult.location != NSNotFound )
         [ retval addObject:[ NSNumber numberWithInt:index ] ];

   }

   return retval;
}


/*
 * Cleanup
 */
- (void) dealloc
{
   /*
    * XXX At this point, we should go through all entries in _allEntries, and
    * clear out each dictionary entry; however, since the entries are mostly
    * strings, and these tend to be NSCFString, ie, bridged to CFString, and
    * CFString being more difficult to look into than, say, NSData, we can't
    * clear it out.
    */
   [ _allEntries release ];
   [ _entryASCache release ];
   [ _undoManager release ];
   [ super dealloc ];
}


/*
 * Return the entry for the given name, or nil if not found
 */
- (NSMutableDictionary *) _findEntryWithName:(NSString *)name
{
   NSEnumerator *enumerator;
   NSMutableDictionary *anEntry;

   enumerator = [ _allEntries objectEnumerator ];
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
   _sortKey = CSDocModelKey_Name;
   _sortAscending = YES;
#if !defined(DEBUG)
   [ NSData setCompressLogging:NO ];
   [ NSData setCryptoLogging:NO ];
#endif
}


/*
 * Return sort order based on proper key and ascending/descending; context
 * is the CSDocModel's self, the two ids are each an NSMutableDictionary
 * (one entry)
 */
int sortEntries( id dict1, id dict2, void *context )
{
   CSDocModel *objSelf;
   NSString *sortKey;
   NSDictionary *dictFirst, *dictSecond;
   NSString *value1, *value2;

   objSelf = (CSDocModel *) context;
   sortKey = [ objSelf sortKey ];
   if( [ objSelf isSortAscending ] )
   {
      dictFirst = dict1;
      dictSecond = dict2;
   }
   else
   {
      dictFirst = dict2;
      dictSecond = dict1;
   }
   if( [ sortKey isEqualToString:CSDocModelKey_Notes ] )
   {
      value1 = [ [ objSelf RTFDStringNotesAtRow:
                              [ objSelf rowForName:
                                           [ dictFirst objectForKey:
                                                          CSDocModelKey_Name ] ] ]
                 string ];
      value2 = [ [ objSelf RTFDStringNotesAtRow:
                              [ objSelf rowForName:
                                           [ dictSecond objectForKey:
                                                          CSDocModelKey_Name ] ] ]
                 string ];
   }
   else
   {
      value1 = [ dictFirst objectForKey:sortKey ];
      value2 = [ dictSecond objectForKey:sortKey ];
   }
      
   return [ value1 caseInsensitiveCompare:value2 ];
}

@end
