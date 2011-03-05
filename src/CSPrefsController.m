/*
 * Copyright © 2007,2011 Bryan L Blackburn.  All rights reserved.
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
/* CSPrefsController.m */

#import "CSPrefsController.h"


NSString * const CSPrefDictKey_SaveBackup = @"CSPrefDictKey_SaveBackup";
NSString * const CSPrefDictKey_CloseAdd = @"CSPrefDictKey_CloseAdd";
NSString * const CSPrefDictKey_CloseEdit = @"CSPrefDictKey_CloseEdit";
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
NSString * const CSPrefDictKey_CurrentSearchKey = @"CSPrefDictKey_CurrentSearchKey";
NSString * const CSPrefDictKey_CloseAfterTimeoutSaveOption = @"CSPrefDictKey_CloseAfterTimeoutSaveOption";

// Values should match the tag values in IB
const NSInteger CSPrefCloseAfterTimeoutSaveOption_Save = 0;
const NSInteger CSPrefCloseAfterTimeoutSaveOption_Discard = 1;
const NSInteger CSPrefCloseAfterTimeoutSaveOption_Ask = 2;
const NSInteger CSPrefCellSpacingOption_Small = 0;
const NSInteger CSPrefCellSpacingOption_Medium = 1;
const NSInteger CSPrefCellSpacingOption_Large = 2;


NSString * const CSPrefsControllerToolbarID_General = @"General";
NSString * const CSPrefsControllerToolbarID_Appearance = @"Appearance";
NSString * const CSPrefsControllerToolbarID_Security = @"Security";


@interface CSPrefsController (InternalMethods)
- (NSToolbarItem *) createToolbarItemWithID:(NSString *)itemID imageNamed:(NSString *)imageName;
- (void) setWindowContentToView:(NSView *)newView;
@end


@implementation CSPrefsController

static NSArray *toolbarItemIDs;
static CSPrefsController *sharedPrefsController = nil;


#pragma mark -
#pragma mark Initialization
/*
 * Setup up default defaults
 */
+ (void) initialize
{
   NSString *defaultPrefsPath = [[NSBundle mainBundle] pathForResource:@"DefaultPrefs"
                                                                ofType:@"plist"];
   NSDictionary *defaultPrefs = [NSDictionary dictionaryWithContentsOfFile:defaultPrefsPath];
   NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
   [userDefaults registerDefaults:defaultPrefs];
   [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaultPrefs];
   // Sanity checks
   if([userDefaults integerForKey:CSPrefDictKey_GenSize] < 1
      || [userDefaults integerForKey:CSPrefDictKey_GenSize] > 255)
      [userDefaults setInteger:8 forKey:CSPrefDictKey_GenSize];
   if([userDefaults integerForKey:CSPrefDictKey_CloseTimeout] < 1
      || [userDefaults integerForKey:CSPrefDictKey_CloseTimeout] > 3600)
      [userDefaults setInteger:10 forKey:CSPrefDictKey_CloseTimeout];
   NSInteger cellSpacing = [userDefaults integerForKey:CSPrefDictKey_CellSpacing];
   if(cellSpacing != CSPrefCellSpacingOption_Small
      && cellSpacing != CSPrefCellSpacingOption_Medium
      && cellSpacing != CSPrefCellSpacingOption_Large)
      [userDefaults setInteger:CSPrefCellSpacingOption_Small forKey:CSPrefDictKey_CellSpacing];
   NSInteger timeoutSaveOption = [userDefaults integerForKey:CSPrefDictKey_CloseAfterTimeoutSaveOption];
   if(timeoutSaveOption != CSPrefCloseAfterTimeoutSaveOption_Save
      && timeoutSaveOption != CSPrefCloseAfterTimeoutSaveOption_Discard
      && timeoutSaveOption != CSPrefCloseAfterTimeoutSaveOption_Ask)
      [userDefaults setInteger:CSPrefCloseAfterTimeoutSaveOption_Save
                        forKey:CSPrefDictKey_CloseAfterTimeoutSaveOption];

   toolbarItemIDs = [[NSArray alloc] initWithObjects:CSPrefsControllerToolbarID_General,
                                                     CSPrefsControllerToolbarID_Appearance,
                                                     CSPrefsControllerToolbarID_Security,
                                                     nil];
}


