//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "MainController.h"

#import "BonjourSearcher.h"
#import "DownloadShares.h"
#import "NSDictionary_JSONExtensions.h"
#import "Constants.h"
#import "FileHelper.h"
#import "Share.h"
#import "Peer.h"
#import "File.h"
#import "ShareScanOperation.h"
#import "FileScanOperation.h"
#import "Configuration.h"
#import "FSWatcher.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"
#import "RevisionMatchOperation.h"
#import "Revision.h"

/**
 * Contains all the Domain-logic
 */
@implementation MainController
{
	NSMutableDictionary * myShares;	// shareId = key of NSDictionary
	
	NSOperationQueue * fsWatcherQueue;
	BOOL fsWatcherQueueRestartet;
	
	NSOperationQueue * matcherQueue;
}





@synthesize bonjourSearcher;
@synthesize config;	// passed down to Share, Peer, Revision
@synthesize httpServer;
@synthesize fswatcher;
@synthesize fileDownloads;


#pragma mark -----------------------
#pragma mark Initializer & Setup & Shutdown


/**
 * Initializer
 */
- (id) init
{
	if ((self = [super init]))
	{
		[self setupConfig];
		[self openModel];
		
		
		// Initialize the BonjourSearcher
		//--------------------------------
		NSString * serviceType = [NSString stringWithFormat:@"_%@._tcp.", APP_NAME];
		bonjourSearcher = [[BonjourSearcher alloc] initWithServiceType:serviceType andDomain:@"local" andMyName:[config myPeerID]];
		
		fswatcher		 = [[FSWatcher alloc] init];
		fsWatcherQueue  = [[NSOperationQueue alloc] init];
		fsWatcherQueueRestartet = FALSE;
		fileDownloads = [[NSMutableArray alloc] init];
		matcherQueue  = [[NSOperationQueue alloc] init];
		[matcherQueue addObserver:self forKeyPath:@"operations" options:0 context:NULL]; // KVO
		
		[self setupHTTPServer];
		[self createWorkingDirectories];
		
		
		// Remove all previously downloaded files from downloadsDir
		//----------------------------------------------------------
		[FileHelper removeAllFilesInDir:[config downloadsDir]];
		
		
		// Perform initial scans of the shares
		//-------------------------------------
		[self restartFSWatcherQueue];
		
		
		// Setup notification listeners
		//------------------------------
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsDir" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsFile" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsSymlink" object:nil];
		
		
		[self updateFSWatcher];
		
		
		// Schedule timer for commit and begin on databases
		//--------------------------------------------------
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(commitAndBeginAllShareDBs) userInfo:nil repeats:YES];
		
	}
	return self;
}



/**
 * Sets up the config-object with the different paths
 */
- (void) setupConfig
{
	config = [[Configuration alloc] init];
	[config setWorkingDir:[[NSString alloc] initWithString:[[FileHelper getDocumentsDirectory] stringByAppendingPathComponent:APP_NAME]]];
	[config setDownloadsDir:[[[NSString alloc] initWithString:[[FileHelper getDocumentsDirectory] stringByAppendingPathComponent:APP_NAME]] stringByAppendingPathComponent:@"downloads"]];
	[config setWebDir:[[[NSString alloc] initWithString:[[FileHelper getDocumentsDirectory] stringByAppendingPathComponent:APP_NAME]] stringByAppendingPathComponent:@"web"]];
}



/**
 * Load 'myShares' and 'myPeerID' from 'model.plist'
 */
- (void) openModel
{
	@autoreleasepool
	{
		myShares = [[NSMutableDictionary alloc] init];
		
		NSString * modelPath = [[config workingDir] stringByAppendingPathComponent:@"model.plist"];
		if (![FileHelper fileFolderExists:modelPath] )
		{
			// "model.plist" DOESN'T exist
			//-----------------------------
			[self generatePeerId];
			return;
		}
		
		NSDictionary * model = [[NSDictionary alloc] initWithContentsOfFile:modelPath];
		if (!model)
		{
			// File "model.plist" DOESN'T contain a dictionary
			//-------------------------------------------------
			[self generatePeerId];
			return;
		}
		
		// Set myPeerID
		//--------------
		[config setMyPeerID:[model objectForKey:@"myPeerID"]];
		
		DebugLog(@"%myPeerID: %@", [config myPeerID]);
		
		// Set myShares
		//--------------
		NSDictionary * shares = [model objectForKey:@"myShares"];
		for (id key1 in shares)
		{
			NSDictionary * shareDict = [shares objectForKey:key1];
			Share * s = [[Share alloc] initShareWithID:[shareDict objectForKey:@"shareId"]
									  andRootURL:[NSURL URLWithString:[shareDict objectForKey:@"root"]]
									  withSecret:[shareDict objectForKey:@"secret"]
									   andConfig:config];
			
			// Iterate through PEERS
			//-----------------------
			NSDictionary * peers = [shareDict objectForKey:@"peers"];
			for (id key2 in peers)
			{
				NSDictionary * peerDict = [peers objectForKey:key2];
				Peer * p = [[Peer alloc] initWithPeerID:[peerDict objectForKey:@"peerID"]
										 andShare:s];
				[p setCurrentRev:[peerDict objectForKey:@"currentRev"]];
				[p setLastDownloadedRev:[peerDict objectForKey:@"lastDownloadedRev"]];
				[s setPeer:p];
			}
			[myShares setObject:s forKey:key1];
		}
	}
}



