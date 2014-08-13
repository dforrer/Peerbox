//
//  DataModel.h
//  Peerbox
//
//  Created by Daniel Forrer on 13.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Share;
@class BonjourSearcher;
@class DownloadFile;


@interface DataModel : NSObject


- (BOOL) addShare:(Share*)s;
- (void) removeShare:(Share*)s;
- (void) commitAllShareDBs;
- (void) saveFileDownloads;
- (NSDictionary*) plistEncoded;
- (void) addOrRemove:(int)addOrRemove synchronizedFromFileDownloads:(DownloadFile *)d;


@property (nonatomic, readonly, strong) NSMutableArray * fileDownloads;
@property (nonatomic, readwrite, strong) NSMutableDictionary * myShares; // shareId = key of NSDictionary


@end
