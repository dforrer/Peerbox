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
@class DataModel;
@class StatusBarController;
@class EditSharesWindowController;


@interface MainController : NSObject <DownloadSharesDelegate, DownloadRevisionsDelegate, DownloadFileDelegate, BonjourSearcherDelegate>


- (id) init;
- (void) saveModelToPlist;
- (void) printResolvedServices;
- (void) printMyShares;
- (void) printDebugLogs;


@property (nonatomic, readonly, strong)	BonjourSearcher * bonjourSearcher;
@property (nonatomic, readonly, strong)	HTTPServer * httpServer;
@property (nonatomic, readonly, strong)	FSWatcher * fswatcher;
@property (nonatomic, readonly, strong)	DataModel * dataModel;
@property (nonatomic, readonly, retain) StatusBarController * statusBarController;
@property (nonatomic, readonly, retain) EditSharesWindowController * editSharesWindowController;



@end
