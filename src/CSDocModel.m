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
// Interesting security issues are noted with XXX in comments
/* CSDocModel.m */

#import "CSDocModel.h"
#import "NSAttributedString_RWDA.h"
#import "NSData_compress.h"
#import "NSData_crypto.h"

// Make identifiers in IB's config match these for easy use
NSString * const CSDocModelKey_Name = @"name";
NSString * const CSDocModelKey_Acct = @"account";
NSString * const CSDocModelKey_Passwd = @"password";
NSString * const CSDocModelKey_URL = @"url";
NSString * const CSDocModelKey_Category = @"category";
NSString * const CSDocModelKey_Notes = @"notes";

NSString * const CSDocModelDidChangeSortNotification = @"CSDocModelDidChangeSortNotification";
NSString * const CSDocModelDidAddEntryNotification = @"CSDocModelDidAddEntryNotification";
NSString * const CSDocModelDidChangeEntryNotification = @"CSDocModelDidChangeEntryNotification";
NSString * const CSDocModelDidRemoveEntryNotification = @"CSDocModelDidRemoveEntryNotification";

NSString * const CSDocModelNotificationInfoKey_AddedNames = @"CSDocModelNotificationInfoKey_AddedNames";
NSString * const CSDocModelNotificationInfoKey_ChangedNameFrom =
   @"CSDocModelNotificationInfoKey_ChangedNameFrom";
NSString * const CSDocModelNotificationInfoKey_ChangedNameTo = @"CSDocModelNotificationInfoKey_ChangedNameTo";
NSString * const CSDocModelNotificationInfoKey_DeletedNames = @"CSDocModelNotificationInfoKey_DeletedName";


// Used to sort the array
NSInteger sortEntries(id dict1, id dict2, void *context);

@interface CSDocModel (InternalMethods)
- (NSString *) nonNilStringFrom:(NSDictionary *)dict forKey:(NSString *)key;
- (NSData *) nonNilDataFrom:(NSDictionary *)dict forKey:(NSString *)key;
@end


@implementation CSDocModel

static NSArray *keyArray;

#pragma mark -
#pragma mark Initialization
+ (void) initialize
{
#if defined(DEBUG)
   [NSData setCompressLogging:YES];
   [NSData setCryptoLogging:YES];
#else
   [NSData setCompressLogging:NO];
   [NSData setCryptoLogging:NO];
#endif
   keyArray = [[NSArray alloc] initWithObjects:CSDocModelKey_Name, CSDocModelKey_Acct,
                                               CSDocModelKey_Passwd, CSDocModelKey_URL,
                                               CSDocModelKey_Category, CSDocModelKey_Notes, nil];
}


/*
 * Setup our configuration
 */
- (void) setupSelf
{
   sortKey = CSDocModelKey_Name;
   sortAscending = YES;
}


/*
 * Initialize an empty document
 */
- (id) init
{
   self = [super init];
   if(self != nil)
   {
      allEntries = [[NSMutableArray alloc] initWithCapacity:25];
      entryASCache = [[NSMutableDictionary alloc] initWithCapacity:25];
      nameRowCache = [[NSMutableDictionary alloc] initWithCapacity:25];
      [self setupSelf];
   }
   
   return self;
}


/*
 * Initialize with the given data encrypted with the given key; if the key
 * doesn't work, releases itself and returns nil
 */
