/* CSDocument.h */

#import <Cocoa/Cocoa.h>

@class CSDocModel;
@class CSWinCtrlMain;
@class CSWinCtrlPassphrase;

@interface CSDocument : NSDocument 
{
   CSDocModel *docModel;
   NSMutableData *bfKey;
   CSWinCtrlMain *mainWindowController;
   CSWinCtrlPassphrase *passphraseWindowController;
   NSInvocation *saveToFileInvocation;
}

// Actions from the menu
- (IBAction) docChangePassphrase:(id)sender;

// Creating new windows
- (void) openAddEntryWindow;
- (void) viewEntries:(NSArray *)namesArray;

// Copy/paste support (and drag/drop)
- (BOOL) copyNames:(NSArray *)names toPasteboard:(NSPasteboard *)pboard;
- (BOOL) retrieveEntriesFromPasteboard:(NSPasteboard *)pboard
         undoName:(NSString *)undoName;

// Methods to add/change/delete entries
- (unsigned) entryCount;
- (void) setSortKey:(NSString *)newSortKey;
- (NSString *) sortKey;
- (void) setSortAscending:(BOOL)sortAsc;
- (BOOL) isSortAscending;
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc;
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

@end