/*
 * Enforce singleton
 */
- (id) initWithWindow:(NSWindow *)window
{
   if(sharedPrefsController != nil)
   {
      [self release];
      return sharedPrefsController;
   }
   
   return [super initWithWindow:window];
}


/*
 * Setup the toolbar and prefs window
 */
- (void) awakeFromNib
{
   NSToolbarItem *generalItem = [self createToolbarItemWithID:CSPrefsControllerToolbarID_General
                                                   imageNamed:@"lightswitch"];
   NSToolbarItem *appearanceItem = [self createToolbarItemWithID:CSPrefsControllerToolbarID_Appearance
                                                      imageNamed:@"mini window ciphsafe"];
   NSToolbarItem *securityItem = [self createToolbarItemWithID:CSPrefsControllerToolbarID_Security
                                                    imageNamed:@"padlock caution behind"];
   toolbarItems = [[NSDictionary alloc] initWithObjectsAndKeys:
                                           generalItem, CSPrefsControllerToolbarID_General,
                                           appearanceItem, CSPrefsControllerToolbarID_Appearance,
                                           securityItem, CSPrefsControllerToolbarID_Security,
                                           nil];
   [generalItem release];
   [appearanceItem release];
   [securityItem release];
   
   toolbarViews = [[NSDictionary alloc] initWithObjectsAndKeys:
                                           generalView, CSPrefsControllerToolbarID_General,
                                           appearanceView, CSPrefsControllerToolbarID_Appearance,
                                           securityView, CSPrefsControllerToolbarID_Security,
                                           nil];
   
   NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"PreferencesToolbar"];
   [toolbar setAllowsUserCustomization:NO];
   [toolbar setAutosavesConfiguration:NO];
   [toolbar setDelegate:self];
   [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
   [toolbar setSizeMode:NSToolbarSizeModeDefault];
   [toolbar setSelectedItemIdentifier:CSPrefsControllerToolbarID_General];
   [self setWindowContentToView:generalView];
   [[self window] setShowsToolbarButton:NO];
   [[self window] setToolbar:toolbar];
   [toolbar release];
}


#pragma mark -
#pragma mark Toolbar Item Handling
/*
 * Create and return a toolbar item for the prefs window toolbar
 */
- (NSToolbarItem *) createToolbarItemWithID:(NSString *)itemID imageNamed:(NSString *)imageName
{
   NSToolbarItem *newItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemID];
   [newItem setAction:@selector(toolbarSelectedAnItem:)];
   [newItem setImage:[NSImage imageNamed:imageName]];
   [newItem setLabel:NSLocalizedString(itemID, @"")];
   [newItem setTarget:self];

   return newItem;
}


/*
 * The default is the list of all IDs
 */
- (NSArray *) toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
   return toolbarItemIDs;
}


/*
 * The allowed is the list of all IDs
 */
- (NSArray *) toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
   return toolbarItemIDs;
}


/*
 * The selectable is the list of all IDs
 */
- (NSArray *) toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
   return toolbarItemIDs;
}


/*
 * Use the previously-setup dictionary to return which toolbar item goes with which ID
 */
- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
   return [toolbarItems objectForKey:itemIdentifier];
}


/*
 * Select appropriate view based on the ID selected
 */
- (void) toolbarSelectedAnItem:(NSToolbarItem *)toolbarItem
{
   [self setWindowContentToView:[toolbarViews objectForKey:[toolbarItem itemIdentifier]]];
}


#pragma mark -
#pragma mark Help Display Actions
/*
 * Display help for the various preference panes
 */
- (IBAction) displayHelpAppearance:(id)sender
{
   [[NSHelpManager sharedHelpManager] openHelpAnchor:@"appearanceprefs" inBook:@"CiphSafe Help"]; 
}