- (id) initWithEncryptedData:(NSData *)encryptedData bfKey:(NSData *)bfKey
{
   if(encryptedData == nil || bfKey == nil)
   {
#if defined(DEBUG)
      NSLog(@"CSDocModel initWithEncryptedData:bfKey: nil argument: %@ %@",
            (encryptedData == nil ? @"encryptedData" : @""),
            (bfKey == nil ? @"bfKey" : @""));
#endif
      return nil;
   }
   
   self = [super init];
   if(self != nil)
   {
      allEntries = nil;
      // Separate into the IV and compressed & encrypted data
      NSData *iv = [encryptedData subdataWithRange:NSMakeRange(0, 8)];
      NSData *ceData = [encryptedData subdataWithRange:NSMakeRange(8, [encryptedData length] - 8)];
      
      NSMutableData *decryptedData = [ceData blowfishDecryptedDataWithKey:bfKey iv:iv];
      if(decryptedData != nil)
      {
         NSMutableData *uncompressedData = [decryptedData uncompressedData];
         // XXX - decryptedData can be zeroed
         if(uncompressedData != nil)
         {
            allEntries = [NSUnarchiver unarchiveObjectWithData:uncompressedData];
            // XXX - uncompressedData can be zeroed
            if(allEntries != nil)
            {
               [allEntries retain];
               entryASCache = [[NSMutableDictionary alloc] initWithCapacity:[allEntries count]];
               nameRowCache = [[NSMutableDictionary alloc] initWithCapacity:[allEntries count]];
               [self setupSelf];
               [self sortEntries];
            }
#if defined(DEBUG)
            else
               NSLog(@"CSDocModel initWithEncryptedData:bfKey: unarchiving of uncompressed data failed");
#endif
         }
#if defined(DEBUG)
         else
            NSLog(@"CSDocModel initWithEncryptedData:bfKey: uncompressing of decrypted data failed");
#endif
      }
#if defined(DEBUG)
      else
         NSLog(@"CSDocModel initWithEncryptedData:bfKey: decryption failed");
#endif
      if(allEntries == nil)
      {
         [self release];
         self = nil;
      }
   }
   
   return self;
}


#pragma mark -
#pragma mark Queries
/*
 * Return the entry for the given name, or nil if not found
 */
- (NSMutableDictionary *) findEntryWithName:(NSString *)name
{
   NSInteger row = [self rowForName:name];
   if(row != -1)
      return [allEntries objectAtIndex:row];
   else
      return nil;
}


/*
 * Get data for the model, encrypted with the given key
 */
- (NSData *) encryptedDataWithKey:(NSData *)bfKey
{
   NSData *iv = [NSData randomDataOfLength:8];
   NSData *archivedData = [NSArchiver archivedDataWithRootObject:allEntries];
   NSMutableData *compressedData = [archivedData compressedData];
   // XXX - archivedData can be zeroed
   NSData *ceData = [compressedData blowfishEncryptedDataWithKey:bfKey iv:iv];
   // XXX - compressedData can be zeroed
   NSMutableData *ivAndData = [NSMutableData dataWithCapacity:[iv length] + [ceData length]];
   [ivAndData appendData:iv];
   [ivAndData appendData:ceData];

   return ivAndData;
}


/*
 * Return total number of entries
 */
- (NSInteger) entryCount
{
   return [allEntries count];
}


/*
 * Return the value for the given key on the given row
 */
- (NSString *) stringForKey:(NSString *)key atRow:(NSInteger)row
{
   NSString *result;
   if([key isEqualToString:CSDocModelKey_Notes])
      result = [[self RTFDStringNotesAtRow:row] string];
   else
      result = [[allEntries objectAtIndex:row] objectForKey:key];
   if(result == nil)
      result = @"";
   
   return result;
}


/*
 * Return an array of strings for the entry at the given row
 */
- (NSArray *) stringArrayForEntryAtRow:(NSInteger)row
{
   NSMutableArray *stringArray = [NSMutableArray arrayWithCapacity:6];
   NSEnumerator *keyEnumerator = [keyArray objectEnumerator];
   id oneKey;
   while((oneKey = [keyEnumerator nextObject]) != nil)
      [stringArray addObject:[self stringForKey:oneKey atRow:row]];
   
   return stringArray;
}


/*
 * Return the RTFD for the notes on the given row
 */
