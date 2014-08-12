//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

/**
 * The MainController should never use the Singleton
 */


#import "DownloadShares.h"
#import "DownloadFile.h"
#import "DownloadRevisions.h"
#import "BonjourSearcher.h"

@class Share;
@class Configuration;
@class FSWatcher;
@class HTTPServer;

@interface MainController : NSObject <DownloadSharesDelegate, DownloadRevisionsDelegate, DownloadFileDelegate, BonjourSearcherDelegate>

- (id) init;
- (Share*) getShareForID:(NSString*)shareID;
- (Share*) addShareWithID:(NSString*)shareId andRootURL:(NSURL*)root andPasswordHash:(NSString*)passwordHash;
- (void) removeShareForID:(NSString*) shareId;
- (void) commitAllShareDBs;
- (void) saveModelToPlist;
- (void) saveFileDownloads;
- (void) printResolvedServices;
- (void) printMyShares;
- (void) printDebugLogs;
- (void) downloadSharesFromPeers;

@property (nonatomic, readonly, strong)	Configuration * config;
@property (nonatomic, readonly, strong)	BonjourSearcher * bonjourSearcher;
@property (nonatomic, readonly, strong)	HTTPServer * httpServer;
@property (nonatomic, readonly, strong)	FSWatcher * fswatcher;

@property (nonatomic, readonly, strong) NSMutableArray * fileDownloads;
@property (nonatomic, readonly, strong) NSMutableDictionary * myShares; // shareId = key of NSDictionary

@end
