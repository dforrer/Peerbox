/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */


@interface FileHelper : NSObject


+ (void) setFilePermissionsAtPath:(NSString*)path toOctal:(int)oct;
+ (BOOL) hashA:(NSString*) hashA isSmallerThanHashB: (NSString *) hashB;
+ (NSString *) getDocumentsDirectory;
+ (BOOL) isSymbolicLink: (NSString*) path;
+ (BOOL) replaceSymlinkAtPath: (NSString*) path;
+ (void) removeSymlinksRecursiveAtPath:(NSString*) path; // UNTESTED
+ (BOOL) hasExtendedAttributes:(NSString *) path;
+ (BOOL) fileFolderExists: (NSString *) path;
+ (BOOL) fileFolderSymlinkExists: (NSString *)path;
+ (BOOL) isDirectory: (NSString *) path;
+ (NSArray *) scanDirectory: (NSURL *) u;
+ (NSArray *) scanDirectoryRecursive: (NSURL *) u;
+ (NSData*) dictionaryToXMLData: (NSDictionary *) dict;
+ (NSString *) sha1OfFile:(NSString *) path;
+ (NSString *) sha1OfNSData: (NSData*) data;
+ (NSString *) sha1OfNSString: (NSString *) str;
+ (NSString *) sha512OfNSString: (NSString *) str;
+ (NSMutableDictionary*) extendedAttrAsDictAtPath: (NSString *) path; // DEPRECEATED
+ (long long) fileModTimeAsLongLongAtPath: (NSString *) path;
+ (NSData *) createRandomNSDataOfSize: (unsigned long)size;
+ (NSString *) createRandomNSStringOfSize: (unsigned int) numOfChars;
+ (BOOL) URL:(NSURL*) one hasAsRootURL: (NSURL*) two;
+ (NSString*) getIPv4FromNetService:(NSNetService*)netService;
+ (NSFileHandle*) fileForWritingAtPath: (NSString*) path;
+ (BOOL) removeAllFilesInDir:(NSString*)path;
// Get and Set extended attributes of files
+ (BOOL)setValue:(NSObject *)value forName:(NSString *)name onFile:(NSString *)filePath;
+ (NSData *)getDataValueForName:(NSString *)name onFile:(NSString *)filePath;
+ (NSDictionary *)getAllValuesOnFile:(NSString *)filePath;
+ (void) removeAllValuesOnFile:(NSString *)filePath;
+ (void) matchExtAttributes:(NSDictionary*)dict onURL:(NSURL*)url;
+ (NSString*) getSymlinkDestination:(NSString*) path;

@end