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


- (void) scanSubDirectoriesOfFile: (File*) f
{
	NSArray * dirTree = [FileHelper scanDirectoryRecursive:[f url]];
	for (NSURL * u in dirTree)
	{
		@autoreleasepool
		{
			if ([self isCancelled])
			{
				return;
			}
			if ([[u lastPathComponent] isEqualToString:@".DS_Store"])
			{
				continue;
			}
			File * f = [share getFileForURL:u];
			if (f == nil)
			{
				f = [[File alloc] initAsNewFileWithPath:[u path]];
				if (f == nil)
				{
					return;
				}
				[share setFile:f];
				continue;
			}
			[f setUrl:u];
			[f updateIsSet];
			[f updateFileSize];
			[f updateContentModDate];
			[f updateAttributesModDate];
			if ([f isEqualToFile:[share getFileForURL:u]])
			{
				continue;
			}
			[f updateExtAttributes];
			if (![f updateVersions])
			{
				return;
			}
			[share setFile:f];
		}
	}
}

// Diese methode muss bei Subklassen
// von NSOperation überschrieben werden!

- (void) main
{
	DebugLog(@"--- FileScanOperation");
	if ([FileHelper fileFolderExists:[fileURL path]])
	{
		// File exists on HD (ADDED/CHANGED)
		//-----------------------------------
		DebugLog(@"File exists on HD");
		File * f = [share getFileForURL:fileURL];
		[f setUrl:fileURL];
		
		if (f == nil)
		{
			// File doesn't exist in Share
			//-----------------------------
			DebugLog(@"File doesn't exist in Share");
			f = [[File alloc] initAsNewFileWithPath:[fileURL path]];
			if (f == nil)
			{
				return;
			}
			[share setFile:f];
			
			// CHECK for directory
			//---------------------
			if ([f isDir])
			{
				[self scanSubDirectoriesOfFile:f];
			}
		}
		else
		{
			// File exists in Share
			//----------------------
			DebugLog(@"File exists in Share");
			[f updateIsSet];
			[f updateFileSize];
			[f updateContentModDate];
			[f updateAttributesModDate];
			if ([f isEqualToFile:[share getFileForURL:fileURL]])
			{
				// DO NOTHING
				//------------
				DebugLog(@"DO NOTHING");
				return;
			}
			[f updateExtAttributes];
			if (![f updateVersions])
			{
				return;
			}
			[share setFile:f];
			
			// CHECK for directory
			//---------------------
			if ([f isDir])
			{
				[self scanSubDirectoriesOfFile: f];
			}
		}
	}
	else
	{
		// File doesn't exist on HD (DELETE)
		//-----------------------------------
		DebugLog(@"File doesn't exist on HD");
		File * f = [share getFileForURL:fileURL];
		if (f == nil)
		{
			// File doesn't exists in Share
			//------------------------------
			DebugLog(@"File doesn't exists in Share");
			// DO NOTHING
		}
		else
		{
			// File exists in Share
			DebugLog(@"File exists in Share");
			if ([f isDir])
			{
				// File is directory
				DebugLog(@"File is directory");
				NSArray * filesToDelete = [share getURLsBelowURL:[f url] withIsSet:YES];
				for (NSArray * a in filesToDelete)
				{
					@autoreleasepool
					{
						if ([self isCancelled])
						{
							return;
						}
						File * g	= [share getFileForURL:[NSURL URLWithString:a[0]]];
						DebugLog(@"filesToDelete: %@", a[0]);
						[g setIsSetBOOL:FALSE];
						[share setFile: g];
					}
				}
			}
			[f setIsSetBOOL:FALSE];
			[share setFile:f];
		}
	}
}


@end