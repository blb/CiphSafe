/*
 * Copyright © 2003,2006, Bryan L Blackburn.  All rights reserved.
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
#import "CSDocument.h"
#import "CSWinCtrlEntry.h"
#import "CSWinCtrlMain.h"
#include <CoreFoundation/CoreFoundation.h>


NSString * const CSPrefDictKey_SaveBackup = @"CSPrefDictKey_SaveBackup";
NSString * const CSPrefDictKey_CloseAdd = @"CSPrefDictKey_CloseAdd";
NSString * const CSPrefDictKey_CloseEdit = @"CSPrefDictKey_CloseEdit";
NSString * const CSPrefDictKey_ConfirmDelete = @"CSPrefDictKey_ConfirmDelete";
NSString * const CSPrefDictKey_ClearClipboard = @"CSPrefDictKey_ClearClipboard";
NSString * const CSPrefDictKey_CreateNew = @"CSPrefDictKey_CreateNew";
NSString * const CSPrefDictKey_GenSize = @"CSPrefDictKey_GenSize";
NSString * const CSPrefDictKey_AlphanumOnly = @"CSPrefDictKey_AlphanumOnly";
NSString * const CSPrefDictKey_IncludePasswd = @"CSPrefDictKey_IncludePasswd";
NSString * const CSPrefDictKey_AutoOpen = @"CSPrefDictKey_AutoOpen";
NSString * const CSPrefDictKey_AutoOpenPath = @"CSPrefDictKey_AutoOpenPath";
NSString * const CSPrefDictKey_CloseAfterTimeout = @"CSPrefDictKey_CloseAfterTimeout";
NSString * const CSPrefDictKey_CloseTimeout = @"CSPrefDictKey_CloseTimeout";
NSString * const CSPrefDictKey_CellSpacing = @"CSPrefDictKey_CellSpacing";
NSString * const CSPrefDictKey_TableAltBackground = @"CSPrefDictKey_TableAltBackground";
NSString * const CSPrefDictKey_IncludeDefaultCategories = @"CSPrefDictKey_IncludeDefaultCategories";

NSString * const CSDocumentPboardType = @"CSDocumentPboardType";


@implementation CSAppController

static NSString *MENUSPACE = @"   ";
/*
static CFAllocatorRef ciphSafeCFAllocator;
static CFAllocatorRef originalCFAllocator;


// These are the custom CoreFoundation allocator functions
void *ciphSafeCFReallocate( void *ptr, CFIndex newsize, CFOptionFlags hint, void *info )
{
//   return realloc( ptr, newsize );
   return CFAllocatorReallocate( originalCFAllocator, ptr, newsize, hint );
}


void ciphSafeCFDeallocate( void *ptr, void *info )
{
//   free( ptr );
//   return;
   CFAllocatorDeallocate( originalCFAllocator, ptr );
}
*/

/*
 * Setup up default defaults
 */
+ (void) initialize
{
   NSString *defaultPrefsPath = [ [ NSBundle mainBundle ] pathForResource:@"DefaultPrefs"
                                                                   ofType:@"plist" ];
   NSDictionary *defaultPrefs = [ NSDictionary dictionaryWithContentsOfFile:defaultPrefsPath ];
   NSUserDefaults *userDefaults = [ NSUserDefaults standardUserDefaults ];
   [ userDefaults registerDefaults:defaultPrefs ];
   [ [ NSUserDefaultsController sharedUserDefaultsController ] setInitialValues:defaultPrefs ];
   // Sanity checks
   if( [ userDefaults integerForKey:CSPrefDictKey_GenSize ] < 1 ||
       [ userDefaults integerForKey:CSPrefDictKey_GenSize ] > 255 )
      [ userDefaults setInteger:8 forKey:CSPrefDictKey_GenSize ];
   if( [ userDefaults integerForKey:CSPrefDictKey_CloseTimeout ] < 1 ||
       [ userDefaults integerForKey:CSPrefDictKey_CloseTimeout ] > 3600 )
      [ userDefaults setInteger:10 forKey:CSPrefDictKey_CloseTimeout ];
   /*
   // Create CoreFoundation custom allocator so we can clear memory on deallocation
   originalCFAllocator = CFAllocatorGetDefault();
   CFRetain( originalCFAllocator );
   CFAllocatorContext originalContext;
   CFAllocatorGetContext( originalCFAllocator, &originalContext );
   
   CFAllocatorContext allocContext;
   memcpy( &allocContext, &originalContext, sizeof( CFAllocatorContext ) );
   allocContext.reallocate = ciphSafeCFReallocate;
   allocContext.deallocate = ciphSafeCFDeallocate;
   ciphSafeCFAllocator = CFAllocatorCreate( NULL, &allocContext );
   CFAllocatorSetDefault( ciphSafeCFAllocator );
    */
}


