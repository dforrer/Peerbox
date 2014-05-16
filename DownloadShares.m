//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

/*
 Request: GET to http://<server>/shares
 Response: JSON-String
 {
	"peerId":"8aed3573025b08170f8be3e305390953bc765c56",
	"shares":
	[
		{"shareId":"FHNW", "currentRev":15},
		{"shareId":"My Data", "currentRev":30423}
	]
 }
 */

// HEADER
#import "DownloadShares.h"

#import "NSDictionary_JSONExtensions.h"
#import "CJSONDeserializer.h"
#import "CJSONSerializer.h"
#import "FileHelper.h"
#import "DownloadRevisions.h"
#import "Share.h"
#import "Constants.h"


@implementation DownloadShares
{
	NSURLConnection* connection;
}


@synthesize request;
@synthesize response;
@synthesize isFinished;
@synthesize hasFailed;
@synthesize delegate;


- (id) initWithNetService:(NSNetService*)n
{
	if ((self = [super init]))
	{
		isFinished	= FALSE;
		hasFailed		= FALSE;
		request		= [[NSMutableURLRequest alloc] init];
		response		= [[NSMutableData alloc] init];
		[request setHTTPMethod:@"GET"];
		[request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
		[request setTimeoutInterval:30];
		
		
		// Resolve IP and prepare URL:
		// http://<ip>/shares
		//-----------------------------
		NSURL * u	= [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/shares",[n hostName], (long)[n port]]];
		[request setURL:u];
	}
	return self;
}


- (void) start
{
	// Starting the async request
	//----------------------------
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
	[connection start];
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response 
{
    [self->response setLength:0];
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)dataIn 
{
    [response appendData:dataIn];
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection didFailWithError:(NSError*)error 
{
	// Handle the error properly
	DebugLog(@"Error: %@", error);
	hasFailed = TRUE;
}


// OVERRIDE
- (void) connectionDidFinishLoading:(NSURLConnection*)connection
{
	isFinished = TRUE;
	
	// Convert NSData to NSDictionary
	//--------------------------------
	NSError * error;

	NSDictionary * dict = [NSDictionary dictionaryWithJSONData:response error:&error];

	if (error)
	{
		[delegate downloadSharesHasFailed];
	}
	else
	{
		[delegate downloadSharesHasFinishedWithResponseDict:dict];
	}
	return;
}	



@end
