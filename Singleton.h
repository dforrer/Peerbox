//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class DataModel;
@class Configuration;
/**
 * Singletons should be used with caution!
 * ----------------------------------------
 * Rules for using the Singleton:
 * - usage should be transparent
 */

@interface Singleton : NSObject

@property (nonatomic, readwrite, retain) DataModel * dataModel;
@property (nonatomic, readwrite, retain) NSString * myPeerID;
@property (nonatomic, readonly, retain) Configuration * config;

+ (id) data;


@end