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
#import "FileMatchOperation.h"
#import "Revision.h"
#import "PostNotification.h"
#import "DataModel.h"
#import "Singleton.h"
#import "StatusBarController.h"
#import "EditSharesWindowController.h"

/**
 * Contains all the Domain-logic
 */

@implementation MainController
{
	NSOperationQueue * fsWatcherQueue;
	NSOperationQueue * revMatcherQueue;
	NSOperationQueue * fileMatcherQueue;
}



@synthesize bonjourSearcher;
@synthesize httpServer;
@synthesize fswatcher;
@synthesize dataModel;
@synthesize statusBarController;
@synthesize editSharesWindowController;

#pragma mark -----------------------
#pragma mark Initializer & Setup & Shutdown


/**
 * Initializer
 */

- (id) init
{
	if ((self = [super init]))
	{
		dataModel = [[Singleton data] dataModel];
		
		[self openModel];
		
		
		// Initialize the BonjourSearcher
		
		NSString * serviceType = [NSString stringWithFormat:@"_%@._tcp.", APP_NAME];
		bonjourSearcher = [[BonjourSearcher alloc] initWithServiceType:serviceType andDomain:@"local" andMyName:[[Singleton data] myPeerID]];
		[bonjourSearcher setDelegate:self];
		
		fswatcher		  = [[FSWatcher alloc] init];
		
		fsWatcherQueue	  = [[NSOperationQueue alloc] init];
		revMatcherQueue  = [[NSOperationQueue alloc] init];
		fileMatcherQueue = [[NSOperationQueue alloc] init];
		
		[fsWatcherQueue   setMaxConcurrentOperationCount:1];
		[fileMatcherQueue setMaxConcurrentOperationCount:1];
		[revMatcherQueue  setMaxConcurrentOperationCount:1];
		
		
		
		// Setup KVO
		
		[revMatcherQueue  addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
		[fsWatcherQueue   addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
		[fileMatcherQueue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
		
		[self setupHTTPServer];
		[self createWorkingDirectories];
		
		
		// Remove all previously downloaded files from downloadsDir
		
		[FileHelper removeAllFilesInDir:[[[Singleton data] config] downloadsDir]];
		
		
		// Perform initial scans of the shares
		
		[self restartFSWatcherQueue];
		
		
		// Setup notification listeners
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsDir" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsFile" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fsWatcherEvent:) name:@"fsWatcherEventIsSymlink" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyPeers:) name:@"notifyPeers" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadSharesFromPeers:) name:@"downloadSharesFromPeers" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addShare:) name:@"addShare" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeShare:) name:@"removeShare" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(openEditDialog:) name:@"openEditDialog" object:nil];
		
		[self updateFSWatcher];
		
		statusBarController = [[StatusBarController alloc] initWithDataModel:dataModel andBonjourSearcher:bonjourSearcher];
		editSharesWindowController = [[EditSharesWindowController alloc] initWithDataModel:dataModel];
	}
	return self;
}


- (void) openEditDialog:(NSNotification*)aNotification
{
	[editSharesWindowController openEditDialog];
}


- (void) addShare:(NSNotification*)aNotification
{
	Share * s = [aNotification object];
	[dataModel addShare:s];
	[self saveModelToPlist];
	
	// Perform initial scan
	
	ShareScanOperation * o = [[ShareScanOperation alloc] initWithShare:s];
	[fsWatcherQueue addOperation:o];
	[self updateFSWatcher];
	
	[self downloadSharesFromPeers:nil];
	
	// Update GUI
	
	[[editSharesWindowController sharesTableView] reloadData];
	[statusBarController updateStatusBarMenu];
}

