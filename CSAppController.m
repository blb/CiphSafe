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

NSString * const CSDocumentPboardType = @"CSDocumentPboardType";

@interface CSAppController (InternalMethods)
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
                                   @"NO", CSPrefDictKey_SaveBackup,
                                   @"NO", CSPrefDictKey_CloseAdd,
                                   @"NO", CSPrefDictKey_CloseEdit,
                                   @"YES", CSPrefDictKey_ConfirmDelete,
                                   @"YES", CSPrefDictKey_ClearClipboard,
                                   @"YES", CSPrefDictKey_WarnShort,
                                   @"YES", CSPrefDictKey_CreateNew,
                                   @"8", CSPrefDictKey_GenSize,
                                   @"NO", CSPrefDictKey_AlphanumOnly,
                                   @"NO", CSPrefDictKey_IncludePasswd,
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
   lastPBChangeCount = [ [ NSPasteboard generalPasteboard ] changeCount ] - 1;
}


/*
 * Do we open a new document on start, or when the icon is clicked in the
 * Dock while we have no document open?
 */
- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
   return [ [ NSUserDefaults standardUserDefaults ]
            boolForKey:CSPrefDictKey_CreateNew ];
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
       [ generalPB changeCount ] == lastPBChangeCount )
   {
      [ generalPB declareTypes:[ NSArray arrayWithObject:@"" ] owner:nil ];
      [ generalPB setString:@"" forType:@"" ];
   }
}


/*
 * Note current change count, so we know if we need to clear the pasteboard on exit
 */
- (void) notePBChangeCount
{
   lastPBChangeCount = [ [ NSPasteboard generalPasteboard ] changeCount ];
}


/*
 * Preferences-related methods
 */
/*
 * Open the preferences window
 */
- (IBAction) openPrefs:(id)sender
{
   [ self _setStateOfButton:prefsKeepBackup fromKey:CSPrefDictKey_SaveBackup ];
   [ self _setStateOfButton:prefsCloseAdd fromKey:CSPrefDictKey_CloseAdd ];
   [ self _setStateOfButton:prefsCloseEdit fromKey:CSPrefDictKey_CloseEdit ];
   [ self _setStateOfButton:prefsConfirmDelete 
          fromKey:CSPrefDictKey_ConfirmDelete ];
   [ self _setStateOfButton:prefsClearClipboard
          fromKey:CSPrefDictKey_ClearClipboard ];
   [ self _setStateOfButton:prefsWarnShort fromKey:CSPrefDictKey_WarnShort ];
   [ self _setStateOfButton:prefsCreateNew fromKey:CSPrefDictKey_CreateNew ];
   [ self _setStateOfButton:prefsAlphanumOnly
          fromKey:CSPrefDictKey_AlphanumOnly ];
   [ self _setStateOfButton:prefsIncludePasswd
          fromKey:CSPrefDictKey_IncludePasswd ];
   [ prefsGenSize setIntValue:[ [ NSUserDefaults standardUserDefaults ]
                                integerForKey:CSPrefDictKey_GenSize ] ];
   [ prefsWindow makeKeyAndOrderFront:self ];
}


/*
 * Close preferences window, saving changes
 */
- (IBAction) prefsSave:(id)sender
{
   [ prefsGenSize validateEditing ];
   if( [ prefsGenSize intValue ] != 0 )
   {
      [ self _setPrefKey:CSPrefDictKey_SaveBackup fromButton:prefsKeepBackup ];
      [ self _setPrefKey:CSPrefDictKey_CloseAdd fromButton:prefsCloseAdd ];
      [ self _setPrefKey:CSPrefDictKey_CloseEdit fromButton:prefsCloseEdit ];
      [ self _setPrefKey:CSPrefDictKey_ConfirmDelete
             fromButton:prefsConfirmDelete ];
      [ self _setPrefKey:CSPrefDictKey_ClearClipboard
             fromButton:prefsClearClipboard ];
      [ self _setPrefKey:CSPrefDictKey_WarnShort fromButton:prefsWarnShort ];
      [ self _setPrefKey:CSPrefDictKey_CreateNew fromButton:prefsCreateNew ];
      [ self _setPrefKey:CSPrefDictKey_AlphanumOnly fromButton:prefsAlphanumOnly ];
      [ self _setPrefKey:CSPrefDictKey_IncludePasswd
             fromButton:prefsIncludePasswd ];
      [ [ NSUserDefaults standardUserDefaults ] setInteger:[ prefsGenSize intValue ]
                                                forKey:CSPrefDictKey_GenSize ];
      [ prefsWindow orderOut:self ];
   }
   else
      NSBeep();
}


/*
 * Close preferences window, ignoring changes
 */
- (IBAction) prefsCancel:(id)sender
{
   [ prefsWindow orderOut:self ];
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
