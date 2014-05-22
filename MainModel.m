//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "MainModel.h"

#import "DownloadShares.h"
#import "NSDictionary_JSONExtensions.h"
#import "Constants.h"
#import "FileHelper.h"
#import "Share.h"
#import "Peer.h"
#import "File.h"
#import "FullScanOperation.h"
#import "SingleFileOperation.h"
#import "Configuration.h"
#import "FSWatcher.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"

/**
 * Contains all the Domain-logic
 */
@implementation MainModel
{
	NSMutableDictionary * myShares;	// shareId = key of NSDictionary
	
	NSOperationQueue * fsWatcherQueue;
	BOOL fsWatcherQueueRestartet;
	NSMutableArray * fileDownloads;
}





@synthesize bonjourSearcher;
@synthesize config;	// passed down to Share, Peer, Revision
@synthesize httpServer;
@synthesize fswatcher;



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
		[bonjourSearcher setDelegate:self];
		
		fswatcher		 = [[FSWatcher alloc] init];
		fsWatcherQueue  = [[NSOperationQueue alloc] init];
		fsWatcherQueueRestartet = FALSE;
		fileDownloads = [[NSMutableArray alloc] init];
		
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
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsSymlink" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(matchRevisions) name:@"MatchEvent" object:nil];
		
		
		[self updateFSWatcher];
		
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
			// CASE: model.plist DOESN'T exist
			//---------------------------------
			[self generatePeerId];
			return;
		}
		
		NSDictionary * model = [[NSDictionary alloc] initWithContentsOfFile:modelPath];
		if (!model)
		{
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
										 andShare:s
										andConfig:config];
				[p setCurrentRev:[peerDict objectForKey:@"currentRev"]];
				[p setLastDownloadedRev:[peerDict objectForKey:@"lastDownloadedRev"]];
				
				
				// Iterate through REVISIONS
				//---------------------------
				NSDictionary * revisions = [peerDict objectForKey:@"revisions"];
				for (id key3 in revisions)
				{
					NSDictionary * revDict = [revisions objectForKey:key3];
					Revision * r = [[Revision alloc] initWithRelURL:[revDict objectForKey:@"relURL"]
												 andRevision:[revDict objectForKey:@"revision"]
												    andIsSet:[revDict objectForKey:@"isSet"]
												  andExtAttr:[revDict objectForKey:@"extAttributes"]
												 andVersions:[revDict objectForKey:@"versions"]
													andPeer:p
												   andConfig:config];
					[p addRevision:r];
				}
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




- (void) commitAllShareFilesDBs
{
	for (Share * s in [myShares allValues])
	{
		[s filesDBCommit];
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
 * OVERRIDE: BonjourSearcherDelegate
 */
- (void) bonjourSearcherServiceResolved:(NSNetService*)n
{
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		Peer * p = [s getPeerForID:[n name]];
		[p setNetService:n];
	}
}


/**
 * OVERRIDE: BonjourSearcherDelegate
 */
- (void) bonjourSearcherServiceRemoved:(NSNetService*)n
{
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		Peer * p = [s getPeerForID:[n name]];
		[p setNetService:nil];
	}
}


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
				p = [[Peer alloc] initWithPeerID:[d objectForKey:@"peerId"] andShare:s andConfig:config];
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
		[[d peer] setRevisionsDownload:nil];
		return;
	}
	
	
	// Store revisions in share->peers->downloadedRevs
	//-------------------------------------------------
	if ([[dict objectForKey:@"revisions"] count] > 0)
	{
		for (id key in [dict objectForKey:@"revisions"])
		{
			NSDictionary * rev	= [[dict objectForKey:@"revisions"] objectForKey:key];
			NSNumber * revision = [rev objectForKey:@"revision"];
			NSNumber * isSet	= [rev objectForKey:@"isSet"];
			NSDictionary * extendedAttributes	= [rev objectForKey:@"extendedAttributes"];
			NSDictionary * versions			= [rev objectForKey:@"versions"];
			
			Revision * r = [[Revision alloc] initWithRelURL:key
										 andRevision:revision
										    andIsSet:isSet
										  andExtAttr:extendedAttributes
										 andVersions:versions
											andPeer:[d peer]
										   andConfig:config];
			[[d peer] addRevision:r];
		}
		
		
		// Get biggest revision from response->revisions
		//-----------------------------------------------
		NSNumber * biggestRev = [dict objectForKey:@"biggestRev"];
		DebugLog(@"biggestRev: %@", biggestRev);
		[[d peer] setLastDownloadedRev:biggestRev];
	}
	[[d peer] setRevisionsDownload:nil];
}