/* 
* Queue up a close all message, if enabled
 */
- (void) queuePendingCloseAll
{
   NSUserDefaults *userDefaults;
   
   userDefaults = [ NSUserDefaults standardUserDefaults ];
   if( [ userDefaults boolForKey:CSPrefDictKey_CloseAfterTimeout ] )
      [ self performSelector:@selector( closeAll: )
                  withObject:self
                  afterDelay:( [ userDefaults integerForKey:CSPrefDictKey_CloseTimeout ] * 60 ) ];
}


/*
 * Cancel any pending closeAll: performs put in the queue
 */
- (void) cancelPendingCloseAll
{
   [ [ self class ] cancelPreviousPerformRequestsWithTarget:self
                                                   selector:@selector( closeAll: )
                                                     object:self ];
}


/*
 * We get here when a menu item is added to the window menu
 */
- (void) windowsMenuDidUpdate:(NSNotification *)aNotification
{
   /*
    * using performSelector:...afterDelay: allows us to only rearrange
    * occasionally, as opposed to every time the menu is updated; the
    * cancelPrevious... keeps from queueing them all up
    */
   [ [ self class ] cancelPreviousPerformRequestsWithTarget:self
                                                   selector:@selector( rearrangeWindowMenu: )
                                                     object:nil ];
   [ self performSelector:@selector( rearrangeWindowMenu: )
               withObject:nil
               afterDelay:0.1 ];
}


/*
 * Return if the given menu item represents a window owned the given window
 * controller class/subclass
 */
- (BOOL) isMenuItem:(id)menuItem forWindowControllerClass:(Class)theClass
{
   id target = [ menuItem target ];
   // Only windows may have window controllers
   if( [ target isKindOfClass:[ NSWindow class ] ] )
   {
      NSWindowController *winController = [ target windowController ];
      if( [ winController isKindOfClass:[ theClass class ] ] )
         return YES;
   }
   
   return NO;
}


/*
 * Rearrange the window menu so secondary windows are spaced and underneath
 * their respective parent window menu entries (like PB)
 */
- (void) rearrangeWindowMenu:(id)unused
{
   NSMenu *windowMenu = [ NSApp windowsMenu ];
   NSMutableArray *windowMenuSecondaryItems = [ NSMutableArray arrayWithCapacity:25 ];
   NSEnumerator *itemEnumerator = [ [ windowMenu itemArray ] objectEnumerator ];
   // First, remove all secondary items which we want to rearrange
   id menuItem;
   while( ( menuItem = [ itemEnumerator nextObject ] ) != nil )
   {
      // We only rearrange windows owned by CSWinCtrlEntry subclasses
      if( [ self isMenuItem:menuItem forWindowControllerClass:[ CSWinCtrlEntry class ] ] )
      {
         // If it is already prefixed by spaces, we've already handled it
         if( [ [ menuItem title ] characterAtIndex:0 ] != ' ' )
         {
            [ menuItem setTitle:[ MENUSPACE stringByAppendingString:[ menuItem title ] ] ];
            [ windowMenuSecondaryItems addObject:menuItem ];
            [ windowMenu removeItem:menuItem ];
         }
      }
   }
   // Now put them in proper order
   if( [ windowMenuSecondaryItems count ] > 0 )
   {
      itemEnumerator = [ windowMenuSecondaryItems reverseObjectEnumerator ];
      while( ( menuItem = [ itemEnumerator nextObject ] ) != nil )
      {
         /*
          * This looks ugly at first, but: from the menu item, get the target
          * (which is the NSWindow to bring front), get the controller from that
          * window, then the document from the controller (which we already know
          * is some form of CSWinCtrlEntry class); the document is called upon to
          * give up its mainWindowController (a CSWinCtrlMain class), and finally,
          * from that, we can get the parent window.  The newly-added menu item
          * goes after that window's menu item.
          */
         int parentItemIndex = [ windowMenu indexOfItemWithTarget:[ [ [ [ [ menuItem target ]
                                                                          windowController ]
                                                                        document ]
                                                                      mainWindowController ]
                                                                    window ]
                                                        andAction:@selector( makeKeyAndOrderFront: ) ];
         NSAssert( parentItemIndex >= 0, @"No parent window menu item" );
         if( parentItemIndex == [ windowMenu numberOfItems ] - 1 )
            [ windowMenu addItem:menuItem ];
         else
            [ windowMenu insertItem:menuItem atIndex:( parentItemIndex + 1 ) ];
      }
   }
}


