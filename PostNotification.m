//
//  PostNotification.m
//  Peerbox
//
//  Created by Daniel on 30.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "PostNotification.h"

#import "Share.h"
#import "Constants.h"


@implementation PostNotification
{
	NSURLConnection * connection;
}


@synthesize request;


- (id) initWithNetService:(NSNetService*)n
{
	if ((self = [super init]))
	{
		request = [[NSMutableURLRequest alloc] init];
		[request setHTTPMethod:@"POST"];
		[request setCachePolicy:NSURLRequestUseProtocolCachePolicy];
		[request setTimeoutInterval:30];
		
		
		// Resolve IP and prepare URL:
		// http://<ip>/shares
		//-----------------------------
		NSURL * u	= [NSURL URLWithString:[NSString stringWithFormat:@"http://%@:%ld/notification",[n hostName], (long)[n port]]];
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
- (void) connection:(NSURLConnection*)connection
 didReceiveResponse:(NSURLResponse*)response
{
	if ([response respondsToSelector:@selector(statusCode)])
	{
		long statusCode = [((NSHTTPURLResponse *)response) statusCode];
		if (statusCode != 200)
		{
			DebugLog(@"HTTP-ERROR: didReceiveResponse statusCode: %li", statusCode);
			[self->connection cancel];  // stop connecting; no more delegate messages
		}
	}
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection
	didReceiveData:(NSData*)dataIn
{
	// there should be no data returned
	return;
}


// OVERRIDE
- (void) connection:(NSURLConnection*)connection
   didFailWithError:(NSError*)error
{
	// Handle the error properly
	DebugLog(@"Error: %@", error);
}


// OVERRIDE
- (void) connectionDidFinishLoading:(NSURLConnection*)connection
{
	return;
}



@end
