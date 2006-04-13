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
/* CSDocument.h */

#import <Cocoa/Cocoa.h>

@class CSDocModel;
@class CSWinCtrlMain;
@class CSWinCtrlPassphrase;

@interface CSDocument : NSDocument 
{
   CSDocModel *docModel;
   NSMutableData *bfKey;
   CSWinCtrlMain *mainWindowController;
   CSWinCtrlPassphrase *passphraseWindowController;
   NSInvocation *getKeyInvocation;
}

// Actions from the menu
- (IBAction) changePassphrase:(id)sender;

// Return just the main window controller
- (CSWinCtrlMain *) mainWindowController;

// Creating new windows
- (void) openAddEntryWindow;
- (void) viewEntries:(NSArray *)namesArray;

// Copy/paste support (and drag/drop)
- (BOOL) copyNames:(NSArray *)names toPasteboard:(NSPasteboard *)pboard;
- (BOOL) retrieveEntriesFromPasteboard:(NSPasteboard *)pboard
         undoName:(NSString *)undoName;

// Category information
- (NSArray *) categories;

// Methods to add/change/delete/find entries
- (int) entryCount;
- (void) setSortKey:(NSString *)newSortKey;
- (NSString *) sortKey;
- (void) setSortAscending:(BOOL)sortAsc;
- (BOOL) isSortAscending;
- (void) setSortKey:(NSString *)newSortKey ascending:(BOOL)sortAsc;
- (NSString *) stringForKey:(NSString *)key atRow:(int)row;
- (NSData *) RTFDNotesAtRow:(int)row;
- (NSData *) RTFNotesAtRow:(int)row;
- (NSAttributedString *) RTFDStringNotesAtRow:(int)row;
- (NSAttributedString *) RTFStringNotesAtRow:(int)row;
- (int) rowForName:(NSString *)name;
- (BOOL) addEntryWithName:(NSString *)name
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         category:(NSString *)category
         notesRTFD:(NSData *)notes;
- (BOOL) changeEntryWithName:(NSString *)name
         newName:(NSString *)newName
         account:(NSString *)account
         password:(NSString *)password
         URL:(NSString *)url
         category:(NSString *)category
         notesRTFD:(NSData *)notes;
- (unsigned) deleteEntriesWithNamesInArray:(NSArray *)nameArray;
- (NSNumber *) firstRowBeginningWithString:(NSString *)findMe
               ignoreCase:(BOOL)ignoreCase
               forKey:(NSString *)key;
- (NSArray *) rowsMatchingString:(NSString *)findMe
              ignoreCase:(BOOL)ignoreCase
              forKey:(NSString *)key;

@end
