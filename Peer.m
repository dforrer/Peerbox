//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "Peer.h"

#import "Revision.h"
#import "NSDictionary_JSONExtensions.h"
#import "SingleFileOperation.h"
#import "Constants.h"


@implementation Peer
{

}



@synthesize currentRev;
@synthesize lastDownloadedRev;
@synthesize peerID;
@synthesize share;



- (id) initWithPeerID:(NSString*)pid andShare:(Share*)s
{
	if( self = [super init] )
	{
		currentRev		= [NSNumber numberWithLongLong:0];
		lastDownloadedRev	= [NSNumber numberWithLongLong:0];
		peerID			= pid;
		share			= s;
	}
	return self;
}





#pragma mark -----------------------
#pragma mark Implemented Interfaces (Protocols)







#pragma mark -----------------------
#pragma mark Other


- (NSDictionary*) plistEncoded
{
	//DebugLog(@"plistEncoded: Peer");
	
	NSMutableDictionary * rv = [[NSMutableDictionary alloc] init];
	[rv setObject:peerID forKey:@"peerID"];
	[rv setObject:currentRev forKey:@"currentRev"];
	[rv setObject:lastDownloadedRev forKey:@"lastDownloadedRev"];
	
	return rv;
}




/**
 * Makes the Object printable with NSLog(@"%@", (Share) s);
 */
- (NSString *) description
{
	return [NSString stringWithFormat: @"PeerID: %@; lastDownloadedRev: %@; currentRev: %@;", peerID, lastDownloadedRev, currentRev];
}

@end