- (NSData *) RTFDNotesAtRow:(NSInteger)row
{
   return [[allEntries objectAtIndex:row] objectForKey:CSDocModelKey_Notes];
}


/*
 * Return the RTF version for the notes on the given row
 *
 * XXX Note this returns an autoreleased NSData with possibly sensitive
 * information
 */
- (NSData *) RTFNotesAtRow:(NSInteger)row
{
   return [[self RTFDStringNotesAtRow:row] RTFWithDocumentAttributes:NULL];
}


/*
 * Return an attributed string with the RTFD notes on the given row; this
 * string is cached as it is quite popular...
 *
 * XXX Note this returns an autoreleased NSString with possibly sensitive
 * information
 */
- (NSAttributedString *) RTFDStringNotesAtRow:(NSInteger)row
{
   NSString *cacheKey = [self stringForKey:CSDocModelKey_Name atRow:row];
   NSAttributedString *rtfdString = [entryASCache objectForKey:cacheKey];
   if(rtfdString == nil)
   {
      NSData *rtfdData = [self RTFDNotesAtRow:row];
      if(rtfdData != nil)
      {
         rtfdString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:NULL];
         [entryASCache setObject:rtfdString forKey:cacheKey];
         [rtfdString release];   // entryASCache has it retained now
      }
   }
   
   return rtfdString;
}


/*
 * Return an attributed string with the RTF notes on the given row
 *
 * XXX Note this returns an autoreleased NSString with possibly sensitive
 * information
 */
- (NSAttributedString *) RTFStringNotesAtRow:(NSInteger)row
{
   return [[[NSAttributedString alloc]
            initWithRTF:[self RTFNotesAtRow:row] documentAttributes:NULL]
           autorelease];
}


/*
 * Return the row number for the given name, -1 if not found
 */
- (NSInteger) rowForName:(NSString *)name
{
   NSNumber *rowNumber = [nameRowCache objectForKey:name];
   if(rowNumber != nil)
      return [rowNumber integerValue];
   else
      return -1;
}


/*
 * Return the row number of the first matching entry
 */
- (NSNumber *) firstRowBeginningWithString:(NSString *)findString
                                ignoreCase:(BOOL)ignoreCase
                                    forKey:(NSString *)key
{
   NSRange searchRange = NSMakeRange(0, [findString length]);
   NSUInteger compareOptions = 0;
   if(ignoreCase)
      compareOptions = NSCaseInsensitiveSearch;
   NSNumber *retval = nil;
   NSInteger index;
   for(index = 0; index < [self entryCount] && retval == nil; index++)
   {
      if([[self stringForKey:key atRow:index] compare:findString
                                              options:compareOptions
                                                range:searchRange] == NSOrderedSame)
         retval = [NSNumber numberWithInteger:index];
   }
   
   return retval;
}


/*
 * Return an array (of elements supporting intValue message) of all
 * matching entries
 */
- (NSArray *) rowsMatchingString:(NSString *)findString
                      ignoreCase:(BOOL)ignoreCase
                          forKey:(NSString *)key
{
   NSMutableArray *retval = [NSMutableArray arrayWithCapacity:10];
   NSUInteger compareOptions = 0;
   if(ignoreCase)
      compareOptions = NSCaseInsensitiveSearch;
   NSInteger index;
   for(index = 0; index < [self entryCount]; index++)
   {
      NSString *stringToSearch;
      if(key == nil)
         stringToSearch = [[self stringArrayForEntryAtRow:index] componentsJoinedByString:@" "];
      else
         stringToSearch = [self stringForKey:key atRow:index];
      NSRange searchResult = [stringToSearch rangeOfString:findString options:compareOptions];
      if(searchResult.location != NSNotFound)
         [retval addObject:[NSNumber numberWithInteger:index]];
   }
   
   return retval;
}


#pragma mark -
#pragma mark Configuration
/*
 * Set the undo manager used by the model (if any)
 */
