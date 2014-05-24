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
#import "MainControlloer.h"
#import "Configuration.h"
#include <CommonCrypto/CommonDigest.h>


@implementation DownloadFile
{
	//RNDecryptor * decryptor;
	NSURLConnection * connection;
	CC_SHA1_CTX state;
	
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


- (id) initWithNetService:(NSNetService*)netService
		    andRevision:(Revision*)r
			 andConfig:(Configuration*)c
{
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
		[request setHTTPMethod:@"POST"];
		[request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
		[request setTimeoutInterval:30];
		[request setHTTPBody: [self preparePostData]];
		[request setURL: [self urlFromNetService: netService]];
		DebugLog(@"URL: %@", [request URL]);
		delegate = r;

	/*	decryptor = [[RNDecryptor alloc] initWithPassword:[share secret] handler:
		 ^(RNCryptor *cryptor, NSData *data) {
		 [download writeData:data];
		 if (cryptor.isFinished)
		 {
		 [self decryptionDidFinish];
		 }
		 }];
	*/
	
	}
	return self;
}



- (NSData*) preparePostData
{
	// Prepare POST-Data
	//-------------------
	NSMutableDictionary * postData = [[NSMutableDictionary alloc] init];
	NSString * relUrl = [[[[[rev remoteState] url] absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] substringFromIndex:[[[[[rev peer] share] root] absoluteString] length]];
	[postData setObject:relUrl forKey:@"relUrl"];
	NSError * error;
	NSData * rv = [[CJSONSerializer serializer] serializeObject: postData
												error: &error];
	if (error)
	{
		DebugLog(@"ERROR 1: %@", error);
	}
	error = nil;
	
	/*
	// V2: Encrypt POST-Data
	//-----------------------
	
	rv = [RNEncryptor encryptData: rv
				  withSettings: kRNCryptorAES256Settings
					 password: [share secret]
					    error: &error];
	*/
	
	if (error)
	{
		DebugLog(@"ERROR 2: %@", error);
	}
	return rv;
}


/*
 * Returns the download-path in the form:
 * --------------------------------------
 * <downloadsDir>/<shareId>-SHA1(<relUrl>)
 *
 * /Users/Docs123/Peerboxes-aa224814213ad299b8bd0258e77bade429ac40d0
 *
 */
- (NSString*) prepareDownloadPath
{
	NSString * relUrl = [[[[rev remoteState] url] absoluteString] substringFromIndex:[[[[[rev peer] share] root] absoluteString] length]];
	return [NSString stringWithFormat:@"%@/%@-%@", [config downloadsDir], [[[rev peer] share] shareId], [FileHelper sha1OfNSString:relUrl]];
}



- (NSURL*) urlFromNetService: (NSNetService*) n
{
	// Prepare URL http://<hostname>/shares/<shareId>/files
	//---------------------------------------------------------------
	return [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/shares/%@/files", [n hostName],(long)[n port], [[[rev peer] share] shareId]]];
}



- (void) start
{
	// Starting the async request
	//----------------------------
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[connection start];
	
	// Init SHA1 state
	//-----------------
	CC_SHA1_Init(&state);
}


- (void) cancel
{
	[connection cancel];
}

/*
- (void) decryptionDidFinish
{
	if (decryptor.error)
	{
		// An error occurred. You cannot trust download at this point
		[download closeFile];
	}
	else
	{
		// decryption complete
		[download closeFile];
	}
	decryptor = nil;
}
*/


// OVERRIDE
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
	if ([response respondsToSelector:@selector(statusCode)])
	{
		long statusCode = [((NSHTTPURLResponse *)response) statusCode];
		if (statusCode != 200)
		{
			DebugLog(@"HTTP-ERROR: didReceiveResponse statusCode: %li", statusCode);
			[self->connection cancel];  // stop connecting; no more delegate messages
			hasFailed = TRUE;
			[delegate downloadFileHasFailed:self];
			return;
		}
	}
	[download seekToFileOffset:0];
}



// OVERRIDE
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)dataIn
{
	//DebugLog(@"didReceiveData");
	//[decryptor addData:dataIn];
	
	[download writeData:dataIn];
	
	CC_SHA1_Update(&state, [dataIn bytes], (int)[dataIn length]);
}



// OVERRIDE
- (void) connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
	// Handle the error properly
	//---------------------------
	DebugLog(@"Error: %@",error);
	hasFailed = TRUE;
	
	// Notify Revision-Instance that the download has failed
	//-------------------------------------------------------
	[delegate downloadFileHasFailed:self];
}



// OVERRIDE
- (void) connectionDidFinishLoading:(NSURLConnection*)connection
{
	DebugLog(@"Download finished");
	isFinished = TRUE;
	
	// Finish up the sha1
	//--------------------
	uint8_t digest[ 20 ];
	CC_SHA1_Final( digest , &state );
	NSMutableString *output = [NSMutableString stringWithCapacity: CC_SHA1_DIGEST_LENGTH * 2];
	for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
	{
		[output appendFormat:@"%02x", digest[i]];
	}
	sha1OfDownload = output;

	//[decryptor finish];

	// Notify Revision-Instance that the download has finished
	//---------------------------------------------------------
	[delegate downloadFileHasFinished:self];
	
}


@end
