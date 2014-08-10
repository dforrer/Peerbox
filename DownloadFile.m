//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "DownloadFile.h"

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#include <arpa/inet.h>
#import "NSDictionary_JSONExtensions.h"
#import "CJSONDeserializer.h"
#import "CJSONSerializer.h"
#import "FileHelper.h"
#import "Share.h"
#import "Revision.h"
#import "File.h"
#import "Peer.h"
#import "RNDecryptor.h"
#import "RNEncryptor.h"
#import "NSDataGZipCategory.h"
#import "Singleton.h"
#import "MainController.h"
#import "Configuration.h"
#include <CommonCrypto/CommonDigest.h>



@implementation DownloadFile
{
	RNDecryptor * decryptor;
	NSURLConnection * connection;
	CC_SHA1_CTX state;
	uint64_t downloadSize;
}



@synthesize request;
@synthesize download;
@synthesize isFinished;
@synthesize downloadPath;
@synthesize hasFailed;
@synthesize rev;
@synthesize delegate;
@synthesize sha1OfDownload;
@synthesize config;
@synthesize statusCode;



- (id) initWithNetService:(NSNetService*)netService
		    andRevision:(Revision*)r
			 andConfig:(Configuration*)c
{
	//DebugLog(@"DownloadFile: 1. Init");
	if ((self = [super init]))
	{
		rev	= r;
		//DebugLog(@"DownloadFile: %@", [[remoteState url] absoluteString]);
		config		= c;
		isFinished	= FALSE;
		hasFailed		= FALSE;
		downloadPath	= [self prepareDownloadPath];
		sha1OfDownload	= nil;
		download		= [FileHelper fileForWritingAtPath:downloadPath];
		request		= [[NSMutableURLRequest alloc] init];
		downloadSize   = 0;
		[request setHTTPMethod:@"POST"];
		[request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
		[request setTimeoutInterval:30];
		[request setHTTPBody: [self preparePostData]];
		[request setURL: [self urlFromNetService: netService]];
		//	DebugLog(@"URL: %@", [request URL]);
		
		
		decryptor = [[RNDecryptor alloc] initWithPassword:[[[rev peer] share] secret] handler:
				   ^(RNCryptor *cryptor, NSData *data) {
					   
					   //DebugLog(@"DownloadFile: 5. Decryptor-Handler");
					   [download writeData:data];
					   
					   // Update the download-hash
					   CC_SHA1_Update(&state, [data bytes], (int)[data length]);
					   
					   if (cryptor.isFinished)
					   {
						   [self decryptionDidFinish];
					   }
				   }];
	}
	return self;
}


- (void) decryptionDidFinish
{
	if (decryptor.error || hasFailed == TRUE)
	{
		// An error occurred. You cannot trust download at this point
		[self->connection cancel];  // stop connecting; no more delegate messages
		[delegate downloadFileHasFailed:self];
	}
	else
	{
		// decryption complete
		isFinished = TRUE;
		
		// Finish up the sha1
		uint8_t digest[20];
		CC_SHA1_Final(digest, &state);
		NSMutableString * output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
		for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		{
			[output appendFormat:@"%02x", digest[i]];
		}
		sha1OfDownload = output;
		
		// Verify the integrity of the downloaded file by comparing Hashes
		
		//NSNumber * sizeOfDownload = [NSNumber numberWithLongLong:[download seekToEndOfFile]];
		NSNumber * sizeOfDownload;
		[[NSURL fileURLWithPath:downloadPath] getResourceValue: &sizeOfDownload
											   forKey: NSURLFileSizeKey
											    error: nil];
		
		if ([sha1OfDownload isEqualToString:[rev getLastVersionHash]] && [sizeOfDownload isEqualToNumber:[rev fileSize]])
		{
			// Notify Revision-Instance that the download has finished
			[delegate downloadFileHasFinished:self];
		}
		else
		{
			DebugLog(@"ERROR: sha1OfDownload: %@", sha1OfDownload);
			DebugLog(@"ERROR: lastVersionhash:%@", [rev versions]);
			DebugLog(@"ERROR: sizeOfDownload: %@", sizeOfDownload);
			DebugLog(@"ERROR: rev fileSize: %@", [rev fileSize]);
			[delegate downloadFileHasFailed:self];
		}
	}
	[download closeFile];
	decryptor = nil;
}


- (NSData*) preparePostData
{
	NSMutableDictionary * postData = [[NSMutableDictionary alloc] init];
	NSString * relUrl = [[rev relURL] stringByRemovingPercentEncoding];
	[postData setObject:relUrl forKey:@"relUrl"];
	NSError * error;
	NSData * rv = [[CJSONSerializer serializer] serializeObject:postData
											    error:&error];
	if (error)
	{
		DebugLog(@"ERROR 1: %@", error);
	}
	error = nil;
	
	rv = [RNEncryptor encryptData:rv
				  withSettings:kRNCryptorAES256Settings
					 password:[[[rev peer] share] secret]
					    error:&error];
	if (error)
	{
		DebugLog(@"ERROR 2: %@", error);
	}
	return rv;
}


/*
 * Returns the download-path in the form:
 * --------------------------------------
 * <downloadsDir>/<shareId>-UUID
 *
 * /Users/Docs123/Peerbox-CED596F1-53DC-4B6C-AD98-3D3E35BF9313
 *
 */
- (NSString*) prepareDownloadPath
{
	//return [NSString stringWithFormat:@"%@/%@-%@", [config downloadsDir], [[[rev peer] share] shareId], [FileHelper sha1OfNSString:[rev relURL]]];
	
	return [NSString stringWithFormat:@"%@/%@-%@", [config downloadsDir], [[[rev peer] share] shareId], [[NSUUID UUID] UUIDString]];
}


/**
 * Prepare URL http://<hostname>/shares/<shareId>/files
 */
- (NSURL*) urlFromNetService: (NSNetService*)n
{
	NSString * shareIDurlEncoded = [[[[rev peer] share] shareId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/shares/%@/files", [n hostName],(long)[n port], shareIDurlEncoded]];
}



- (void) start
{
	//DebugLog(@"DownloadFile: 2. start - %@", downloadPath);

	// Starting the async request
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[connection start];
	
	// Init SHA1 state
	CC_SHA1_Init(&state);
}


- (void) cancel
{
	[connection cancel];
	[download closeFile];
}




// OVERRIDE
- (void) connection:(NSURLConnection*)connection
 didReceiveResponse:(NSURLResponse*)response
{
	//DebugLog(@"DownloadFile: 3. didReceiveResponse");
	if ([response respondsToSelector:@selector(statusCode)])
	{
		statusCode = (int)[((NSHTTPURLResponse *)response) statusCode];
		if (statusCode != 200)
		{
			DebugLog(@"HTTP-ERROR: didReceiveResponse statusCode: %i", statusCode);
			hasFailed = TRUE;
			return [self decryptionDidFinish];
		}
	}
	[download seekToFileOffset:0];
}



// OVERRIDE
- (void) connection:(NSURLConnection*)connection
	didReceiveData:(NSData*)dataIn
{
	//DebugLog(@"DownloadFile: 4a. didReceiveData");
	[decryptor addData:dataIn];
	
	//[download writeData:dataIn];
	
	//CC_SHA1_Update(&state, [dataIn bytes], (int)[dataIn length]);
}



// OVERRIDE
- (void) connection:(NSURLConnection*)connection
   didFailWithError:(NSError*)error
{
	// Handle the error properly
	DebugLog(@"Error: %@",error);
	DebugLog(@"StatusCode: %li", [error code]);
	hasFailed = TRUE;
	[self decryptionDidFinish];
}



// OVERRIDE
- (void) connectionDidFinishLoading:(NSURLConnection*)connection
{
	//DebugLog(@"DownloadFile: 4. didFinishLoading");
	[decryptor finish];
}


@end