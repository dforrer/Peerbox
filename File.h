//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class Share;


@interface File : NSObject

- (NSString*) description;
- (id) initAsNewFileWithPath:(NSString*) p;
- (id) initWithShare:(Share*)s relUrl:(NSString*)u isSet:(NSNumber*)i extAttributesAsBase64:(NSDictionary*)e versions:(NSMutableDictionary*)v;
- (void) print;
- (void) addVersion:(NSString *) hash;
- (NSString*) getLastVersionHash;
- (NSString*) getLastVersionKey;
- (BOOL) isCoreEqualToFile:(File*)f;
- (BOOL) isEqualToFile:(File*)f;
- (BOOL) isDir;
- (BOOL) hasConflictingVersionsWithFile:(File*)f;
+ (BOOL) versions:(NSDictionary*)v1 hasConflictsWithVersions:(NSDictionary*)v2;
+ (void) matchExtAttributes:(NSDictionary*)dict onURL:(NSURL*)url;

// Setter
//--------
- (void) setUrl:(NSURL *)u;
- (void) setRevision:(NSNumber *)rev;
- (void) setFileSize:(NSNumber *)size;
- (void) setContentModDate:(NSDate *)modDate;
- (void) setAttributesModDate:(NSDate *)modDate;
- (void) setIsSetBOOL:(BOOL)b;
- (void) setIsSet:(NSNumber *)s;
- (void) setExtAttributes:(NSMutableDictionary *)extAttr;
- (void) setVersions:(NSMutableDictionary *)v ;

// Updater
//---------
- (void) updateIsSet;
- (void) updateFileSize;
- (void) updateContentModDate;
- (void) updateAttributesModDate;
- (void) updateExtAttributes;
- (BOOL) updateVersions;


@property (nonatomic,readonly,strong) NSURL		* url;
@property (nonatomic,readonly,strong) NSNumber	* revision;
@property (nonatomic,readonly,strong) NSNumber	* fileSize;
@property (nonatomic,readonly,strong) NSDate		* contentModDate;
@property (nonatomic,readonly,strong) NSDate		* attributesModDate;
@property (nonatomic,readonly,strong) NSNumber	* isSet;
@property (nonatomic,readonly,strong) NSMutableDictionary * extAttributes; // BASE64-encoded
@property (nonatomic,readonly,strong) NSMutableDictionary * versions;


@end