/**
 * OVERRIDE: DownloadRevisionsDelegate
 */
- (void) downloadRevisionsHasFailed:(DownloadRevisions*)d
{
	[[d peer] setRevisionsDownload:nil];
}



/**
 * OVERRIDE: RevisionDelegate
 */
- (void) revisionMatched:(Revision*) rev
{
	DebugLog(@"revisionMatched called");
	[[rev peer] removeRevision:rev];
	[fileDownloads removeObject:rev];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventIsFile" object:[[rev remoteState] url]];
	
	if ([fileDownloads count] <= MAX_CONCURRENT_DOWNLOADS / 2)
	{
		[self performSelectorInBackground:@selector(matchRevisions) withObject:nil];
	}
}



#pragma mark -----------------------
#pragma mark FSWatcher-Controller

/**
 *
 */
- (void) restartFSWatcherQueue
{
	DebugLog(@"restartFSWatcherQueue");
	[fsWatcherQueue cancelAllOperations];
	
	// Do the rescan
	//--------------
	for (Share * s in [myShares allValues])
	{
		FullScanOperation * o = [[FullScanOperation alloc] initWithShare:s];
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
	for ( Share * share in [myShares allValues] )
	{
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
		
		SingleFileOperation * o = [[SingleFileOperation alloc] initWithURL:fileURL andShare:share];
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
		
		FullScanOperation * o = [[FullScanOperation alloc] initWithShare:s];
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
	// For every announced NetService...
	//-----------------------------------
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
				[p setRevisionsDownload:[[DownloadRevisions alloc] initWithNetService:ns andPeer:p]];
				[[p revisionsDownload] setDelegate:self];
				[[p revisionsDownload] start];
			}
		}
	}
}





- (void) matchRevisions
{
	DebugLog(@"MainModel: matchRevisions called");
	for (id key in myShares)
	{
		Share * s = [myShares objectForKey:key];
		for (Peer * p in [s allPeers])
		{
			if ([[p downloadedRevsWithFilesToAdd] count] == 0)
			{
				continue;
			}
			// Match DELETE-Revisions
			//------------------------
			DebugLog(@"+++ Match DELETE-Revisions");
			
			NSArray * sortedKeys = [[[p downloadedRevsWithIsSetFalse] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			for (id key in [sortedKeys reverseObjectEnumerator])
			{
				DebugLog(@"---------------------");
				DebugLog(@"key: %@", key);
				DebugLog(@"---------------------");
				Revision * r = [[p downloadedRevsWithIsSetFalse] objectForKey:key];
				[r match];
				[p removeRevision:r];
			}
			
			// Match DIR-Revisions
			//---------------------
			DebugLog(@"+++ Match DIR-Revisions");
			
			sortedKeys = [[[p downloadedRevsWithIsDirTrue] allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
			for (id key in [sortedKeys reverseObjectEnumerator])
			{
				DebugLog(@"---------------------");
				DebugLog(@"key: %@", key);
				DebugLog(@"---------------------");
				Revision * r = [[p downloadedRevsWithIsDirTrue] objectForKey:key];
				[r match];
				[p removeRevision:r];
			}
			
			// Match FILE-Revisions
			//----------------------
			DebugLog(@"+++ Match FILE-Revisions");
			
			if ([fileDownloads count] <= MAX_CONCURRENT_DOWNLOADS / 2)
			{
				NSArray * fileRevs = [p getNextFileRevisions:(int)(MAX_CONCURRENT_DOWNLOADS - [fileDownloads count])];
				for (Revision * r in fileRevs)
				{
					DebugLog(@"---------------------");
					DebugLog(@"key: %@", key);
					DebugLog(@"---------------------");
					[r setDelegate:self];
					[fileDownloads addObject:r];
					[r match];
				}
			}
		}
	}
}




@end