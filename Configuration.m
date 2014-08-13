//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import "Configuration.h"
#import "FileHelper.h"
#import "Constants.h"

@implementation Configuration

@synthesize webDir;
@synthesize workingDir;
@synthesize downloadsDir;


- (id) init
{
	if (self = [super init])
	{
		workingDir = [[NSString alloc] initWithString:[[FileHelper getDocumentsDirectory] stringByAppendingPathComponent:APP_NAME]];
		downloadsDir = [[[NSString alloc] initWithString:[[FileHelper getDocumentsDirectory] stringByAppendingPathComponent:APP_NAME]] stringByAppendingPathComponent:@"downloads"];
		webDir = [[[NSString alloc] initWithString:[[FileHelper getDocumentsDirectory] stringByAppendingPathComponent:APP_NAME]] stringByAppendingPathComponent:@"web"];
	}
	return self;
}


@end
