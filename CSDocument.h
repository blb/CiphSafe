/* CSDocument.h */

#import <Cocoa/Cocoa.h>

@class CSDocModel;

@interface CSDocument : NSDocument 
{
   CSDocModel *docModel;
   NSMutableData *bfKey;
   NSTableColumn *previouslySelectedColumn;
   NSWindowController *mainWindowController;
   NSTextStorage *textStorage;
   NSLayoutManager *layoutManager;
   NSTextContainer *textContainer;

   IBOutlet NSTableView *documentView;
   IBOutlet NSMenu *contextualMenu;
   IBOutlet NSButton *documentDeleteButton;
   IBOutlet NSButton *documentViewButton;
}

// Actions from the main window
- (IBAction) docAddEntry:(id)sender;
- (IBAction) docViewEntry:(id)sender;
- (IBAction) docDeleteEntry:(id)sender;

// Actions from the menu
- (IBAction) docChangePassphrase:(id)sender;

// Methods to add/change/delete entries
- (NSString *) stringForKey:(NSString *)key atRow:(unsigned)row;
- (NSData *) RTFDNotesAtRow:(unsigned)row;
- (NSData *) RTFNotesAtRow:(unsigned)row;
- (NSAttributedString *) RTFDStringNotesAtRow:(unsigned)row;
- (NSAttributedString *) RTFStringNotesAtRow:(unsigned)row;
- (unsigned) rowForName:(NSString *)name;
- (BOOL) addEntryWithName:(NSString *)name account:(NSString *)account
         password:(NSString *)password URL:(NSString *)url
         notesRTFD:(NSData *)notes;
- (BOOL) changeEntryWithName:(NSString *)name newName:(NSString *)newName
         account:(NSString *)account password:(NSString *)password
         URL:(NSString *)url notesRTFD:(NSData *)notes;
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray;

@end
