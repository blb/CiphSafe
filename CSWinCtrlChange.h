/* CSWinCtrlChange.h */

#import <Cocoa/Cocoa.h>
#import "CSWinCtrlEntry.h"

@interface CSWinCtrlChange : CSWinCtrlEntry
{
   NSString *myEntryName;
}

// For finding an already-open controller
+ (CSWinCtrlChange *) controllerForEntryName:(NSString *)entryName
                      inDocument:(NSDocument *)document;

// Close all open controllers for a given document
+ (void) closeOpenControllersForDocument:(NSDocument *)document;

// Designated initializer
- (id) initForEntryName:(NSString *)name;

// Get/change the receiver's entry
- (NSString *) entryName;
- (void) setEntryName:(NSString *)newEntryName;

// Make the change
- (IBAction) doChange:(id)sender;

@end
