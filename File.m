//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "File.h"

#import <Foundation/Foundation.h>
#import "FileHelper.h"
#import "Share.h"
#import "Constants.h"

@implementation File;


#pragma mark -----------------------
#pragma mark Syntheziser


@synthesize url;
@synthesize revision;
@synthesize fileSize;
@synthesize contentModDate;
@synthesize attributesModDate;
@synthesize isSet;
@synthesize extAttributes;
@synthesize versions;
@synthesize isSymlink;
@synthesize targetPath;

#pragma mark -----------------------
#pragma mark Initializer


// Objects returned from methods are autoreleased. Meaning they release themselves when its safe.




/**
 This Initializer is called when we
 */
- (id) initAsNewFileWithPath:(NSString*) p
{
	@autoreleasepool
	{
		// Check if superclass could create its object
		if (self = [super init])
		{
			if ([FileHelper isSymbolicLink:p])
			{
				isSymlink = [NSNumber numberWithBool:TRUE];
				targetPath = [FileHelper getSymlinkDestination:p];
			}
			else
			{
				isSymlink = [NSNumber numberWithBool:FALSE];
				targetPath = @"";
			}

			url		= [NSURL fileURLWithPath:p];
			revision	= [NSNumber numberWithLongLong:0];
			isSet 	= [NSNumber numberWithBool:TRUE];
			[self updateFileSize];
			[self updateContentModDate];
			[self updateAttributesModDate];
			[self updateExtAttributes];
			versions	= [NSMutableDictionary dictionary];
			[self updateVersions];
		}
		// return our newly created object
		return self;
	}
}

- (id) initWithShare:(Share*)s
		    relUrl:(NSString*)u
			isSet:(NSNumber*)i
	  extAttributes:(NSDictionary*)e
		  versions:(NSMutableDictionary*)v
		 isSymlink:(NSNumber*)sym
		 targetPath:(NSString *)t
{
	if (self == [super init])
	{
		url = [NSURL URLWithString:u relativeToURL:[s root]];
		isSet = i;
		versions = v;
		extAttributes = [NSMutableDictionary dictionaryWithDictionary:e];
		isSymlink = sym;
		targetPath = t;
	}
	return self;
}



#pragma mark -----------------------
#pragma mark Custom Setter

- (void) setIsSetBOOL:(BOOL)b
{
	isSet = [NSNumber numberWithBool:b];
}



#pragma mark -----------------------
#pragma mark Other

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

/**
 * Unit Tested in: "File Unit Tests.m"
 */
- (BOOL) hasConflictingVersionsWithFile:(File*)f
{
	if (f == nil)
	{
		return FALSE;
	}
	
	return [File versions:[self versions] hasConflictsWithVersions:[f versions]];
}


/**
 * v1 = [self versions]
 * v2 = [f versions]
 */
+ (BOOL) versions:(NSDictionary*)v1 hasConflictsWithVersions:(NSDictionary*)v2
{
	// 1,2,3,4 ... OR 10,11,12,13 ...
	NSArray * local = [[v1 allKeys] sortedArrayUsingComparator:^(NSString *str1, NSString *str2) {
		return [str1 compare:str2 options:NSNumericSearch];
	}];;
	NSArray * remote = [[v2 allKeys] sortedArrayUsingComparator:^(NSString *str1, NSString *str2) {
		return [str1 compare:str2 options:NSNumericSearch];
	}];;
	
	//DebugLog(@"local: %@", local);
	//DebugLog(@"remote: %@", remote);
	
	int local_smallest	 = [[local firstObject] intValue];
	int remote_smallest = [[remote firstObject] intValue];
	int local_biggest	 = [[local lastObject] intValue];
	int remote_biggest	 = [[remote lastObject] intValue];
	
	//DebugLog(@"local_smallest:  %i", local_smallest);
	//DebugLog(@"remote_smallest: %i", remote_smallest);
	//DebugLog(@"local_biggest:   %i", local_biggest);
	//DebugLog(@"remote_biggest:  %i", remote_biggest);
	
	int smallestSharedVersion;
	int biggestSharedVersion;
	
	// Finding the smallest shared revision
	//-------------------------------------
	smallestSharedVersion = MAX(local_smallest , remote_smallest);
	//DebugLog(@"shared smallest: %i", smallestSharedVersion);
	biggestSharedVersion  = MIN(local_biggest  , remote_biggest);
	//DebugLog(@"shared biggest:  %i", biggestSharedVersion);
	
	if ( (biggestSharedVersion - smallestSharedVersion) < 0)
	{
		/* An overlapping range DOESN'T exists */
		return TRUE;
	}
	int i = smallestSharedVersion;
	while (i <= biggestSharedVersion
		  && [[v1 objectForKey:[NSString stringWithFormat:@"%i", i]] isEqualToString:[v2 objectForKey:[NSString stringWithFormat:@"%i", i]]])
	{
		//DebugLog(@"%i: %@", i, [v1 objectForKey:[NSString stringWithFormat:@"%i", i]]);
		//DebugLog(@"%i: %@", i, [v2 objectForKey:[NSString stringWithFormat:@"%i", i]]);
		i++;
	}
	return !(i == biggestSharedVersion + 1);
}


