/* BLBTextField.h */

#import <Cocoa/Cocoa.h>

@interface BLBTextField : NSTextField
{
}

@end

/*
 * Added methods for the delegate
 *
 * implement textFieldDidBecomeFirstResponder: to be notified when the
 * text field has accepted first responder
 */
@interface NSObject (BLBTextFieldDelegate)

- (void) textFieldDidBecomeFirstResponder:(BLBTextField *)textField;       

@end