/*
 * You need to have the OpenSSL header files (as well as the location of their
 * include directory given to Project Builder) for this to compile.  For it
 * to link, add /usr/lib/libcrypto.dylib and /usr/lib/libssl.dylib to the linked
 * frameworks.
 */
/* NSData_crypto.m */

#import "NSData_crypto.h"
#include <unistd.h>
#include <openssl/evp.h>

// Localized strings
#define NSDATA_CRYPTO_LOC_READERR \
        NSLocalizedString( @"read() error in randomDataOfLength: %s (%d)", @"" )
#define NSDATA_CRYPTO_LOC_FAILOPENRAND \
        NSLocalizedString( @"failed to open /dev/random", @"" )
#define NSDATA_CRYPTO_LOC_ENCRYPTFINALFAIL \
        NSLocalizedString( @"EVP_EncryptFinal() failed", @"" )
#define NSDATA_CRYPTO_LOC_ENCRYPTUPDATEFAIL \
        NSLocalizedString( @"EVP_EncryptUpdate() failed", @"" )
#define NSDATA_CRYPTO_LOC_ENCRYPTINITFAIL \
        NSLocalizedString( @"EVP_EncryptInit() failed (setting key)", @"" )
#define NSDATA_CRYPTO_LOC_SETKEYLENFAIL \
        NSLocalizedString( @"EVP_CIPHER_CTX_set_key_length failed", @"" )
#define NSDATA_CRYPTO_LOC_ENCRYPTINITINITIALFAIL \
        NSLocalizedString( @"EVP_EncryptInit() failed (initial)", @"" )
#define NSDATA_CRYPTO_LOC_IVBAD NSLocalizedString( @"iv is %d bytes, not 8", @"" )
#define NSDATA_CRYPTO_LOC_DECRYPTFINALFAIL \
        NSLocalizedString( @"EVP_DecryptFinal() failed", @"" )
#define NSDATA_CRYPT_LOC_DECRYPTUPDATEFAIL \
        NSLocalizedString( @"EVP_DecryptUpdate() failed", @"" )
#define NSDATA_CRYPTO_LOC_DECRYPTINITSETKEYFAIL \
        NSLocalizedString( @"EVP_DecryptInit() failed (setting key)", @"" )
#define NSDATA_CRYPTO_LOC_DECRYPTINITINTIALFAIL \
        NSLocalizedString( @"EVP_DecryptInit() failed (initial)", @"" )
#define NSDATA_CRYPTO_LOC_DIGESTFINALFAIL \
        NSLocalizedString( @"EVP_DigestFinal wrote %u bytes, not the expected " \
        @"of %u", @"" )

@interface NSData (withay_crypto_InternalMethods)
+ (void) _doCryptoLog:(NSString *)format, ...;
@end

@implementation NSData (withay_crypto)

static BOOL cryptoLoggingEnabled = YES;

/*
 * Whether or not errors should be logged
 */
+ (void) setCryptoLogging:(BOOL)logEnabled
{
   cryptoLoggingEnabled = logEnabled;
}


/*
 * Pull out 'len' bytes from /dev/random, returning in a mutable data so
 * they can be overwritten later, if necessary
 */
+ (NSMutableData *) randomDataOfLength:(int)len
{
   NSMutableData *randomData;
   ssize_t amtRead, oneRead;
   NSFileHandle *devRandom;

   randomData = [ NSMutableData dataWithLength:len ];
   amtRead = 0;
   devRandom = [ NSFileHandle fileHandleForReadingAtPath:@"/dev/random" ];
   if( devRandom != nil )
   {
      while( amtRead < len )
      {
         /*
          * Here, we use read() instead of NSFileHandle's readDataOfLength:
          * because readDataOfLength: returns an NSData *, not NSMutableData *.
          */
         oneRead = read( [ devRandom fileDescriptor ], [ randomData mutableBytes ],
                         len - amtRead );
         if( oneRead <= 0 && ( errno != EINTR && errno != EAGAIN ) )
         {
            [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_READERR, strerror( errno ),
                                  errno ];
            randomData = nil;
            break;
         }
         amtRead += oneRead;
      }
      [ devRandom closeFile ];
   }
   else
      [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_FAILOPENRAND ];

   return randomData;
}


/* 
 * Encrypt the receiver's data with Blowfish (CBC mode) using the given
 * key and initialization vector; make sure iv is 8 bytes
 */
