//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@interface Configuration : NSObject

- (id) init;

@property (nonatomic, readwrite, strong) NSString * workingDir;
@property (nonatomic, readwrite, strong) NSString * downloadsDir;
@property (nonatomic, readwrite, strong) NSString * webDir;


@end