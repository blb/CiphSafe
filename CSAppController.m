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
/* CSAppController.m */

#import "CSAppController.h"

NSString * const CSPrefDictKey_SaveBackup = @"CSPrefDictKey_SaveBackup";
NSString * const CSPrefDictKey_CloseAdd = @"CSPrefDictKey_CloseAdd";
NSString * const CSPrefDictKey_CloseEdit = @"CSPrefDictKey_CloseEdit";
NSString * const CSPrefDictKey_ConfirmDelete = @"CSPrefDictKey_ConfirmDelete";
NSString * const CSPrefDictKey_ClearClipboard = @"CSPrefDictKey_ClearClipboard";
NSString * const CSPrefDictKey_WarnShort = @"CSPrefDictKey_WarnShort";
NSString * const CSPrefDictKey_CreateNew = @"CSPrefDictKey_CreateNew";
NSString * const CSPrefDictKey_GenSize = @"CSPrefDictKey_GenSize";
NSString * const CSPrefDictKey_AlphanumOnly = @"CSPrefDictKey_AlphanumOnly";
NSString * const CSPrefDictKey_IncludePasswd = @"CSPrefDictKey_IncludePasswd";
NSString * const CSPrefDictKey_AutoOpen = @"CSPrefDictKey_AutoOpen";
NSString * const CSPrefDictKey_AutoOpenPath = @"CSPrefDictKey_AutoOpenPath";

NSString * const CSDocumentPboardType = @"CSDocumentPboardType";

@interface CSAppController (InternalMethods)
- (void) _selectPathSheetDidEnd:(NSOpenPanel *)sheet
         returnCode:(int)returnCode
         contextInfo:(void  *)contextInfo;
- (void) _configureAutoOpenControls;
- (void) _setStateOfButton:(NSButton *)button fromKey:(NSString *)key;
- (void) _setPrefKey:(NSString *)key fromButton:(NSButton *)button;
@end

@implementation CSAppController

/*
 * Setup up default defaults
 */
+ (void) initialize
{
   NSDictionary *appDefaults;
   NSUserDefaults *userDefaults;

   appDefaults = [ NSDictionary dictionaryWithObjectsAndKeys:
                                   @"NO",
                                      CSPrefDictKey_SaveBackup,
                                   @"NO",
                                      CSPrefDictKey_CloseAdd,
                                   @"NO",
                                      CSPrefDictKey_CloseEdit,
                                   @"YES",
                                      CSPrefDictKey_ConfirmDelete,
                                   @"YES",
                                      CSPrefDictKey_ClearClipboard,
                                   @"YES",
                                      CSPrefDictKey_WarnShort,
                                   @"YES",
                                      CSPrefDictKey_CreateNew,
                                   @"8",
                                      CSPrefDictKey_GenSize,
                                   @"NO",
                                      CSPrefDictKey_AlphanumOnly,
                                   @"NO",
                                      CSPrefDictKey_IncludePasswd,
                                   @"NO",
                                      CSPrefDictKey_AutoOpen,
                                   nil ];
   userDefaults = [ NSUserDefaults standardUserDefaults ];
   [ userDefaults registerDefaults:appDefaults ];
   // Sanity check
   if( [ userDefaults integerForKey:CSPrefDictKey_GenSize ] < 1 ||
       [ userDefaults integerForKey:CSPrefDictKey_GenSize ] > 255 )
      [ userDefaults setInteger:8 forKey:CSPrefDictKey_GenSize ];
}


/*
 * Record current pasteboard changecount, but one less since we haven't
 * touched it yet
 */
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
   NSUserDefaults *userDefaults;

   userDefaults = [ NSUserDefaults standardUserDefaults ];
   if( [ userDefaults boolForKey:CSPrefDictKey_AutoOpen ] )
      [ [ NSDocumentController sharedDocumentController ]
        openDocumentWithContentsOfFile:
           [ userDefaults objectForKey:CSPrefDictKey_AutoOpenPath ]
        display:YES ];
   _lastPBChangeCount = [ [ NSPasteboard generalPasteboard ] changeCount ] - 1;
}


/*
 * Do we open a new document on start, or when the icon is clicked in the
 * Dock while we have no document open?
 */
- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
   static BOOL initialShouldOpen = YES;
   NSUserDefaults *userDefaults;

   userDefaults = [ NSUserDefaults standardUserDefaults ];
   if( initialShouldOpen )
   {
      initialShouldOpen = NO;
      return ( [ userDefaults boolForKey:CSPrefDictKey_CreateNew ] &&
               ![ userDefaults boolForKey:CSPrefDictKey_AutoOpen ] );
   }
   else
      return [ userDefaults boolForKey:CSPrefDictKey_CreateNew ];
}


/*
 * Clear the pasteboard, if option is on and we were the last to put something
 * there
 */
- (void) applicationWillTerminate:(NSNotification *)aNotification
{
   NSPasteboard *generalPB;
   
   [ [ NSUserDefaults standardUserDefaults ] synchronize ];
   generalPB = [ NSPasteboard generalPasteboard ];
   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_ClearClipboard ] &&
       [ generalPB changeCount ] == _lastPBChangeCount )
   {
      [ generalPB declareTypes:[ NSArray arrayWithObject:@"" ] owner:nil ];
      [ generalPB setString:@"" forType:@"" ];
   }
}


/*
 * Note current change count, so we know if we need to clear the pasteboard on
 * exit
 */
- (void) notePBChangeCount
{
   _lastPBChangeCount = [ [ NSPasteboard generalPasteboard ] changeCount ];
}


/*
 * Preferences-related methods
 */
/*
 * Open the preferences window
 */
- (IBAction) openPrefs:(id)sender
{
   NSUserDefaults *userDefaults;
   NSString *autoOpenPath;

   userDefaults = [ NSUserDefaults standardUserDefaults ];
   // Interface tab
   [ self _setStateOfButton:_prefsCloseAdd fromKey:CSPrefDictKey_CloseAdd ];
   [ self _setStateOfButton:_prefsCloseEdit fromKey:CSPrefDictKey_CloseEdit ];
   [ self _setStateOfButton:_prefsConfirmDelete 
          fromKey:CSPrefDictKey_ConfirmDelete ];
   [ self _setStateOfButton:_prefsWarnShort fromKey:CSPrefDictKey_WarnShort ];
   [ self _setStateOfButton:_prefsCreateNew fromKey:CSPrefDictKey_CreateNew ];
   [ self _setStateOfButton:_prefsIncludePasswd
          fromKey:CSPrefDictKey_IncludePasswd ];
   [ self _setStateOfButton:_prefsAutoOpen fromKey:CSPrefDictKey_AutoOpen ];
   autoOpenPath = [ userDefaults stringForKey:CSPrefDictKey_AutoOpenPath ];
   if( autoOpenPath != nil )
      [ _prefsAutoOpenName setStringValue:autoOpenPath ];
   [ self _configureAutoOpenControls ];
   // Password tab
   [ _prefsGenSize setIntValue:
                      [ userDefaults integerForKey:CSPrefDictKey_GenSize ] ];
   [ self _setStateOfButton:_prefsAlphanumOnly
          fromKey:CSPrefDictKey_AlphanumOnly ];
   // Misc tab
   [ self _setStateOfButton:_prefsKeepBackup fromKey:CSPrefDictKey_SaveBackup ];
   [ self _setStateOfButton:_prefsClearClipboard
          fromKey:CSPrefDictKey_ClearClipboard ];

   [ _prefsWindow makeKeyAndOrderFront:self ];
}


/*
 * Close preferences window, saving changes
 */
