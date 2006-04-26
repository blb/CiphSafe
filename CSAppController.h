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
/* CSAppController.h */

#import <Cocoa/Cocoa.h>

// Identifiers for preferences
extern NSString * const CSPrefDictKey_SaveBackup;
extern NSString * const CSPrefDictKey_CloseAdd;
extern NSString * const CSPrefDictKey_CloseEdit;
extern NSString * const CSPrefDictKey_ConfirmDelete;
extern NSString * const CSPrefDictKey_ClearClipboard;
extern NSString * const CSPrefDictKey_CreateNew;
extern NSString * const CSPrefDictKey_GenSize;
extern NSString * const CSPrefDictKey_AlphanumOnly;
extern NSString * const CSPrefDictKey_IncludePasswd;
extern NSString * const CSPrefDictKey_AutoOpen;
extern NSString * const CSPrefDictKey_AutoOpenPath;
extern NSString * const CSPrefDictKey_CloseAfterTimeout;
extern NSString * const CSPrefDictKey_CloseTimeout;
extern NSString * const CSPrefDictKey_CellSpacing;
extern NSString * const CSPrefDictKey_TableAltBackground;
extern NSString * const CSPrefDictKey_IncludeDefaultCategories;

// Name of our internal pasteboard type
extern NSString * const CSDocumentPboardType;

@interface CSAppController : NSObject
{
   int lastPBChangeCount;

   IBOutlet NSMenuItem *editMenuSetCategory;
   // Preferences window
   IBOutlet NSWindow *prefsWindow;
}

// Note the general pasteboard's current change count
- (void) notePBChangeCount;

// Give out the Set Category menu item
- (id <NSMenuItem>) editMenuSetCategoryMenuItem;

// Actions for the prefs window
- (IBAction) prefsAutoOpenSelectPath:(id)sender;

// Close all open documents
- (IBAction) closeAll:(id)sender;

@end