- (void) setUndoManager:(NSUndoManager *)newManager
{
   if(undoManager != newManager)
   {
      [undoManager autorelease];
      undoManager = [newManager retain];
   }
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
   [self setSortKey:newSortKey ascending:sortAscending];
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
   [self setSortKey:sortKey ascending:sortAsc];
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
   /*
    * We just set insetad of doing the usual retain/release deal here since the sort key is going
    * to be one of the CSDocModelKey_* constants
    */
   sortKey = newSortKey;
   sortAscending = sortAsc;
   [[NSNotificationCenter defaultCenter] postNotificationName:CSDocModelDidChangeSortNotification
                                                       object:self];
   [self sortEntries];
}


#pragma mark -
#pragma mark Changing the Model
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
                 category:(NSString *)category
                notesRTFD:(NSData *)notes
{
   BOOL result = [self addBulkEntryWithName:name
                                    account:account
                                   password:password
                                        URL:url
                                   category:category
                                  notesRTFD:notes];
   if(result)
   {
      if(undoManager != nil)
      {
         [undoManager registerUndoWithTarget:self selector:@selector(deleteEntryWithName:) object:name];
         if(![undoManager isUndoing] && ![undoManager isRedoing])
            [undoManager setActionName:NSLocalizedString(@"Add", @"")];
      }

      NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSArray arrayWithObject:name]
                                                           forKey:CSDocModelNotificationInfoKey_AddedNames];
      [[NSNotificationCenter defaultCenter] postNotificationName:CSDocModelDidAddEntryNotification
                                                          object:self
                                                        userInfo:userInfo];
      [self sortEntries];
   }
      
   return result;
}


/*
 * Add a new entry with the given data, skipping certain post-processing for cases when a number of
 * entries will be added at once; returns YES if all went okay, NO if an entry with that name already
 * exists.  Use registerAddForNamesInArray: to finalize the bulk add.
 */
- (BOOL) addBulkEntryWithName:(NSString *)name
                      account:(NSString *)account
                     password:(NSString *)password
                          URL:(NSString *)url
                     category:(NSString *)category
                    notesRTFD:(NSData *)notes
{
   // If it already exists, we're outta here
   if([self rowForName:name] != -1)
      return NO;
   
   [allEntries addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                                 name, CSDocModelKey_Name,
                                                 account, CSDocModelKey_Acct,
                                                 password, CSDocModelKey_Passwd,
                                                 url, CSDocModelKey_URL,
                                                 category, CSDocModelKey_Category,
                                                 notes, CSDocModelKey_Notes,
                                                 nil]];

   return YES;
}


/*
 * Register a bulk add of names, as given by nameArray, with the undo manager and notification center;
 * also resort the array
 */