/**
 * Save 'myShares' and 'myPeerID' to 'model.plist'
 */
- (void) saveModel
{
	NSMutableDictionary * model = [[NSMutableDictionary alloc] init];
	[model setObject:[self plistEncoded] forKey:@"myShares"];
	[model setObject:[config myPeerID] forKey:@"myPeerID"];
	
	// Write model to disk
	//---------------------
	NSString * path = [[config workingDir] stringByAppendingPathComponent:@"model.plist"];
	if (![model writeToFile:path atomically:TRUE])
	{
		DebugLog(@"AN ERROR OCCURED DURING SAVING OF: model.plist");
	}
}



/**
 * Helper function for encoding the model in a readable format
 */
- (NSDictionary*) plistEncoded
{
	//DebugLog(@"plistEncoded: MainModel");
	NSMutableDictionary * plist = [[NSMutableDictionary alloc] init];
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		[plist setObject:[s plistEncoded] forKey:[s shareId]];
	}
	return plist;
}



/**
 * Setup and start httpserver
 */
- (void) setupHTTPServer
{
	/*
	 Note: Clicking the bonjour service in Safari won't work because Safari will use http and not https.
	 Just change the url to https for proper access.
	 
	 Normally there's no need to run our server on any specific port.
	 Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	 However, for easy testing you may want force a certain port so you can just hit the refresh button.
	 
	 We're going to extend the base HTTPConnection class with our MyHTTPConnection class.
	 This allows us to customize the server for things such as SSL and password-protection.
	 */
	
	httpServer = [[HTTPServer alloc] init];
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	[httpServer setPort:0];
	//	[httpServer setPort:12345];
	
	// Tell the server to broadcast its presence via Bonjour.
	// This allows browsers such as Safari to automatically discover our service.
	NSString * serviceType = [NSString stringWithFormat:@"_%@._tcp.", APP_NAME];
	[httpServer setType:serviceType];
	[httpServer setName:[config myPeerID]];
	[httpServer setDocumentRoot:[config webDir]];
	NSError *error = nil;
	
	if( ![httpServer start:&error] )
	{
		DebugLog(@"Error starting HTTP Server: %@", error);
	}
	else
	{
		DebugLog(@"Server started");
		DebugLog(@"address: localhost");
		DebugLog(@"port: %i", [httpServer listeningPort]);
	}
}



/**
 * Creates the directories:
 *	/APP_NAME/web
 *	/APP_NAME/downloads
 */
- (void) createWorkingDirectories
{
	// Create directory "downloads"
	//------------------------------
	[[NSFileManager defaultManager] createDirectoryAtPath:[config downloadsDir]
						 withIntermediateDirectories:YES
									   attributes:nil
										   error:nil];
	// Create directory "web"
	//------------------------
	[[NSFileManager defaultManager] createDirectoryAtPath:[config webDir]
						 withIntermediateDirectories:YES
									   attributes:nil
										   error:nil];
}



/**
 * Generates a new random PeerID
 */
- (void) generatePeerId
{
	NSData * random = [FileHelper createRandomNSDataOfSize:20];
	[config setMyPeerID:[FileHelper sha1OfNSData:random]];
}

- (void) commitAndBeginAllShareDBs
{
	for (Share * s in [myShares allValues])
	{
		[s commitAndBegin];
	}
}

- (void) commitAllShareDBs
{
	for (Share * s in [myShares allValues])
	{
		[s dbCommit];
	}
}


#pragma mark -----------------------
#pragma mark Info


- (void) printResolvedServices
{
	NSDictionary * resolvedServices = [bonjourSearcher resolvedServices];
	for (NSNetService *aNetService in [resolvedServices allValues])
	{
		DebugLog(@"ResolvedServiceName: %@, hostname: %@",[aNetService name], [aNetService hostName]);
		DebugLog(@"\thostname: %@", [aNetService hostName]);
	}
}



