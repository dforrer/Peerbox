//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADERS
#import "MyHTTPConnection.h"

#import <Cocoa/Cocoa.h>
#import "HTTPMessage.h"		// needed for POST-handling
#import "HTTPDataResponse.h"	// needed for POST-handling
#import "HTTPErrorResponse.h"
#import "HTTPFileResponse.h"
#import "HTTPAsyncFileResponse.h"
#import "HTTPAsyncEncryptedFileResponse.h"
#import "Singleton.h"
#import "Share.h"
#import "RNDecryptor.h"
#import "RNEncryptor.h"
#import "NSDataGZipCategory.h"
#import "CJSONSerializer.h"
#import "NSDictionary_JSONExtensions.h"
#import "FileHelper.h"
#import "Constants.h"
#import "DataModel.h"
#import "Configuration.h"


@implementation MyHTTPConnection


// UNUSED
/*
- (NSString*) generateNonce
{
	NSData * random
	= [FileHelper createRandomNSDataOfSize:20];
	
	NSString * newNonce
	= [FileHelper sha1OfNSData:random];
	
	NSMutableDictionary * nonces
	= [[Singleton data] nonces];
	
	NSNumber * expirationTime
	= [NSNumber numberWithLongLong:((long long)[[NSDate date] timeIntervalSince1970]+(12*60*60))];
	
	[nonces setObject:expirationTime forKey:newNonce];
	
	return newNonce;
}
*/



- (BOOL) supportsMethod: (NSString *)method
			  atPath: (NSString *)path
{
	// Add support for POST
	
	if ([method isEqualToString:@"POST"])
	{
		return requestContentLength < 4096;
	}
	return [super supportsMethod:method atPath:path];
}


- (BOOL)expectsRequestBodyFromMethod: (NSString *)method
						atPath: (NSString *)path
{
	// Inform HTTP server that we expect a body to accompany a POST request
	if ( [method isEqualToString:@"POST"] )
	{
		return YES;
	}
	return [super expectsRequestBodyFromMethod:method atPath:path];
}


- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method
									 URI:(NSString *)path
{
	// Singleton-Usage
	
	NSDictionary * allShares = [[[Singleton data] dataModel] myShares];
	NSString	   * myPeerID	= [[Singleton data] myPeerID];
	
	// Remove queries from the URI
	
	path = [[path componentsSeparatedByString:@"?"] objectAtIndex:0];
	
	// Here we switch between the different cases (GET, POST, Data-Response,
	// File-Response etc.)
	
	
	//NSLog(@"httpResponseForMethod: %@ URI: %@", method, path);
	
	// POST-REQUEST to URI /notification
	//----------------------------------
	
	if ( [method isEqualToString:@"POST"]
	    && [path isEqualToString:@"/notification"] )
	{
		//NSLog(@"POST-REQUEST to URI /notification");
		
		/*
		NSString *postStr = nil;
		NSData *postData = [request body];
		if ( postData )
		{
			postStr = [[NSString alloc] initWithData:postData encoding:NSUTF8StringEncoding];
		}
		 */
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"downloadSharesFromPeers" object:nil];
		return [[HTTPErrorResponse alloc] initWithErrorCode:200];
	}
	
	// GET-REQUEST to URI /info
	//-------------------------

	if ( [method isEqualToString:@"GET"]
	    && [path isEqualToString:@"/info"])
	{
		//NSLog(@"GET-REQUEST to URI /info");
		NSMutableDictionary * responseDict = [NSMutableDictionary dictionary];
		[responseDict setObject:myPeerID forKey:@"peerId"];
		NSError * error;
		NSData * response = [[CJSONSerializer serializer] serializeObject:responseDict error:&error];
		if ( error )
		{
			NSLog(@"A CJSON error occurec!");
		}
		return [[HTTPDataResponse alloc] initWithData:response];
	}
	
	// GET-REQUEST to URI /shares
	//---------------------------
	
	if ( [method isEqualToString:@"GET"]
	    && [path isEqualToString:@"/shares"])
	{
		//NSLog(@"GET-REQUEST to URI /shares");
		NSMutableArray * tmpArray = [NSMutableArray array];
		for ( Share * s in [allShares allValues ])
		{
			@autoreleasepool
			{
				NSMutableDictionary * tmpDict = [NSMutableDictionary dictionary];
				[tmpDict setObject:[s shareId] forKey:@"shareId"];
				[tmpDict setObject:[s currentRevision] forKey:@"currentRev"];
				[tmpArray addObject:tmpDict];
			}
		}
		NSMutableDictionary * responseDict = [NSMutableDictionary dictionary];
		[responseDict setObject:myPeerID forKey:@"peerId"];
		[responseDict setObject:tmpArray forKey:@"shares"];
		NSError * error;
		NSData * response = [[CJSONSerializer serializer] serializeObject:responseDict error:&error];
		if ( error )
		{
			NSLog(@"A CJSON error occurred!");
		}
		return [[HTTPDataResponse alloc] initWithData:response];
	}

	NSMutableArray * pathComponents = [NSMutableArray arrayWithArray:[path pathComponents]];
	
	// UNUSED: POST-REQUEST to URI /shares/<shareId>/revisions
	//---------------------------------------------------------
	
	if ([method isEqualToString:@"POST"]
	    && [pathComponents count] == 4
	    && [[pathComponents objectAtIndex:1] isEqualToString:@"shares"]
	    && [[pathComponents objectAtIndex:3] isEqualToString:@"revisions"])
	{
		NSLog(@"POST-REQUEST to URI /shares/<shareId>/revisions");
		
		NSString * shareId = [[pathComponents objectAtIndex: 2] stringByRemovingPercentEncoding];
		Share * requestForShare = [allShares objectForKey:shareId];
		

		// Handle error
	
		if (requestForShare == nil)
		{
			NSLog(@"ERROR 4: 404");
			return [[HTTPErrorResponse alloc] initWithErrorCode:404];
		}
		
		// Read and decrypt post-data
		
		NSData * postData = [request body];
		NSError * error;
		
		if (postData)
		{
			postData = [RNDecryptor decryptData:postData
							   withPassword:[requestForShare secret]
									error:&error];
		}

		NSDictionary * postDict = [NSDictionary dictionaryWithJSONData:postData
													  error:&error];
		if (error)
		{
			return [[HTTPErrorResponse alloc] initWithErrorCode:400];
		}
		NSNumber * fromRev = [postDict objectForKey:@"fromRev"];
		
		
		// Prepare response
		
		NSMutableDictionary * responseDict = [NSMutableDictionary dictionary];
		[responseDict setObject:myPeerID forKey:@"peerId"];
		
		
		// Get Files-Array from share
		
		NSArray * filesFromRev = [requestForShare getFilesAsJSONwithLimit:[NSNumber numberWithInt:MAX_REVS_PER_REQUEST] startingFromRev:fromRev];
		[responseDict setObject:filesFromRev forKey:@"revisions"];
		
		
		// Serialize response into JSON-Format
		
		NSData * response = [[CJSONSerializer serializer] serializeObject:responseDict error:&error];
		if (error)
		{
			NSLog(@"ERROR 5: 500");
			return [[HTTPErrorResponse alloc] initWithErrorCode:500];
		}
		
		// Compress the response with GZIP
		
		response = [response gzipDeflate];
			
		// Encrypt response with share-secret
		
		response = [RNEncryptor encryptData:response
						   withSettings:kRNCryptorAES256Settings
							  password:[requestForShare secret]
								error:&error];

		return [[HTTPDataResponse alloc] initWithData:response];
	 
	 }
	
	// POST-REQUEST to URI /shares/<shareId>/revisionsDict
	//-----------------------------------------------------
	
	if ([method isEqualToString:@"POST"]
	    && [pathComponents count] == 4
	    && [[pathComponents objectAtIndex:1] isEqualToString:@"shares"]
	    && [[pathComponents objectAtIndex:3] isEqualToString:@"revisionsDict"])
	{
		//NSLog(@"POST-REQUEST to URI /shares/<shareId>/revisionsDict");
		
		NSString * shareId = [[pathComponents objectAtIndex: 2] stringByRemovingPercentEncoding];
		Share * requestForShare = [allShares objectForKey:shareId];
		
		
		// Handle error for non-existing share
		
		if (requestForShare == nil)
		{
			NSLog(@"ERROR: 404");
			NSLog(@"requestForShare == nil");
			return [[HTTPErrorResponse alloc] initWithErrorCode:404];
		}
		
		// Read and decrypt post-data
		
		NSData * postData = [request body];
		if (!postData)
		{
			NSLog(@"ERROR: postData is nil");
			return [[HTTPErrorResponse alloc] initWithErrorCode:404];
		}

		NSError * error;

		if (postData)
		{
			postData = [RNDecryptor decryptData:postData
							   withPassword:[requestForShare secret]
									error:&error];
		}
		NSDictionary * postDict = [NSDictionary dictionaryWithJSONData:postData
													  error:&error];
		if (error)
		{
			NSLog(@"ERROR: %@", error);
			return [[HTTPErrorResponse alloc] initWithErrorCode:400];
		}
		NSNumber * fromRev = [postDict objectForKey:@"fromRev"];
		if (fromRev == nil)
		{
			return [[HTTPErrorResponse alloc] initWithErrorCode:404];
		}
		
		// Prepare response
		
		NSMutableDictionary * responseDict = [NSMutableDictionary dictionary];
		[responseDict setObject:myPeerID forKey:@"peerId"];
		
		
		// Get Revisions-Dictionary from share
		
		NSNumber * biggestRev;
		NSDictionary * dictFromRev = [requestForShare getFilesAsJSONDictWithLimit:[NSNumber numberWithInt:MAX_REVS_PER_REQUEST] startingFromRev:fromRev biggestRev:&biggestRev];
		//NSLog(@"dictFromRev:\%@", dictFromRev);
		if ([dictFromRev count] == 0 || dictFromRev == nil)
		{
			return [[HTTPErrorResponse alloc] initWithErrorCode:500];
		}
		[responseDict setObject:dictFromRev forKey:@"revisions"];
		[responseDict setObject:biggestRev forKey:@"biggestRev"];
		
		
		// Serialize response into JSON-Format
		
		NSData * response = [[CJSONSerializer serializer] serializeObject:responseDict error:&error];
		if (error)
		{
			NSLog(@"A CJSON error occurred!");
			return [[HTTPErrorResponse alloc] initWithErrorCode:500]; // "Server error"
		}
	
		// Compress the response with GZIP
		
		response = [response gzipDeflate];
		
		// Encrypt response with share-secret
		
		response = [RNEncryptor encryptData:response
						   withSettings:kRNCryptorAES256Settings
							  password:[requestForShare secret]
								error:&error];
		
		return [[HTTPDataResponse alloc] initWithData:response];
	}

	// POST-REQUEST to URI /shares/<shareId>/files
	//--------------------------------------------
	if ([method isEqualToString:@"POST"]
	    && [pathComponents count] == 4
	    && [[pathComponents objectAtIndex:1] isEqualToString:@"shares"]
	    && [[pathComponents objectAtIndex:3] isEqualToString:@"files"])
	{
		//NSLog(@"POST-REQUEST to URI /shares/<shareId>/files");

		NSString * shareId = [[pathComponents objectAtIndex: 2] stringByRemovingPercentEncoding];
		Share * requestForShare = [allShares objectForKey:shareId];
		
		// Handle error
		
		if (requestForShare == nil)
		{
			NSLog(@"ERROR: 404 - Share does not exist");
			return [[HTTPErrorResponse alloc] initWithErrorCode:404];
		}
		
		// Read and decrypt post-data
		
		NSData *postData = [request body];
		NSError * error;

		if (postData)
		{
			postData = [RNDecryptor decryptData:postData
							   withPassword:[requestForShare secret]
									error:&error];
		}

		NSDictionary * postDict = [NSDictionary dictionaryWithJSONData:postData error:&error];
		if (error)
		{
			NSLog(@"ERROR: 400 - Postdata is invalid");
			return [[HTTPErrorResponse alloc] initWithErrorCode:400];
		}
		NSString * relUrl = [postDict objectForKey:@"relUrl"];
		NSLog(@"relUrl: %@", relUrl);
		NSURL * localURL = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:[[requestForShare root] path], relUrl, nil]];
		if (![FileHelper fileFolderExists:[localURL path]])
		{
			NSLog(@"ERROR: 404 - File does not exist");
			return [[HTTPErrorResponse alloc] initWithErrorCode:404];
		}
		//NSLog(@"url: %@", rv);
	
		return [[HTTPAsyncEncryptedFileResponse alloc] initWithFilePath:[localURL path]
												  andPassword:[requestForShare secret]
												forConnection:self];
		/*
		return [[HTTPAsyncFileResponse alloc] initWithFilePath:[localURL path] forConnection:self];
		 */
	}
		
	return [[HTTPErrorResponse alloc] initWithErrorCode:400];
}


- (void)prepareForBodyWithSize:(UInt64)contentLength
{
	// only called with POST or PUT Requests
	//NSLog(@"%lld", contentLength);
	// If we supported large uploads,
	// we might use this method to create/open files, allocate memory, etc.
}


- (void)processBodyData:(NSData *)postDataChunk
{
	// Remember: In order to support LARGE POST uploads, the data is read in chunks.
	// This prevents a 50 MB upload from being stored in RAM.
	// The size of the chunks are limited by the POST_CHUNKSIZE definition.
	// Therefore, this method may be called multiple times for the same POST request.
	
	BOOL result = [request appendData:postDataChunk];
	if (!result)
	{
		NSLog(@"Couldn't append bytes!");
	}
}


@end
