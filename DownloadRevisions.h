//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class Peer;
@class DownloadRevisions;



@protocol DownloadRevisionsDelegate <NSObject>

- (void) downloadRevisionsHasFinished:(DownloadRevisions*)d;
- (void) downloadRevisionsHasFailed:(DownloadRevisions*)d;

@end



@interface DownloadRevisions : NSObject

- (id) initWithNetService:(NSNetService*)netService andPeer:(Peer*)p;
- (void)start;

@property (nonatomic, readonly, strong) Peer * peer;
@property (nonatomic, readonly, strong) NSMutableURLRequest * request;
@property (nonatomic, readonly, strong) NSMutableData * response;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic,assign) id<DownloadRevisionsDelegate> delegate;

@end