- (IBAction) prefsSave:(id)sender
{
   NSUserDefaults *userDefaults;
   NSString *autoOpenPath;

   [ _prefsGenSize validateEditing ];
   if( [ _prefsGenSize intValue ] != 0 )
   {
      userDefaults = [ NSUserDefaults standardUserDefaults ];
      // Interface tab
      [ self _setPrefKey:CSPrefDictKey_CloseAdd fromButton:_prefsCloseAdd ];
      [ self _setPrefKey:CSPrefDictKey_CloseEdit fromButton:_prefsCloseEdit ];
      [ self _setPrefKey:CSPrefDictKey_ConfirmDelete
             fromButton:_prefsConfirmDelete ];
      [ self _setPrefKey:CSPrefDictKey_WarnShort fromButton:_prefsWarnShort ];
      [ self _setPrefKey:CSPrefDictKey_CreateNew fromButton:_prefsCreateNew ];
      [ self _setPrefKey:CSPrefDictKey_IncludePasswd
             fromButton:_prefsIncludePasswd ];
      autoOpenPath = [ _prefsAutoOpenName stringValue ];
      if( autoOpenPath == nil || [ autoOpenPath length ] == 0 )
      {
         [ userDefaults setBool:NO forKey:CSPrefDictKey_AutoOpen ];
         [ userDefaults setObject:nil forKey:CSPrefDictKey_AutoOpenPath ];
      }
      else
      {
         [ self _setPrefKey:CSPrefDictKey_AutoOpen fromButton:_prefsAutoOpen ];
         [ userDefaults setObject:autoOpenPath
                        forKey:CSPrefDictKey_AutoOpenPath ];
      }
      // Password tab
      [ userDefaults setInteger:[ _prefsGenSize intValue ]
                     forKey:CSPrefDictKey_GenSize ];
      [ self _setPrefKey:CSPrefDictKey_AlphanumOnly
             fromButton:_prefsAlphanumOnly ];
      // Misc tab
      [ self _setPrefKey:CSPrefDictKey_SaveBackup fromButton:_prefsKeepBackup ];
      [ self _setPrefKey:CSPrefDictKey_ClearClipboard
             fromButton:_prefsClearClipboard ];

      [ _prefsWindow orderOut:self ];
   }
   else
      NSBeep();
}


/*
 * Close preferences window, ignoring changes
 */
- (IBAction) prefsCancel:(id)sender
{
   [ _prefsWindow orderOut:self ];
}


/*
 * Checkbox to autoopen a document was clicked, so either enable or disable
 * its associated controls
 */
- (IBAction) prefsAutoOpenClicked:(id)sender
{
   [ self _configureAutoOpenControls ];
}


/*
 * Create a sheet to allow user to select a file to automatically open on
 * program launch
 */
- (IBAction) prefsAutoOpenSelectPath:(id)sender
{
   NSOpenPanel *openPanel;
   SEL didEndSel;

   didEndSel = @selector( _selectPathSheetDidEnd:returnCode:contextInfo: );
   openPanel = [ NSOpenPanel openPanel ];
   [ openPanel setCanChooseFiles:YES ];
   [ openPanel setCanChooseDirectories:NO ];
   [ openPanel setAllowsMultipleSelection:NO ];
   [ openPanel beginSheetForDirectory:nil
               file:[ _prefsAutoOpenName stringValue ]
               types:[ NSArray arrayWithObject:@"csd" ]
               modalForWindow:_prefsWindow
               modalDelegate:self
               didEndSelector:didEndSel
               contextInfo:NULL ];
}


/*
 * Open panel to select an autoopen file ended
 */
- (void) _selectPathSheetDidEnd:(NSOpenPanel *)sheet
         returnCode:(int)returnCode
         contextInfo:(void  *)contextInfo
{
   if( returnCode == NSOKButton )
      [ _prefsAutoOpenName setStringValue:[ [ sheet filenames ]
                                            objectAtIndex:0 ] ];
}


/*
 * Enable/disable autoopen controls, as appropriate
 */
- (void) _configureAutoOpenControls
{
   BOOL enableLinkedControls;

   enableLinkedControls = NO;
   if( [ _prefsAutoOpen state ] == NSOnState )
      enableLinkedControls = YES;
   [ _prefsAutoOpenName setEnabled:enableLinkedControls ];
   [ _prefsAutoOpenSelect setEnabled:enableLinkedControls ];
}


/*
 * Set the button's state based on the user default from the given key
 */
- (void) _setStateOfButton:(NSButton *)button fromKey:(NSString *)key
{
   [ button setState:( [ [ NSUserDefaults standardUserDefaults ]
                         boolForKey:key ] ? NSOnState : NSOffState ) ];
}


/*
 * Set the user default for the given key based on the button state
 */
- (void) _setPrefKey:(NSString *)key fromButton:(NSButton *)button
{
   [ [ NSUserDefaults standardUserDefaults ]
     setBool:( ( [ button state ] == NSOnState ) ? YES : NO ) forKey:key ];
}

@end
