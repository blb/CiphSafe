/*
 * Convenience methods to return RTF or RTFD for the entire attributed string
 */
/* NSAttributedString_RWDA.m */

#import "NSAttributedString_RWDA.h"


@implementation NSAttributedString (withay_RWDA)

- (NSData *) RTFWithDocumentAttributes:(NSDictionary *)dict
{
   return [ self RTFFromRange:NSMakeRange( 0, [ self length ] )
                 documentAttributes:dict ];
}

- (NSData *) RTFDWithDocumentAttributes:(NSDictionary *)dict
{
   return [ self RTFDFromRange:NSMakeRange( 0, [ self length ] )
                 documentAttributes:dict ];
}

@end
