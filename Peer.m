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
#import "Constants.h"


@implementation Peer
{
	NSMutableDictionary * downloadedRevsWithFilesToAdd; // key = relURL
	NSMutableDictionary * downloadedRevsWithIsSetFalse; // key = relURL
	NSMutableDictionary * downloadedRevsWithIsDirTrue;  // key = relURL
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
		downloadedRevsWithFilesToAdd	= [NSMutableDictionary dictionary];
		downloadedRevsWithIsSetFalse	= [NSMutableDictionary dictionary];
		downloadedRevsWithIsDirTrue	= [NSMutableDictionary dictionary];
		currentRev		= [NSNumber numberWithLongLong:0];
		lastDownloadedRev	= [NSNumber numberWithLongLong:0];
		peerID			= pid;
		share			= s;
		config			= c;
	}
	return self;
}


- (NSDictionary*) downloadedRevsWithFilesToAdd
{
	return downloadedRevsWithFilesToAdd; // this is non-editable
}



- (NSDictionary*) downloadedRevsWithIsSetFalse
{
	return downloadedRevsWithIsSetFalse; // this is non-editable
}



- (NSDictionary*) downloadedRevsWithIsDirTrue
{
	return downloadedRevsWithIsDirTrue; // this is non-editable
}


- (Revision *) revisionForRelURL:(NSString*) relURL
{
	Revision * oldRev = [downloadedRevsWithIsSetFalse objectForKey:relURL];
	if (oldRev)
	{
		return oldRev;
	}
	oldRev = [downloadedRevsWithIsDirTrue objectForKey:relURL];
	if (oldRev)
	{
		return oldRev;
	}
	oldRev = [downloadedRevsWithFilesToAdd objectForKey:relURL];
	if (oldRev)
	{
		return oldRev;
	}
	return nil;
}


- (void) addRevision:(Revision*)rev
{
	// Cancel ongoing rev->download if necessary
	//-------------------------------------------
	Revision * oldRev = [self revisionForRelURL:[rev relURL]];
	if (oldRev && [oldRev download])
	{
		[[oldRev download] cancel];
	}
	
	// Switch between the 3 NSDictionaries to add revisions to
	//---------------------------------------------------------
	if ([[rev isSet] boolValue] == FALSE)
	{
		[downloadedRevsWithIsSetFalse  setObject:rev forKey:[rev relURL]];
	}
	else if ([rev isDir])
	{
		[downloadedRevsWithIsDirTrue  setObject:rev forKey:[rev relURL]];
	}
	else
	{
		[downloadedRevsWithFilesToAdd setObject:rev forKey:[rev relURL]];
	}
}





- (void) removeRevision:(Revision*)rev
{
	[downloadedRevsWithIsSetFalse removeObjectForKey:[rev relURL]];
	[downloadedRevsWithIsDirTrue removeObjectForKey:[rev relURL]];
	[downloadedRevsWithFilesToAdd removeObjectForKey:[rev relURL]];
}


/**
 * Returns MAX_CONCURRENT_DOWNLOADS number of Revisions
 * from 'downloadedRevsWithFilesToAdd'
 */
- (NSArray*) getNextFileRevisions:(int)count
{
	if (count <= 0)
	{
		return [NSArray array];
	}
	
	NSMutableArray * a = [[NSMutableArray alloc] init];
	for (Revision * r in downloadedRevsWithFilesToAdd)
	{
		count--;
		[a addObject:r];
		if (count == 0)
		{
			break;
		}
	}
	return a;
}



#pragma mark -----------------------
#pragma mark Implemented Interfaces (Protocols)







#pragma mark -----------------------
#pragma mark Other


- (NSDictionary*) plistEncoded
{
	//DebugLog(@"plistEncoded: Peer");
	
	NSMutableDictionary * rv = [[NSMutableDictionary alloc] init];
	
	NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
	
	// Encode the revisions stored in the 3 NSDictionaries "downloadedRevs..."
	//-------------------------------------------------------------------------
	for (id key in downloadedRevsWithIsSetFalse)
	{
		Revision * r = [downloadedRevsWithIsSetFalse objectForKey:key];
		[dict setObject:[r plistEncoded] forKey:[r relURL]];
	}
	for (id key in downloadedRevsWithIsDirTrue)
	{
		Revision * r = [downloadedRevsWithIsDirTrue objectForKey:key];
		[dict setObject:[r plistEncoded] forKey:[r relURL]];
	}
	for (id key in downloadedRevsWithFilesToAdd)
	{
		Revision * r = [downloadedRevsWithFilesToAdd objectForKey:key];
		[dict setObject:[r plistEncoded] forKey:[r relURL]];
	}
	
	[rv setObject:dict forKey:@"revisions"];
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
