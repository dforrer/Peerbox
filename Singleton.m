//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "Singleton.h"
#import "MainControlloer.h"

@implementation Singleton


@synthesize mainModel;


- (id) init
{
	if (self = [super init])
	{
		mainModel = [[MainControlloer alloc] init];
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