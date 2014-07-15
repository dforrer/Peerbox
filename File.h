//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class Share;


@interface File : NSObject

- (NSString*) description;
- (id) initAsNewFileWithPath:(NSString*) p;
- (id) initWithShare:(Share*)s
		    relUrl:(NSString*)u
			isSet:(NSNumber*)i
	  extAttributes:(NSDictionary*)e
		  versions:(NSMutableDictionary*)v
		 isSymlink:(NSNumber*)sym
		targetPath:(NSString*)t;
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
- (void) setIsSetBOOL:(BOOL)b;
- (void) setIsSymlinkBOOL:(BOOL)b;

// Updater
//---------
- (void) updateSymlink; // needs to be called before the other update functions
- (void) updateFileSize;
- (void) updateContentModDate;
- (void) updateAttributesModDate;
- (void) updateExtAttributes;
- (BOOL) updateVersions;


@property (nonatomic,readwrite,strong) NSURL		* url;
@property (nonatomic,readwrite,strong) NSNumber	* revision;
@property (nonatomic,readwrite,strong) NSNumber	* fileSize;
@property (nonatomic,readwrite,strong) NSDate	* contentModDate;
@property (nonatomic,readwrite,strong) NSDate	* attributesModDate;
@property (nonatomic,readwrite,strong) NSNumber	* isSet;
@property (nonatomic,readwrite,strong) NSMutableDictionary * extAttributes; // BASE64-encoded
@property (nonatomic,readwrite,strong) NSMutableDictionary * versions;
@property (nonatomic,readwrite,strong) NSNumber	* isSymlink;
@property (nonatomic,readwrite,strong) NSString	* targetPath;


@end