- (void) printMyShares
{
	DebugLog(@"myPeerId: %@", [config myPeerID]);
	for (Share * s in [myShares allValues])
	{
		DebugLog(@"%@", s);
		for (Peer * p in [s allPeers])
		{
			DebugLog(@"%@", p);
		}
	}
}



#pragma mark -----------------------
#pragma mark Implemented Interfaces (Protocols)



/**
 * OVERRIDE: DownloadSharesDelegate
 */
- (void) downloadSharesHasFinishedWithResponseDict:(NSDictionary*)d
{
	DebugLog(@"downloadSharesHasFinishedWithResponseDict");
	// Store response in model
	//-------------------------
	NSArray * sharesRemote = [d objectForKey:@"shares"];
	
	if (!sharesRemote)
	{
		DebugLog(@"ERROR 11: shares is nil");
		return;
	}
	
	for (NSDictionary * dict in sharesRemote)
	{
		// Check if we even have a share with the shareId
		//------------------------------------------------
		Share * s = [myShares objectForKey:[dict objectForKey:@"shareId"]];
		if ( s )
		{
			DebugLog(@"Share exists: %@", [s shareId]);
			// Check if s(hare) contains a peer with peerId
			//----------------------------------------------
			Peer * p = [s getPeerForID:[d objectForKey:@"peerId"]];
			if ( p == nil )
			{
				p = [[Peer alloc] initWithPeerID:[d objectForKey:@"peerId"] andShare:s];
				[s setPeer:p];
			}
			// Set the currentRev
			//--------------------
			[p setCurrentRev:[dict objectForKey:@"currentRev"]];
		}
	}
}



/**
 * OVERRIDE: DownloadSharesDelegate
 */
- (void) downloadSharesHasFailed
{
	DebugLog(@"downloadSharesHasFailed: Whatever...!");
}



/**
 * OVERRIDE: DownloadRevisionsDelegate
 */
- (void) downloadRevisionsHasFinished:(DownloadRevisions*)d
{
	DebugLog(@"downloadRevisionsHasFinished");
	NSError * error;
	
	// Convert NSData to NSDictionary
	//--------------------------------
	NSDictionary * dict = [NSDictionary dictionaryWithJSONData:[d response] error:&error];
	DebugLog(@"response:\n%@", dict);
	if (error)
	{
		DebugLog(@"response-count:%li", [[dict objectForKey:@"revisions"] count]);
		return;
	}
	
	
	// Store revisions in share->peers->downloadedRevs
	//-------------------------------------------------
	if ([[dict objectForKey:@"revisions"] count] > 0)
	{
		// Sort the downloaded revisions by the revision-number
		//------------------------------------------------------
		NSArray * keysSortedByRevision = [[dict objectForKey:@"revisions"] keysSortedByValueUsingComparator: ^(id obj1, id obj2)
		{
			if ([[obj1 objectForKey:@"revision"] longLongValue] > [[obj2 objectForKey:@"revision"] longLongValue])
			{
				return (NSComparisonResult)NSOrderedDescending;
			}
			if ([[obj1 objectForKey:@"revision"] longLongValue] < [[obj2 objectForKey:@"revision"] longLongValue])
			{
				return (NSComparisonResult)NSOrderedAscending;
			}
			return (NSComparisonResult)NSOrderedSame;
		}];
		
		// Create a RevisionMatchOperation for every downloaded revision
		//---------------------------------------------------------------
		for (id key in keysSortedByRevision)
		{
			NSDictionary * rev	= [[dict objectForKey:@"revisions"] objectForKey:key];
			NSNumber * revision = [rev objectForKey:@"revision"];
			NSNumber * fileSize = [rev objectForKey:@"fileSize"];
			NSNumber * isSet	= [rev objectForKey:@"isSet"];
			NSMutableDictionary * extendedAttributes	= [NSMutableDictionary dictionaryWithDictionary:[rev objectForKey:@"extendedAttributes"]];
			NSMutableDictionary * versions			= [NSMutableDictionary dictionaryWithDictionary:[rev objectForKey:@"versions"]];
			
			Revision * r = [[Revision alloc] init];
			[r setRelURL:key];
			[r setRevision:revision];
			[r setFileSize:fileSize];
			[r setIsSet:isSet];
			//DebugLog(@"key: %@ hasSuffix:%@",key, [NSNumber numberWithBool:[key hasSuffix:@"/"]]);
			[r setIsDir:[NSNumber numberWithBool:[key hasSuffix:@"/"]]];
			[r setExtAttributes:extendedAttributes];
			[r setVersions:versions];
			[r setPeer:[d peer]];
			
			RevisionMatchOperation * o = [[RevisionMatchOperation alloc] initWithRevision:r andConfig:config];
			if ([matcherQueue operationCount] > 0)
			{
				[o addDependency:[[matcherQueue operations] lastObject]];
			}
			[matcherQueue addOperation:o];
		}
				
		
		// Get biggest revision from response->revisions
		//-----------------------------------------------
		NSNumber * biggestRev = [dict objectForKey:@"biggestRev"];
		DebugLog(@"biggestRev: %@", biggestRev);
		[[d peer] setLastDownloadedRev:biggestRev];
	}
}


