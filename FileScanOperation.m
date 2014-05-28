//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "FileScanOperation.h"

#import "Share.h"
#import "File.h"
#import "FileHelper.h"

@implementation FileScanOperation


@synthesize share;
@synthesize fileURL;


- (id)initWithURL: (NSURL*) u
	    andShare: (Share*) s
{
	if (self = [super init])
	{
		fileURL = u;
		share = s;
	}
	return self;
}


// Diese methode muss bei Subklassen
// von NSOperation überschrieben werden!

- (void) main
{
	return [share scanURL:fileURL];
}


@end