/* BLBTextField.m */

#import "BLBTextField.h"

@implementation BLBTextField

- (BOOL) becomeFirstResponder
{
   if( [ super becomeFirstResponder ] )
   {
      [ [ self delegate ] textFieldDidBecomeFirstResponder:self ];
      return YES;
   }

   return NO;
}

@end