- (IBAction) displayHelpGeneral:(id)sender
{
   [[NSHelpManager sharedHelpManager] openHelpAnchor:@"generalprefs" inBook:@"CiphSafe Help"]; 
}

- (IBAction) displayHelpSecurity:(id)sender
{
   [[NSHelpManager sharedHelpManager] openHelpAnchor:@"securityprefs" inBook:@"CiphSafe Help"]; 
}


#pragma mark -
#pragma mark Miscellaneous
/*
 * Only have a single prefs controller
 */
+ (CSPrefsController *) sharedPrefsController
{
   if(sharedPrefsController == nil)
      sharedPrefsController = [[CSPrefsController alloc] initWithWindowNibName:@"CSPreferences"];
   
   return sharedPrefsController;
}


/*
 * Set the current content view of the prefs window to the given view, resizing as necessary
 */
- (void) setWindowContentToView:(NSView *)newView
{
   NSWindow *window = [self window];
   NSView *contentView = [window contentView];
   NSView *currentSubview = nil;
   if([[contentView subviews] count] > 0)
      currentSubview = [[contentView subviews] objectAtIndex:0];
   if(![currentSubview isEqual:newView])
   {
      NSRect windowFrame = [window frame];
      NSRect newFrame = [window frameRectForContentRect:[newView frame]];
      newFrame.origin = windowFrame.origin;
      newFrame.origin.y -= NSHeight(newFrame) - NSHeight(windowFrame);
      [currentSubview removeFromSuperview];
      [window setFrame:newFrame display:YES animate:YES];
      [contentView addSubview:newView];
   }
}


/*
 * Create a sheet to allow user to select a file to automatically open on
 * program launch
 */
- (IBAction) prefsAutoOpenSelectPath:(id)sender
{
   /*
    * Query the bundle information to get the file types we can handle; this way we avoid hardcoding it
    * below in the beginSheet... call
    */
   NSArray *docTypes = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDocumentTypes"];
   NSMutableArray *extensionArray = [NSMutableArray arrayWithCapacity:4];
   NSEnumerator *typeEnumerator = [docTypes objectEnumerator];
   id typeDictionary;
   while((typeDictionary = [typeEnumerator nextObject]) != nil)
      [extensionArray addObjectsFromArray:[typeDictionary objectForKey:@"CFBundleTypeExtensions"]];
   
   NSOpenPanel *openPanel = [NSOpenPanel openPanel];
   [openPanel setCanChooseFiles:YES];
   [openPanel setCanChooseDirectories:NO];
   [openPanel setAllowsMultipleSelection:NO];
   [openPanel beginSheetForDirectory:nil
                                file:[[NSUserDefaults standardUserDefaults]
                                      objectForKey:CSPrefDictKey_AutoOpenPath]
                               types:extensionArray
                      modalForWindow:[self window]
                       modalDelegate:self
                      didEndSelector:@selector(selectPathSheetDidEnd:returnCode:contextInfo:)
                         contextInfo:NULL];
}


/*
 * Center the window if not already on screen
 */
- (IBAction) showWindow:(id)sender
{
   static BOOL firstShow = YES;
   if(firstShow)
   {
      [[self window] center];
      firstShow = NO;
   }
   [super showWindow:sender];
}


/*
 * Force any formatters to go prior to closing the window
 */
- (BOOL) windowShouldClose:(id)sender
{
   return [sender makeFirstResponder:nil];
}


/*
 * Open panel to select an autoopen file ended
 */
- (void) selectPathSheetDidEnd:(NSOpenPanel *)sheet
                    returnCode:(NSInteger)returnCode
                   contextInfo:(void *)contextInfo
{
   if(returnCode == NSOKButton)
      [[NSUserDefaults standardUserDefaults] setObject:[[sheet filenames] objectAtIndex:0]
                                                forKey:CSPrefDictKey_AutoOpenPath];
}

@end
