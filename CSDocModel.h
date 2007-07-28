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
/* CSDocModel.h */

#import <Foundation/Foundation.h>

/*
 * Identifiers for the table columns as well as keys for each entry;
 * Name, Acct, Passwd, URL, and Category are NSStrings, Notes is NSData
 */
extern NSString * const CSDocModelKey_Name;
extern NSString * const CSDocModelKey_Acct;
extern NSString * const CSDocModelKey_Passwd;
extern NSString * const CSDocModelKey_URL;
extern NSString * const CSDocModelKey_Category;
extern NSString * const CSDocModelKey_Notes;

// Notifications
extern NSString * const CSDocModelDidChangeSortNotification;
extern NSString * const CSDocModelDidAddEntryNotification;
extern NSString * const CSDocModelDidChangeEntryNotification;
extern NSString * const CSDocModelDidRemoveEntryNotification;

/*
 * Keys to the dictionaries contained in the userInfo of notifications
 * the _DeletedNames' value is an NSArray
 */
extern NSString * const CSDocModelNotificationInfoKey_AddedName;
extern NSString * const CSDocModelNotificationInfoKey_ChangedNameFrom;
extern NSString * const CSDocModelNotificationInfoKey_ChangedNameTo;
extern NSString * const CSDocModelNotificationInfoKey_DeletedNames;

@interface CSDocModel : NSObject
{
   NSMutableArray *allEntries;     // Of NSMutableDictionary's
   // Cache attributed strings from allEntries
   NSMutableDictionary *entryASCache;
   NSString *sortKey;
   BOOL sortAscending;
   NSUndoManager *undoManager;
}

// Initialization
- (id) init;
- (id) initWithEncryptedData:(NSData *)encryptedData bfKey:(NSData *)bfKey;

// For saving
- (NSData *) encryptedDataWithKey:(NSData *)bfKey;

// Undo manager access
- (void) setUndoManager:(NSUndoManager *)newManager;
- (NSUndoManager *) undoManager;

// Sorting
- (void) setSortKey:(NSString *)newSortKey;
- (NSString *) sortKey;
- (void) setSortAscending:(BOOL)sortAsc;
- (BOOL) isSortAscending;
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc;

// Entry access
- (int) entryCount;
- (NSString *) stringForKey:(NSString *)key atRow:(int)row;
- (NSArray *) stringArrayForEntryAtRow:(int)row;
- (NSData *) RTFDNotesAtRow:(int)row;
- (NSData *) RTFNotesAtRow:(int)row;
- (NSAttributedString *) RTFDStringNotesAtRow:(int)row;
- (NSAttributedString *) RTFStringNotesAtRow:(int)row;
- (int) rowForName:(NSString *)name;
- (BOOL) addEntryWithName:(NSString *)name
                  account:(NSString *)account
                 password:(NSString *)password
                      URL:(NSString *)url
                 category:(NSString *)category
                notesRTFD:(NSData *)notes;
- (BOOL) changeEntryWithName:(NSString *)name
                     newName:(NSString *)newName
                     account:(NSString *)account
                    password:(NSString *)password
                         URL:(NSString *)url
                    category:(NSString *)category
                   notesRTFD:(NSData *)notes;
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray;
- (BOOL) deleteEntryWithName:(NSString *)name;


// Finding elements
- (NSNumber *) firstRowBeginningWithString:(NSString *)findMe
                                ignoreCase:(BOOL)ignoreCase
                                    forKey:(NSString *)key;
- (NSArray *) rowsMatchingString:(NSString *)findMe
                      ignoreCase:(BOOL)ignoreCase
                          forKey:(NSString *)key;

@end
