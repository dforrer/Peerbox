//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class Revision;
@class DownloadBulk;


@protocol DownloadBulkDelegate <NSObject>

- (void) downloadBulkHasFinished:(DownloadBulk*)d;
- (void) downloadBulkHasFailed:(DownloadBulk*)d;

@end


@interface DownloadBulk : NSObject

- (id) initWithNetService:(NSNetService*)netService
		   andRevisions:(NSDictionary*)r;
- (void) start;
- (void) cancel;

@property (nonatomic, readonly, strong) NSDictionary * revisions;
@property (nonatomic, readonly, strong) NSMutableURLRequest * request;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL hasFailed;
@property (nonatomic, assign) id <DownloadFileDelegate> delegate;
@property (nonatomic, readonly) int statusCode;
@end
