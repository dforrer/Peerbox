//
//  PostNotification.h
//  Peerbox
//
//  Created by Daniel on 30.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PostNotification : NSObject

- (id) initWithNetService:(NSNetService*)n;
- (void)start;

@property (nonatomic, readonly, strong) NSMutableURLRequest * request;

@end
