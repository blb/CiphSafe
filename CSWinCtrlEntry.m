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

// XXX If it were possible, we'd clear out all the controls in windowWillClose:

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

@interface CSWinCtrlEntry (InternalMethods)
- (void) _closeSheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
         contextInfo:(void *)contextInfo;
- (void) _undoManagerDidChange:(NSNotification *)notification;
@end

@implementation CSWinCtrlEntry

/*
 * Character strings for password generation; the extra characters in genAll
 * are doubled to help propagate them further
 */
static const char *genAlphanum = "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwW"
                                 "xXyYzZ0123456789";
static const char *genAll      = "aAbBcCdDeEfFgGhHiIjJkKlLmMnNoOpPqQrRsStTuUvVwW"
                                 "xXyYzZ0123456789~!@#$%^&*()_+`-=[]\\{}|;':\",."
                                 "/<>?~!@#$%^&*()_+`-=[]\\{}|;':\",./<>?";

- (id) initWithWindowNibName:(NSString *)windowNibName
{
   self = [ super initWithWindowNibName:windowNibName ];
   if( self != nil )
   {
      /*
       * Create an undo manager for the notes field, so that "Undo Typing" won't
       * be present in the Edit menu when sitting on a text field which doesn't
       * support undo
       * Watching undo/redo change notifications lets us update the 'document
       * is dirty' status
       */
      _notesUM = [ [ NSUndoManager alloc ] init ];
      [ [ NSNotificationCenter defaultCenter ]
        addObserver:self
        selector:@selector( _undoManagerDidChange: )
        name:NSUndoManagerDidUndoChangeNotification
        object:_notesUM ];
      [ [ NSNotificationCenter defaultCenter ]
        addObserver:self
        selector:@selector( _undoManagerDidChange: )
        name:NSUndoManagerDidRedoChangeNotification
        object:_notesUM ];
      // Undo manager for everything else in the window
      _otherUM = [ [ NSUndoManager alloc ] init ];
   }

   return self;
}


/*
 * Generate a random password
 */
- (IBAction) doGenerate:(id)sender
{
   const char *genString;
   int genStringLength;
   int genSize;
   NSMutableString *randomString;
   NSMutableData *randomData;
   unsigned char *randomBytes;
   int index;

   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_AlphanumOnly ] )
      genString = genAlphanum;
   else
      genString = genAll;
   genStringLength = strlen( genString );

   genSize = [ [ NSUserDefaults standardUserDefaults ]
               integerForKey:CSPrefDictKey_GenSize ];
   randomString = [ NSMutableString stringWithCapacity:genSize ];
   randomData = [ NSData randomDataOfLength:genSize ];
   randomBytes = [ randomData mutableBytes ];
   for( index = 0; index < genSize; index++ )
      [ randomString appendFormat:@"%c",
                        genString[ randomBytes[ index ] % genStringLength ] ];
   [ _passwordText setStringValue:randomString ];
   [ randomData clearOutData ];
   /*
    * XXX deleteCharactersInRange: probably just changes its length; strings are
    * a pain in the ass in Cocoa from a security point of view
    */
   [ randomString deleteCharactersInRange:
                     NSMakeRange( 0, [ randomString length ] ) ];

   [ [ self window ] setDocumentEdited:YES ];
}


/*
 * Open the URL in the URL field
 */
- (IBAction) doOpenURL:(id)sender
{
   BOOL urlIsInvalid;
   NSURL *theURL;

   urlIsInvalid = YES;
   theURL = [ NSURL URLWithString:[ _urlText stringValue ] ];
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
   if( [ [ [ self window ] firstResponder ] isEqual:_notes ] )
      return _notesUM;
   else
      return _otherUM;
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
   if( [ [ aNotification object ] isEqual:_nameText ] )
   {
      nameTextString = [ _nameText stringValue ];
      if( nameTextString == nil || [ nameTextString length ] == 0 )
         [ _mainButton setEnabled:NO ];
      else
         [ _mainButton setEnabled:YES ];
   }
}


/*
 * Sent by the category combo box
 */
- (void) comboBoxWillDismiss:(NSNotification *)notification
{
   [ self updateDocumentEditedStatus ];
}


/*
 * Sent by the text view, but not for undo/redo
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

   retval = YES;
   if( [ [ self window ] isDocumentEdited ] )
   {
      alertPanel = NSGetCriticalAlertPanel( CSWINCTRLENTRY_LOC_NOTSAVED,
                                            CSWINCTRLENTRY_LOC_NOTSAVEDCLOSE,
                                            CSWINCTRLENTRY_LOC_CLOSEANYWAY,
                                            CSWINCTRLENTRY_LOC_DONTCLOSE, nil );
      [ NSApp beginSheet:alertPanel
              modalForWindow:[ self window ]
              modalDelegate:self
              didEndSelector:
                 @selector( _closeSheetDidEnd:returnCode:contextInfo: )
              contextInfo:NULL ];
      retval = NO;
   }

   return retval;
}


/* 
 * Make sure any attached sheet gets ended prior to closing, otherwise the
 * app gets stuck
 */
- (void) windowWillClose:(NSNotification *)notification
{
   NSWindow *sheet;

   sheet = [ [ self window ] attachedSheet ];
   if( sheet != nil )
      [ NSApp endSheet:sheet ];
}


/*
 * Update the window's edited status based on whether anything in the window
 * has changed
 */
- (void) updateDocumentEditedStatus
{
   if( [ self nameChanged ] || [ self accountChanged ] ||
       [ self passwordChanged ] || [ self urlChanged ] ||
       [ self categoryChanged ] || [ self notesChanged ] )
      [ [ self window ] setDocumentEdited:YES ];
   else
      [ [ self window ] setDocumentEdited:NO ];
}


/*
 * Provide information to combo boxes for categories
 */
- (int) numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
   if( [ aComboBox isEqual:_category ] )
      return [ [ [ self document ] categories ] count ];
   return 0;
}

- (id) comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index
{
   if( [ aComboBox isEqual:_category ] )
      return [ [ [ self document ] categories ] objectAtIndex:index ];
   return nil;
}

- (unsigned int) comboBox:(NSComboBox *)aComboBox
                 indexOfItemWithStringValue:(NSString *)aString
{
   if( [ aComboBox isEqual:_category ] )
      return [ [ [ self document ] categories ] indexOfObject:aString ];
   return -1;
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

- (BOOL) categoryChanged
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
   [ _notesUM release ];
   [ _otherUM release ];
   [ super dealloc ];
}


/*
 * Handle the "should close" sheet
 */
- (void) _closeSheetDidEnd:(NSWindow *)sheet
         returnCode:(int)returnCode
         contextInfo:(void *)contextInfo
{
   if( returnCode == NSAlertDefaultReturn )
   {
      // Close the window this way so the proper delegation is performed
      [ [ self window ] setDocumentEdited:NO ];
      [ [ NSRunLoop currentRunLoop ]
        performSelector:@selector( performClose: )
        target:[ self window ]
        argument:self
        order:9999
        modes:[ NSArray arrayWithObject:NSDefaultRunLoopMode ] ];
   }
   [ sheet orderOut:self ];
   [ NSApp endSheet:sheet ];
   NSReleaseAlertPanel( sheet );
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
