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
/* CSWinCtrlMain.h */

#import <Cocoa/Cocoa.h>
#import "BLBTableView.h"

@class BLBTextField;

@interface CSWinCtrlMain : NSWindowController
{
   NSTableColumn *_previouslySelectedColumn;
   BOOL _searchFieldModified;
   NSArray *_searchResultList;

   IBOutlet BLBTableView *_documentView;
   IBOutlet NSButton *_documentDeleteButton;
   IBOutlet NSButton *_documentViewButton;
   IBOutlet NSTextField *_documentStatus;
   IBOutlet BLBTextField *_documentSearch;
   IBOutlet NSMenu *_contextualMenu;
   IBOutlet NSMenu *_cmmTableHeader;
}

// Actions from the main window
- (IBAction) doAddEntry:(id)sender;
- (IBAction) doViewEntry:(id)sender;
- (IBAction) doDeleteEntry:(id)sender;
- (IBAction) doResetSearch:(id)sender;

// Actions from the contextual menu
- (IBAction) cmmCopyField:(id)sender;
- (IBAction) cmmOpenURL:(id)sender;

// Action from the corner view menu
- (IBAction) cornerSelectField:(id)sender;

// Refresh the window and contents
- (void) refreshWindow;

@end
