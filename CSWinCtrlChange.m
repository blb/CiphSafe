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
// Interesting security issues are noted with XXX in comments
/* CSWinCtrlChange.m */

#import "CSWinCtrlChange.h"
#import "CSDocument.h"
#import "CSDocModel.h"
#import "CSAppController.h"

// Defines for localized strings
#define CSWINCTRLCHANGE_LOC_VIEW \
           NSLocalizedString( @"View/Change %@ in %@", @"" )

@interface CSWinCtrlChange (InternalMethods)
+ (void) _addController:(CSWinCtrlChange *)newController
         forDocument:(NSDocument *)document;
+ (void) _removeController:(CSWinCtrlChange *)oldController
         forDocument:(NSDocument *)document;
+ (NSNumber *) _numberForDocument:(NSDocument *)document;
- (void) _updateFields;
@end

@implementation CSWinCtrlChange

static NSMutableDictionary *controllerList;   // Indexed by document, of arrays

/*
 * Create our controller list
 */
+ (void) initialize
{
   controllerList = [ [ NSMutableDictionary alloc ] initWithCapacity:25 ];
}


/*
 * Find the controller responsible for the given entry
 */
+ (CSWinCtrlChange *) controllerForEntryName:(NSString *)entryName
                      inDocument:(NSDocument *)document
{
   NSArray *arrayForDocument;
   unsigned index;
   CSWinCtrlChange *curController;

   arrayForDocument = [ controllerList objectForKey:
                                [ CSWinCtrlChange _numberForDocument:document ] ];
   if( arrayForDocument != nil )
   {
      for( index = 0; index < [ arrayForDocument count ]; index++ )
      {
         curController = [ arrayForDocument objectAtIndex:index ];
         if( [ [ curController entryName ] isEqualToString:entryName ] )
            return curController;
      }
   }

   return nil;
}


/*
 * Close all open controllers
 */
+ (void) closeOpenControllersForDocument:(NSDocument *)document
{
   NSArray *arrayForDocument;

   arrayForDocument = [ controllerList objectForKey:
                                [ CSWinCtrlChange _numberForDocument:document ] ];

   if( arrayForDocument != nil )
   {
      while( [ arrayForDocument count ] > 0 )
         [ [ [ arrayForDocument objectAtIndex:0 ] window ] performClose:self ];
   }
}


/*
 * Initialize for the given entry
 */
- (id) initForEntryName:(NSString *)name
{
   self = [ super initWithWindowNibName:@"CSDocumentChange" ];
   if( self != nil )
      _myEntryName = [ name retain ];

   return self;
}


/*
 * Override so we can setup to be on the list for this document
 */
- (void) setDocument:(NSDocument *)document
{
   [ super setDocument:document ];
   [ CSWinCtrlChange _addController:self forDocument:document ];
}


/* 
 * Return the entry for which we are in charge
 */
- (NSString *) entryName
{
   return _myEntryName;
}


/*
 * Change the entry being edited/viewed
 */
- (void) setEntryName:(NSString *)newEntryName
{
   [ newEntryName retain ];
   [ _myEntryName release ];
   _myEntryName = newEntryName;
   [ self _updateFields ];
   [ self synchronizeWindowTitleWithDocumentName ];
}


/*
 * Update the fields and set first responder to the name field
 */
- (IBAction) showWindow:(id)sender
{
   [ self _updateFields ];
   [ [ self window ] makeFirstResponder:_nameText ];
   [ super showWindow:sender ];
}


/*
 * We don't want to have the file represented (icon) in the title bar
 */
- (void) synchronizeWindowTitleWithDocumentName
{
   [ [ self window ] setTitle:
                        [ NSString stringWithFormat:CSWINCTRLCHANGE_LOC_VIEW,
                                            _myEntryName,
                                            [ [ self document ] displayName ] ] ];
}


/*
 * Change the entry
 */
- (IBAction) doChange:(id)sender
{
   NSRange fullNotesRange;

   fullNotesRange = NSMakeRange( 0, [ [ _notes textStorage ] length ] );
   if( [ [ self document ] changeEntryWithName:_myEntryName
                           newName:[ _nameText stringValue ]
                           account:[ _accountText stringValue ]
                           password:[ _passwordText stringValue ]
                           URL:[ _urlText stringValue ]
                           notesRTFD:[ _notes RTFDFromRange:fullNotesRange ] ] )
   {
      [ [ self window ] setDocumentEdited:NO ];
      if( ![ [ NSUserDefaults standardUserDefaults ]
             boolForKey:CSPrefDictKey_CloseEdit ] )
      {
         [ self setEntryName:[ _nameText stringValue ] ];
         // This won't work if we do it right away, so put it on the event queue
         [ [ NSRunLoop currentRunLoop ]
           performSelector:@selector( makeFirstResponder: )
           target:[ self window ]
           argument:_nameText
           order:9999
           modes:[ NSArray arrayWithObject:NSDefaultRunLoopMode ] ];
      }
      else
         [ [ self window ] performClose:self ];
   }
   else
      NSBeginInformationalAlertSheet( CSWINCTRLENTRY_LOC_ENTRYEXISTS,
                                      nil, nil, nil, [ self window ],
                                      nil, nil, nil, NULL,
                                      CSWINCTRLENTRY_LOC_ENTRYEXISTSRENAME );
}


