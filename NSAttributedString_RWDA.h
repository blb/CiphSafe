/* NSAttributedString_RWDA.h */

#import <AppKit/AppKit.h>

@interface NSAttributedString (withay_RWDA)

- (NSData *) RTFWithDocumentAttributes:(NSDictionary *)dict;
- (NSData *) RTFDWithDocumentAttributes:(NSDictionary *)dict;

@end
