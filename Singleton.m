//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "Singleton.h"
#import "DataModel.h"
#import "Configuration.h"

@implementation Singleton


@synthesize dataModel;
@synthesize config;
@synthesize myPeerID;

- (id) init
{
	if (self = [super init])
	{
		dataModel = [[DataModel alloc] init];
		config = [[Configuration alloc] init];
	}
	return self;
}


+ (id) data
{
	static Singleton *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});
	return sharedInstance;
 }



@end