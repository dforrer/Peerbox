/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:
 */

// HEADER
#import "FileHelper.h"

#include <arpa/inet.h>
#include <CommonCrypto/CommonDigest.h>
#include <sys/xattr.h>
#include <sys/stat.h>



@implementation FileHelper

/**
 * Unused
 */

+ (void) setFilePermissionsTo755:(NSString*) path
{
	mode_t dirMask = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;
	chmod([path cStringUsingEncoding:NSUTF8StringEncoding], dirMask);
}



+ (void) setFilePermissionsAtPath:(NSString*)path toOctal:(int)oct
{
	// Convert octal to decimal

	int dec = octal_decimal(oct);
	
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	[dict setObject:[NSNumber numberWithInt:dec]  forKey:NSFilePosixPermissions];
	/* 493 is Decimal for the 755 octal */
	/* 511 is Decimal for the 777 octal */
	NSError *error1;
	[[NSFileManager defaultManager] setAttributes:dict ofItemAtPath:path error:&error1];
	if (error1) {
		NSLog(@"setFilePermissionsAtPath: %@", error1);
	}
}



/**
 * Function to convert decimal to octal
 */

int decimal_octal(int n)
{
	int rem, i=1, octal=0;
	while (n!=0)
	{
		rem=n%8;
		n/=8;
		octal+=rem*i;
		i*=10;
	}
	return octal;
}



/**
 * Function to convert octal to decimal
 */

int octal_decimal(int n)
{
	int decimal=0, i=0, rem;
	while (n!=0)
	{
		rem = n%10;
		n/=10;
		decimal += rem*pow(8,i);
		++i;
	}
	return decimal;
}

+ (BOOL) hashA:(NSString*) hashA isSmallerThanHashB: (NSString *) hashB
{
	if ([hashA isLessThan:hashB])
	{
		return true;
	}
	return false;
}



+ (NSString*) getDocumentsDirectory
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
											   NSUserDomainMask,
											   YES);
	return [paths objectAtIndex:0];
}



/**
 * Returns TRUE if 'path' points to a symbolic link
 */

+ (BOOL) isSymbolicLink:(NSString*)path
{
	if ([[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileType] isEqualToString:@"NSFileTypeSymbolicLink"])
	{
		return TRUE;
	}
	return FALSE;
}



/**
 * Replaces the symbolic link at 'path' with
 * the file at path. If the symlink points to
 * a folder the symlink is replaced by the folder
 * with all of its contents.
 */

+ (BOOL) replaceSymlinkAtPath: (NSString*) path
{
	NSLog(@"PATH: %@\n", path);
	NSString * pointsTo = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:path error:nil];
	NSLog(@"POINTS TO: %@\n", pointsTo);
	NSString * newPath;
	
	if (![pointsTo hasPrefix:@"/"])
	{
		newPath = [path stringByDeletingLastPathComponent];
		newPath = [newPath stringByAppendingPathComponent:pointsTo];
	}
	else
	{
		newPath = pointsTo;
	}
	
	NSLog(@"NEWPATH: %@\n", newPath);
	
	NSError * error;
	[[NSFileManager defaultManager] removeItemAtPath:path error:&error];
	
	if (error)
	{
		NSLog(@"ERROR 1: %@\n", error);
		return FALSE;
	}
	
	// copyItemAtPath() copies the contents of the file
	// or folder, but that means, that there may still
	// be symlinks inside that newly copied folder!
	
	[[NSFileManager defaultManager] copyItemAtPath:newPath toPath:path error:&error];
	
	if (error)
	{
		// we get an error here, if newPath points to
		// a location that does not exist, e.g. if the
		// symlink contains an absolute path from
		// a different system.
		
		NSLog(@"ERROR 2: %@\n", error);
		return FALSE;
	}
	return TRUE;
}



/**
 * UNTESTED
 */

+ (void) removeSymlinksRecursiveAtPath: (NSString*) path
{
	BOOL continueScanning = TRUE;
	while (continueScanning)
	{
		@autoreleasepool
		{
			continueScanning = FALSE;
			NSArray * initialscan = [FileHelper scanDirectoryRecursive:[NSURL fileURLWithPath:path]];
			
			for (NSURL * u in initialscan)
			{
				if ([FileHelper isSymbolicLink:[u path]])
				{
					continueScanning = TRUE;
					[FileHelper replaceSymlinkAtPath:[u path]];
				}
			}
		}
	}
}



/**
 * Returns an Array of NSURLs
 * Keys allow us to precache information
 */