- (void) registerAddForNamesInArray:(NSArray *)nameArray
{
   if(undoManager != nil)
   {
      [undoManager registerUndoWithTarget:self
                                 selector:@selector(deleteEntriesWithNamesInArray:)
                                   object:nameArray];
      if(![undoManager isUndoing] && ![undoManager isRedoing])
         [undoManager setActionName:NSLocalizedString(@"Add", @"")];
   }

   NSDictionary *userInfo = [NSDictionary dictionaryWithObject:nameArray
                                                        forKey:CSDocModelNotificationInfoKey_AddedNames];
   [[NSNotificationCenter defaultCenter] postNotificationName:CSDocModelDidAddEntryNotification
                                                       object:self
                                                     userInfo:userInfo];
   [self sortEntries];
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
                    category:(NSString *)category
                   notesRTFD:(NSData *)notes
{
   NSMutableDictionary *theEntry = [self findEntryWithName:name];
   /*
    * If theEntry is nil, we can't change it...
    * Also, if newName is not the same as name, and newName is already present,
    * we can't change
    */
   if(theEntry == nil || (![name isEqualToString:newName] && [self rowForName:newName] != -1))
      return NO;

   [entryASCache removeObjectForKey:name];
   NSString *realNewName = (newName != nil ? newName : name);
   if(undoManager != nil)
   {
      [[undoManager prepareWithInvocationTarget:self]
        changeEntryWithName:realNewName
                    newName:name
                    account:[self nonNilStringFrom:theEntry forKey:CSDocModelKey_Acct]
                   password:[self nonNilStringFrom:theEntry forKey:CSDocModelKey_Passwd]
                        URL:[self nonNilStringFrom:theEntry forKey:CSDocModelKey_URL]
                   category:[self nonNilStringFrom:theEntry forKey:CSDocModelKey_Category]
                  notesRTFD:[self nonNilDataFrom:theEntry forKey:CSDocModelKey_Notes]];
      if(![undoManager isUndoing] && ![undoManager isRedoing])
         [undoManager setActionName:NSLocalizedString(@"Change", @"")];
   }

   if(newName != nil)
      [theEntry setObject:newName forKey:CSDocModelKey_Name];
   if(account != nil)
      [theEntry setObject:account forKey:CSDocModelKey_Acct];
   if(password != nil)
      [theEntry setObject:password forKey:CSDocModelKey_Passwd];
   if(url != nil)
      [theEntry setObject:url forKey:CSDocModelKey_URL];
   if(category != nil)
      [theEntry setObject:category forKey:CSDocModelKey_Category];
   if(notes != nil)
      [theEntry setObject:notes forKey:CSDocModelKey_Notes];

   NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                             name, CSDocModelNotificationInfoKey_ChangedNameFrom,
                                             realNewName, CSDocModelNotificationInfoKey_ChangedNameTo,
                                             nil];
   [[NSNotificationCenter defaultCenter] postNotificationName:CSDocModelDidChangeEntryNotification
                                                       object:self
                                                     userInfo:userInfo];
   [self sortEntries];

   return YES;
}


/*
 * Delete all entries given by the names in the array; returns number of entries
 * actually deleted (it, obviously, can't delete entries which aren't present).
 *
 * XXX Note that the deleted entries will live on in the undo manager
 * and the names are also given to the notification center
 */
- (NSUInteger) deleteEntriesWithNamesInArray:(NSArray *)nameArray
{
   NSUInteger numDeleted = 0;

   /*
    * Build a list, do this in advance since they will be deleted soon, causing the entry array to be
    * modified during this operation
    */
   NSEnumerator *nameEnumerator = [nameArray objectEnumerator];
   id nameToDelete;
   NSMutableArray *entriesToDelete = [NSMutableArray arrayWithCapacity:[nameArray count]];
   while((nameToDelete = [nameEnumerator nextObject]) != nil)
   {
      NSMutableDictionary *theEntry = [self findEntryWithName:nameToDelete];
      if(theEntry != nil)
         [entriesToDelete addObject:theEntry];
   }

   NSEnumerator *entryEnumerator = [entriesToDelete objectEnumerator];
   id entryToDelete;
   while((entryToDelete = [entryEnumerator nextObject]) != nil)
   {
      numDeleted++;
      [entryASCache removeObjectForKey:[entryToDelete objectForKey:CSDocModelKey_Name]];
      // removeObject: is going to release it, so we hold it for a bit here
      [entryToDelete retain];
      [allEntries removeObject:entryToDelete];
      if(undoManager != nil)
      {
         id undoInvocation = [undoManager prepareWithInvocationTarget:self];
         [undoInvocation addEntryWithName:[entryToDelete objectForKey:CSDocModelKey_Name]
                                  account:[entryToDelete objectForKey:CSDocModelKey_Acct]
                                 password:[entryToDelete objectForKey:CSDocModelKey_Passwd]
                                      URL:[entryToDelete objectForKey:CSDocModelKey_URL]
                                 category:[entryToDelete objectForKey:CSDocModelKey_Category]
                                notesRTFD:[entryToDelete objectForKey:CSDocModelKey_Notes]];
         if(![undoManager isUndoing] && ![undoManager isRedoing])
            [undoManager setActionName:NSLocalizedString(@"Delete", @"")];
      }
      [entryToDelete release];
   }

   if(numDeleted > 0)
   {
      NSDictionary *userInfo = [NSDictionary dictionaryWithObject:nameArray
                                                           forKey:CSDocModelNotificationInfoKey_DeletedNames];
      [[NSNotificationCenter defaultCenter] postNotificationName:CSDocModelDidRemoveEntryNotification
                                                          object:self
                                                        userInfo:userInfo];
      [self sortEntries];
   }

   return numDeleted;
}


