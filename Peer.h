//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//


@class DownloadRevisions;
@class Share;
@class Revision;
@class Configuration;


@interface Peer : NSObject


- (id) initWithPeerID:(NSString*) pid andShare:(Share*) s andConfig:(Configuration*)c;
- (void) addRevision:(Revision*)rev;
- (void) removeRevision:(Revision*)rev;
- (NSDictionary*) downloadedRevs;
- (NSArray*) downloadedRevsWithIsSetFalse;
- (NSArray*) downloadedRevsWithIsDirTrue;


// Other
//-------
- (NSString *)description;
- (NSDictionary*) plistEncoded;


@property (nonatomic,readwrite,strong) NSNumber * currentRev; // of the remote peer
@property (nonatomic,readwrite,strong) NSNumber * lastDownloadedRev;
@property (nonatomic,readonly ,strong) NSString * peerID;
@property (nonatomic,readwrite,strong) Share * share;
@property (nonatomic,readwrite,strong) NSNetService * netService;
@property (nonatomic,readonly) int numOfRevsBeingMatched;
@property (nonatomic,readonly,strong) Configuration * config;
@property (nonatomic, readwrite, strong) DownloadRevisions * revisionsDownload;


@end
