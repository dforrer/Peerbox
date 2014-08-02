//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "HTTPAsyncEncryptedFileResponse.h"

#import "HTTPConnection.h"
#import "HTTPLogging.h"
#import <Foundation/Foundation.h>
#import "RNEncryptor.h"
#import "HTTPConnection.h"
#import <unistd.h>
#import <fcntl.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
//static const int httpLogLevel = HTTP_LOG_FLAG_WARN; //

#define NULL_FD  -1
#define READ_CHUNKSIZE  (1024 * 512)
/**
 * Architecure overview:
 * 
 * HTTPConnection will invoke our readDataOfLength: method to fetch data.
 * We will return nil, and then proceed to read the data via our readSource on our readQueue.
 * Once the requested amount of data has been read, we then pause our readSource,
 * and inform the connection of the available data.
 * 
 * While our read is in progress, we don't have to worry about the connection calling any other methods,
 * except the connectionDidClose method, which would be invoked if the remote end closed the socket connection.
 * To safely handle this, we do a synchronous dispatch on the readQueue,
 * and nilify the connection as well as cancel our readSource.
 * 
 * In order to minimize resource consumption during a HEAD request,
 * we don't open the file until we have to (until the connection starts requesting data).
**/

@implementation HTTPAsyncEncryptedFileResponse


- (id)initWithFilePath: (NSString *)fpath
		 andPassword: (NSString*)pw
	    forConnection: (HTTPConnection *)parent
{
	// Check Input Values
	//-------------------
	if (fpath == nil || pw == nil || parent == nil)
	{
		return nil;
	}
	
	if ((self = [super init]))
	{
		connection		= parent;
		filePath			= [fpath copy];
		if (filePath == nil)
		{
			DebugLog(@"%@: Init failed - Nil filePath", THIS_FILE);
			
			return nil;
		}

		aborted			= NO;
		finishedReading	= NO;
		password			= pw;
		
		// We don't need to keep making new NSData objects.
		// We can just use one repeatedly.
		//-------------------------------------------------
		data = nil;
		readStream = [NSInputStream inputStreamWithFileAtPath:filePath];
		[readStream open];

		void (^handlerBlock) (RNCryptor *, NSData *) = ^(RNCryptor *cryptor, NSData *encryptedData) {
			//DebugLog(@"handler");
			data = [[NSMutableData alloc] initWithData:encryptedData]; // alloc is very importent here!!!
			// Notify the connection that we have data available for it.
			[connection responseHasAvailableData:self];
			if (encryptor.isFinished)
			{
				[readStream close];
				//DebugLog(@"Encryption finished");
			}
		};
		encryptor	= [[RNEncryptor alloc] initWithSettings:kRNCryptorAES256Settings
										 password:password
										  handler:handlerBlock];
		// We don't bother opening the file here.
	}
	return self;
}


- (void) asyncRead
{
	data = [[NSMutableData alloc] initWithLength:READ_CHUNKSIZE];
	NSInteger bytesRead = [readStream read:[data mutableBytes]
						    maxLength:READ_CHUNKSIZE];
	if (bytesRead < 0)
	{
		// Throw an error
		DebugLog(@"ERROR 3: bytesRead < 0")
		[self abort];
	}
	else if (bytesRead == 0)
	{
		[encryptor finish];
	}
	else
	{
		[data setLength:bytesRead];
		[encryptor addData:data];
		//DebugLog(@"Sent %ld bytes to encryptor", (unsigned long)bytesRead);
	}
}


- (void) abort
{
	DebugLog(@"ABORTED");
	[connection responseDidAbort:self];
	aborted = YES;
}


- (BOOL) isChunked
{
	return YES;
}


/**
 readDataOfLength() is called by the Connection-Class (= from outside)
 */

- (NSData *) readDataOfLength: (NSUInteger)length
{
	//DebugLog(@"readDataOfLength:%lu", (unsigned long)length);
	if (data)
	{
		NSData * result = [NSData dataWithData:data];
		data = nil;
		if ([encryptor isFinished])
		{
			finishedReading = YES;
		}
		return result;
	}
	//[self performSelectorInBackground:@selector(asyncRead) withObject: nil];
	[self asyncRead];
	return nil;
}


- (BOOL) isDone
{
	BOOL result = finishedReading;
	// DebugLog(@"isDone - %@", (result ? @"YES" : @"NO"));
	return result;
}


- (NSString *) filePath
{
	return filePath;
}


- (BOOL) isAsynchronous
{
	return YES;
}


- (void) connectionDidClose
{
	DebugLog(@"connectionDidClose");
	[readStream close];
	readStream	= nil;
	filePath		= nil;
	data			= nil;
	encryptor		= nil;
}


- (void) dealloc
{
//	DebugLog(@"dealloc");
}




/**
 * The HTTP server supports range requests in order to allow things like
 * file download resumption and optimized streaming on mobile devices.
 **/
- (UInt64) offset
{
	// NOT NEEDED because we don't support download resumption
	return 0;
}

- (void) setOffset:(UInt64)offset
{
	// NOT NEEDED because we don't support download resumption
}

- (UInt64) contentLength
{
	// NOT NEEDED because we don't support download resumption
	return 0;
}


@end