+ (NSArray *) scanDirectory: (NSURL *) u
{
	@autoreleasepool
	{
		NSArray *keys = [NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey, NSURLIsPackageKey, NSURLContentModificationDateKey, NSURLIsReadableKey, NSURLPathKey, NSURLFileResourceTypeKey, NSURLParentDirectoryURLKey, NSURLFileSizeKey,nil];
		
		NSArray *filelist = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:u includingPropertiesForKeys:keys options:0 error:nil];
		return filelist;
	}
}



/**
 * Returns an Array of NSURLs
 * Keys allow us to precache information
 */

+ (NSArray *) scanDirectoryRecursive: (NSURL *) u
{
	@autoreleasepool
	{
		// NSLog(@"FUNKTION: scanDirectoryRecursive");
		
		NSMutableArray * filelist = [[NSMutableArray alloc] init];
		
		NSArray *keys =[NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey, NSURLIsPackageKey, NSURLContentModificationDateKey, NSURLAttributeModificationDateKey, NSURLIsReadableKey, NSURLPathKey, NSURLFileResourceTypeKey, NSURLParentDirectoryURLKey, NSURLFileSizeKey, nil];
		
		NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:u includingPropertiesForKeys:keys options:0 errorHandler:^(NSURL *url, NSError *error) {
			// Handle the error.
			// Return YES if the enumeration should continue after the error.
			return YES;
		}];
		
		for (NSURL *url in enumerator)
		{
			@autoreleasepool
			{
				[filelist addObject:url];
			}
		}
		return filelist;
	}
}


/**
 * Converts the NSDictionary 'dict' to an NSData-Object
 * which is being returned in the 'NSPropertyListXMLFormat_v1_0'
 */

+ (NSData*) dictionaryToXMLData:(NSDictionary*)dict
{
	// convert dict to nsdata
	@autoreleasepool
	{
		NSError *error;
		NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format: NSPropertyListXMLFormat_v1_0 options:0 error:&error];
		if (data == nil)
		{
			NSLog (@"error serializing to xml: %@", error);
			return nil;
		}
		return data;
	}
}



/**
 * Calculates the SHA1-Hash of the NSData data
 */

+ (NSString*) sha1OfNSData:(NSData*)data
{
	@autoreleasepool
	{
		CC_SHA1_CTX state;
		CC_SHA1_Init(&state);
		CC_SHA1_Update( &state , [data bytes] , (int) [data length] );
		
		uint8_t digest[ 20 ];
		CC_SHA1_Final( digest , &state );
		
		NSMutableString *output = [NSMutableString stringWithCapacity: CC_SHA1_DIGEST_LENGTH * 2];
		
		for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		{
			[output appendFormat:@"%02x", digest[i]];
		}
		return output;
	}
}


/**
 * Returns TRUE if a file has xattr-attributes
 */

+ (BOOL) hasExtendedAttributes:(NSString *) path
{
	@autoreleasepool
	{
		size_t size_list = listxattr([path cStringUsingEncoding:NSUTF8StringEncoding], NULL, 1, 0);
		
		if (size_list<=0)
		{
			return FALSE;
		}
		else
		{
			return TRUE;
		}
	}
}


/**
 * DEPRECEATED: Use instead
 *
 * + (BOOL)setValue:(NSObject *)value forName:(NSString *)name onFile:(NSString *)filePath;
 * + (NSData *)getDataValueForName:(NSString *)name onFile:(NSString *)filePath;
 * + (NSDictionary *)getAllValuesOnFile:(NSString *)filePath;
 *
 * Returns an NSDictionary with the extended Attributes
 * Before calling this function check with "hasExtendedAttributes"
 * if the file/folder really has extended Attributes
 */

