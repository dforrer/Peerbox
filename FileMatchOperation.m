//
//  Created by Daniel on 29.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "FileMatchOperation.h"
#import "DownloadFile.h"
#import "Share.h"
#import "Peer.h"
#import "Revision.h"
#import "FileHelper.h"
#import "File.h"



@implementation FileMatchOperation
{
	DownloadFile * d;
}



- (id) initWithDownloadFile:(DownloadFile*)dl
{
	if (self = [super init])
	{
		d = dl;
	}
	return self;
}



- (void) main
{
	Share    * share    = [[[d rev] peer] share];
	Revision * rev		= [d rev];
	
	NSURL * fullURL = [NSURL URLWithString:[rev relURL] relativeToURL:[share root]];
	
	// Continue matching the file

	if ( [[NSFileManager defaultManager] isReadableFileAtPath:[d downloadPath]] )
	{
		// Move existing file to the trash
	
		NSError * error;
		if ( [[NSFileManager defaultManager] isReadableFileAtPath:[fullURL path]] )
		{
			[[NSFileManager defaultManager] removeItemAtURL:fullURL error:&error];
			if (error)
			{
				NSLog(@"ERROR: removeItemAtURL failed!, %@", error);
				return;
			}
		}
		error = nil;
		if ([d downloadPath] != nil && [fullURL path] != nil)
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:[[fullURL URLByDeletingLastPathComponent] path]
								 withIntermediateDirectories:YES
											   attributes:nil
												   error:nil];
			BOOL successfullyMoved = [[NSFileManager defaultManager] moveItemAtPath:[d downloadPath] toPath:[fullURL path] error:&error];
			if (successfullyMoved == NO || error)
			{
				NSLog(@"ERROR: during moving of file an error occurred!, %@", error);
				return;
			}
		}
		else
		{
			NSLog(@"ERROR: downloadPath = %@, [fullURL path] = %@", [d downloadPath], [fullURL path]);
			return;
		}
	}
	else
	{
		NSLog(@"ERROR: Can't read file at %@", [d downloadPath]);
		return;
	}
	
	[FileHelper matchExtAttributes:[rev extAttributes] onURL:fullURL];

	[FileHelper setFilePermissionsAtPath:[fullURL path] toOctal:755];
	
	// Save the File with the updated versions
	
	File * newState = [[File alloc] initAsNewFileWithPath:[fullURL path]];
	[newState setVersions:[NSMutableDictionary dictionaryWithDictionary:[rev versions]]];
	[share setFile:newState];
	
}

@end
