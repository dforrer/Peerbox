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
	Share * share		= [[[d rev] peer] share];
	Revision * revision	= [d rev];
	
	NSURL * fullURL = [NSURL URLWithString:[revision relURL] relativeToURL:[share root]];
	
	// Continue matching the file
	//----------------------------
	if ( [[NSFileManager defaultManager] isReadableFileAtPath:[d downloadPath]] )
	{
		// Move existing file to the trash
		//---------------------------------
		NSError * error;
		if ( [[NSFileManager defaultManager] isReadableFileAtPath:[fullURL path]] )
		{
			[[NSFileManager defaultManager] removeItemAtURL:fullURL error:&error];
			if (error)
			{
				DebugLog(@"ERROR: removeItemAtURL failed!, %@", error);
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
			[[NSFileManager defaultManager] moveItemAtPath:[d downloadPath] toPath:[fullURL path] error:&error];
			if (error)
			{
				DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
				return;
			}
		}
	}
	
	// Set extended attributes
	//-------------------------
	for (id key in [revision extAttributes])
	{
		NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[revision extAttributes] objectForKey:key] options:0];
		[FileHelper setValue:extAttrBinary forName:key onFile:[fullURL path]];
	}
	
	File * newState = [[File alloc] initAsNewFileWithPath:[fullURL path]];
	[newState setVersions:[NSMutableDictionary dictionaryWithDictionary:[revision versions]]];
	[share setFile:newState];
}

@end
