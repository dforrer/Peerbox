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

@implementation RevisionMatchOperation
{
	Revision		* rev;
	NSURL		* fullURL;
	Configuration	* config;
}

- (id) initWithRevision:(Revision*)r andConfig:(Configuration*)c
{
	if ((self = [super init]))
	{
		rev = r;
		config = c;
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
	DebugLog(@"match");
	//[rev updateLastMatchAttempt];
	

		
	// match directory
	//-----------------
	if ([[rev isDir] boolValue])
	{
		[self matchDir];
		return;
	}
	
	// Remove Revision from db:
	// in case a file was added, not yet downloaded
	// and deleted again.
	//----------------------------------------------
	[[[rev peer] share] removeRevision:rev forPeer:[rev peer]];
	
	// match 'normal' files
	//----------------------
	[self handleFileConflicts];
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
		DebugLog(@"ADD-Directory");
		NSError * error = nil;
		[[NSFileManager defaultManager] createDirectoryAtURL:fullURL withIntermediateDirectories:YES attributes:nil error:&error];
		if (error != nil)
		{
			DebugLog(@"ERROR creating directory: %@", error);
			return;
		}
		
		// Set extended attributes
		// This works, but does not dispaly correctly in the Finder
		//----------------------------------------------------------
		for (id key in [rev extAttributes])
		{
			NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[rev extAttributes] objectForKey:key] options:0];
			[FileHelper setValue:extAttrBinary forName:key onFile:[fullURL path]];
		}
	}
	else
	{
		// Revision = DELETE-Directory
		//-----------------------------
		DebugLog(@"DEL-Directory");
		if ([FileHelper fileFolderExists:[fullURL path]])
		{
			// C implementation
			//------------------
			chdir([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
			remove(".DS_Store");
			int rv = rmdir([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
			if (rv != 0)
			{
				DebugLog(@"DEL of Dir failed, there must be other files in this directory");
			}
		}
	}
}


- (void) matchZeroLengthFile
{
	DebugLog(@"matchZeroLengthFile");
	
	// Create empty file
	//-------------------
	NSString * tmpPath = [[config downloadsDir] stringByAppendingPathComponent:@"tmp"];
	NSFileHandle * fh = [FileHelper fileForWritingAtPath:tmpPath];
	[fh closeFile];
	
	// Move the file
	//---------------
	NSError * error;
	[[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:[fullURL path] error:&error];
	if (error)
	{
		DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
		return;
	}
	
	// Set extended attributes
	//-------------------------
	for (id key in [rev extAttributes])
	{
		NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[rev extAttributes] objectForKey:key] options:0];
		[FileHelper setValue:extAttrBinary forName:key onFile:[fullURL path]];
	}
	
	// Set remoteState in Share s
	//----------------------------
	/*
	 File * newState = [[File alloc] initAsNewFileWithPath:[fullURL path]];
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
	
	// Store Revision in Share->db, if the file requires a download
	//--------------------------------------------------------------
	if (![rev canBeMatchedInstantly])
	{
		DebugLog(@"Revision CAN'T be matched instantly");
		[[[rev peer] share] setRevision:rev forPeer:[rev peer]];
		return;
	}
	
	// match zero-length files
	//-------------------------
	if ([rev isZeroLengthFile])
	{
		[self matchZeroLengthFile];
	}
}



- (void) createConflictedCopy
{
	File * localState = [[[rev peer] share] getFileForURL:fullURL];
	
	// Create CONFLICTEDCOPY
	//-----------------------
	NSError * error;
	NSURL * conflictedCopyURL;
	if ( [[NSFileManager defaultManager] isReadableFileAtPath:[[localState url] path]] )
	{
		// Rename localState-File to "xxx conflicted copy on abc193848.xxx"
		//------------------------------------------------------------------
		NSURL * superdir = [fullURL URLByDeletingLastPathComponent];
		NSString * oldFilename = [[fullURL lastPathComponent] stringByDeletingPathExtension];
		NSString * newFilename = [oldFilename stringByAppendingString:[NSString stringWithFormat:@" conflicted copy on %@", [config myPeerID]]];
		newFilename = [newFilename stringByAppendingPathExtension:[fullURL pathExtension]];
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

/**
 *
 */
- (void) handleFileConflicts
{
	File * localState = [[[rev peer] share] getFileForURL:fullURL];
	
	// localState is NOT set, remotestate is set (ADD new file)
	//----------------------------------------------------------
	if ( ([[localState isSet] intValue] == 0 || localState == nil) && [[rev isSet] intValue] == 1)
	{
		DebugLog(@"A");
		
		// (No checking for conflicts)
		
		// Delete localState
		//-------------------
		[[[rev peer] share] removeFile:localState];
		
		// Match remoteState
		//-------------------
		[self matchRemoteState];
		
		return;
	}
	
	
	// localState is NOT set, remotestate is NOT set (DELETE non-existing file)
	//-----------------------------------------------------------------------------
	if ( ([[localState isSet] intValue] == 0 || localState == nil) && [[rev isSet] intValue] == 0)
	{
		DebugLog(@"B  (doing nothing)");
	}
	
	
	// localState is set, remotestate is NOT set (DELETE file)
	//---------------------------------------------------------
	if ( [[localState isSet] intValue] == 1 && [[rev isSet] intValue] == 0)
	{
		DebugLog(@"C");
		
		// check for conflicts
		//---------------------
		if ([File versions:[rev versions] hasConflictsWithVersions:[localState versions]])
		{
			DebugLog(@"C1");
			
			// (WITH CONFLICT)
			
			[self createConflictedCopy];
			
			// Delete localState
			//-------------------
			[[[rev peer] share] removeFile:localState];
			
			return;
		}
		else
		{
			DebugLog(@"C2");
			
			// (WITHOUT CONFLICT)
			
			// Make sure we only delete a file...
			// if the remoteState->Versions is bigger than on localState
			//-----------------------------------------------------------
			if ([[localState getLastVersionKey] intValue] <= [[rev getLastVersionKey] intValue])
			{
				// Delete FILE
				//-------------
				NSError * error;
				if ( [[NSFileManager defaultManager] isReadableFileAtPath:[fullURL path]] )
				{
					// Move existing file to the trash
					//---------------------------------
					BOOL success = [[NSFileManager defaultManager] removeItemAtURL:fullURL error:&error];
					
					if (error || success)
					{
						DebugLog(@"ERROR: during moving of file an error occurred!, %@", error);
						remove([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
						
						//	[remoteState setIsSetBOOL:FALSE];
						//	[[peer share] setFile:remoteState];
					}
				}
			}
			return;
		}
		
	}
	
	
	// localState is set, remotestate is set (ADD file, but there may be a conflicts)
	//--------------------------------------------------------------------------------
	if ( [[localState isSet] intValue] == 1 && [[rev isSet] intValue] == 1)
	{
		DebugLog(@"D");
		// check for conflicts
		//---------------------
		if ([File versions:[rev versions] hasConflictsWithVersions:[localState versions]])
		{
			DebugLog(@"D1");
			// (WITH CONFLICT)
			
			if ([[config myPeerID] isLessThan:[[rev peer] peerID]])
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
				 NSURL * superdir = [fullURL URLByDeletingLastPathComponent];
				 NSString * oldFilename = [[fullURL lastPathComponent] stringByDeletingPathExtension];
				 NSString * newFilename = [oldFilename stringByAppendingString:[NSString stringWithFormat:@" conflicted copy on %@", myPeerID]];
				 newFilename = [newFilename stringByAppendingPathExtension:[fullURL pathExtension]];
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
				[[[rev peer] share] removeFile:localState];
				
				// Match remoteState
				//-------------------
				return [self matchRemoteState];
			}
			else
			{
				// (myPeerId >= otherPeerId)
				DebugLog(@"DO NOTHING because myPeerId >= otherPeerId");
				
				// DO NOTHING
			}
		}
		else
		{
			DebugLog(@"D2");
			
			// (WITHOUT CONFLICT)
			
			if ([[localState getLastVersionKey] intValue] < [[rev getLastVersionKey] intValue])
			{
				// (localState:versions:biggestKey < remoteState:versions:biggestKey)
				
				// Delete localState
				//-------------------
				[[[rev peer] share] removeFile:localState];
				
				// Match remoteState
				//-------------------
				return [self matchRemoteState];
			}
			else
			{
				// (localState:versions:biggestKey >= remoteState:versions:biggestKey)
				
				// DO NOTHING
				DebugLog(@"DO NOTHING");
			}
		}
	}
}

@end
