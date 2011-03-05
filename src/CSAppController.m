/*
 * Copyright © 2003,2006-2007,2011, Bryan L Blackburn.  All rights reserved.
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
#import "CSPrefsController.h"
#import "CSDocument.h"
#import "CSWinCtrlEntry.h"
#import "CSWinCtrlMain.h"
#include <CoreFoundation/CoreFoundation.h>


NSString * const CSDocumentPboardType = @"CSDocumentPboardType";


@implementation CSAppController

/*
static CFAllocatorRef ciphSafeCFAllocator;
static CFAllocatorRef originalCFAllocator;


// These are the custom CoreFoundation allocator functions
void *ciphSafeCFReallocate(void *ptr, CFIndex newsize, CFOptionFlags hint, void *info)
{
//   return realloc(ptr, newsize);
   return CFAllocatorReallocate(originalCFAllocator, ptr, newsize, hint);
}


void ciphSafeCFDeallocate(void *ptr, void *info)
{
//   free(ptr);
//   return;
   CFAllocatorDeallocate(originalCFAllocator, ptr);
}
*/


#pragma mark -
#pragma mark Initialization
/*
 * Setup up custom allocator stuff
 */
+ (void) initialize
{
#if defined(DEBUG)
   NSLog(@"CiphSafe debug build");
#endif
   // Force the prefs controller to load so it does its +initialize thing
   [CSPrefsController sharedPrefsController];
/*   
   // Create CoreFoundation custom allocator so we can clear memory on deallocation
   originalCFAllocator = CFAllocatorGetDefault();
   CFRetain(originalCFAllocator);
   CFAllocatorContext originalContext;
   CFAllocatorGetContext(originalCFAllocator, &originalContext);
   
   CFAllocatorContext allocContext;
   memcpy(&allocContext, &originalContext, sizeof(CFAllocatorContext));
   allocContext.reallocate = ciphSafeCFReallocate;
   allocContext.deallocate = ciphSafeCFDeallocate;
   ciphSafeCFAllocator = CFAllocatorCreate(NULL, &allocContext);
   CFAllocatorSetDefault(ciphSafeCFAllocator);
   */
}


- (id) init
{
   self = [super init];
   if(self != nil)
      closeAllFromTimeout = NO;

   return self;
}


/*
 * Listen for additions to the window menu (to rearrange it), and record
 * the current pasteboard changecount, but one less since we haven't
 * touched it yet
 */
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
   [[NSNotificationCenter defaultCenter] addObserver:self
                                            selector:@selector(windowsMenuDidUpdate:)
                                                name:NSMenuDidAddItemNotification
                                              object:[NSApp windowsMenu]];
   NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
   if([userDefaults boolForKey:CSPrefDictKey_AutoOpen])
   {
      NSDocumentController *sharedDocController = [NSDocumentController sharedDocumentController];
      if([[sharedDocController documents] count] == 0)
      {
         NSURL *fileURL = [NSURL fileURLWithPath:[userDefaults objectForKey:CSPrefDictKey_AutoOpenPath]];
         NSError *openError = nil;
         [sharedDocController openDocumentWithContentsOfURL:fileURL display:YES error:&openError];
#if defined(DEBUG)
         if(openError != nil)
            NSLog(@"CSAppController applicationDidFinishLaunching: errored at "
                   @"openDocumentWithContentsOfURL:display:error: %@", openError);
#endif
      }
   }
   lastPBChangeCount = [[NSPasteboard generalPasteboard] changeCount] - 1;
}


#pragma mark -
#pragma mark CloseAll Support
/*
 * Queue up a close all message, if enabled
 */
- (void) queuePendingCloseAll
{
   NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
   if([userDefaults boolForKey:CSPrefDictKey_CloseAfterTimeout])
      [self performSelector:@selector(closeAll:)
                 withObject:self
                 afterDelay:([userDefaults integerForKey:CSPrefDictKey_CloseTimeout] * 60)];
}


/*
 * Cancel any pending closeAll: performs put in the queue
 */
- (void) cancelPendingCloseAll
{
   [[self class] cancelPreviousPerformRequestsWithTarget:self
                                                selector:@selector(closeAll:)
                                                  object:self];
}


/*
 * When we lose active status, queue up a closeAll: if enabled
 */
- (void) applicationDidResignActive:(NSNotification *)aNotification
{
   [self queuePendingCloseAll];
}


/*
 * When activated, cancel any pending closeAll
 */
- (void) applicationDidBecomeActive:(NSNotification *)aNotification
{
   [self cancelPendingCloseAll];
}


/*
 * Note if a close all was caused by the timeout option, so documents can decide whether to act on the
 * close all save option, or just ask.
 */
- (BOOL) closeAllFromTimeout
{
   return closeAllFromTimeout;
}


/*
 * Note that a timeout is no longer what caused a close all
 */
- (void) docController:(NSDocumentController *)docController
           didCloseAll:(BOOL)didCloseAll
           contextInfo:(void *)contextInfo
{
   closeAllFromTimeout = NO;
}


/*
 * Close all open documents
 */
- (IBAction) closeAll:(id)sender
{
   if(sender == self)
      closeAllFromTimeout = YES;
   [[NSDocumentController sharedDocumentController]
    closeAllDocumentsWithDelegate:self
              didCloseAllSelector:@selector(docController:didCloseAll:contextInfo:)
                      contextInfo:NULL];
}


#pragma mark -
#pragma mark Special Window Menu Handling
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
   [[self class] cancelPreviousPerformRequestsWithTarget:self
                                                selector:@selector(rearrangeWindowMenu:)
                                                  object:nil];
   [self performSelector:@selector(rearrangeWindowMenu:)
              withObject:nil
              afterDelay:0.1];
}


