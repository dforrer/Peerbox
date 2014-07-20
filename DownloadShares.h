//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@protocol DownloadSharesDelegate <NSObject>

- (void) downloadSharesHasFinishedWithResponseDict:(NSDictionary*)d;
- (void) downloadSharesHasFailed;

@end


@interface DownloadShares : NSObject


- (id) initWithNetService:(NSNetService*)n;
- (void)start;


@property (nonatomic, readonly, strong) NSMutableURLRequest * request;
@property (nonatomic, readonly, strong) NSMutableData * response;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL hasFailed;
@property (nonatomic, assign) id <DownloadSharesDelegate> delegate;

@end
