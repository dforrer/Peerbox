//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class Revision;
@class Configuration;
@class DownloadFile;


@protocol DownloadFileDelegate <NSObject>

- (void) downloadFileHasFinished:(DownloadFile*)d;
- (void) downloadFileHasFailed:(DownloadFile*)d;

@end


@interface DownloadFile : NSObject

- (id) initWithNetService:(NSNetService*)netService
		    andRevision:(Revision*)r
			 andConfig:(Configuration*)c;
- (void) start;
- (void) cancel;

@property (nonatomic, readonly, strong) Revision * rev;
@property (nonatomic, readonly, strong) NSString * downloadPath;
@property (nonatomic, readonly, strong) NSMutableURLRequest * request;
@property (nonatomic, readonly, strong) NSFileHandle * download;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL hasFailed;
@property (nonatomic, assign) id <DownloadFileDelegate> delegate;
@property (nonatomic, readonly, strong) NSString * sha1OfDownload;
@property (nonatomic, readonly, strong) Configuration * config;
@property (nonatomic, readonly) int statusCode;
@end
