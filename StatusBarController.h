//
//  StatusBarController.h
//  Peerbox
//
//  Created by Daniel Forrer on 12.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MainController;
@class EditSharesWindowController;

@interface StatusBarController : NSObject

- (id) initWithMainController:(MainController*) m;

@property (nonatomic, readonly, retain) NSStatusItem * statusItem;
@property (nonatomic, readonly, retain) EditSharesWindowController * eswc;
@property (nonatomic, readonly, retain) MainController * mc;

@end