/*
 * Delete the entry with the given name; returns TRUE if successful, FALSE if
 * no entry with the given name
 */
- (BOOL) deleteEntryWithName:(NSString *)name
{
   return ([self deleteEntriesWithNamesInArray:[NSArray arrayWithObject:name]] > 0);
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * Force the model to perform a sort of the entries
 */
- (void) sortEntries
{
   [allEntries sortUsingFunction:sortEntries context:self];
   [nameRowCache removeAllObjects];
   NSInteger row;
   NSInteger entryCount = [self entryCount];
   for(row = 0; row < entryCount; row++)
      [nameRowCache setObject:[NSNumber numberWithInteger:row]
                       forKey:[self stringForKey:CSDocModelKey_Name atRow:row]];
}


/*
 * Return a valid string (empty, @"", if necessary)
 */
- (NSString *) nonNilStringFrom:(NSDictionary *)dict forKey:(NSString *)key
{
   NSString *result = [dict objectForKey:key];
   if(result == nil)
      result = @"";
   
   return result;
}


/*
 * Return valid data (empty if necessary)
 */
- (NSData *) nonNilDataFrom:(NSDictionary *)dict forKey:(NSString *)key
{
   NSData *result = [dict objectForKey:key];
   if(result == nil)
      result = [NSData data];
   
   return result;
}


/*
 * Cleanup
 */
- (void) dealloc
{
   /*
    * XXX At this point, we should go through all entries in allEntries, and
    * clear out each dictionary entry; however, since the entries are mostly
    * strings, and these tend to be NSCFString, ie, bridged to CFString, and
    * CFString being more difficult to look into than, say, NSData, we can't
    * clear it out.
    */
   [allEntries release];
   [entryASCache release];
   [undoManager release];
   [super dealloc];
}


/*
 * Return sort order based on proper key and ascending/descending; context
 * is the CSDocModel's self, the two ids are each an NSMutableDictionary
 * (one entry)
 */
NSInteger sortEntries(id dict1, id dict2, void *context)
{
   CSDocModel *objSelf = (CSDocModel *) context;
   NSString *sortKey = [objSelf sortKey];
   NSDictionary *dictFirst, *dictSecond;
   if([objSelf isSortAscending])
   {
      dictFirst = dict1;
      dictSecond = dict2;
   }
   else
   {
      dictFirst = dict2;
      dictSecond = dict1;
   }
   NSString *value1, *value2;
   if([sortKey isEqualToString:CSDocModelKey_Notes])
   {
      NSUInteger row = [objSelf rowForName:[dictFirst objectForKey:CSDocModelKey_Name]];
      value1 = [[objSelf RTFDStringNotesAtRow:row] string];
      row = [objSelf rowForName:[dictSecond objectForKey:CSDocModelKey_Name]];
      value2 = [[objSelf RTFDStringNotesAtRow:row] string];
   }
   else
   {
      value1 = [dictFirst objectForKey:sortKey];
      value2 = [dictSecond objectForKey:sortKey];
   }
   if(value1 == nil)
      value1 = @"";
   if(value2 == nil)
      value2 = @"";

   return [value1 caseInsensitiveCompare:value2];
}

@end