- (NSMutableData *) blowfishEncryptedDataWithKey:(NSData *)key iv:(NSData *)iv
{
   EVP_CIPHER_CTX cipherContext;
   NSMutableData *encryptedData;
   int encLen, finalLen;

   encryptedData = nil;
   if( [ iv length ] == 8 )
   {
      if( EVP_EncryptInit( &cipherContext, EVP_bf_cbc(), NULL, [ iv bytes ] ) )
      {
         if( EVP_CIPHER_CTX_set_key_length( &cipherContext, [ key length ] ) )
         {
            if( EVP_EncryptInit( &cipherContext, NULL, [ key bytes ], NULL ) )
            {
               encLen = [ self length ] + 8;   // Make sure we have enough space
               encryptedData = [ NSMutableData dataWithLength:encLen ];
               if( EVP_EncryptUpdate( &cipherContext,
                                      [ encryptedData mutableBytes ], &encLen,
                                      [ self bytes ], [ self length ] ) )
               {
                  finalLen = encLen;
                  encLen = [ encryptedData length ] - finalLen;
                  if( EVP_EncryptFinal( &cipherContext,
                                       [ encryptedData mutableBytes ] + finalLen,
                                       &encLen ) )
                  {
                     finalLen += encLen;
                     [ encryptedData setLength:finalLen ];
                  }
                  else
                     [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_ENCRYPTFINALFAIL ];
               }
               else
                  [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_ENCRYPTUPDATEFAIL ];
            }
            else
               [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_ENCRYPTINITFAIL ];
         }
         else
            [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_SETKEYLENFAIL ];
         EVP_CIPHER_CTX_cleanup( &cipherContext );
      }
      else
         [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_ENCRYPTINITINITIALFAIL ];
   }
   else
      [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_IVBAD, [ iv length ] ];

   if( encryptedData != nil && [ encryptedData length ] != finalLen )
      encryptedData = nil;

   return encryptedData;
}


/* 
 * Dencrypt the receiver's data with Blowfish (CBC mode) using the given
 * key and initialization vector; make sure iv is 8 bytes
 */
- (NSMutableData *) blowfishDecryptedDataWithKey:(NSData *)key iv:(NSData *)iv
{
   EVP_CIPHER_CTX cipherContext;
   NSMutableData *plainData;
   int decLen, finalLen;

   plainData = nil;
   if( [ iv length ] == 8 )
   {
      if( EVP_DecryptInit( &cipherContext, EVP_bf_cbc(), NULL, [ iv bytes ] ) )
      {
         if( EVP_CIPHER_CTX_set_key_length( &cipherContext, [ key length ] ) )
         {
            if( EVP_DecryptInit( &cipherContext, NULL, [ key bytes ], NULL ) )
            {
               decLen = [ self length ] + 8;   // Make sure there's enough room
               plainData = [ NSMutableData dataWithLength:decLen ];
               if( EVP_DecryptUpdate( &cipherContext, [ plainData mutableBytes ],
                                      &decLen, [ self bytes ], [ self length ] ) )
               {
                  finalLen = decLen;
                  decLen = [ plainData length ] - finalLen;
                  if( EVP_DecryptFinal( &cipherContext,
                                        [ plainData mutableBytes ] + finalLen,
                                        &decLen ) )
                  {
                     finalLen += decLen;
                     [ plainData setLength:finalLen ];
                  }
                  else
                     [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_DECRYPTFINALFAIL ];
               }
               else
                  [ NSData _doCryptoLog:NSDATA_CRYPT_LOC_DECRYPTUPDATEFAIL ];
            }
            else
               [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_DECRYPTINITSETKEYFAIL ];
         }
         else
            [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_SETKEYLENFAIL ];
         EVP_CIPHER_CTX_cleanup( &cipherContext );
      }
      else
         [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_DECRYPTINITINTIALFAIL ];
   }
   else
      [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_IVBAD, [ iv length ] ];

   if( plainData != nil && [ plainData length ] != finalLen )
      plainData = nil;

   return plainData;
}


/*
 * Return a SHA1 hash of the receiver's data
 */
- (NSMutableData *) SHA1Hash
{
   EVP_MD_CTX digestContext;
   NSMutableData *hashValue;
   unsigned int hashLen, writtenLen;

   EVP_DigestInit( &digestContext, EVP_sha1() );
   hashLen = EVP_MD_CTX_size( &digestContext );
   hashValue = [ NSMutableData dataWithLength:hashLen ];
   EVP_DigestUpdate( &digestContext, [ self bytes ], [ self length ] );
   EVP_DigestFinal( &digestContext, [ hashValue mutableBytes ], &writtenLen );
   if( writtenLen != hashLen )
   {
      [ NSData _doCryptoLog:NSDATA_CRYPTO_LOC_DIGESTFINALFAIL, writtenLen,
                            hashLen ];
      hashValue = nil;
   }

   return hashValue;
}


/*
 * Log the warning/error, if logging enabled
 */
+ (void) _doCryptoLog:(NSString *)format, ...
{
   va_list args;

   if( cryptoLoggingEnabled )
   {
      va_start( args, format );
      NSLogv( [ NSString stringWithFormat:@"NSData_crypto: %@\n", format ], args );
      va_end( args );
   }
}

@end
