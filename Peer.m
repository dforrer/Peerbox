//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "Peer.h"

#import <Foundation/Foundation.h>
#import "Revision.h"
#import "File.h"
#import "NSDictionary_JSONExtensions.h"
#import "SingleFileOperation.h"


@implementation Peer
{
	NSMutableDictionary * downloadedRevs; // key = relUrl
}



@synthesize currentRev;
@synthesize lastDownloadedRev;
@synthesize peerID;
@synthesize share;
@synthesize netService;
@synthesize config;
@synthesize revisionsDownload;



- (id) initWithPeerID:(NSString*)pid andShare:(Share*)s andConfig:(Configuration *)c
{
	if( self = [super init] )
	{
		downloadedRevs		= [NSMutableDictionary dictionary];
		currentRev		= [NSNumber numberWithLongLong:0];
		lastDownloadedRev	= [NSNumber numberWithLongLong:0];
		peerID			= pid;
		share			= s;
		config			= c;
	}
	return self;
}





- (NSDictionary*) allDownloadedRevs
{
	return downloadedRevs; // this is non-editable
}




- (void) matchRevisions
{
	NSArray * sortedKeys = [[downloadedRevs allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	for (id key in [sortedKeys reverseObjectEnumerator])
	{
		DebugLog(@"---------------------");
		DebugLog(@"key: %@", key);
		DebugLog(@"---------------------");
		Revision * r = [downloadedRevs objectForKey:key];
		[r match];
	}
}



- (void) addRevision:(Revision*)rev
{
	// Cancel ongoing rev->download if necessary
	//-------------------------------------------
	Revision * oldRev = [downloadedRevs objectForKey:[rev relURL]];
	if (oldRev && [oldRev download])
	{
		[[oldRev download] cancel];
	}
	[downloadedRevs setObject:rev forKey:[rev relURL]];
}





- (void) removeRevision:(Revision*)rev
{
	[downloadedRevs removeObjectForKey:[rev relURL]];
}





#pragma mark -----------------------
#pragma mark Implemented Interfaces (Protocols)


/**
 * OVERRIDE: RevisionDelegate
 */
- (void) revisionMatched:(Revision*) rev
{
	[self removeRevision:rev];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventIsFile" object:[[rev remoteState] url]];
}




#pragma mark -----------------------
#pragma mark Other


- (NSDictionary*) plistEncoded
{
	//DebugLog(@"plistEncoded: Peer");
	
	NSMutableDictionary * rv = [[NSMutableDictionary alloc] init];
	
	[rv setObject:currentRev forKey:@"currentRev"];
	[rv setObject:lastDownloadedRev forKey:@"lastDownloadedRev"];
	
	NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
	for (id key in downloadedRevs)
	{
		Revision * r = [downloadedRevs objectForKey:key];
		[dict setObject:[r plistEncoded] forKey:[r relURL]];
	}
	[rv setObject:dict forKey:@"revisions"];
	[rv setObject:peerID forKey:@"peerID"];
	
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