+ (NSMutableDictionary*) extendedAttrAsDictAtPath:(NSString*)path
{
	@autoreleasepool
	{
		// Get xattr data
		size_t size_list = listxattr([path cStringUsingEncoding:NSUTF8StringEncoding], NULL, 1, 0);
		char *listxattr_data = malloc(size_list+1);
		size_t rv	= listxattr([path cStringUsingEncoding:NSUTF8StringEncoding], listxattr_data, size_list, 0);
		if (rv == -1)
		{
			free(listxattr_data);
			return nil;
		}
		// remove all NULLs in listxattr_data
		int number_of_attributes = 0;
		for (int i=0; i<size_list; i++)
		{
			if (listxattr_data[i]==0)
			{
				listxattr_data[i] = '/';
				number_of_attributes++;
			}
		}
		// NULL-terminate the string
		listxattr_data [ size_list ] = '\0';
		if ( number_of_attributes == 0 )
		{
			free(listxattr_data);
			return nil;
		}
		// Parse listxattr_data
		NSMutableDictionary * xattr_list = [[NSMutableDictionary alloc] init];
		char * pch;
		pch = strtok(listxattr_data,"/");
		while ( pch != NULL )
		{
			// UPDATE hash: length_attribute_name
			NSString * attributeName = [[NSString alloc] initWithCString:pch encoding:NSUTF8StringEncoding];
			//NSLog(@"attributeName: %@", attributeName);
			// Get xattr-attributes for attribute-name
			size_t size_attr = getxattr([path cStringUsingEncoding:NSUTF8StringEncoding], pch, NULL, 1, 0, 0);
			NSMutableData * attributeData = [[NSMutableData alloc] init];
			int64_t offset = 0;
			int     bytestoread = 0;
			do {
				//printfdebug("do-While-Loop: offset: %lld, bytestoread: %i\n",offset, bytestoread);
				// Define how much to read
				if (size_attr - offset > 4000)
				{
					bytestoread = 4000;
				}
				else
				{
					bytestoread = (int)size_attr - (int)offset;
				}
				//printfdebug("size_attr: %i, offset: %lld, bytestoread: %i\n", size_attr, offset, bytestoread);
				char attr_part[bytestoread];
				// Read from the resource value
				// position specifies an offset within the extended attribute.  In the current
				// implementation, this argument is only used with the resource fork
				// attribute.  For all other extended attributes, this parameter is reserved
				// and should be zero.
				int rv = (int) getxattr([path cStringUsingEncoding:NSUTF8StringEncoding], pch, attr_part, bytestoread, (unsigned int)offset, 0);
				if (rv == -1)
				{
					free(listxattr_data);
					return nil;
				}
				[attributeData appendBytes:attr_part length:bytestoread];
				offset += bytestoread;
			} while (size_attr > offset);
			// Add Pair to Dictionary
			[xattr_list setObject:attributeData forKey:attributeName];
			pch = strtok (NULL, "/");
		}
		free(listxattr_data);
		return xattr_list;
	}
}



/**
 * Calculates the SHA1-Hash of the File at path
 */

+ (NSString*) sha1OfFile:(NSString*)path
{
	@autoreleasepool
	{
		// Sets the file pointer to the beginning of the file
		NSFileHandle * fh = [NSFileHandle fileHandleForReadingAtPath:path];
		
		if (!fh)
		{
			NSLog(@"sha1OfFile failed");
			return nil;
		}
		
		CC_SHA1_CTX state;
		CC_SHA1_Init(&state);
		
		NSData * buffer;
		
		do {
			@autoreleasepool
			{
				buffer = [fh readDataOfLength:4096];
				CC_SHA1_Update( &state , [buffer bytes] , (int) [buffer length] );
			}
		} while ( [buffer length] > 0 );
		
		[fh closeFile];
		
		uint8_t digest[ 20 ];
		CC_SHA1_Final( digest , &state );
		
		NSMutableString *output = [NSMutableString stringWithCapacity: CC_SHA1_DIGEST_LENGTH * 2];
		
		for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		{
			[output appendFormat:@"%02x", digest[i]];
		}
		
		return output;
	}
}



/**
 * Returns TRUE if the file at 'path' is a directory
 */

