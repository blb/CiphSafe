// Interesting security issues are noted with XXX in comments
/* CSWinCtrlChange.m */

#import "CSWinCtrlChange.h"
#import "CSDocument.h"
#import "CSDocModel.h"
#import "CSAppController.h"

// Defines for localized strings
#define CSWINCTRLCHANGE_LOC_VIEW NSLocalizedString( @"View/Change %@ in %@", @"" )

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
      myEntryName = [ name retain ];

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
   return myEntryName;
}


/*
 * Change the entry being edited/viewed
 */
- (void) setEntryName:(NSString *)newEntryName
{
   [ newEntryName retain ];
   [ myEntryName release ];
   myEntryName = newEntryName;
   [ self _updateFields ];
   [ self synchronizeWindowTitleWithDocumentName ];
}


/*
 * Update the fields and set first responder to the name field
 */
- (IBAction) showWindow:(id)sender
{
   [ self _updateFields ];
   [ [ self window ] makeFirstResponder:nameText ];
   [ super showWindow:sender ];
}


/*
 * We don't want to have the file represented (icon) in the title bar
 */
- (void) synchronizeWindowTitleWithDocumentName
{
   [ [ self window ] setTitle:[ NSString stringWithFormat:CSWINCTRLCHANGE_LOC_VIEW,
                                            myEntryName,
                                            [ [ self document ] displayName ] ] ];
}


/*
 * Change the entry
 */
- (IBAction) doChange:(id)sender
{
   NSRange fullNotesRange;

   fullNotesRange = NSMakeRange( 0, [ [ notes textStorage ] length ] );
   if( [ [ self document ] changeEntryWithName:myEntryName
                           newName:[ nameText stringValue ]
                           account:[ accountText stringValue ]
                           password:[ passwordText stringValue ]
                           URL:[ urlText stringValue ]
                           notesRTFD:[ notes RTFDFromRange:fullNotesRange ] ] )
   {
      if( ![ [ NSUserDefaults standardUserDefaults ]
             boolForKey:CSPrefDictKey_CloseEdit ] )
      {
         [ self setEntryName:[ nameText stringValue ] ];
         [ [ self window ] setDocumentEdited:NO ];
         // This won't work if we do it right away, so put it on the event queue
         [ [ NSRunLoop currentRunLoop ]
           performSelector:@selector( makeFirstResponder: )
           target:[ self window ]
           argument:nameText
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
   return ![ [ nameText stringValue ] isEqualToString:myEntryName ];
}

- (BOOL) accountChanged
{
   int row;

   row = [ [ self document ] rowForName:myEntryName ];

   return ![ [ accountText stringValue ]
             isEqualToString:[ [ self document ] stringForKey:CSDocModelKey_Acct
                                                 atRow:row ] ];
}

- (BOOL) passwordChanged
{
   int row;

   row = [ [ self document ] rowForName:myEntryName ];

   return ![ [ passwordText stringValue ]
             isEqualToString:[ [ self document ] stringForKey:CSDocModelKey_Passwd
                                                 atRow:row ] ];
}

- (BOOL) urlChanged
{
   int row;

   row = [ [ self document ] rowForName:myEntryName ];

   return ![ [ urlText stringValue ]
             isEqualToString:[ [ self document ] stringForKey:CSDocModelKey_URL
                                                 atRow:row ] ];
}

- (BOOL) notesChanged
{
   int row;

   row = [ [ self document ] rowForName:myEntryName ];

   return ![ [ notes textStorage ]
             isEqualToAttributedString:[ [ self document ]
                                         RTFDStringNotesAtRow:row ] ];
}


/*
 * Cleanup
 */
- (void) dealloc
{
   [ myEntryName release ];
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
   [ nameText setStringValue:myEntryName ];
   myEntryRowNum = [ [ self document ] rowForName:myEntryName ];
   if( myEntryRowNum >= 0 )
   {
      [ mainButton setEnabled:YES ];
      [ accountText setStringValue:[ [ self document ]
                                     stringForKey:CSDocModelKey_Acct
                                     atRow:myEntryRowNum ] ];
      [ passwordText setStringValue:[ [ self document ]
                                      stringForKey:CSDocModelKey_Passwd
                                      atRow:myEntryRowNum ] ];
      [ urlText setStringValue:[ [ self document ] stringForKey:CSDocModelKey_URL
                                                   atRow:myEntryRowNum ] ];
      fullNotesRange = NSMakeRange( 0, [ [ notes textStorage ] length ] );
      [ notes replaceCharactersInRange:fullNotesRange
              withRTFD:[ [ self document ] RTFDNotesAtRow:myEntryRowNum ] ];
      [ self updateDocumentEditedStatus ];
   }
}

@end
