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
/* CSWinCtrlMain.h */

#import <Cocoa/Cocoa.h>
#import "BLBTableView.h"


/*
 * Tag values for the selection in the export accessory view type selector
 */
extern const int CSWinCtrlMainExportType_CSV;
extern const int CSWinCtrlMainExportType_XML;


@interface CSWinCtrlMain : NSWindowController
{
   NSTableColumn *previouslySelectedColumn;
   NSArray *searchResultList;
   int currentSearchCategory;

   IBOutlet BLBTableView *documentView;
   IBOutlet NSButton *documentDeleteButton;
   IBOutlet NSButton *documentViewButton;
   IBOutlet NSTextField *documentStatus;
   IBOutlet NSMenu *contextualMenu;
   IBOutlet NSMenu *cmmTableHeader;
   IBOutlet NSSearchField *searchField;

   // New Category window
   IBOutlet NSPanel *newCategoryWindow;
   IBOutlet NSTextField *newCategory;

   // Accessory view for export save panel
   IBOutlet NSView *exportAccessoryView;
   IBOutlet NSPopUpButton *exportType;
}

// Actions from the main window
- (IBAction) addEntry:(id)sender;
- (IBAction) viewEntry:(id)sender;
- (IBAction) delete:(id)sender;

// Actions from the new category window
- (IBAction) newCategoryOK:(id)sender;
- (IBAction) newCategoryCancel:(id)sender;

// Actions from the main menu
- (IBAction) setCategory:(id)sender;

// Actions from the contextual menu
- (IBAction) cmmCopyField:(id)sender;
- (IBAction) cmmOpenURL:(id)sender;

// Action from the corner view menu
- (IBAction) cornerSelectField:(id)sender;

// Refresh the window and contents
- (void) refreshWindow;

// Search field stuff
- (IBAction) limitSearch:(id)sender;

// List of selected items indices
- (NSIndexSet *) selectedRowIndexes;

// Provide access to the export accessory view
- (NSView *) exportAccessoryView;
- (NSPopUpButton *) exportType;

@end
