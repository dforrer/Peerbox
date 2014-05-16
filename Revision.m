//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import "Revision.h"

#import "Share.h"
#import "Peer.h"
#import "File.h"
#import "FileHelper.h"
#import "BonjourSearcher.h"
#import "Configuration.h"


@implementation Revision
{
	NSString * myPeerID;
}


@synthesize relURL, revision, isSet, extAttributes, versions;
@synthesize peer, download, lastMatchAttempt, absoluteURL, remoteState, isDir;
@synthesize delegatePeer, config;



- (id) initWithRelURL:(NSString*)u
		andRevision:(NSNumber*)r
		   andIsSet:(NSNumber*)i
		 andExtAttr:(NSDictionary*)e
		andVersions:(NSDictionary*)v
		    andPeer:(Peer*)p
		  andConfig:(Configuration*)c;
{
	if ((self = [super init]))
	{
		// Core information from the response
		//------------------------------------
		relURL = u;
		revision = r;
		isSet = i;
		extAttributes = [NSMutableDictionary dictionaryWithDictionary:e];
		versions = [NSMutableDictionary dictionaryWithDictionary:v];
		
		// Additional Info
		//-----------------
		peer = p;
		lastMatchAttempt = nil;
		download = nil;
		config = c;

		[self helperInit];
	}
	return self;
}



/**
 * Generates all the additional attributes
 */
- (void) helperInit
{
	absoluteURL = [NSURL URLWithString:relURL relativeToURL:[[peer share] root]];
	remoteState = [[File alloc] initWithShare:[peer share] relUrl:relURL isSet:isSet extAttributesAsBase64:extAttributes versions:versions];
	isDir = [remoteState isDir];
	
	myPeerID = [config myPeerID];
	
	// Set the delegate of the revision to this peer-instance
	//--------------------------------------------------------
	delegatePeer = peer;
}



- (NSDictionary*) plistEncoded
{
	DebugLog(@"plistEncoded: Revision");

	NSMutableDictionary * rv = [[NSMutableDictionary alloc] init];
	
	[rv setObject:relURL		forKey:@"relURL"];
	[rv setObject:revision		forKey:@"revision"];
	[rv setObject:isSet			forKey:@"isSet"];
	[rv setObject:extAttributes	forKey:@"extAttributes"];
	[rv setObject:versions		forKey:@"versions"];

	return rv;
}



/**
 * Matches the directory immedeatly or starts the download of the file
 * for later matching.
 */
- (void) match
{
	DebugLog(@"---------------------");
	DebugLog(@"match");
	[self updateLastMatchAttempt];
	
	// match directory
	//-----------------
	if (isDir)
	{
		[self matchDir];
		return [delegatePeer revisionMatched:self];
	}
	
	// match 'normal' files
	//----------------------
	[self handleFileConflicts];
}

/*
 * Revision = Directory
 */
- (void) matchDir
{
	if ([[remoteState isSet] intValue] == 1)
	{
		// Revision = ADD-Directory
		//--------------------------
		DebugLog(@"ADD-Directory");
		NSError * error = nil;
		[[NSFileManager defaultManager] createDirectoryAtURL:[remoteState url] withIntermediateDirectories:YES attributes:nil error:&error];
		if (error != nil)
		{
			DebugLog(@"ERROR creating directory: %@", error);
			return;
		}
		
		// Set extended attributes
		// This works, but does not dispaly correctly in the Finder
		//----------------------------------------------------------
		for (id key in [remoteState extAttributes])
		{
			NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[remoteState extAttributes] objectForKey:key] options:0];
			[FileHelper setValue:extAttrBinary forName:key onFile:[[remoteState url] path]];
		}
	}
	else
	{
		// Revision = DELETE-Directory
		//-----------------------------
		DebugLog(@"DEL-Directory");
		if ([FileHelper fileFolderExists:[[remoteState url] path]])
		{
			// C implementation
			//------------------
			chdir([[[remoteState url] path] cStringUsingEncoding:NSUTF8StringEncoding]);
			remove(".DS_Store");
			int rv = rmdir([[[remoteState url] path] cStringUsingEncoding:NSUTF8StringEncoding]);
			if (rv != 0)
			{
				DebugLog(@"DEL of Dir failed, there must be other files in this directory");
				[remoteState setIsSetBOOL:FALSE];
				[[peer share] setFile:remoteState];
			}
		}
	}
}


- (BOOL) isZeroLengthFile
{
	return [[remoteState getLastVersionHash] isEqualToString:@"da39a3ee5e6b4b0d3255bfef95601890afd80709"];
}


