/* NSAttributedString_RWDA.h */

#import <Cocoa/Cocoa.h>

@interface NSAttributedString (withay_RWDA)

- (NSData *) RTFWithDocumentAttributes:(NSDictionary *)dict;
- (NSData *) RTFDWithDocumentAttributes:(NSDictionary *)dict;

@end
