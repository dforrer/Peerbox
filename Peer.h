//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import "Revision.h"

@class DownloadRevisions;
@class Share;


@interface Peer : NSObject <RevisionDelegate>


- (id) initWithPeerID:(NSString*) pid andShare:(Share*) s andConfig:(Configuration*)c;
- (void) addRevision:(Revision*)rev;
- (void) removeRevision:(Revision*)rev;
- (NSDictionary*) allDownloadedRevs;
- (NSDictionary*) plistEncoded;
- (void) matchNextRevisions;


// Other
//-------
- (NSString *)description;


@property (nonatomic,readwrite,strong) NSNumber * currentRev; // of the remote peer
@property (nonatomic,readwrite,strong) NSNumber * lastDownloadedRev;
@property (nonatomic,readonly ,strong) NSString * peerID;
@property (nonatomic,readwrite,strong) Share * share;
@property (nonatomic,readwrite,strong) NSNetService * netService;
@property (nonatomic,readonly) int numOfRevsBeingMatched;
@property (nonatomic,readonly,strong) Configuration * config;
@property (nonatomic, readwrite, strong) DownloadRevisions * revisionsDownload;


@end
