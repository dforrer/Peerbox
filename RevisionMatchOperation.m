//
//  Created by Daniel on 23.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import "RevisionMatchOperation.h"
#import "MainController.h"
#import "Share.h"
#import "Peer.h"
#import "File.h"
#import "Revision.h"
#import "Constants.h"
#import "FileHelper.h"
#import "Configuration.h"
#import "Singleton.h"

@implementation RevisionMatchOperation
{
	Revision		* rev;
	NSURL		* fullURL;
	File			* localState;
	File			* remoteState;
}

- (id) initWithRevision:(Revision*)r
{
	if (self = [super init])
	{
		rev	   = r;
		fullURL = [NSURL URLWithString:[rev relURL] relativeToURL:[[[rev peer] share] root]];
	}
	return self;
}

- (void) main
{
	[self match];
}


/**
 * Matches the directory immedeatly or starts the download of the file
 * for later matching.
 */
- (void) match
{
	//NSLog(@"match: %@", fullURL);
	
	localState  = [[[rev peer] share] getFileForURL:fullURL];
	remoteState = [[File alloc] initWithShare:[[rev peer] share]
								relUrl:[rev relURL]
								 isSet:[rev isSet]
						   extAttributes:[rev extAttributes]
							   versions:[NSMutableDictionary dictionaryWithDictionary:[rev versions]]
							  isSymlink:[rev isSymlink]
							 targetPath:[rev targetPath]];
	
	if ([localState isCoreEqualToFile:remoteState])
	{
		//NSLog(@"match: isCoreEqualToFile -> YES");
		return;
	}
	
	
	// match directory / match file
	
	if ([[rev isSymlink] boolValue])
	{
		[self matchSymlink];
	}
	else if ([[rev isDir] boolValue])
	{
		[self matchDir];
	}
	else
	{
		/*
		 * Remove Revision from db:
		 * in case a file was added, not yet downloaded
		 * and deleted again.
		 */
		
		[[[rev peer] share] removeRevision:rev
							  forPeer:[rev peer]];
		
		// match 'normal' files
	
		[self matchFile];
	}
	
	/*
	 * Force FSWatcher to rescan this file:
	 * Why? Because otherwise a file/folder is created
	 * without the program knowing about.
	 */
	
	[[[rev peer] share] scanURL:fullURL
				   recursive:NO];
}