- (void) addVersion:(NSString *) hash
{
	NSString * lastVersion = [self getLastVersionKey];
	NSNumber * nextVersion = [NSNumber numberWithLongLong:[lastVersion longLongValue] + 1];
	[versions setObject:hash forKey:[nextVersion stringValue]];

	// Limit the number of versions for a single file to MAX_VERSIONS_PER_FILE
	//-------------------------------------------------------------------------
	if ([nextVersion longLongValue] > MAX_VERSIONS_PER_FILE)
	{
		NSNumber * versionToRemove = [NSNumber numberWithLongLong:[nextVersion longLongValue] - MAX_VERSIONS_PER_FILE];
		[versions removeObjectForKey:[versionToRemove stringValue]];
	}
	
	// OLD
	
	//	NSNumber * nextVersion = [NSNumber numberWithLongLong:[versions count] + 1];
	//	[versions setObject:hash forKey:[nextVersion stringValue]];
}

- (BOOL) isDir
{
	if ([isSymlink boolValue] == TRUE)
	{
		return FALSE;
	}
	return [[url absoluteString] hasSuffix:@"/"];
}

- (BOOL) isCoreEqualToFile:(File*)f
{
	if (![[[[self url] absoluteString] lowercaseString] isEqualToString:[[[f url] absoluteString] lowercaseString]])
	{
		return FALSE;
	}
	if (![[self isSet] isEqualToNumber:[f isSet]])
	{
		return FALSE;
	}
	if (![[self extAttributes] isEqualToDictionary:[f extAttributes]])
	{
		return FALSE;
	}
	if (![[self versions] isEqualToDictionary:[f versions]])
	{
		return FALSE;
	}
	if (![[self isSymlink] isEqualToNumber:[f isSymlink]])
	{
		return FALSE;
	}
	if (![[self targetPath] isEqualToString:[f targetPath]])
	{
		return FALSE;
	}
	return TRUE;
}

- (BOOL) isEqualToFile:(File*)f
{
	if (![[[self url] absoluteString] isEqualToString:[[f url] absoluteString]])
	{
		return FALSE;
	}
	if (![[self revision] isEqualToNumber:[f revision]])
	{
		//	DebugLog(@"isEqualToFile: revision");
		return FALSE;
	}
	if (![[self fileSize] isEqualToNumber:[f fileSize]])
	{
		//	DebugLog(@"isEqualToFile: fileSize");
		return FALSE;
	}
	if (![[self contentModDate] isEqualToDate:[f contentModDate]])
	{
		//	DebugLog(@"isEqualToFile: contentModDate");
		return FALSE;
	}
	if (![[self attributesModDate] isEqualToDate:[f attributesModDate]])
	{
		//	DebugLog(@"isEqualToFile: attributesModDate");
		return FALSE;
	}
	if (![[self isSet] isEqualToNumber:[f isSet]])
	{
		//	DebugLog(@"isEqualToFile: isSet");
		return FALSE;
	}
	if (![[self extAttributes] isEqualToDictionary:[f extAttributes]])
	{
		//	DebugLog(@"isEqualToFile: extAttributes");
		return FALSE;
	}
	if (![[self versions] isEqualToDictionary:[f versions]])
	{
		//	DebugLog(@"isEqualToFile: versions");
		return FALSE;
	}
	if (![[self isSymlink] isEqualToNumber:[f isSymlink]])
	{
		return FALSE;
	}
	if (![[self targetPath] isEqualToString:[f targetPath]])
	{
		return FALSE;
	}
	return TRUE;
}

