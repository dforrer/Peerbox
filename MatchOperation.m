//
//  Created by Daniel on 23.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "MatchOperation.h"
#import "MainControlloer.h"
#import "Share.h"
#import "Peer.h"
#import "Revision.h"
#import "Constants.h"

@implementation MatchOperation
{
	MainControlloer * mm;
}

-(id) initWithMainModel:(MainControlloer*)m
{
	if ((self = [super init]))
	{
		mm = m;
	}
	return self;
}

- (void) main
{
	DebugLog(@"MainModel: MatchOperation started");
	NSMutableDictionary * myShares = [mm getAllShares];
	
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		for (Peer * p in [s allPeers])
		{
			Revision * r = [s nextDownloadedRevisionForPeer:p];
			[r setDelegate:mm];
			[r match];
		}
	}
}


@end
