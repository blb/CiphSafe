/*
 * Compresses/decompresses data using zlib (see RFC 1950 and /usr/include/zlib.h)
 *
 * Be sure to add /usr/lib/libz.dylib to the linked frameworks, or add "-lz" to
 * 'Other Linker Flags' in the 'Linker Settings' section of the target's
 * 'Build Settings'
 *
 * insert license
 */
/* NSData_compress.m */

#import "NSData_compress.h"
#include <zlib.h>

const int NSDataCompressionLevelNone = Z_NO_COMPRESSION;
const int NSDataCompressionLevelDefault = Z_DEFAULT_COMPRESSION;
const int NSDataCompressionLevelLow = Z_BEST_SPEED;
const int NSDataCompressionLevelMedium = 5;
const int NSDataCompressionLevelHigh = Z_BEST_COMPRESSION;

// Localized strings
#define NSDATA_COMPRESS_LOC_COMPRESS2FAIL \
        NSLocalizedString( @"call to compress2() failed: %d - %s", @"" )
#define NSDATA_COMPRESS_LOC_MEMERR NSLocalizedString( @"memory error", @"" )
#define NSDATA_COMPRESS_LOC_BADSIZE \
        NSLocalizedString( @"bad size in data, is it really compressed? "\
                           @"(reason is %@)", @"" )
#define NSDATA_COMPRESS_LOC_UNCOMPRESSFAIL \
        NSLocalizedString( @"call to uncompress() failed: %d - %s", @"" )
#define NSDATA_COMPRESS_LOC_DATASIZEWARN \
        NSLocalizedString( @"(warning) data size was %u, expected %u", @"" )
#define NSDATA_COMPRESS_LOC_NOTZLIBFMT \
        NSLocalizedString( @"data is not in zlib-compatible format", @"" )

@interface NSData (withay_compress_InternalMethods)
+ (void) _doCompressLog:(NSString *)format, ...;
@end

@implementation NSData (withay_compress)

static BOOL compressLoggingEnabled = YES;

/*
 * Enable/disable logging, class-wide, not object-wide
 */
+ (void) setCompressLogging:(BOOL)logEnabled
{
   compressLoggingEnabled = logEnabled;
}


/*
 * Compress the data, default level of compression
 */
- (NSMutableData *) compressedData
{
   return [ self compressedDataAtLevel:NSDataCompressionLevelDefault ];
}


/*
 * Compress the data at the given compression level; stores the original data
 * size at the end of the compressed data
 */
- (NSMutableData *) compressedDataAtLevel:(int)level
{
   NSMutableData *newData;
   long bufferLength;
   int zlibError;

   /*
    * zlib says to make sure the destination has 0.1% more + 12 bytes; last
    * additional bytes to store the original size (needed for uncompress)
    */
   bufferLength = ceil( (float) [ self length ] * 1.001 ) + 12 + sizeof( unsigned );
   newData = [ NSMutableData dataWithLength:bufferLength ];
   if( newData != nil )
   {
      zlibError = compress2( [ newData mutableBytes ], &bufferLength,
                             [ self bytes ], [ self length ], level );
      if( zlibError == Z_OK )
      {
         // Add original size to the end of the buffer, written big-endian
         *( (unsigned *) ( [ newData mutableBytes ] + bufferLength ) ) =
            NSSwapHostIntToBig( [ self length ] );
         [ newData setLength:bufferLength + sizeof( unsigned ) ];
      }
      else
      {
         [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_COMPRESS2FAIL,
                                 zlibError, zError( zlibError ) ];
         newData = nil;
      }
   }
   else
      [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_MEMERR ];

   return newData;
}


/*
 * Decompress data
 */
- (NSMutableData *) uncompressedData
{
   NSMutableData *newData;
   unsigned originalSize;
   long outSize;
   int zlibError;

   newData = nil;
   if( [ self isCompressedFormat ] )
   {
      originalSize = NSSwapBigIntToHost( *( (unsigned *) ( [ self bytes ] +
                                                           [ self length ] -
                                                           sizeof( unsigned ) ) ) );
      /*
       * In the rare circumstance that data which is not compressed happens to
       * pass the checks above, we need to deal with the possibility that there
       * will be a huge number as the original size (ie, 2GB).  If that is the
       * case, NSInvalidArgumentException will be thrown.
       * There is still the possibility that uncompressed data will pass the checks
       * above and have a believable size at the end, but that will be discovered
       * in the uncompress() call.
       */
      NS_DURING
         newData = [ NSMutableData dataWithLength:originalSize ];
      NS_HANDLER
         if( [ [ localException name ]
               isEqualToString:NSInvalidArgumentException ] )
         {
            [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_BADSIZE,
                                    [ localException reason ] ];
            NS_VALUERETURN( nil, NSMutableData * );
         }
         else
            [ localException raise ];   // This should NEVER happen...
      NS_ENDHANDLER
      if( newData != nil )
      {
         outSize = originalSize;
         zlibError = uncompress( [ newData mutableBytes ], &outSize,
                                 [ self bytes ],
                                 [ self length ] - sizeof( unsigned ) );
         if( zlibError != Z_OK )
         {
            [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_UNCOMPRESSFAIL,
                                    zlibError, zError( zlibError ) ];
            newData = nil;
         }
         else if( originalSize != outSize )
            [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_DATASIZEWARN,
                                    outSize, originalSize ];
      }
      else
         [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_MEMERR ];
   }
   else
      [ NSData _doCompressLog:NSDATA_COMPRESS_LOC_NOTZLIBFMT ];

   return newData;
}


/*
 * Quick check of the data to avoid obviously-not-compressed data (see the
 * RFC for the explanation of these checks)
 */
- (BOOL) isCompressedFormat
{
   BOOL retval;
   const unsigned char *bytes;

   retval = NO;
   bytes = [ self bytes ];
   /*
    * The checks are:
    *    ( *bytes & 0x0F ) == 8           : method is deflate (this is called CM,
    *                                       compression method, in the RFC)
    *    ( *bytes & 0x80 ) == 0           : info must be at most seven, this makes
    *                                       sure the MSB is not set, otherwise it
    *                                       is at least 8 (this is called CINFO,
    *                                       compression info, in the RFC)
    *    *( (short *) bytes ) ) % 31 == 0 : the two first bytes as a whole (big
    *                                       endian format) must be a multiple of 31
    *                                       (this is discussed in the FCHECK in
    *                                       FLG, flags, section)
    */
   if( ( *bytes & 0x0F ) == 8 && ( *bytes & 0x80 ) == 0 &&
       NSSwapBigShortToHost( *( (short *) bytes ) ) % 31 == 0 )
      retval = YES;

   return retval;
}


/*
 * Log the warning/error, if logging enabled
 */
+ (void) _doCompressLog:(NSString *)format, ...
{
   va_list args;

   if( compressLoggingEnabled )
   {
      va_start( args, format );
      NSLogv( [ NSString stringWithFormat:@"NSData_compress: %@", format ], args );
      va_end( args );
   }
}

@end
