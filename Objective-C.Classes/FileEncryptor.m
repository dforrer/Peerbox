/**
 * VERSION:	1.0
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */

// HEADER
#import "FileEncryptor.h"

#include <CommonCrypto/CommonDigest.h>
/*
 GET RNEncryptor from this link:
 https://github.com/RNCryptor/RNCryptor
 */
#import "RNCryptor.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"


@implementation FileEncryptor

+ (void) encryptAtPath: (NSString*) fromPath
			 toPath: (NSString*) toPath
		  withAES256: (NSString*) password {
	
	// Make sure that this number is larger than the header + 1 block.
	// 33+16 bytes = 49 bytes. So it shouldn't be a problem.
	int blockSize = 32 * 1024;
	NSInputStream * unencryptedStream = [NSInputStream inputStreamWithFileAtPath:fromPath];
	NSOutputStream * encryptedStream = [NSOutputStream outputStreamToFileAtPath:toPath append:NO];
	[unencryptedStream open];
	[encryptedStream open];
	// We don't need to keep making new NSData objects. We can just use one repeatedly.
	__block NSMutableData *data = [NSMutableData dataWithLength:blockSize];
	__block RNEncryptor *encryptor = nil;

	dispatch_block_t readStreamBlock = ^{
		[data setLength:blockSize];
		NSInteger bytesRead = [unencryptedStream read:[data mutableBytes]
									 maxLength:blockSize];
		if (bytesRead < 0)
		{
			// Throw an error
		}
		else if (bytesRead == 0)
		{
			[encryptor finish];
		}
		else
		{
			[data setLength:bytesRead];
			[encryptor addData:data];
			DebugLog(@"Sent %ld bytes to decryptor", (unsigned long)bytesRead);
		}
	};
	
	encryptor = [[RNEncryptor alloc] initWithSettings:kRNCryptorAES256Settings
											 password:password
											  handler:^(RNCryptor *cryptor, NSData *data) {
												  DebugLog(@"Decryptor recevied %ld bytes", (unsigned long)data.length);
												  [encryptedStream write:data.bytes maxLength:data.length];
												  if (cryptor.isFinished)
												  {
													  [encryptedStream close];
													  DebugLog(@"Encryption finished");
													  // call my delegate that I'm finished with decrypting
												  }
												  else
												  {
													  // Might want to put this in a dispatch_async(), but I don't think you need it.
													  readStreamBlock();
												  }
											  }];
	
	// Read the first block to kick things off
	readStreamBlock();
}

@end