- (NSString *) getLastVersionHash
{
	return [versions objectForKey:[self getLastVersionKey]];
}

- (NSString *) getLastVersionKey
{
	NSArray * local = [[[self versions] allKeys] sortedArrayUsingComparator:^(NSString *str1, NSString *str2) {
		return [str1 compare:str2 options:NSNumericSearch];
	}];;
	return [local lastObject];
}

- (void) print
{
	DebugLog(@"--------------------");
	DebugLog(@"url:                %@", url);
	DebugLog(@"revision:           %@", revision);
	DebugLog(@"fileSize:           %@", fileSize);
	DebugLog(@"contentModDate:     %@", contentModDate);
	DebugLog(@"attributesModDate:  %@", attributesModDate);
	DebugLog(@"isSet:              %@", isSet);
	DebugLog(@"extAttributes: %@", extAttributes);
	DebugLog(@"versions:           %@", versions);
	DebugLog(@"--------------------");
}


/*
 Allows for an object to be printed with DebugLog()
 */
- (NSString *)description
{
	return [NSString stringWithFormat: @"url: %@\n revision: %@", url, revision];
}


#pragma mark -----------------------
#pragma mark Updater

- (void) updateFileSize
{
	if ([isSymlink boolValue])
	{
		fileSize = [NSNumber numberWithInt:0];
		return;
	}
	if ([isSet boolValue])
	{
		NSNumber * sizeOfFile;
		[ url getResourceValue: &sizeOfFile
					 forKey: NSURLFileSizeKey
					  error: nil];
		[self setFileSize:sizeOfFile];
	}
}

- (void) updateContentModDate
{
	if ([isSymlink boolValue])
	{
		contentModDate = [NSDate dateWithTimeIntervalSince1970:0];
		return;
	}
	if ([isSet boolValue])
	{
		NSDate * fileChangeDate;
		[url getResourceValue:&fileChangeDate
					forKey:NSURLContentModificationDateKey
					 error:nil];
		[self setContentModDate:fileChangeDate];
	}
}

- (void) updateAttributesModDate
{
	if ([isSymlink boolValue])
	{
		attributesModDate = [NSDate dateWithTimeIntervalSince1970:0];
		return;
	}
	if ([isSet boolValue])
	{
		NSDate * attrChangeDate;
		[url getResourceValue:&attrChangeDate
					forKey:NSURLAttributeModificationDateKey
					 error:nil];
		[self setAttributesModDate:attrChangeDate];
	}
}


- (void) updateExtAttributes
{
	if ([isSymlink boolValue])
	{
		extAttributes = [NSMutableDictionary dictionary];
		return;
	}
	if ( [isSet boolValue] )
	{
		// Convert "extAttributes"-Dictionary-Values to BASE64-Strings:
		//--------------------------------------------------------------
		NSMutableDictionary * extAttrBase64Encoded = [NSMutableDictionary dictionaryWithDictionary:[FileHelper getAllValuesOnFile:[url path]]];
		
		if (IGNORE_RESOURCE_FORKS)
		{
			[extAttrBase64Encoded removeObjectForKey:@"com.apple.ResourceFork"];
		}
		
		for (NSString *key in [extAttrBase64Encoded allKeys])
		{
			NSData * data = [extAttrBase64Encoded objectForKey:key];
			NSString * dataBase64 = [data base64EncodedStringWithOptions:0];
			[extAttrBase64Encoded setObject:dataBase64 forKey:key];
		}
		[self setExtAttributes:extAttrBase64Encoded];
	}
}


- (BOOL) updateVersions
{
	if ( [self isDir] || [isSymlink boolValue] == TRUE)
	{
		[self setVersions:[NSMutableDictionary dictionaryWithObject:@"0" forKey:@"1"]];
		return TRUE;
	}
	
	if ( [isSet boolValue] )
	{
		NSString * hash = [FileHelper sha1OfFile:[url path]];
		if (hash == nil)
		{
			return FALSE;
		}
		if (![hash isEqualToString:[self getLastVersionHash]])
		{
			[self addVersion:hash];
		}
	}
	return TRUE;
}



@end