- (void) removeShare:(NSNotification*)aNotification
{
	Share * s = [aNotification object];
	[dataModel removeShare:s];
	[self saveModelToPlist];

	[self updateFSWatcher];
	
	// Remove .sqlite-File
	
	NSString * sqlitePath = [NSString stringWithFormat:@"%@/%@.sqlite", [[[Singleton data] config] workingDir], [s shareId]];
	NSError * error;
	[[NSFileManager defaultManager] removeItemAtPath:sqlitePath error:&error];

	
	// Update GUI
	
	[[editSharesWindowController sharesTableView] reloadData];
	[statusBarController updateStatusBarMenu];
}

/**
 * Load 'myShares' and 'myPeerID' from 'model.plist'
 */

- (void) openModel
{
	@autoreleasepool
	{
		
		NSString * modelPath = [[[[Singleton data] config] workingDir] stringByAppendingPathComponent:@"model.plist"];
		if (![FileHelper fileFolderExists:modelPath] )
		{
			// "model.plist" DOESN'T exist
			
			[self generatePeerId];
			return;
		}
		
		NSDictionary * model = [[NSDictionary alloc] initWithContentsOfFile:modelPath];
		if (!model)
		{
			// File "model.plist" DOESN'T contain a dictionary
			
			[self generatePeerId];
			return;
		}
		
		// Set myPeerID
		
		[[Singleton data] setMyPeerID:[model objectForKey:@"myPeerID"]];
		
		DebugLog(@"%myPeerID: %@", [[Singleton data] myPeerID]);
		
		// Set myShares
		
		NSDictionary * sharesSetup = [model objectForKey:@"myShares"];
		for (id key1 in sharesSetup)
		{
			NSDictionary * shareDict = [sharesSetup objectForKey:key1];
			Share * s = [[Share alloc] initShareWithID:[shareDict objectForKey:@"shareId"]
									  andRootURL:[NSURL URLWithString:[shareDict objectForKey:@"root"]]
									  withSecret:[shareDict objectForKey:@"secret"]];
			
			// Iterate through PEERS
			
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
			[[dataModel myShares] setObject:s forKey:key1];
		}
	}
}






/**
 * Save 'myShares' and 'myPeerID' to 'model.plist'
 */

