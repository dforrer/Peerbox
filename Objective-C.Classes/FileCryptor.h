/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */


@interface FileCryptor : NSObject

+ (void) encryptAtPath: (NSString*) fromPath
			 toPath: (NSString*) toPath
		  withAES256: (NSString*) password;

+ (void) decryptAtPath: (NSString*) fromPath
			 toPath: (NSString*) toPath
		  withAES256: (NSString*) password;

@end