- (void) matchZeroLengthFile
{
	DebugLog(@"matchZeroLengthFile");
	
	// Create empty file
	//-------------------
	[[NSFileManager defaultManager] createFileAtPath:[[remoteState url] path] contents:nil attributes:nil];
	
	// Set extended attributes
	//-------------------------
	for (id key in [remoteState extAttributes])
	{
		NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[remoteState extAttributes] objectForKey:key] options:0];
		[FileHelper setValue:extAttrBinary forName:key onFile:[[remoteState url] path]];
	}
	
	// Set remoteState in Share s
	//----------------------------
	/*
	 File * newState = [[File alloc] initAsNewFileWithPath:[[remoteState url] path]];
	 [newState setVersions:[remoteState versions]];
	 [[peer share] setFile:newState];
	 */
}


/*
 * No conflict resolution is done here
 */
- (void) matchRemoteState
{
	DebugLog(@"matchRemoteState");
	
	// match zero-length files
	//-------------------------
	if ([self isZeroLengthFile])
	{
		[self matchZeroLengthFile];
		return [delegatePeer revisionMatched:self];
	}
	
	if (!download)
	{
		// Start the download of the file
		//--------------------------------
		download = [[DownloadFile alloc] initWithNetService:[peer netService] andRevision:self andConfig:config];
		[download setDelegate:self];
		[download start];
		return;
	}
}



/*
 * OVERRIDE: Delegate function called by "download" inherited from <DownloadFileDelegate>
 */
- (void) downloadFileHasFinished:(DownloadFile*)d
{
	// Continue matching the file
	//----------------------------
	if ( [[NSFileManager defaultManager] isReadableFileAtPath:[download downloadPath]] )
	{
		// Move existing file to the trash
		//---------------------------------
		NSError * error;
		if ( [[NSFileManager defaultManager] isReadableFileAtPath:[[remoteState url] path]] )
		{
			[[NSFileManager defaultManager] removeItemAtURL:[remoteState url] error:&error];
			if (error)
			{
				DebugLog(@"ERROR: removeItemAtURL failed!, %@", error);
				return [delegatePeer revisionMatched:self];
			}
		}
		error = nil;
		if ([download downloadPath] != nil && [[remoteState url] path] != nil)
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:[[[remoteState url] URLByDeletingLastPathComponent] path]
								 withIntermediateDirectories:YES
											   attributes:nil
												   error:nil];
			[[NSFileManager defaultManager] moveItemAtPath:[download downloadPath] toPath:[[remoteState url] path] error:&error];
			if (error)
			{
				DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
				return [delegatePeer revisionMatched:self];
			}
		}
	}
	
	// Set extended attributes
	//-------------------------
	for (id key in [remoteState extAttributes])
	{
		NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[remoteState extAttributes] objectForKey:key] options:0];
		[FileHelper setValue:extAttrBinary forName:key onFile:[[remoteState url] path]];
	}
	
	File * newState = [[File alloc] initAsNewFileWithPath:[[remoteState url] path]];
	[newState setVersions:[remoteState versions]];
	[[peer share] setFile:newState];
	
	// Informing the peer (delegate) that this
	// revision has been successfully matched
	//-----------------------------------------
	return [delegatePeer revisionMatched:self];
}

/*
 * OVERRIDE: Delegate function called by "download" inherited from <DownloadFileDelegate>
 */
- (void) downloadFileHasFailed:(DownloadFile*)d
{
	DebugLog(@"ERROR: downloadFileHasFailed");
	[delegatePeer revisionMatched:self];
	//download = nil;
}


- (void) updateLastMatchAttempt
{
	lastMatchAttempt = [NSDate date];
}