+ (BOOL) isDirectory:(NSString*)path
{
	@autoreleasepool
	{
		BOOL isDir;
		[[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
		return isDir;
	}
}



/**
 * Returns the File-Modification time of the file/folder at 'path'
 * as a long long (=int64_t)
 */

+ (long long) fileModTimeAsLongLongAtPath: (NSString *)path
{
	/* works with files and folders */
	struct stat buf;
	stat([path cStringUsingEncoding:NSUTF8StringEncoding], &buf);
	return buf.st_mtime; // seconds since the epoch
}



+ (NSString*) sha1OfNSString:(NSString*)str
{
	@autoreleasepool
	{
		CC_SHA1_CTX state;
		CC_SHA1_Init(&state);
		CC_SHA1_Update( &state , [str cStringUsingEncoding:NSUTF8StringEncoding] , (int) [str length] );
		uint8_t digest[ CC_SHA1_DIGEST_LENGTH ];
		CC_SHA1_Final( digest , &state );
		NSMutableString *output = [NSMutableString stringWithCapacity: CC_SHA1_DIGEST_LENGTH * 2];
		for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
		{
			[output appendFormat:@"%02x", digest[i]];
		}
		return output;
	}
}


+ (NSString *) sha512OfNSString:(NSString*)str
{
	@autoreleasepool
	{
		CC_SHA512_CTX state;
		CC_SHA512_Init(&state);
		CC_SHA512_Update( &state , [str cStringUsingEncoding:NSUTF8StringEncoding] , (int) [str length] );
		uint8_t digest[ CC_SHA512_DIGEST_LENGTH ];
		CC_SHA512_Final( digest , &state );
		NSMutableString *output = [NSMutableString stringWithCapacity: CC_SHA512_DIGEST_LENGTH * 2];
		for (int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++)
		{
			[output appendFormat:@"%02x", digest[i]];
		}
		return output;
	}
}



/**
 * If path points to a symlink, the result represents 
 * the existence of the linked file and not the symlink itself
 */
+ (BOOL) fileFolderExists: (NSString *)path
{
	// Works with both Folders and Files
	struct stat   buf;
	return (stat([path cStringUsingEncoding:NSUTF8StringEncoding], &buf) == 0);
}



/**
 * Returns a boolean value on wheter a
 * file, folder or symlink exists at 'path'
 */
+ (BOOL) fileFolderSymlinkExists: (NSString *)path
{
	// Works with both Folders and Files
	struct stat   buf;
	return (lstat([path cStringUsingEncoding:NSUTF8StringEncoding], &buf) == 0);
}



+ (NSData *) createRandomNSDataOfSize: (unsigned long)size
{
	NSMutableData* theData = [NSMutableData dataWithCapacity:size];
	for( unsigned int i = 0 ; i < size/4 ; ++i )
	{
		u_int32_t randomBits = arc4random();
		[theData appendBytes:(void*)&randomBits length:4];
	}
	return theData;
}



+ (NSString *) createRandomNSStringOfSize: (unsigned int) numOfChars
{
	char data[numOfChars];
	for (int x=0;x<numOfChars;data[x++] = (char)('A' + (arc4random_uniform(26))));
	return [[NSString alloc] initWithBytes: data
							  length: numOfChars
							encoding: NSUTF8StringEncoding];
}


+ (BOOL) URL:(NSURL*)one hasAsRootURL:(NSURL*)two
{
	NSString * urlOneStr = [one absoluteString];
	NSString * urlTwoStr = [two absoluteString];
	if ([urlOneStr length] < [urlTwoStr length])
	{
		return FALSE;
	}
	NSString * cmp = [urlOneStr substringToIndex:[urlTwoStr length]];
	return [urlTwoStr isEqualToString:cmp];
}


+ (NSString*) getIPv4FromNetService:(NSNetService*)netService
{
	// Resolve ip
	char addressBuffer[INET6_ADDRSTRLEN];
	for (NSData *data in [netService addresses])
	{
		memset(addressBuffer, 0, INET6_ADDRSTRLEN);
		
		typedef union
		{
			struct sockaddr sa;
			struct sockaddr_in ipv4;
			struct sockaddr_in6 ipv6;
		} ip_socket_address;
		
		ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];
		if (socketAddress && (socketAddress->sa.sa_family == AF_INET))
		{
			const char *addressStr = inet_ntop(socketAddress->sa.sa_family,			   (socketAddress->sa.sa_family == AF_INET ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)), addressBuffer,sizeof(addressBuffer));
			int port = ntohs(socketAddress->sa.sa_family == AF_INET ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);
			
			if (addressStr && port)
			{
				NSString * urlAndPort = [NSString stringWithFormat:@"%s:%d", addressStr, port];
				return urlAndPort;
			}
		}
	}
	return nil;
}



+ (NSFileHandle*) fileForWritingAtPath: (NSString*) path
{
	NSFileHandle * h = [NSFileHandle fileHandleForWritingAtPath: path];	// NO creation call
	if (h == nil)
	{
		[[NSFileManager defaultManager] createFileAtPath: path contents: nil attributes: nil];
		h = [NSFileHandle fileHandleForWritingAtPath: path];
	}
	return h;
}



/**
 * Copied from http://stackoverflow.com/a/2226623
 */

+ (BOOL) removeAllFilesInDir:(NSString*)directory
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSError *error = nil;
	BOOL errorOccurred = FALSE;
	for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error])
	{
		BOOL success = [fm removeItemAtPath:[directory stringByAppendingPathComponent:file] error:&error];
		if (!success || error)
		{
			NSLog(@"%@", error);
			errorOccurred = TRUE;
			// it failed.
		}
	}
	return errorOccurred;
}

/**
 * Set attribute of a file
 * Copied from: http://senojsitruc.blogspot.ch/2012/01/getting-and-setting-files-extended.html
 */
