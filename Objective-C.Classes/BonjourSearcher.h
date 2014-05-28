/**
 * VERSION:	1.02
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */


#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#define NSLog(FORMAT, ...) fprintf( stderr, "%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String] );
#define DebugLog( s, ... ) NSLog( @"<%@:(%d)> \t%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )

#endif

@protocol BonjourSearcherDelegate <NSObject>

- (void) bonjourSearcherServiceResolved:(NSNetService*)n;
- (void) bonjourSearcherServiceRemoved:(NSNetService*)n;

@end



@interface BonjourSearcher : NSObject <NSNetServiceBrowserDelegate, NSNetServiceDelegate>

/* 
 * NSMutableArray of NSNetService:
 * in this Array we store all the announced AND resolved
 * services 
 */

@property (nonatomic,readonly,strong) NSMutableDictionary * resolvedServices;
@property (nonatomic,readonly,strong) NSString * myServiceName;
@property (nonatomic,assign) id<BonjourSearcherDelegate> delegate;

- (id) initWithServiceType: (NSString *) type
			  andDomain: (NSString *) domain;

- (id) initWithServiceType: (NSString *) type
			  andDomain: (NSString *) domain
		andMyName: (NSString *) name;

- (NSNetService*) getNetServiceForName: (NSString *) name;

@end
