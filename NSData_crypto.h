/*
 * You need to have the OpenSSL header files (as well as the location of their
 * include directory given to Project Builder) for this to compile.  For it
 * to link, add /usr/lib/libcrypto.dylib and /usr/lib/libssl.dylib to the linked
 * frameworks.
 */
/* NSData_crypto.h */

#import <Foundation/Foundation.h>

@interface NSData (withay_crypto)

+ (void) setCryptoLogging:(BOOL)logEnabled;
+ (NSMutableData *) randomDataOfLength:(int)len;
- (NSMutableData *) blowfishEncryptedDataWithKey:(NSData *)key iv:(NSData *)iv;
- (NSMutableData *) blowfishDecryptedDataWithKey:(NSData *)key iv:(NSData *)iv;
- (NSMutableData *) SHA1Hash;

@end
