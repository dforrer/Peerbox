//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

/**
 * The MainModel should never use the Singleton
 */


#import "BonjourSearcher.h"
#import "DownloadShares.h"
#import "DownloadFile.h"
#import "DownloadRevisions.h"
#import "Revision.h"

@class Share;
@class Configuration;
@class FSWatcher;
@class HTTPServer;


@interface MainModel : NSObject <BonjourSearcherDelegate, DownloadSharesDelegate, DownloadRevisionsDelegate, RevisionDelegate>



- (id) init;
- (Share*) getShareForID:(NSString*)shareID;
- (Share*) addShareWithID:(NSString*)shareId andRootURL:(NSURL*)root andPasswordHash:(NSString*)passwordHash;
- (NSMutableDictionary*) getAllShares;
- (void) removeShareForID:(NSString*) shareId;
- (void) commitAllShareFilesDBs;
- (void) saveModel;
- (void) printResolvedServices;
- (void) printMyShares;
- (void) matchRevisions;
- (void) downloadSharesFromPeers;
- (void) downloadRevisionsFromPeers;

@property (nonatomic, readonly, strong)	Configuration * config;
@property (nonatomic, readonly, strong)	BonjourSearcher * bonjourSearcher;
@property (nonatomic, readonly, strong)	HTTPServer * httpServer;
@property (nonatomic, readonly, strong)	FSWatcher  * fswatcher;



@end
