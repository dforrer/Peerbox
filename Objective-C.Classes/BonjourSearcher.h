/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */


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