/*
 * Listen for additions to the window menu (to rearrange it), and record
 * the current pasteboard changecount, but one less since we haven't
 * touched it yet
 */
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
   [ [ NSNotificationCenter defaultCenter ]
     addObserver:self
        selector:@selector( windowsMenuDidUpdate: )
            name:NSMenuDidAddItemNotification
          object:[ NSApp windowsMenu ] ];
   NSUserDefaults *userDefaults = [ NSUserDefaults standardUserDefaults ];
   if( [ userDefaults boolForKey:CSPrefDictKey_AutoOpen ] )
      [ [ NSDocumentController sharedDocumentController ]
        openDocumentWithContentsOfFile:[ userDefaults objectForKey:CSPrefDictKey_AutoOpenPath ]
                               display:YES ];
   lastPBChangeCount = [ [ NSPasteboard generalPasteboard ] changeCount ] - 1;
}


/*
 * Do we open a new document on start, or when the icon is clicked in the
 * Dock while we have no document open?
 */
- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
   static BOOL initialShouldOpen = YES;
   NSUserDefaults *userDefaults = [ NSUserDefaults standardUserDefaults ];
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
 * When activated, cancel any pending closeAll
 */
- (void) applicationDidBecomeActive:(NSNotification *)aNotification
{
   [ self cancelPendingCloseAll ];
}


/*
 * When we lose active status, queue up a closeAll: if enabled
 */
- (void) applicationDidResignActive:(NSNotification *)aNotification
{
   [ self queuePendingCloseAll ];
}


/*
 * Clear the pasteboard, if option is on and we were the last to put something
 * there
 */
- (void) applicationWillTerminate:(NSNotification *)aNotification
{
   [ [ NSUserDefaults standardUserDefaults ] synchronize ];
   NSPasteboard *generalPB = [ NSPasteboard generalPasteboard ];
   if( [ [ NSUserDefaults standardUserDefaults ] boolForKey:CSPrefDictKey_ClearClipboard ] &&
       ( [ generalPB changeCount ] == lastPBChangeCount ) )
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
   lastPBChangeCount = [ [ NSPasteboard generalPasteboard ] changeCount ];
}


/*
 * Give out the Set Category menu item
 */
- (id <NSMenuItem>) editMenuSetCategoryMenuItem
{
   return editMenuSetCategory;
}


/*
 * Open panel to select an autoopen file ended
 */
- (void) selectPathSheetDidEnd:(NSOpenPanel *)sheet
                    returnCode:(int)returnCode
                   contextInfo:(void *)contextInfo
{
   if( returnCode == NSOKButton )
      [ [ NSUserDefaults standardUserDefaults ] setObject:[ [ sheet filenames ] objectAtIndex:0 ]
                                                   forKey:CSPrefDictKey_AutoOpenPath ];
}


/*
 * Create a sheet to allow user to select a file to automatically open on
 * program launch
 */
- (IBAction) prefsAutoOpenSelectPath:(id)sender
{
   NSOpenPanel *openPanel = [ NSOpenPanel openPanel ];
   [ openPanel setCanChooseFiles:YES ];
   [ openPanel setCanChooseDirectories:NO ];
   [ openPanel setAllowsMultipleSelection:NO ];
   [ openPanel beginSheetForDirectory:nil
                                 file:[ [ NSUserDefaults standardUserDefaults ]
                                        objectForKey:CSPrefDictKey_AutoOpenPath ]
                                types:[ NSArray arrayWithObject:@"csd" ]
                       modalForWindow:prefsWindow
                        modalDelegate:self
                       didEndSelector:@selector( selectPathSheetDidEnd:returnCode:contextInfo: )
                          contextInfo:NULL ];
}


/*
 * Sent by the prefs window
 */
- (BOOL) windowShouldClose:(id)sender
{
   if( [ sender isEqual:prefsWindow ] )
      return [ sender makeFirstResponder:nil ];

   return YES;
}


/*
 * Enable only valid menu items
 */
- (BOOL) validateMenuItem:(id <NSMenuItem>)menuItem
{
   SEL menuItemAction = [ menuItem action ];
   if( menuItemAction == @selector( closeAll: ) )
      return ( [ [ [ NSDocumentController sharedDocumentController ] documents ] count ] > 0 );

   return YES;
}


/*
 * A selector is required for the closeAll... stuff for the document
 * controller
 */
- (void) docController:(NSDocumentController *)docController
           didCloseAll:(BOOL)didCloseAll
           contextInfo:(void *)contextInfo
{
   // We don't need to do anything
}


/*
 * Close all open documents
 */
- (IBAction) closeAll:(id)sender
{
   [ [ NSDocumentController sharedDocumentController ]
     closeAllDocumentsWithDelegate:self
               didCloseAllSelector:@selector( docController:didCloseAll:contextInfo: )
                       contextInfo:NULL ];
}

@end
