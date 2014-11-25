/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:	Observes 0-n directories and reports changes to directories (and files)
 *			via NSNotificationCenter
 */



@interface FSWatcher : NSObject


- (id) init;
- (void) shouldObserveFiles: (BOOL) b;	// By Default YES
- (void) shouldIgnoreSelf: (BOOL) b;	// By Default YES
- (void) setPaths:(NSArray *) paths;
- (void) startWatching;
- (void) stopWatching;

@property (nonatomic, readonly, strong) NSArray * watchedPaths;
@property (nonatomic, readonly) BOOL observeFiles;
@property (nonatomic, readonly) BOOL ignoreSelf;
@property (nonatomic, readonly) BOOL isWatching;


@end


/*
 nonatomic vs. atomic - "atomic" is the default. Always use "nonatomic". I don't know why, but the book I read said there is "rarely a reason" to use "atomic". (BTW: The book I read is the BNR "iOS Programming" book.)
 
 readwrite vs. readonly - "readwrite" is the default. When you @synthesize, both a getter and a setter will be created for you. If you use "readonly", no setter will be created. Use it for a value you don't want to ever change after the instantiation of the object.
 
 strong vs. strong
 
 */