- (void) matchSymlink
{
	if ([[rev isSet] intValue] == 1)
	{
		// Revision = ADD-Symlink
		//--------------------------
		NSLog(@"ADD-Symlink");
		int rv = symlink([[remoteState targetPath] cStringUsingEncoding:NSUTF8StringEncoding], [[[remoteState url] path] cStringUsingEncoding:NSUTF8StringEncoding]);
		if (rv != 0)
		{
			NSLog(@"Error creating symlink\ntargetPath:%@\nurl:%@",[remoteState targetPath],[[remoteState url] path]);
			NSLog(@"errno: %s",strerror(errno));
			return;
		}
		/*
		// Symlinks can have permissions, but they are applied to the destination
		[FileHelper setFilePermissionsAtPath:[fullURL path] toOctal:755];
		 */
	}
	else
	{
		if ([FileHelper fileFolderSymlinkExists:[fullURL path]])
		{
			// Revision = DELETE-Symlink (C implementation)
			//----------------------------------------------
			int rv = remove([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
			
			if (rv != 0)
			{
				NSLog(@"ERROR: during deleting of symlink an error occurred!");
				
				/*
				 * Because DELETE failed, we set isSet
				 * to FALSE, so that it will be added
				 * again after a rescan.
				 */
				[localState setIsSetBOOL:FALSE];
				[[[rev peer] share] setFile:localState];
			}
		}
	}
	
}


/*
 * Revision = Directory
 */
- (void) matchDir
{
	if ([[rev isSet] intValue] == 1)
	{
		// Revision = ADD-Directory
		//--------------------------
		NSLog(@"ADD-Directory");
		NSError * error = nil;
		[[NSFileManager defaultManager] createDirectoryAtURL:fullURL withIntermediateDirectories:YES attributes:nil error:&error];
		if (error != nil)
		{
			NSLog(@"ERROR creating directory: %@", error);
			return;
		}
		
		[FileHelper matchExtAttributes:[rev extAttributes] onURL:fullURL];
		[FileHelper setFilePermissionsAtPath:[fullURL path] toOctal:755];
	}
	else
	{
		if ([FileHelper fileFolderSymlinkExists:[fullURL path]])
		{
			// Revision = DELETE-Directory (C implementation)
			//------------------------------------------------
			chdir([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
			remove(".DS_Store");
			int rv = rmdir([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
			if (rv != 0)
			{
				NSLog(@"DEL of Dir failed, there must be other files in this directory");
				
				/*
				 * Because DELETE failed, we set isSet
				 * to FALSE, so that it will be added
				 * again after a rescan.
				 */
				
				[localState setIsSetBOOL:FALSE];
				[[[rev peer] share] setFile:localState];
			}
		}
	}
}



/**
 * Handles File-conflicts
 */
- (void) matchFile
{
	/*
	 * localState is NOT set, remotestate is set (ADD new file)
	 */
	
	if (([[localState isSet] intValue] == 0 || localState == nil)
	    && [[rev isSet] intValue] == 1)
	{
		//NSLog(@"A");
		
		// We intentionally don't check for conflicts
		
		// Match remoteState
	
		[self executeMatch];
		
		return;
	}
	
	
	/*
	 * localState is NOT set, remotestate is NOT set (DELETE non-existing file)
	 */
	
	if (([[localState isSet] intValue] == 0 || localState == nil)
	    && [[rev isSet] intValue] == 0)
	{
		//NSLog(@"B  (doing nothing)");
	}
	
	
	/*
	 * localState is set, remotestate is NOT set (DELETE file)
	 */
	
	if ( [[localState isSet] intValue] == 1
	    && [[rev isSet] intValue] == 0)
	{
		//NSLog(@"C");
		
		// check for conflicts
		
		if ([File versions:[rev versions] hasConflictsWithVersions:[localState versions]])
		{
			//NSLog(@"C1");
			
			// (WITH CONFLICT)
			
			NSURL* conflictedCopyURL = [self createConflictedCopy];
			
			[[[rev peer] share] scanURL:conflictedCopyURL recursive:NO];
			
			return;
		}
		else
		{
			//NSLog(@"C2");
			
			// (WITHOUT CONFLICT)
			
			// Make sure we only delete a file...
			// if the remoteState->Versions is bigger than on localState
		
			if ([[localState getLastVersionKey] intValue] <= [[rev getLastVersionKey] intValue])
			{
				// Delete FILE
			
				int rv = remove([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
				
				if (rv != 0)
				{
					NSLog(@"ERROR: during moving of file an error occurred!");
					
					/*
					 * Because DELETE failed, we set isSet
					 * to FALSE, so that it will be added
					 * again after a rescan.
					 */
					[localState setIsSetBOOL:FALSE];
					[[[rev peer] share] setFile:localState];
				}
			}
			return;
		}
		
	}
	
	
	
	/*
	 * localState is set, remotestate is set
	 * (ADD file, but there may be a conflicts)
	 */
	
	if ([[localState isSet] intValue] == 1
	    && [[rev isSet] intValue] == 1)
	{
		//NSLog(@"D");
		// check for conflicts

		if ([File versions:[rev versions] hasConflictsWithVersions:[localState versions]])
		{
			//NSLog(@"D1");
			// WITH CONFLICT
		
			if ([[[Singleton data] myPeerID] isLessThan:[[rev peer] peerID]])
			{
				// myPeerId < otherPeerId
			
				NSURL* conflictedCopyURL = [self createConflictedCopy];
				
				[[[rev peer] share] scanURL:conflictedCopyURL recursive:NO];
				
				// Match remoteState
			
				return [self executeMatch];
			}
			else
			{
				// myPeerId >= otherPeerId
				
				//NSLog(@"DO NOTHING because myPeerId >= otherPeerId");
				
				// DO NOTHING
			}
		}
		else
		{
			//NSLog(@"D2");
			
			// WITHOUT CONFLICT
			
			if ([[localState getLastVersionKey] intValue] < [[rev getLastVersionKey] intValue])
			{
				// Match remoteState
			
				return [self executeMatch];
			}
			else
			{
				[FileHelper matchExtAttributes:[rev extAttributes] onURL:fullURL];
				
				// DO NOTHING
			}
		}
	}
}



/*
 * At this point, the conflict resolution has
 * already happened in "matchFile"
 */

- (void) executeMatch
{
	//NSLog(@"matchRemoteState");
	
	// Store Revision in Share->db, if the file requires a download

	if (![rev canBeMatchedInstantly])
	{
		//NSLog(@"Revision CAN'T be matched instantly");
		[[[rev peer] share] setRevision:rev forPeer:[rev peer]];
		return;
	}
	
	// match zero-length files
	
	if ([rev isZeroLengthFile])
	{
		[self createZeroLengthFile];
	}
}



- (void) createZeroLengthFile
{
	NSLog(@"matchZeroLengthFile");
	
	// Delete FILE (because writeData:[NSData data] doesn't work)
	
	remove([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
	
	
	if (![FileHelper fileFolderExists:[[fullURL URLByDeletingLastPathComponent] path]])
	{
		NSError * error = nil;
		[[NSFileManager defaultManager] createDirectoryAtURL:[fullURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
		if (error != nil)
		{
			NSLog(@"ERROR creating directory: %@", error);
			return;
		}
	}
	
	// Create empty file
	
	NSFileHandle * fh = [FileHelper fileForWritingAtPath:[fullURL path]];
	
	if (fh == nil)
	{
		NSLog(@"ERROR: Failure to create empty file at %@", [fullURL path]);
		
		return;
	}
	
	//[fh writeData:[NSData data]];
	[fh closeFile];
	
	[FileHelper matchExtAttributes:[rev extAttributes] onURL:fullURL];
	[FileHelper setFilePermissionsAtPath:[fullURL path] toOctal:755];
	
	// Set remoteState in Share s

	File * newState = [[File alloc] initAsNewFileWithPath:[fullURL path]];
	[newState setVersions:[remoteState versions]];
	[[[rev peer] share] setFile:newState];
}



- (NSURL*) createConflictedCopy
{
	// Create CONFLICTEDCOPY
	
	NSError * error;
	NSURL * conflictedCopyURL;
	if ( [[NSFileManager defaultManager] isReadableFileAtPath:[[localState url] path]] )
	{
		// Rename localState-File to "xxx conflicted copy on abc193848.xxx"
	
		NSURL * superdir = [fullURL URLByDeletingLastPathComponent];
		NSString * oldFilename = [[fullURL lastPathComponent] stringByDeletingPathExtension];
		NSString * newFilename = [oldFilename stringByAppendingString:[NSString stringWithFormat:@" conflicted copy on %@", [[Singleton data] myPeerID]]];
		newFilename = [newFilename stringByAppendingPathExtension:[fullURL pathExtension]];
		conflictedCopyURL = [superdir URLByAppendingPathComponent:newFilename];
		
		[[NSFileManager defaultManager] moveItemAtPath:[[localState url] path] toPath:[conflictedCopyURL path] error:&error];
		if (error)
		{
			NSLog(@"ERROR: during moving of file an error occurred!, %@", error);
			return nil;
		}
		[FileHelper setFilePermissionsAtPath:[conflictedCopyURL path] toOctal:755];
		return conflictedCopyURL;
	}
	return nil;
}


@end
