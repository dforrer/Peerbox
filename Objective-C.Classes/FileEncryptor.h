/**
 * VERSION:	1.0
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */


#ifdef __OBJC__

#import <Cocoa/Cocoa.h>
#define NSLog(FORMAT, ...) fprintf( stderr, "%s\n", [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String] );
#define DebugLog( s, ... ) NSLog( @"<%@:(%d)> \t%@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )

#endif


@interface FileEncryptor : NSObject

+ (void) encryptAtPath:(NSString*)fromPath toPath:(NSString*)toPath withAES256:(NSString*) password;

@end