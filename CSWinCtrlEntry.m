/* CSWinCtrlEntry.m */

#import "CSWinCtrlEntry.h"
#import "CSDocument.h"
#import "CSAppController.h"
#import "NSData_crypto.h"
#import "NSData_clear.h"

// Defines for localized strings
#define CSWINCTRLENTRY_LOC_INVALIDURL NSLocalizedString( @"Invalid URL", @"" )
#define CSWINCTRLENTRY_LOC_URLNOTVALID \
        NSLocalizedString( @"The URL entered is not a valid URL", @"" )
#define CSWINCTRLENTRY_LOC_NOTSAVED NSLocalizedString( @"Entry Not Saved", @"" )
#define CSWINCTRLENTRY_LOC_NOTSAVEDCLOSE \
        NSLocalizedString( @"The entry has not been saved, close anyway?", @"" )
#define CSWINCTRLENTRY_LOC_CLOSEANYWAY NSLocalizedString( @"Close Anyway", @"" )
#define CSWINCTRLENTRY_LOC_DONTCLOSE NSLocalizedString( @"Don't Close", @"" )

@implementation CSWinCtrlEntry

// Character strings for password generation
static const char *genAlphanum = "abcdefghijklmnopqrstuvwxyz"
                                 "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
static const char *genOther    = "`~!@#$%^&*()-_=+[{]}\\|;:'\",<.>/?";

- (id) initWithWindowNibName:(NSString *)windowNibName
{
   self = [ super initWithWindowNibName:windowNibName ];
   if( self != nil )
   {
      notesUM = [ [ NSUndoManager alloc ] init ];
      [ [ NSNotificationCenter defaultCenter ]
        addObserver:self selector:@selector( _undoManagerDidChange: )
        name:NSUndoManagerDidUndoChangeNotification
        object:notesUM ];
      [ [ NSNotificationCenter defaultCenter ]
        addObserver:self selector:@selector( _undoManagerDidChange: )
        name:NSUndoManagerDidRedoChangeNotification
        object:notesUM ];
      otherUM = [ [ NSUndoManager alloc ] init ];
   }

   return self;
}


/*
 * Generate a random password
 */
- (IBAction) doGenerate:(id)sender
{
   NSString *genString;
   int genSize;
   NSMutableString *randomString;
   NSMutableData *randomData;
   unsigned char *randomBytes;
   int index;

   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_AlphanumOnly ] )
      genString = [ NSString stringWithCString:genAlphanum ];
   else
      genString = [ NSString stringWithFormat:@"%s%s", genAlphanum, genOther ];

   genSize = [ [ NSUserDefaults standardUserDefaults ]
               integerForKey:CSPrefDictKey_GenSize ];
   randomString = [ NSMutableString stringWithCapacity:genSize ];
   randomData = [ NSData randomDataOfLength:genSize ];
   randomBytes = [ randomData mutableBytes ];
   for( index = 0; index < genSize; index++ )
      [ randomString appendFormat:@"%c",
                        [ genString characterAtIndex:( randomBytes[ index ] %
                                                     [ genString length ] ) ] ];
   [ passwordText setStringValue:randomString ];
   [ randomData clearOutData ];
// XXX does delete... clear the memory?
   [ randomString deleteCharactersInRange:
                     NSMakeRange( 0, [ randomString length ] ) ];
   [ self updateDocumentEditedStatus ];
}


/*
 * Open the URL in the URL field
 */
- (IBAction) doOpenURL:(id)sender
{
   BOOL urlIsInvalid;
   NSURL *theURL;

   urlIsInvalid = YES;
   theURL = [ NSURL URLWithString:[ urlText stringValue ] ];
   if( theURL != nil && [ [ NSWorkspace sharedWorkspace ] openURL:theURL ] )
      urlIsInvalid = NO;

   if( urlIsInvalid )
      NSBeginInformationalAlertSheet( CSWINCTRLENTRY_LOC_INVALIDURL,
                                      nil, nil, nil, [ self window ], nil, nil,
                                      nil, nil, CSWINCTRLENTRY_LOC_URLNOTVALID );
}


