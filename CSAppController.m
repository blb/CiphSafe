/* CSAppController.m */

#import "CSAppController.h"
#import "NSData_crypto.h"
#import "NSData_clear.h"

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


NSString * const CSPassphraseNote_Save = @"Passphrase hint";
NSString * const CSPassphraseNote_Load = @"Passphrase for file";
NSString * const CSPassphraseNote_Change = @"New passphrase";

// Defines for localized strings
#define CSAPPCONTROLLER_LOC_SHORTPHRASE \
        NSLocalizedString( @"Short Passphrase", "short passphrase" )
#define CSAPPCONTROLLER_LOC_PHRASEISSHORT \
        NSLocalizedString( @"The entered passphrase is somewhat short, do " \
                           @"you wish to use it anyway?", @"" )
#define CSAPPCONTROLLER_LOC_USEIT NSLocalizedString( @"Use It", @"" )
#define CSAPPCONTROLLER_LOC_ENTERAGAIN NSLocalizedString( @"Enter Again", @"" )
#define CSAPPCONTROLLER_LOC_WINTITLE \
        NSLocalizedString( @"Enter passphrase for %@", @"" )

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
 * Do we open a new document on start, or when the icon is clicked in the
 * Dock while we have no document open?
 */
- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
   return [ [ NSUserDefaults standardUserDefaults ]
            boolForKey:CSPrefDictKey_CreateNew ];
}


/*
 * Clear the clipboard, if option is on
 */
- (void) applicationWillTerminate:(NSNotification *)aNotification
{
   NSPasteboard *generalPB;

   [ [ NSUserDefaults standardUserDefaults ] synchronize ];
   if( [ [ NSUserDefaults standardUserDefaults ]
         boolForKey:CSPrefDictKey_ClearClipboard ] )
   {
      generalPB = [ NSPasteboard generalPasteboard ];
      [ generalPB declareTypes:[ NSArray arrayWithObject:NSStringPboardType ]
                  owner:nil ];
      [ generalPB setString:@"" forType:NSStringPboardType ];
   }
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
      [ [ NSUserDefaults standardUserDefaults ]
        setInteger:[ prefsGenSize intValue ] forKey:CSPrefDictKey_GenSize ];
      [ prefsWindow performClose:self ];
   }
   else
      NSBeep();
}


/*
 * Close preferences window, ignoring changes
 */
- (IBAction) prefsCancel:(id)sender
{
   [ prefsWindow performClose:self ];
}


/*
 * Passphrase methods
 */
/*
 * Open the passphrase window to request a passphrase; noteType is one of
 * the CSPassphraseNote_* variables
 */
- (NSMutableData *) getEncryptionKeyWithNote:(NSString *)noteType
                    warnOnShortPassphrase:(BOOL)shouldWarn
                    forDocumentNamed:(NSString *)docName
{
   int windowReturn;
   NSString *passphrase;
   NSData *passphraseData;
   NSMutableData *keyData;

   keyData = nil;
   shouldWarnOnShortPhrase = shouldWarn;

   [ passphraseWindow setTitle:
                         [ NSString stringWithFormat:CSAPPCONTROLLER_LOC_WINTITLE,
                         docName ] ];

   [ passphraseNote setStringValue:NSLocalizedString( noteType, nil ) ];
   windowReturn = [ NSApp runModalForWindow:passphraseWindow ];

   passphrase = [ passphrasePhrase stringValue ];
   // XXX Might setStringValue: leave any cruft around?
   [ passphrasePhrase setStringValue:@"" ];
   [ passphraseWindow orderOut:self ];
   if( windowReturn == NSRunStoppedResponse )
   {
      passphraseData = [ passphrase dataUsingEncoding:NSUnicodeStringEncoding ];
      keyData = [ passphraseData SHA1Hash ];
      [ passphraseData clearOutData ];
      passphraseData = nil;
   }

   /*
    * XXX At this point, passphrase should be cleared, however, there is no
    * way, that I've yet found, to do that...here's hoping it gets released
    * and cleared soon...
    */
   passphrase = nil;

   return keyData;
}

/*
 * Passphrase was accepted; warn if it's pretty short
 */
- (IBAction) passphraseAccept:(id)sender
{
   if( [ [ passphrasePhrase stringValue ] length ] < 8 && shouldWarnOnShortPhrase )
   {
      if( NSRunInformationalAlertPanel( CSAPPCONTROLLER_LOC_SHORTPHRASE,
                                        CSAPPCONTROLLER_LOC_PHRASEISSHORT,
                                        CSAPPCONTROLLER_LOC_USEIT,
                                        CSAPPCONTROLLER_LOC_ENTERAGAIN,
                                        nil ) ==
          NSAlertDefaultReturn )
         [ NSApp stopModal ];
   }
   else
      [ NSApp stopModal ];
}


/*
 * Passphrase not entered
 */
- (IBAction) passphraseCancel:(id)sender
{
   [ NSApp abortModal ];
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