- (void) createConflictedCopy
{
	File * localState = [[peer share] getFileForURL:[remoteState url]];
	
	// Create CONFLICTEDCOPY
	//-----------------------
	NSError * error;
	NSURL * conflictedCopyURL;
	if ( [[NSFileManager defaultManager] isReadableFileAtPath:[[localState url] path]] )
	{
		// Rename localState-File to "xxx conflicted copy on abc193848.xxx"
		//------------------------------------------------------------------
		NSURL * superdir = [[remoteState url] URLByDeletingLastPathComponent];
		NSString * oldFilename = [[[remoteState url] lastPathComponent] stringByDeletingPathExtension];
		NSString * newFilename = [oldFilename stringByAppendingString:[NSString stringWithFormat:@" conflicted copy on %@", myPeerID]];
		newFilename = [newFilename stringByAppendingPathExtension:[[remoteState url] pathExtension]];
		conflictedCopyURL = [superdir URLByAppendingPathComponent:newFilename];
		
		[[NSFileManager defaultManager] moveItemAtPath:[[localState url] path] toPath:[conflictedCopyURL path] error:&error];
		if (error)
		{
			DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
		}
		
		// Force FSWatcher to rescan this file
		//-------------------------------------
		[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventIsFile" object:conflictedCopyURL];
	}
}

/*
 *
 */
- (void) handleFileConflicts
{
	File * localState = [[peer share] getFileForURL:[remoteState url]];
	
	// localState is NOT set, remotestate is set (ADD new file)
	//----------------------------------------------------------
	if ( ([[localState isSet] intValue] == 0 || localState == nil) && [[remoteState isSet] intValue] == 1)
	{
		DebugLog(@"A");
		
		// (No checking for conflicts)
		
		// Delete localState
		//-------------------
		[[peer share] removeFile:localState];
		
		// Match remoteState
		//-------------------
		[self matchRemoteState];
		
		return;
	}
	
	
	// localState is NOT set, remotestate is NOT set (DELETE non-existing file)
	//-----------------------------------------------------------------------------
	if ( ([[localState isSet] intValue] == 0 || localState == nil) && [[remoteState isSet] intValue] == 0)
	{
		DebugLog(@"B  (doing nothing)");
		return [delegatePeer revisionMatched:self];
	}
	
	
	// localState is set, remotestate is NOT set (DELETE file)
	//---------------------------------------------------------
	if ( [[localState isSet] intValue] == 1 && [[remoteState isSet] intValue] == 0)
	{
		DebugLog(@"C");
		
		// check for conflicts
		//---------------------
		if ([remoteState hasConflictingVersionsWithFile:localState])
		{
			DebugLog(@"C1");
			
			// (WITH CONFLICT)
			
			[self createConflictedCopy];
			
			// Delete localState
			//-------------------
			[[peer share] removeFile:localState];
			
			return;
		}
		else
		{
			DebugLog(@"C2");
			
			// (WITHOUT CONFLICT)
			
			// Make sure we only delete a file...
			// if the remoteState->Versions is bigger than on localState
			//-----------------------------------------------------------
			if ([[localState getLastVersionKey] intValue] <= [[remoteState getLastVersionKey] intValue])
			{
				// Delete FILE
				//-------------
				NSError * error;
				if ( [[NSFileManager defaultManager] isReadableFileAtPath:[[remoteState url] path]] )
				{
					// Move existing file to the trash
					//---------------------------------
					[[NSFileManager defaultManager] removeItemAtURL:[remoteState url] error:&error];
					
					if (error)
					{
						DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
						[remoteState setIsSetBOOL:FALSE];
						[[peer share] setFile:remoteState];
					}
				}
			}
			[delegatePeer revisionMatched:self];
			return;
		}
		
	}
	
	
	// localState is set, remotestate is set (ADD file, but there may be a conflicts)
	//--------------------------------------------------------------------------------
	if ( [[localState isSet] intValue] == 1 && [[remoteState isSet] intValue] == 1)
	{
		DebugLog(@"D");
		// check for conflicts
		//---------------------
		if ([remoteState hasConflictingVersionsWithFile:localState])
		{
			DebugLog(@"D1");
			// (WITH CONFLICT)
			
			if ([myPeerID isLessThan:[peer peerID]])
			{
				// (myPeerId < otherPeerId)
				[self createConflictedCopy];
						
				/*
				// Create CONFLICTEDCOPY
				//-----------------------
				NSError * error;
				NSURL * conflictedCopyURL;
				if ( [[NSFileManager defaultManager] isReadableFileAtPath:[[localState url] path]] )
				{
					// Rename localState-File to "xxx conflicted copy on abc193848.xxx"
					//-----------------------------------------------------------------
					NSURL * superdir = [[remoteState url] URLByDeletingLastPathComponent];
					NSString * oldFilename = [[[remoteState url] lastPathComponent] stringByDeletingPathExtension];
					NSString * newFilename = [oldFilename stringByAppendingString:[NSString stringWithFormat:@" conflicted copy on %@", myPeerID]];
					newFilename = [newFilename stringByAppendingPathExtension:[[remoteState url] pathExtension]];
					conflictedCopyURL = [superdir URLByAppendingPathComponent:newFilename];
					
					[[NSFileManager defaultManager] moveItemAtPath:[[localState url] path] toPath:[conflictedCopyURL path] error:&error];
					if (error)
					{
						DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
					}
				}
				*/
				
				// Delete localState
				//-------------------
				[[peer share] removeFile:localState];
				
				// Match remoteState
				//-------------------
				return [self matchRemoteState];
			}
			else
			{
				// (myPeerId >= otherPeerId)
				DebugLog(@"DO NOTHING because myPeerId >= otherPeerId");
				
				// DO NOTHING
				return [delegatePeer revisionMatched:self];
			}
		}
		else
		{
			DebugLog(@"D2");
			
			// (WITHOUT CONFLICT)
			
			if ([[localState getLastVersionKey] intValue] < [[remoteState getLastVersionKey] intValue])
			{
				// (localState:versions:biggestKey < remoteState:versions:biggestKey)
				
				// Delete localState
				//-------------------
				[[peer share] removeFile:localState];
				
				// Match remoteState
				//-------------------
				return [self matchRemoteState];
			}
			else
			{
				// (localState:versions:biggestKey >= remoteState:versions:biggestKey)
				
				// DO NOTHING
				return [delegatePeer revisionMatched:self];
			}
		}
	}
}


@end