/*
 * When the window needs an undo manager, we give it the notes one for that
 * view, or the rest-of-the-window manager
 */
- (NSUndoManager *) windowWillReturnUndoManager:(NSWindow *)window
{
   if( [ [ self window ] firstResponder ] == notes )
      return notesUM;
   else
      return otherUM;
}


/*
 * We ignore this as changes in the main document don't affect entry
 * controllers; we handle edited state separately
 */
- (void) setDocumentEdited:(BOOL)dirtyFlag
{
   // Do nothing
}


/*
 * Sent by the text fields
 */
- (void) controlTextDidChange:(NSNotification *)aNotification
{
   NSString *nameTextString;

   [ self updateDocumentEditedStatus ];
   if( [ [ aNotification object ] isEqual:nameText ] )
   {
      nameTextString = [ nameText stringValue ];
      if( nameTextString == nil || [ nameTextString length ] == 0 )
         [ mainButton setEnabled:NO ];
      else
         [ mainButton setEnabled:YES ];
   }
}


/*
 * Sent by the text view
 */
- (void)textDidChange:(NSNotification *)notification
{
   [ self updateDocumentEditedStatus ];
}


/*
 * If the window has been edited, ask about the close first
 */
- (BOOL) windowShouldClose:(id)sender
{
   BOOL retval;
   id alertPanel;
// XXX maybe should clear controls here if possible
   retval = YES;
   if( [ [ self window ] isDocumentEdited ] )
   {
      alertPanel = NSGetCriticalAlertPanel( CSWINCTRLENTRY_LOC_NOTSAVED,
                                            CSWINCTRLENTRY_LOC_NOTSAVEDCLOSE,
                                            CSWINCTRLENTRY_LOC_CLOSEANYWAY,
                                            CSWINCTRLENTRY_LOC_DONTCLOSE, nil );
      [ NSApp beginSheet:alertPanel modalForWindow:[ self window ]
              modalDelegate:self
              didEndSelector:@selector( closeSheetDidEnd:returnCode:contextInfo: )
              contextInfo:NULL ];
      retval = NO;
   }

   return retval;
}


/*
 * Handle the "should close" sheet
 */
- (void) closeSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode
         contextInfo:(void *)contextInfo;
{
   if( returnCode == NSAlertDefaultReturn )
   {
      // Close the window this way so the proper delegation is performed
      [ [ self window ] setDocumentEdited:NO ];
      [ [ NSRunLoop currentRunLoop ]
        performSelector:@selector( performClose: ) target:[ self window ]
        argument:self order:9999
        modes:[ NSArray arrayWithObject:NSDefaultRunLoopMode ] ];
   }
   [ sheet orderOut:self ];
   [ NSApp endSheet:sheet ];
   NSReleaseAlertPanel( sheet );
}


/*
 * Update the window's edited status based on whether anything in the window
 * has changed
 */
- (void) updateDocumentEditedStatus
{
   if( [ self nameChanged ] || [ self accountChanged ] ||
       [ self passwordChanged ] || [ self urlChanged ] || [ self notesChanged ] )
      [ [ self window ] setDocumentEdited:YES ];
   else
      [ [ self window ] setDocumentEdited:NO ];
}


/*
 * The ...Changed are meant to be overridden in subclasses
 */
- (BOOL) nameChanged
{
   return YES;
}

- (BOOL) accountChanged
{
   return YES;
}

- (BOOL) passwordChanged
{
   return YES;
}

- (BOOL) urlChanged
{
   return YES;
}

- (BOOL) notesChanged
{
   return YES;
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ notesUM release ];
   [ otherUM release ];
   [ super dealloc ];
}


/*
 * When the undo manager for the notes text view performs undo or redo, we
 * update the edited status
 */
- (void) _undoManagerDidChange:(NSNotification *)notification
{
   [ self updateDocumentEditedStatus ];
}

@end