- (void) saveModelToPlist
{	
	NSMutableDictionary * model = [[NSMutableDictionary alloc] init];
	[model setObject:[dataModel plistEncoded] forKey:@"myShares"];
	[model setObject:[[Singleton data] myPeerID] forKey:@"myPeerID"];
	
	// Write model to disk
	
	NSString * path = [[[[Singleton data] config] workingDir] stringByAppendingPathComponent:@"model.plist"];
	if (![model writeToFile:path atomically:TRUE])
	{
		DebugLog(@"AN ERROR OCCURED DURING SAVING OF: model.plist");
	}
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
	[httpServer setName:[[Singleton data] myPeerID]];
	[httpServer setDocumentRoot:[[[Singleton data] config] webDir]];
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
	
	[[NSFileManager defaultManager] createDirectoryAtPath:[[[Singleton data] config] downloadsDir]
						 withIntermediateDirectories:YES
									   attributes:nil
										   error:nil];
	// Create directory "web"
	
	[[NSFileManager defaultManager] createDirectoryAtPath:[[[Singleton data] config] webDir]
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
	[[Singleton data] setMyPeerID:[FileHelper sha1OfNSData:random]];
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
	DebugLog(@"myPeerId: %@", [[Singleton data] myPeerID]);
	for (Share * s in [[dataModel myShares] allValues])
	{
		DebugLog(@"%@", s);
		for (Peer * p in [s allPeers])
		{
			DebugLog(@"%@", p);
		}
	}
}


- (void) printDebugLogs
{
	// TODO: Find out why certain downloads finish but the downloads are then not moved to their destination
	DebugLog(@"FileDownloads-Count: %lu",(unsigned long)[[dataModel fileDownloads] count]);
}


#pragma mark -----------------------
#pragma mark Implemented Interfaces (Protocols)



/**
 * OVERRIDE: BonjourSearcherDelegate
 */

- (void) bonjourSearcherServiceResolved:(NSNetService*)n
{
	[self notifyPeers:nil];
	
	// Update StatusBar

	[statusBarController updateStatusBarMenu];
	
	[self matchFiles];
}



/**
 * OVERRIDE: BonjourSearcherDelegate
 */

- (void) bonjourSearcherServiceRemoved:(NSNetService*)n
{
	// Update StatusBar
	
	[statusBarController updateStatusBarMenu];
}



/**
 * OVERRIDE: DownloadSharesDelegate
 */

- (void) downloadSharesHasFinishedWithResponseDict:(NSDictionary*)d
{
	// Store response in model
	
	NSArray * sharesRemote = [d objectForKey:@"shares"];
	
	if (!sharesRemote)
	{
		DebugLog(@"ERROR 11: shares is nil");
		return;
	}
	
	for (NSDictionary * dict in sharesRemote)
	{
		// Check if we even have a share with the shareId
		
		Share * s = [[dataModel myShares] objectForKey:[dict objectForKey:@"shareId"]];
		if ( s )
		{
			// Check if s(hare) contains a peer with peerId
			
			Peer * p = [s getPeerForID:[d objectForKey:@"peerId"]];
			if ( p == nil )
			{
				p = [[Peer alloc] initWithPeerID:[d objectForKey:@"peerId"] andShare:s];
				[s setPeer:p];
			}
			// Set the currentRev
			
			[p setCurrentRev:[dict objectForKey:@"currentRev"]];
		}
	}
	
	// Continue downloading revisions...
	
	if ([revMatcherQueue operationCount] == 0)
	{
		[self downloadRevisionsFromPeers];
	}
	
	
	// ...and files
	
	if ([[dataModel fileDownloads] count] < MAX_CONCURRENT_DOWNLOADS / 2)
	{
		[self matchFiles];
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
	NSError * error;
	
	// Convert NSData to NSDictionary
	
	NSDictionary * dict = [NSDictionary dictionaryWithJSONData:[d response] error:&error];
	if (error)
	{
		DebugLog(@"response-count:%li", [[dict objectForKey:@"revisions"] count]);
		return;
	}
	//	DebugLog(@"REVISIONS:\n%@", dict);
	
	
	// Store revisions in share->peers->downloadedRevs
	
	if ([[dict objectForKey:@"revisions"] count] > 0)
	{
		// Sort the downloaded revisions by the revision-number
		
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
		
		for (id key in keysSortedByRevision)
		{
			NSDictionary * rev	= [[dict objectForKey:@"revisions"] objectForKey:key];
			NSNumber * revision = [rev objectForKey:@"revision"];
			NSNumber * fileSize = [rev objectForKey:@"fileSize"];
			NSNumber * isSet = [rev objectForKey:@"isSet"];
			NSMutableDictionary * extendedAttributes = [NSMutableDictionary dictionaryWithDictionary:[rev objectForKey:@"extendedAttributes"]];
			NSMutableDictionary * versions = [NSMutableDictionary dictionaryWithDictionary:[rev objectForKey:@"versions"]];
			NSNumber * isSymlink = [rev objectForKey:@"isSymlink"];
			NSString * targetPath = [rev objectForKey:@"targetPath"];
			Revision * r = [[Revision alloc] init];
			[r setRelURL:key];
			[r setRevision:revision];
			[r setFileSize:fileSize];
			[r setIsSet:isSet];
			[r setIsDir:[NSNumber numberWithBool:[key hasSuffix:@"/"]]];
			[r setExtAttributes:extendedAttributes];
			[r setVersions:versions];
			[r setIsSymlink:isSymlink];
			[r setTargetPath:targetPath];
			[r setPeer:[d peer]];
			
			RevisionMatchOperation * o = [[RevisionMatchOperation alloc] initWithRevision:r];
			[revMatcherQueue addOperation:o];
		}
		
		
		// Get biggest revision from response->revisions
		
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


/**
 * OVERRIDE: Delegate function called by "download" inherited from <DownloadFileDelegate>
 */
- (void) downloadFileHasFinished:(DownloadFile*)d
{
	DebugLog(@"DL finished : %@", [[d rev] relURL]);
	DebugLog(@"downloadPath: %@", [d downloadPath]);
	[dataModel addOrRemove:0 synchronizedFromFileDownloads:d];
	
	FileMatchOperation * o = [[FileMatchOperation alloc] initWithDownloadFile:d];
	[fileMatcherQueue addOperation:o];
}



/**
 * OVERRIDE: Delegate function called by "download" inherited from <DownloadFileDelegate>
 */
- (void) downloadFileHasFailed:(DownloadFile*)d
{
	DebugLog(@"ERROR: downloadFileHasFailed: %@", [d downloadPath]);
	[dataModel addOrRemove:0 synchronizedFromFileDownloads:d];
	
	// Remove failed download-file from downloads directory
	
	NSError * error;
	[[NSFileManager defaultManager] removeItemAtPath:[d downloadPath] error:&error];
	if (error)
	{
		DebugLog(@"ERROR: removeItemAtURL failed!, %@", error);
		return;
	}
	
	// Keep the revision unless we receive a 404-Error
	
	if ([d statusCode] != 404)
	{
		Revision * r = [d rev];
		[[[r peer] share] setRevision:r forPeer:[r peer]];
	}
}



/**
 * KVO: matcherQueue->operationCount
 * KVO: fsWatcherQueue->operationCount
 */
- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
	if (object == revMatcherQueue && [keyPath isEqualToString:@"operationCount"])
	{
		//DebugLog(@"revMatcherQueue->operationCount: %lu", (unsigned long)[revMatcherQueue operationCount]);
		if ([revMatcherQueue operationCount] == 0)
		{
			// Do something here when your queue has completed
			
			DebugLog(@"queue has completed");
			
			
			// Restart Revision-Download
			
			[self downloadRevisionsFromPeers];
			
			if ([fileMatcherQueue operationCount] == 0)
			{
				// Download more files
				
				[self matchFiles];
			}
		}
	}
	else if (object == fsWatcherQueue && [keyPath isEqualToString:@"operationCount"])
	{
		//DebugLog(@"fsWatcherQueue->operationCount: %lu", (unsigned long)[fsWatcherQueue operationCount]);
		
		/*
		 * If the 'operationCount' gets bigger than FSWATCHER_QUEUE_THRESHOLD the application
		 * should cancelAll ongoing operations,
		 * sleep for 5 seconds and then scan all the shares.
		 */
		
		if ([fsWatcherQueue operationCount] > FSWATCHER_QUEUE_THRESHOLD)
		{
			if (![fsWatcherQueue isSuspended])
			{
				[fsWatcherQueue cancelAllOperations];
				DebugLog(@"fswatcherQueueRestartet == FALSE");
				[fsWatcherQueue setSuspended:TRUE];
				[self performSelector: @selector(restartFSWatcherQueue)
						 withObject: nil
						 afterDelay: 5.0];
			}
			return;
		}
	}
	else if (object == fileMatcherQueue && [keyPath isEqualToString:@"operationCount"])
	{
		//DebugLog(@"fileMatcherQueue->operationCount: %lu", (unsigned long)[fsWatcherQueue operationCount]);
		if ([fileMatcherQueue operationCount] == 0)
		{
			// Download more files
			
			[self matchFiles];
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
	
	// Do the rescan
	
	[fsWatcherQueue setSuspended:FALSE];
	
	for (Share * s in [[dataModel myShares] allValues])
	{
		ShareScanOperation * o = [[ShareScanOperation alloc] initWithShare:s];
		[fsWatcherQueue addOperation:o];
	}
}





/**
 * Notification from Watcher
 * This is the buffer for the firehose of fsevents
 */
- (void) fsWatcherEvent: (NSNotification *)notification
{
	// Return from function if fsWatcherQueue isSuspended
	
	if ([fsWatcherQueue isSuspended])
	{
		return;
	}
	
	NSURL * fileURL = [notification object];
	//DebugLog(@"fsWatcherEvent: %@", fileURL);
	
	for (Share * share in [[dataModel myShares] allValues])
	{
		if (![FileHelper URL:fileURL hasAsRootURL:[share root]])
		{
			continue;
		}
		
		FileScanOperation * o = [[FileScanOperation alloc] initWithURL:fileURL andShare:share];
		[fsWatcherQueue addOperation:o];
	}
}


/**
 * Updates the FSWatcher-instance with the currently synced shares
 */
- (void) updateFSWatcher
{
	// Prepare temporary table with paths
	
	NSMutableArray * a = [[NSMutableArray alloc] init];
	
	for (Share * s in [[dataModel myShares] allValues])
	{
		[a addObject:[[s root] path]];
	}
	DebugLog(@"%@", a);
	[fswatcher setPaths:a];
	[fswatcher startWatching];
}






#pragma mark -----------------------
#pragma mark Download Manager Functions


/**
 * Status: COMPLETE
 */
- (void) downloadSharesFromPeers:(NSNotification*)aNotification
{
	DebugLog(@"downloadSharesFromPeers");
	
	// For every announced NetService...
	
	for (id key in [bonjourSearcher resolvedServices])
	{
		NSNetService *aNetService = [[bonjourSearcher resolvedServices] objectForKey:key];
		
		// ...and for every Share
		
		DownloadShares * d = [[DownloadShares alloc] initWithNetService:aNetService];
		[d setDelegate:self];
		[d start];
	}
}



- (void) notifyPeers:(NSNotification*)aNotification
{
	DebugLog(@"notifyPeers");
	// For every announced NetService...
	
	for (id key in [bonjourSearcher resolvedServices])
	{
		NSNetService *aNetService = [[bonjourSearcher resolvedServices] objectForKey:key];
		
		PostNotification * n = [[PostNotification alloc] initWithNetService:aNetService];
		[n start];
	}
}


/**
 *
 */
- (void) downloadRevisionsFromPeers
{
	// For every Share ....
	
	for (id key in [dataModel myShares])
	{
		Share * s = [[dataModel myShares] objectForKey:key];
		for (Peer * p in [s allPeers])
		{
			NSNetService * ns = [bonjourSearcher getNetServiceForName:[p peerID]];
			
			// Compare currentRev (on remote peer) with lastDownloadedRev
			
			if (ns != nil
			    && ([[p currentRev] longLongValue] > [[p lastDownloadedRev] longLongValue]))
			{
				DownloadRevisions * d = [[DownloadRevisions alloc] initWithNetService:ns andPeer:p];
				[d setDelegate:self];
				[d start];
			}
		}
	}
}


- (void) matchFiles
{
	// For every Share ...
	for (id key in [dataModel myShares])
	{
		Share * s = [[dataModel myShares] objectForKey:key];
		
		// For ervery Peer ...
		for (Peer * p in [s allPeers])
		{
			NSNetService * ns = [bonjourSearcher getNetServiceForName:[p peerID]];
			
			if (ns != nil)
			{
				Revision * r = [s nextRevisionForPeer:p];
				
				while (r != nil && [[dataModel fileDownloads] count] < MAX_CONCURRENT_DOWNLOADS)
				{
					[s removeRevision:r forPeer:p];
					
					DownloadFile * d = [[DownloadFile alloc] initWithNetService:ns andRevision:r];
					[dataModel addOrRemove:1 synchronizedFromFileDownloads:d];
					[d setDelegate:self];
					[d start];
					
					r = [s nextRevisionForPeer:p];
				}
			}
		}
	}
}



@end