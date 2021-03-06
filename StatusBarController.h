//
//  StatusBarController.h
//  Peerbox
//
//  Created by Daniel Forrer on 12.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import <Foundation/Foundation.h>


@class DataModel;
@class BonjourSearcher;


@interface StatusBarController : NSObject


- (id) initWithDataModel:(DataModel*)dm andBonjourSearcher:(BonjourSearcher*)bs;
- (void) refreshStatusBar;


@property (nonatomic, readonly, retain) NSStatusItem * statusItem;
@property (nonatomic, readonly, retain) DataModel * dataModel;
@property (nonatomic, readonly, retain) BonjourSearcher * bonjourSearcher;
@property (nonatomic, retain) NSTimer * timer;


@end
