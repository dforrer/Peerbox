//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class MainController;

/**
 * Singletons should be used with caution!
 * ----------------------------------------
 * Rules for using the Singleton:
 * - use Singleton only in the initializer
 * - usage should be transparent
 */

@interface Singleton : NSObject
{
	MainController * mainModel;
}


@property (nonatomic, retain) MainController * mainModel;	// only used by 'MyHTTPConnection'


+ (id) data;


@end