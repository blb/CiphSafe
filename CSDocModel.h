/* CSDocModel.h */

#import <AppKit/AppKit.h>

/*
 * Identifiers for the table columns as well as keys for each entry;
 * Name, Acct, Passwd, and URL are NSStrings, Notes is NSData
 */
extern NSString * const CSDocModelKey_Name;
extern NSString * const CSDocModelKey_Acct;
extern NSString * const CSDocModelKey_Passwd;
extern NSString * const CSDocModelKey_URL;
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
   NSMutableArray *allEntries;   // Of NSMutableDictionary's
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
- (unsigned) entryCount;
- (NSString *) stringForKey:(NSString *)key atRow:(unsigned)row;
- (NSData *) RTFDNotesAtRow:(unsigned)row;
- (NSData *) RTFNotesAtRow:(unsigned)row;
- (NSAttributedString *) RTFDStringNotesAtRow:(unsigned)row;
- (NSAttributedString *) RTFStringNotesAtRow:(unsigned)row;
- (unsigned) rowForName:(NSString *)name;
- (BOOL) addEntryWithName:(NSString *)name
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         notesRTFD:(NSData *)notes;
- (BOOL) changeEntryWithName:(NSString *)name
         newName:(NSString *)newName
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         notesRTFD:(NSData *)notes;
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray;
- (BOOL) deleteEntryWithName:(NSString *)name;

@end
