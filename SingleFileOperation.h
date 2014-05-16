//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class Share;


@interface SingleFileOperation : NSOperation


- (id)initWithURL: (NSURL*) u andShare: (Share*) s;


@property (nonatomic, readonly, strong)	NSURL * fileURL;
@property (nonatomic, readonly, strong)	Share * share;


@end