/*
 * Remove this instance from the list when the window closes (use ShouldClose:
 * as the document reference is lost by the time WillClose: is called)
 */
- (BOOL) windowShouldClose:(id)sender
{
   BOOL retval;

   if( ( retval = [ super windowShouldClose:sender ] ) == YES )
      [ CSWinCtrlChange _removeController:self forDocument:[ self document ] ];

   return retval;
}


/*
 * Check if any of the fields have been changed
 */
- (BOOL) nameChanged
{
   return ![ [ _nameText stringValue ] isEqualToString:_myEntryName ];
}

- (BOOL) accountChanged
{
   int row;

   row = [ [ self document ] rowForName:_myEntryName ];

   return ![ [ _accountText stringValue ]
             isEqualToString:[ [ self document ] stringForKey:CSDocModelKey_Acct
                                                 atRow:row ] ];
}

- (BOOL) passwordChanged
{
   int row;

   row = [ [ self document ] rowForName:_myEntryName ];

   return ![ [ _passwordText stringValue ]
             isEqualToString:[ [ self document ] stringForKey:CSDocModelKey_Passwd
                                                 atRow:row ] ];
}

- (BOOL) urlChanged
{
   int row;

   row = [ [ self document ] rowForName:_myEntryName ];

   return ![ [ _urlText stringValue ]
             isEqualToString:[ [ self document ] stringForKey:CSDocModelKey_URL
                                                 atRow:row ] ];
}

- (BOOL) notesChanged
{
   int row;

   row = [ [ self document ] rowForName:_myEntryName ];

   return ![ [ _notes textStorage ]
             isEqualToAttributedString:[ [ self document ]
                                         RTFDStringNotesAtRow:row ] ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ _myEntryName release ];
   [ super dealloc ];
}


/*
 * Add the controller to the list of controllers
 */
+ (void) _addController:(CSWinCtrlChange *)newController
         forDocument:(NSDocument *)document
{
   NSMutableArray *arrayForDocument;

   arrayForDocument = [ controllerList objectForKey:
                                [ CSWinCtrlChange _numberForDocument:document ] ];
   if( arrayForDocument == nil )
   {
      arrayForDocument = [ NSMutableArray arrayWithCapacity:5 ];
      [ controllerList setObject:arrayForDocument
                       forKey:[ CSWinCtrlChange _numberForDocument:document ] ];
   }
   [ arrayForDocument addObject:newController ];
}


/*
 * Remove the controller
 */
+ (void) _removeController:(CSWinCtrlChange *)oldController
         forDocument:(NSDocument *)document
{
   NSMutableArray *arrayForDocument;

   arrayForDocument = [ controllerList objectForKey:
                                [ CSWinCtrlChange _numberForDocument:document ] ];
   NSAssert( arrayForDocument != nil,
             @"attempt to remove controller for document with no controllers" );
   [ arrayForDocument removeObject:oldController ];
}


/*
 * Return an NSNumber representing the document
 */
+ (NSNumber *) _numberForDocument:(NSDocument *)document
{
   return [ NSNumber numberWithUnsignedInt:[ document hash ] ];
}


/*
 * Update all the fields in the window
 */
- (void) _updateFields
{
   int myEntryRowNum;
   NSRange fullNotesRange;

   // XXX If it were possible, we'd clear out controls here
   [ _nameText setStringValue:_myEntryName ];
   myEntryRowNum = [ [ self document ] rowForName:_myEntryName ];
   if( myEntryRowNum >= 0 )
   {
      [ _mainButton setEnabled:YES ];
      [ _accountText setStringValue:[ [ self document ]
                                      stringForKey:CSDocModelKey_Acct
                                      atRow:myEntryRowNum ] ];
      [ _passwordText setStringValue:[ [ self document ]
                                       stringForKey:CSDocModelKey_Passwd
                                       atRow:myEntryRowNum ] ];
      [ _urlText setStringValue:[ [ self document ] stringForKey:CSDocModelKey_URL
                                                    atRow:myEntryRowNum ] ];
      fullNotesRange = NSMakeRange( 0, [ [ _notes textStorage ] length ] );
      [ _notes replaceCharactersInRange:fullNotesRange
               withRTFD:[ [ self document ] RTFDNotesAtRow:myEntryRowNum ] ];
      [ self updateDocumentEditedStatus ];
   }
}

@end
