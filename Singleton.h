//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class MainModel;

/**
 * Singletons should be used with caution!
 * ----------------------------------------
 * Rules for using the Singleton:
 * - use Singleton only in the initializer
 * - usage should be transparent
 */

@interface Singleton : NSObject
{
	MainModel * mainModel;
}


@property (nonatomic, retain) MainModel * mainModel;	// only used by 'MyHTTPConnection'


+ (id) data;


@end