/**
 * OVERRIDE: DownloadRevisionsDelegate
 */
- (void) downloadRevisionsHasFailed:(DownloadRevisions*)d
{

}



/*
 * OVERRIDE: Delegate function called by "download" inherited from <DownloadFileDelegate>
 */
- (void) downloadFileHasFinished:(DownloadFile*)d
{
	NSURL * fullURL = [NSURL URLWithString:[[d rev] relURL] relativeToURL:[[[[d rev] peer] share] root]];
	
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
	for (id key in [[d rev] extAttributes])
	{
		NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[[[d rev] extAttributes] objectForKey:key] options:0];
		[FileHelper setValue:extAttrBinary forName:key onFile:[fullURL path]];
	}
	
	File * newState = [[File alloc] initAsNewFileWithPath:[fullURL path]];
	[newState setVersions:[NSMutableDictionary dictionaryWithDictionary:[[d rev] versions]]];
	[[[[d rev] peer] share] setFile:newState];
	
	// Remove Revision from db
	//-------------------------
	[[[[d rev] peer] share] removeRevision:[d rev] forPeer:[[d rev] peer]];
	[fileDownloads removeObject:d];
	
	
	// Download more files
	//---------------------
	if ([fileDownloads count] < MAX_CONCURRENT_DOWNLOADS / 2)
	{
		[self matchFiles];
	}
}



/*
 * OVERRIDE: Delegate function called by "download" inherited from <DownloadFileDelegate>
 */
- (void) downloadFileHasFailed:(DownloadFile*)d
{
	DebugLog(@"ERROR: downloadFileHasFailed");
	[fileDownloads removeObject:d];
	
	
	// Download more files
	//---------------------
	if ([fileDownloads count] < MAX_CONCURRENT_DOWNLOADS / 2)
	{
		[self matchFiles];
	}
}



/**
 * KVO: matcherQueue->operations
 */
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
	if (object == matcherQueue && [keyPath isEqualToString:@"operations"])
	{
		if ([matcherQueue.operations count] == 0)
		{
			// Do something here when your queue has completed
			NSLog(@"queue has completed");
			
			// Restart Revision-Download
			//---------------------------
			[self downloadRevisionsFromPeers];
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object
						   change:change context:context];
	}
}



#pragma mark -----------------------
#pragma mark Controlling FSWatcher

/**
 * Cancels all operations in 'fsWatcherQueue' 
 * and sets complete Share-rescans.
 */
- (void) restartFSWatcherQueue
{
	DebugLog(@"restartFSWatcherQueue");
	[fsWatcherQueue cancelAllOperations];
	
	// Do the rescan
	//--------------
	for (Share * s in [myShares allValues])
	{
		ShareScanOperation * o = [[ShareScanOperation alloc] initWithShare:s];
		[fsWatcherQueue  addOperation: o];
	}
	[fsWatcherQueue setSuspended:FALSE];
	fsWatcherQueueRestartet = FALSE;
}



/**
 * Notification from Watcher
 * This is the buffer for the firehose of fsevents
 */
- (void) fsWatcherEvent: (NSNotification *)notification
{
	NSURL * fileURL = [notification object];
	DebugLog(@"fsWatcherEvent: %@", fileURL);

	for ( Share * share in [myShares allValues] )
	{
		if ([fileURL isEqualTo:[share root]])
		{
			continue;
		}
		if ( ![FileHelper URL:fileURL hasAsRootURL:[share root]] )
		{
			continue;
		}
		
		/*
		 * If the 'operationCount' gets bigger than 20 the application
		 * should cancelAll ongoing operations,
		 * sleep for 7 seconds and then scan all the shares.
		 */
		
		if ([fsWatcherQueue operationCount] > 20)
		{
			if (fsWatcherQueueRestartet == FALSE)
			{
				DebugLog(@"fswatcherQueueRestartet == FALSE");
				[fsWatcherQueue setSuspended:TRUE];
				[self performSelector: @selector(restartFSWatcherQueue)
						 withObject: nil
						 afterDelay: 7.0];
				fsWatcherQueueRestartet = TRUE;
			}
			continue;
		}
		
		FileScanOperation * o = [[FileScanOperation alloc] initWithURL:fileURL andShare:share];
		if ([fsWatcherQueue operationCount] > 0)
		{
			[o addDependency:[[fsWatcherQueue operations] lastObject]];
		}
		[fsWatcherQueue addOperation: o];
	}
}