/*
 * Return if the given menu item represents a window owned the given window
 * controller class/subclass
 */
- (BOOL) isMenuItem:(id)menuItem forWindowControllerClass:(Class)theClass
{
   id target = [menuItem target];
   // Only windows may have window controllers
   if([target isKindOfClass:[NSWindow class]]
      && [[target windowController] isKindOfClass:[theClass class]])
      return YES;

   return NO;
}


/*
 * Rearrange the window menu so secondary windows are spaced and underneath
 * their respective parent window menu entries (like PB)
 */
- (void) rearrangeWindowMenu:(id)unused
{
   NSMenu *windowMenu = [NSApp windowsMenu];
   /*
    * Use a copy since we'll be modifying the original list below, and this protects us in case 
    * the array from itemArray is just a reference to the original
    */
   NSArray *itemArrayCopy = [[windowMenu itemArray] copy];
   NSEnumerator *itemEnumerator = [itemArrayCopy objectEnumerator];
   id menuItem;
   NSMutableArray *windowMenuSecondaryItems = [NSMutableArray arrayWithCapacity:25];
   // First, remove all secondary items which we want to rearrange
   while((menuItem = [itemEnumerator nextObject]) != nil)
   {
      // We only rearrange windows owned by CSWinCtrlEntry subclasses
      if([self isMenuItem:menuItem forWindowControllerClass:[CSWinCtrlEntry class]])
      {
         [menuItem setIndentationLevel:1];
         [windowMenuSecondaryItems addObject:menuItem];
         [windowMenu removeItem:menuItem];
      }
   }
   [itemArrayCopy release];
   // Now put them in proper order
   if([windowMenuSecondaryItems count] > 0)
   {
      itemEnumerator = [windowMenuSecondaryItems reverseObjectEnumerator];
      while((menuItem = [itemEnumerator nextObject]) != nil)
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
         int parentItemIndex = [windowMenu indexOfItemWithTarget:[[[[[menuItem target]
                                                                     windowController]
                                                                    document]
                                                                   mainWindowController]
                                                                  window]
                                                       andAction:@selector(makeKeyAndOrderFront:)];
         NSAssert(parentItemIndex >= 0, @"No parent window menu item");
         if(parentItemIndex == [windowMenu numberOfItems] - 1)
            [windowMenu addItem:menuItem];
         else
            [windowMenu insertItem:menuItem atIndex:(parentItemIndex + 1)];
      }
   }
}


#pragma mark -
#pragma mark Menu Item Handling
/*
 * Update the Set Category menu item with the given category list
 */
- (void) updateSetCategoryMenuWithCategories:(NSArray *)categories action:(SEL)action
{
   NSMenu *categoriesMenu = [editMenuSetCategory submenu];
   NSEnumerator *oldItemsEnum = [[categoriesMenu itemArray] objectEnumerator];
   id oldItem;
   while((oldItem = [oldItemsEnum nextObject]) != nil)
      [categoriesMenu removeItem:oldItem];
   NSEnumerator *currentCategoriesEnum = [categories objectEnumerator];
   id newItem;
   while((newItem = [currentCategoriesEnum nextObject]) != nil)
      [categoriesMenu addItemWithTitle:newItem action:action keyEquivalent:@""];
   [categoriesMenu addItem:[NSMenuItem separatorItem]];
   [categoriesMenu addItemWithTitle:NSLocalizedString(@"New Category", @"")
                             action:action
                      keyEquivalent:@""];
}


/*
 * Enable only valid menu items
 */
- (BOOL) validateMenuItem:(id <NSMenuItem>)menuItem
{
   SEL menuItemAction = [menuItem action];
   if(menuItemAction == @selector(closeAll:))
      return ([[[NSDocumentController sharedDocumentController] documents] count] > 0);
   
   return YES;
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * Do we open a new document on start, or when the icon is clicked in the
 * Dock while we have no document open?
 */
- (BOOL) applicationShouldOpenUntitledFile:(NSApplication *)sender
{
   static BOOL initialShouldOpen = YES;
   NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
   if(initialShouldOpen)
   {
      initialShouldOpen = NO;
      return ([userDefaults boolForKey:CSPrefDictKey_CreateNew]
              && ![userDefaults boolForKey:CSPrefDictKey_AutoOpen]);
   }
   else
      return [userDefaults boolForKey:CSPrefDictKey_CreateNew];
}


/*
 * Note current change count, so we know if we need to clear the pasteboard on
 * exit
 */
- (void) notePBChangeCount
{
   lastPBChangeCount = [[NSPasteboard generalPasteboard] changeCount];
}


/*
 * Tell the prefs controller to handle preferences
 */
- (IBAction) openPreferences:(id)sender
{
   [[CSPrefsController sharedPrefsController] showWindow:sender];
}


/*
 * Clear the pasteboard, if option is on and we were the last to put something
 * there
 */
- (void) applicationWillTerminate:(NSNotification *)aNotification
{
   [[NSUserDefaults standardUserDefaults] synchronize];
   NSPasteboard *generalPB = [NSPasteboard generalPasteboard];
   if([[NSUserDefaults standardUserDefaults] boolForKey:CSPrefDictKey_ClearClipboard]
      && ([generalPB changeCount] == lastPBChangeCount))
   {
      [generalPB declareTypes:[NSArray arrayWithObject:@""] owner:nil];
      [generalPB setString:@"" forType:@""];
   }
}

@end
