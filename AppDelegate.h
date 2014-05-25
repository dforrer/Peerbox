//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource>


- (IBAction) addShare: (id)sender;
- (IBAction) removeShare: (id)sender;
- (IBAction) downloadShares:(id)sender;
- (IBAction) downloadRevisions:(id)sender;
- (IBAction) matchFiles:(id)sender;
- (IBAction) printShares: (id)sender;
- (IBAction) printResolvedServices: (id)sender;

@property (assign) IBOutlet NSTableView *sharesTableView;
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *shareIdTextfield;
@property (weak) IBOutlet NSTextField *rootTextfield;
@property (weak) IBOutlet NSTextField *passwordTextfield;


@end


/*
 nonatomic vs. atomic - "atomic" is the default. Always use "nonatomic". I don't know why, but the book I read said there is "rarely a reason" to use "atomic". (BTW: The book I read is the BNR "iOS Programming" book.)
 
 readwrite vs. readonly - "readwrite" is the default. When you @synthesize, both a getter and a setter will be created for you. If you use "readonly", no setter will be created. Use it for a value you don't want to ever change after the instantiation of the object.
 
 retain vs. copy vs. assign
 
 "assign" is the default. In the setter that is created by @synthesize, the value will simply be assigned to the attribute. My understanding is that "assign" should be used for non-pointer attributes.
 "retain" is needed when the attribute is a pointer to an object. The setter generated by @synthesize will retain (aka add a retain count) the object. You will need to release the object when you are finished with it.
 "copy" is needed when the object is mutable. Use this if you need the value of the object as it is at this moment, and you don't want that value to reflect any changes made by other owners of the object. You will need to release the object when you are finished with it because you are retaining the copy.
 */