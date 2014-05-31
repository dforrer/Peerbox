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
	File			* localState;
	File			* remoteState;
}

- (id) initWithRevision:(Revision*)r andConfig:(Configuration*)c
{
	if ((self = [super init]))
	{
		rev	   = r;
		config  = c;
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
	//DebugLog(@"match: %@", fullURL);
	
	localState  = [[[rev peer] share] getFileForURL:fullURL];
	remoteState = [[File alloc] initWithShare:[[rev peer] share]
								relUrl:[rev relURL]
								 isSet:[rev isSet]
					extAttributesAsBase64:[rev extAttributes]
							   versions:[NSMutableDictionary dictionaryWithDictionary:[rev versions]]];
	
	if ([localState isCoreEqualToFile:remoteState])
	{
		//DebugLog(@"match: isCoreEqualToFile -> YES");
		return;
	}
	
	
	// match directory / match file
	//------------------------------
	if ([[rev isDir] boolValue])
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
		//----------------------
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







/*
 * Revision = Directory
 */
- (void) matchDir
{
	if ([[rev isSet] intValue] == 1)
	{
		// Revision = ADD-Directory
		//--------------------------
		//DebugLog(@"ADD-Directory");
		NSError * error = nil;
		[[NSFileManager defaultManager] createDirectoryAtURL:fullURL withIntermediateDirectories:YES attributes:nil error:&error];
		if (error != nil)
		{
			DebugLog(@"ERROR creating directory: %@", error);
			return;
		}
		
		[File matchExtAttributes:[rev extAttributes] onURL:fullURL];
	}
	else
	{
		// Revision = DELETE-Directory (C implementation)
		//------------------------------------------------
		chdir([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
		remove(".DS_Store");
		int rv = rmdir([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
		if (rv != 0)
		{
			DebugLog(@"DEL of Dir failed, there must be other files in this directory");
			
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



/**
 * Handles File-conflicts
 */
- (void) matchFile
{
	// localState is NOT set, remotestate is set (ADD new file)
	//----------------------------------------------------------
	if (	([[localState isSet] intValue] == 0 || localState == nil)
	    && [[rev isSet] intValue] == 1)
	{
		//DebugLog(@"A");
		
		// (No checking for conflicts)
		

		// Delete localState
		//-------------------
		[[[rev peer] share] removeFile:localState];

		
		// Match remoteState
		//-------------------
		[self executeMatch];
		
		return;
	}
	
	
	// localState is NOT set, remotestate is NOT set (DELETE non-existing file)
	//-----------------------------------------------------------------------------
	if ( ([[localState isSet] intValue] == 0 || localState == nil) && [[rev isSet] intValue] == 0)
	{
		//DebugLog(@"B  (doing nothing)");
	}
	
	
	// localState is set, remotestate is NOT set (DELETE file)
	//---------------------------------------------------------
	if ( [[localState isSet] intValue] == 1 && [[rev isSet] intValue] == 0)
	{
		//DebugLog(@"C");
		
		// check for conflicts
		//---------------------
		if ([File versions:[rev versions] hasConflictsWithVersions:[localState versions]])
		{
			//DebugLog(@"C1");
			
			// (WITH CONFLICT)
			
			NSURL* conflictedCopyURL = [self createConflictedCopy];
			
			[[[rev peer] share] scanURL:conflictedCopyURL recursive:NO];
			
			
			// Delete localState
			//-------------------
			[[[rev peer] share] removeFile:localState];
			
			return;
		}
		else
		{
			//DebugLog(@"C2");
			
			// (WITHOUT CONFLICT)
			
			// Make sure we only delete a file...
			// if the remoteState->Versions is bigger than on localState
			//-----------------------------------------------------------
			if ([[localState getLastVersionKey] intValue] <= [[rev getLastVersionKey] intValue])
			{
				// Delete FILE
				//-------------
				int rv = remove([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
				
				if (rv != 0)
				{
					DebugLog(@"ERROR: during moving of file an error occurred!");
						
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
	
	
	// localState is set, remotestate is set (ADD file, but there may be a conflicts)
	//--------------------------------------------------------------------------------
	if ( [[localState isSet] intValue] == 1 && [[rev isSet] intValue] == 1)
	{
		//DebugLog(@"D");
		// check for conflicts
		//---------------------
		if ([File versions:[rev versions] hasConflictsWithVersions:[localState versions]])
		{
			//DebugLog(@"D1");
			// WITH CONFLICT
			//---------------
			if ([[config myPeerID] isLessThan:[[rev peer] peerID]])
			{
				// myPeerId < otherPeerId
				//------------------------
				
				NSURL* conflictedCopyURL = [self createConflictedCopy];
				
				[[[rev peer] share] scanURL:conflictedCopyURL recursive:NO];
				
				
				// Delete localState
				//-------------------
				[[[rev peer] share] removeFile:localState];
				
				// Match remoteState
				//-------------------
				return [self executeMatch];
			}
			else
			{
				// myPeerId >= otherPeerId
				//-------------------------
				//DebugLog(@"DO NOTHING because myPeerId >= otherPeerId");
				
				// DO NOTHING
			}
		}
		else
		{
			//DebugLog(@"D2");
			
			// WITHOUT CONFLICT
			//------------------
			if ([[localState getLastVersionKey] intValue] < [[rev getLastVersionKey] intValue])
			{
				// localState->versions->biggestKey < remoteState->versions->biggestKey
				//----------------------------------------------------------------------
				
				
				// Delete localState
				//-------------------
				[[[rev peer] share] removeFile:localState];
				
				
				// Match remoteState
				//-------------------
				return [self executeMatch];
			}
			else
			{
				[File matchExtAttributes:[rev extAttributes] onURL:fullURL];

				// localState->versions->biggestKey >= remoteState->versions->biggestKey
				//-----------------------------------------------------------------------
				
				// DO NOTHING
				//DebugLog(@"DO NOTHING");
			}
		}
	}
}



/*
 * No conflict resolution is done here
 */
- (void) executeMatch
{
	//DebugLog(@"matchRemoteState");
	
	// Store Revision in Share->db, if the file requires a download
	//--------------------------------------------------------------
	if (![rev canBeMatchedInstantly])
	{
		//DebugLog(@"Revision CAN'T be matched instantly");
		[[[rev peer] share] setRevision:rev forPeer:[rev peer]];
		return;
	}
	
	// match zero-length files
	//-------------------------
	if ([rev isZeroLengthFile])
	{
		[self createZeroLengthFile];
	}
}



- (void) createZeroLengthFile
{
	DebugLog(@"matchZeroLengthFile");
	
	// Delete FILE (because writeData:[NSData data] doesn't work)
	//------------------------------------------------------------
	remove([[fullURL path] cStringUsingEncoding:NSUTF8StringEncoding]);
	
	// Create empty file
	//-------------------
	NSFileHandle * fh = [FileHelper fileForWritingAtPath:[fullURL path]];
	
	/*
	 * Because file-creation might fail, if the
	 * super-directories weren't readily created
	 * we have to make sure it is done again here
	 */
	
	if (fh == nil)
	{
		DebugLog(@"ERROR: Failure to create empty file at %@", [fullURL path]);
		NSError * error = nil;
		[[NSFileManager defaultManager] createDirectoryAtURL:[fullURL URLByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error];
		if (error != nil)
		{
			DebugLog(@"ERROR creating directory: %@", error);
			return;
		}
		
		// Retry
		//-------
		fh = [FileHelper fileForWritingAtPath:[fullURL path]];
	}
	//[fh writeData:[NSData data]];
	[fh closeFile];
	
	[File matchExtAttributes:[rev extAttributes] onURL:fullURL];
	
	// Set remoteState in Share s
	//----------------------------
	File * newState = [[File alloc] initAsNewFileWithPath:[fullURL path]];
	[newState setVersions:[remoteState versions]];
	[[[rev peer] share] setFile:newState];
}



- (NSURL*) createConflictedCopy
{	
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
			return nil;
		}
		return conflictedCopyURL;
	}
	return nil;
}


@end
