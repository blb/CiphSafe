/* NSData_clear.m */

#import "NSData_clear.h"
#include <objc/objc-runtime.h>

@implementation NSData (withay_clear)

/* 
 * Warning: massive hack ahead, but it gets the job done, at least for now...
 */
- (void) clearOutData
{
   BOOL isMutable;
   char *someData;
   int index, length;
   Ivar ivar;

   if( [ self isKindOfClass:NSClassFromString( @"NSConcreteData" ) ] ||
       [ self isKindOfClass:NSClassFromString( @"NSConcreteMutableData" ) ] )
   {
      if( [ self isKindOfClass:NSClassFromString( @"NSConcreteData" ) ] )
         isMutable = NO;
      else
         isMutable = YES;
      someData = NULL;
      for( index = 0; index < isa->ivars->ivar_count; index++ )
      {
         ivar = &isa->ivars->ivar_list[ index ];
         if( strcmp( ivar->ivar_name, "_bytes" ) == 0 )
         {
            if( isMutable )
               someData = *( (char **) ( (char *) self + ivar->ivar_offset ) );
            else
               someData = ( (char *) self + ivar->ivar_offset );
         }
      }
      if( someData != NULL )   // We found _bytes
      {
         length = [ self length ];
         for( index = 0; index < length; index++ )
            someData[ index ] = 0;
      }
      else
         NSLog( @"NSData_clear: warning, couldn't find _bytes\n" );
   }
   else
      NSLog( @"NSData_clear: warning, can't clear class %@\n",
             NSStringFromClass( [ self class ] ) );
}

@end
