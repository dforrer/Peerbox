//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class File;
@class Share;


@interface FullScanOperation : NSOperation

- (id)initWithShare: (Share*) s;

@property (nonatomic, readonly, strong)	Share * share;

@end
