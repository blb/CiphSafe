/*
 * Compresses/decompresses data using zlib (see RFC 1950 and /usr/include/zlib.h)
 *
 * Be sure to add /usr/lib/libz.dylib to the linked frameworks, or add "-lz" to
 * 'Other Linker Flags' in the 'Linker Settings' section of the target's
 * 'Build Settings'
 */
/* NSData_compress.h */

#import <Foundation/Foundation.h>

extern const int NSDataCompressionLevelNone;
extern const int NSDataCompressionLevelDefault;
extern const int NSDataCompressionLevelLow;
extern const int NSDataCompressionLevelMedium;
extern const int NSDataCompressionLevelHigh;

@interface NSData (withay_compress)

+ (void) setCompressLogging:(BOOL)logEnabled;
- (NSMutableData *) compressedData;
- (NSMutableData *) compressedDataAtLevel:(int)level;
- (NSMutableData *) uncompressedData;
- (BOOL) isCompressedFormat;

@end