/**
 * Updates the FSWatcher-instance with the currently synced shares
 */
- (void) updateFSWatcher
{
	// Prepare temporary table with paths
	//-----------------------------------
	NSMutableArray * a = [[NSMutableArray alloc] init];
	
	for (Share * s in [myShares allValues])
	{
		[a addObject:[[s root] path]];
	}
	DebugLog(@"%@", a);
	[fswatcher setPaths:a];
	[fswatcher startWatching];
}




#pragma mark -----------------------
#pragma mark Getter / Setter



- (Share*) getShareForID:(NSString*)shareID
{
	return [myShares objectForKey:shareID];
}



- (NSMutableDictionary*) getAllShares
{
	return myShares;
}



/**
 * Creates and adds a Share to 'myShares',
 * but only if there is no Share with the same name already
 */
- (Share*) addShareWithID:(NSString*)shareId
			andRootURL:(NSURL*)root
		andPasswordHash:(NSString*)passwordHash
{
	// Verify Input values cannot be null
	//------------------------------------
	if (shareId == nil || root == nil || passwordHash == nil)
	{
		return nil;
	}
	
	if (![[myShares allKeys] containsObject:shareId])
	{
		Share * s = [[Share alloc] initShareWithID:shareId
								  andRootURL:root
								  withSecret:passwordHash
								   andConfig:config];
		[myShares setObject:s forKey:shareId];
		[self saveModel];
		
		ShareScanOperation * o = [[ShareScanOperation alloc] initWithShare:s];
		[fsWatcherQueue addOperation:o];
		[self updateFSWatcher];
		return s;
	}
	return nil;
}



- (void) removeShareForID:(NSString*)shareId
{
	if (shareId == nil)
	{
		return;
	}
	
	[myShares removeObjectForKey:shareId];
	
	[self saveModel];
	[self updateFSWatcher];
	
}




#pragma mark -----------------------
#pragma mark Download Manager Functions


/**
 * Status: COMPLETE
 */
- (void) downloadSharesFromPeers
{
	DebugLog(@"downloadShares() called...");
	// For every announced NetService...
	//-----------------------------------
	for (id key in [bonjourSearcher resolvedServices])
	{
		NSNetService *aNetService = [[bonjourSearcher resolvedServices] objectForKey:key];
		// ...and for every Share
		//------------------------
		DownloadShares * d = [[DownloadShares alloc] initWithNetService:aNetService];
		[d setDelegate:self];
		[d start];
	}
}



/**
 *
 */
- (void) downloadRevisionsFromPeers
{
	DebugLog(@"downloadRevisionsFromPeers");
	// For every Share ....
	//----------------------
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		for (Peer * p in [s allPeers])
		{
			NSNetService * ns = [bonjourSearcher getNetServiceForName:[p peerID]];
			
			// Compare currentRev (on remote peer) with lastDownloadedRev
			//------------------------------------------------------------
			if (ns != nil
			    && ([[p currentRev] longLongValue] > [[p lastDownloadedRev] longLongValue]))
			{
				DebugLog(@"revisionsDownload alloc");
				DownloadRevisions * d = [[DownloadRevisions alloc] initWithNetService:ns andPeer:p];
				[d setDelegate:self];
				[d start];
			}
		}
	}
}


- (void) matchFiles
{
	// For every Share ....
	//----------------------
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		for (Peer * p in [s allPeers])
		{
			NSNetService * ns = [bonjourSearcher getNetServiceForName:[p peerID]];
			
			// Compare currentRev (on remote peer) with lastDownloadedRev
			//------------------------------------------------------------
			if (ns != nil)
			{
				Revision * r = [s nextRevisionForPeer:p];

				while (r != nil && [fileDownloads count] < MAX_CONCURRENT_DOWNLOADS)
				{
					[s removeRevision:r forPeer:p];
					
					DownloadFile * d = [[DownloadFile alloc] initWithNetService:ns andRevision:r andConfig:config];
					[fileDownloads addObject:d];
					[d setDelegate:self];
					[d start];

					r = [s nextRevisionForPeer:p];
				}
			}
		}
	}
}



@end