+ (BOOL)setValue:(NSObject *)value forName:(NSString *)name onFile:(NSString *)filePath
{
	int err;
	const void *bytes = NULL;
	size_t length = 0;
	
	if ([value isKindOfClass:[NSString class]]) {
		bytes = [(NSString *)value UTF8String];
		length = [(NSString *)value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	}
	else if ([value isKindOfClass:[NSData class]]) {
		bytes = [(NSData *)value bytes];
		length = [(NSData *)value length];
	}
	else {
		NSLog(@"%s.. unsupported data type, %@", __PRETTY_FUNCTION__, NSStringFromClass([value class]));
		return FALSE;
	}
	
	if (0 != (err = setxattr([filePath UTF8String], [name UTF8String], bytes, length, 0, 0))) {
		NSLog(@"%s.. failed to setxattr(%@), %s", __PRETTY_FUNCTION__, filePath, strerror(errno));
	}
	
	return TRUE;
}

/**
 * Get file attribute
 * Copied from: http://senojsitruc.blogspot.ch/2012/01/getting-and-setting-files-extended.html
 */
+ (NSData *)getDataValueForName:(NSString *)name onFile:(NSString *)filePath
{
	ssize_t size;
	void *buffer[4096];
	
	if (0 > (size = getxattr([filePath UTF8String], [name UTF8String], buffer, sizeof(buffer), 0, 0)) || size > sizeof(buffer)) {
		NSLog(@"%s.. failed to getxattr(%@), %s", __PRETTY_FUNCTION__, filePath, strerror(errno));
		return nil;
	}
	
	return [[NSData alloc] initWithBytes:buffer length:size];
}

/**
 * Get all file attributes
 * Copied from: http://senojsitruc.blogspot.ch/2012/01/getting-and-setting-files-extended.html
 */
+ (NSDictionary *)getAllValuesOnFile:(NSString *)filePath
{
	ssize_t size;
	char buffer[4096], *bufferPtr;
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	
	if (0 > (size = listxattr([filePath UTF8String], buffer, sizeof(buffer), 00))
	    || size > sizeof(buffer))
	{
		NSLog(@"%s.. failed to listxattr(%@), %s", __PRETTY_FUNCTION__, filePath, strerror(errno));
		return nil;
	}
	
	bufferPtr = buffer;
	
	for (ssize_t bufferNdx = 0; bufferNdx < size; )
	{
		NSString *name = [NSString stringWithCString:bufferPtr encoding:NSUTF8StringEncoding];
		NSData *value = [self getDataValueForName:name onFile:filePath];
		unsigned long namelen = strlen(bufferPtr);
		
		if (name && value)
		{
			[attributes setValue:value forKey:name];
		}
		bufferPtr += namelen + 1;
		bufferNdx += namelen + 1;
	}
	
	return attributes;
}

/**
 * Remove all file attributes
 */
+ (void) removeAllValuesOnFile:(NSString *)filePath
{
	ssize_t size;
	char buffer[4096], *bufferPtr;
	
	if (0 > (size = listxattr([filePath UTF8String], buffer, sizeof(buffer), 00))
	    || size > sizeof(buffer))
	{
		NSLog(@"%s.. failed to listxattr(%@), %s", __PRETTY_FUNCTION__, filePath, strerror(errno));
		return;
	}
	
	bufferPtr = buffer;
	
	for (ssize_t bufferNdx = 0; bufferNdx < size; )
	{
		NSString *name = [NSString stringWithCString:bufferPtr encoding:NSUTF8StringEncoding];
		unsigned long namelen = strlen(bufferPtr);
		
		if (name)
		{
			removexattr([filePath UTF8String], [name UTF8String], 0);
		}

		bufferPtr += namelen + 1;
		bufferNdx += namelen + 1;
	}
}


/**
 * Set extended attributes
 * This works, but does not dispaly correctly in the Finder
 * @params Expects a Base64-encoded string for the values
 * of the extended attributes.
 */
+ (void) matchExtAttributes:(NSDictionary*)dict onURL:(NSURL*)url
{
	[FileHelper removeAllValuesOnFile:[url path]];
	
	for (id key in dict)
	{
		NSData * extAttrBinary = [[NSData alloc] initWithBase64EncodedString:[dict objectForKey:key] options:0];
		[FileHelper setValue:extAttrBinary forName:key onFile:[url path]];
	}
}


+ (NSString*) getSymlinkDestination:(NSString*) path
{
	char buf[MAXPATHLEN];
	ssize_t len;
	if ((len = readlink([path cStringUsingEncoding:NSUTF8StringEncoding], buf, sizeof(buf)-1)) != -1)
	{
		buf[len] = '\0';
		return [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
	}
	return nil;
}
@end
