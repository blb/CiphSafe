/* NSArray_FOOC.m */

#import "NSArray_FOOC.h"

@implementation NSArray (withay_FOOC)

/*
 * Find the first instance of a given class from the receiver's array
 */
- (id) firstObjectOfClass:(Class)classToFind
{
   NSEnumerator *objectEnumerator;
   id someObject;

   objectEnumerator = [ self objectEnumerator ];
   while( ( someObject = [ objectEnumerator nextObject ] ) != nil &&
          ![ someObject isKindOfClass:classToFind ] )
      ;   // Simply iterate

   return someObject;
}

@end
