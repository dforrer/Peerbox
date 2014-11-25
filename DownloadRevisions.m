//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

/*

{
	"peerId":"8aed3573025b08170f8be3e305390953bc765c56",
	"revisions":
	{
		"Google/ABC.txt":
		{
			"revision":13 ,
			"isSet":1,
			"extendedAttributes":
			{
			},
			"versions":
			{
				"1":"521d3573025b08170f8be3e305390953bc765c56"
			}
		},
		"Apple/":
		{
			"revision":15,
			"isSet":0,
			"extendedAttributes":
			{
			},
			"versions":
			{
				"1":"0"
			}
		}
	}
}
 
*/


// HEADER
#import "DownloadRevisions.h"

#import <Foundation/Foundation.h>
#include <arpa/inet.h>
#import "NSDictionary_JSONExtensions.h"
#import "CJSONDeserializer.h"
#import "CJSONSerializer.h"
#import "FileHelper.h"
#import "Share.h"
#import "Peer.h"
#import "RNDecryptor.h"
#import "RNEncryptor.h"
#import "NSDataGZipCategory.h"
#import "Configuration.h"



@implementation DownloadRevisions
{
	NSURLConnection * connection;
}



@synthesize request;
@synthesize response;
@synthesize isFinished;
@synthesize peer;
@synthesize delegate;



- (id) initWithNetService:(NSNetService*)netService andPeer:(Peer*)p
{
	if ( self = [super init] )
	{ // superclass could create its object
		peer = p;
		isFinished	= FALSE;
		request		= [[NSMutableURLRequest alloc] init];
		response		= [[NSMutableData alloc] init];
		[request setHTTPMethod:@"POST"];
		[request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
		[request setTimeoutInterval:30];
		
		// Resolve IP and prepare URL:
		// http://<hostname>/shares/<shareId>/revisionsDict
		
		NSString * shareIDurlEncoded = [[[peer share] shareId] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		
		NSURL* u = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/shares/%@/revisionsDict", [netService hostName], [netService port], shareIDurlEncoded]];
		[request setURL:u];
		
		// Prepare POST-Data
	
		//NSLog(@"fromRev: %@",[peer lastDownloadedRev]);
		NSMutableDictionary * postData = [NSMutableDictionary dictionary];
		[postData setObject:[NSNumber numberWithLongLong:[[peer lastDownloadedRev] longLongValue] + 1] forKey:@"fromRev"];
		NSError * error;
		NSData * json = [[CJSONSerializer serializer] serializeObject:postData error:&error];
		//NSLog(@"json: %@", postData);
		if (error)
		{
			NSLog(@"ERROR 10: CJSON-Serializer failed: %@", error);
		}
		json = [RNEncryptor encryptData:json
					    withSettings:kRNCryptorAES256Settings
						   password:[[peer share] secret]
							 error:&error];
		[request setHTTPBody:json];
	}
	return self;
}

- (void) start
{
	// Starting the async request

	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[connection start];
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection
 didReceiveResponse:(NSURLResponse*)response
{
	[self->response setLength:0];
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection
	didReceiveData:(NSData*)dataIn
{
	[response appendData:dataIn];
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection
   didFailWithError:(NSError*)error
{
	// Handle the error properly
	
	NSLog(@"Error: %@",error);
	
	[delegate downloadRevisionsHasFailed:self];
}


// OVERRIDE
- (void) connectionDidFinishLoading:(NSURLConnection*)connection
{
	isFinished = TRUE;

	// Decrypt Data
	
	NSError * error;
	NSData * responseData = [RNDecryptor decryptData:response
								 withPassword:[[peer share] secret]
									   error:&error];
	if (error)
	{
		NSLog(@"During decryption an error occurred!");
		return;
	}

//	NSLog(@"Size before inflation: %lu",(unsigned long)[response length]);
	
	// Decompress response
	
	response = [NSMutableData dataWithData:[responseData gzipInflate]];

//	NSLog(@"Size after inflation: %lu",(unsigned long)[response length]);
	
	[delegate downloadRevisionsHasFinished:self];
 
}


@end