/* CSWinCtrlEntry.h */

#import <Cocoa/Cocoa.h>

// Defines for localized strings
#define CSWINCTRLENTRY_LOC_ENTRYEXISTS \
        NSLocalizedString( @"Entry Already Exists", @"" )
#define CSWINCTRLENTRY_LOC_ENTRYEXISTSRENAME \
        NSLocalizedString( @"An entry with that name already exists, enter " \
                           @"another name", @"" )

@interface CSWinCtrlEntry : NSWindowController
{
   NSUndoManager *notesUM;
   NSUndoManager *otherUM;

   IBOutlet NSTextField *nameText;
   IBOutlet NSTextField *accountText;
   IBOutlet NSTextField *passwordText;
   IBOutlet NSTextField *urlText;
   IBOutlet NSTextView *notes;
   IBOutlet NSButton *mainButton;
}

// Gererate an random password
- (IBAction) doGenerate:(id)sender;

// Open the URL from the URL field
- (IBAction) doOpenURL:(id)sender;

// Our implementation of whether the data is dirty
- (void) updateDocumentEditedStatus;

/*
 * Used by updateDocumentEditedStatus to determine if data is dirty; overridden
 * in subclasses
 */
- (BOOL) nameChanged;
- (BOOL) accountChanged;
- (BOOL) passwordChanged;
- (BOOL) urlChanged;
- (BOOL) notesChanged;

@end
