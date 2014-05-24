//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//


@class Share;


@interface Peer : NSObject


- (id) initWithPeerID:(NSString*) pid andShare:(Share*) s;

// Other
//-------
- (NSString*) description;
- (NSDictionary*) plistEncoded;


@property (nonatomic, readwrite, strong) NSNumber * currentRev; // of the remote peer
@property (nonatomic, readwrite, strong) NSNumber * lastDownloadedRev;
@property (nonatomic, readonly , strong) NSString * peerID;
@property (nonatomic, readwrite, strong) Share * share;


@end
