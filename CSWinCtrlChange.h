/* CSWinCtrlChange.h */

#import <Cocoa/Cocoa.h>
#import "CSWinCtrlEntry.h"

@interface CSWinCtrlChange : CSWinCtrlEntry
{
   NSString *myEntryName;
}

+ (CSWinCtrlChange *) controllerForEntryName:(NSString *)entryName
                      inDocument:(NSDocument *)document;
+ (void) closeOpenControllersForDocument:(NSDocument *)document;
- (id) initForEntryName:(NSString *)name;
- (NSString *) entryName;
- (void) setEntryName:(NSString *)newEntryName;
- (IBAction) doChange:(id)sender;

@end
