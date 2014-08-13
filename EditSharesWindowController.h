//
//  Created by Daniel Forrer on 10.08.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DataModel;

@interface EditSharesWindowController : NSWindowController <NSTableViewDataSource>

- (id) initWithDataModel:(DataModel*) dm;
- (void) openEditDialog;

- (IBAction) addShare: (id)sender;
- (IBAction) removeShare: (id)sender;
- (IBAction) downloadShares:(id)sender;
- (IBAction) printShares: (id)sender;
- (IBAction) printResolvedServices: (id)sender;
- (IBAction) printDebugLogs:(id)sender;

@property (nonatomic, readonly, retain) IBOutlet NSTableView * sharesTableView;
@property (nonatomic, readonly, retain) IBOutlet NSTextField * shareIdTextfield;
@property (nonatomic, readonly, retain) IBOutlet NSTextField * rootTextfield;
@property (nonatomic, readonly, retain) IBOutlet NSTextField * passwordTextfield;


@end
