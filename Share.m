//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

// HEADER
#import "Share.h"

#import <Foundation/Foundation.h>
#import "SQLiteDatabase.h"
#import "FileHelper.h"
#import "File.h"
#import "Revision.h"
#import "Peer.h"
#import "NSDictionary_JSONExtensions.h"
#import "CJSONDeserializer.h"
#import "CJSONSerializer.h"
#import "Configuration.h"


@implementation Share
{
	// instance variables declared in implementation context
	//-------------------------------------------------------
	SQLiteDatabase * db;
	NSMutableDictionary * peers; // key = peerId
	NSNumber * currentRevision;
	int totalChanges;
}


#pragma mark -----------------------
#pragma mark Syntheziser

@synthesize shareId;
@synthesize root;
@synthesize secret;
@synthesize config;


#pragma mark -----------------------
#pragma mark Initializer

- (void) helperInit
{
	
	// Create path and init SQLite
	//-----------------------------
	NSString * sqlitePath = [NSString stringWithFormat:@"%@/%@.sqlite", [config workingDir], shareId];
	db = [[SQLiteDatabase alloc] initCreateAtPath:sqlitePath];
	
	// Prepare Tables in "db"
	//------------------------
	[self prepareTables];
	
	
	// get current revision
	//----------------------
	NSArray * rows;
	NSError * error;
	
	long long rv = [db performQuery:@"SELECT revision FROM files ORDER BY revision DESC LIMIT 1;" rows:&rows error:&error];
	
	if ( rv == 0 || rv == -1 )
	{
		currentRevision = [NSNumber numberWithLongLong:0];
	}
	else
	{
		currentRevision = rows[0][0];
	}
	
	[self dbBegin];
}


/**
 Initializer: Used for creating new shares, including the SQLiteDatabase
 */
- (id) initShareWithID:(NSString*)i
		  andRootURL:(NSURL*)u
		  withSecret:(NSString*)s
		   andConfig:(Configuration*)c
{
	@autoreleasepool
	{
		// Check if superclass could create its object
		//--------------------------------------------
		if ((self = [super init]))
		{
			shareId	= i;
			root		= u;
			secret	= s;
			config	= c;
			peers	= [NSMutableDictionary dictionary];
			
			[self helperInit];
		}
		
		// return our newly created object
		return self;
	}
}

- (NSDictionary*) plistEncoded
{
	//DebugLog(@"plistEncoded: Share");
	
	NSMutableDictionary * rv = [[NSMutableDictionary alloc] init];
	[rv setObject:shareId forKey:@"shareId"];
	[rv setObject:[root absoluteString] forKey:@"root"];
	[rv setObject:secret forKey:@"secret"];
	
	NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
	for (id key in peers)
	{
		Peer * p = [peers objectForKey:key];
		[dict setObject:[p plistEncoded] forKey:[p peerID]];
	}
	[rv setObject:dict forKey:@"peers"];
	
	return rv;
}

#pragma mark -----------------------
#pragma mark Database Functions


-(void) prepareTables
{
	// Peerindex erstellen falls es nicht existiert
	
	NSError * error;
	
	// Causes the sqlite-file to shrink after deletions
	//--------------------------------------------------
	//[db performQuery:@"PRAGMA auto_vacuum = FULL" rows:nil error:&error];
	
	
	// Create Table "files" + index
	//------------------------------
	[db performQuery:@"CREATE TABLE IF NOT EXISTS files (uid TEXT PRIMARY KEY, url TEXT, revision SQLITE3_INT64 UNIQUE, fileSize SQLITE3_INT64, contentModDate TEXT, attributesModDate TEXT, isSet INTEGER, extAttributes TEXT, versions TEXT, isSymlink INTEGER, targetPath TEXT)" rows:nil error:&error];
	[db performQuery:@"CREATE INDEX IF NOT EXISTS index_files_revision ON files (revision);" rows:nil error:&error];
	
	
	// Create Table "Revisions" + index
	//----------------------------------
	[db performQuery:@"CREATE TABLE IF NOT EXISTS revisions (peerID TEXT, relURL TEXT, revision SQLITE3_INT64, fileSize SQLITE3_INT64, isSet INTEGER, extAttributes TEXT, versions TEXT, isDir INTEGER, lastMatchAttemptDate TEXT, isSymlink INTEGER, targetPath TEXT)" rows:nil error:&error];
	[db performQuery:@"CREATE INDEX IF NOT EXISTS index_revisions_peerID_relURL ON revisions (peerID, relURL);" rows:nil error:&error];
	[db performQuery:@"CREATE INDEX IF NOT EXISTS index_revisions_fileSize ON revisions (peerID, fileSize);" rows:nil error:&error];
	
}

/**
 * Returns total number of uncommited changes
 */
- (int) commitAndBegin
{
	@autoreleasepool
	{
		// COMMIT Changes in "indexfile" if there are any

		int changes_diff = 0;
		int newTotalChanges = [db getTotalChanges];

		if (newTotalChanges > totalChanges)
		{
			[self dbCommit];
			changes_diff = (newTotalChanges-totalChanges);
			DebugLog(@"UNCOMMITTED: %i\t currentRev:%@", changes_diff, currentRevision);
			totalChanges = newTotalChanges;
			[self dbBegin];
		}
		return changes_diff;
	}
}


- (void) dbBegin
{
	NSError * error;
	[db performQuery: @"BEGIN" rows:nil error:&error];
	if (error)
	{
		DebugLog(@"%@", error);
	}
}


- (void) dbCommit
{
	NSError * error;
	[db performQuery: @"COMMIT" rows:nil error:&error];
	if (error)
	{
		DebugLog(@"%@", error);
	}
}

#pragma mark -----------------------
#pragma mark Getter/Setter Peer





- (NSArray*) allPeers
{
	return [peers allValues];
}





- (Peer*) getPeerForID:(NSString*)i
{
	return [peers objectForKey:i];
}





- (BOOL) setPeer:(Peer*)p
{
	if (p != nil && [[p peerID] length] == 40)
	{
		[peers setObject:p forKey:[p peerID]];
		return true;
	}
	return false;
}


#pragma mark -----------------------
#pragma mark Getter/Setter Revision

- (void) setRevision:(Revision*)r forPeer:(Peer*)p
{
	@autoreleasepool
	{
		// Serialize "extAttrBase64Encoded" to JSON-String
		//-------------------------------------------------
		NSError * error;
		NSData * extAttrData = [[CJSONSerializer serializer] serializeObject:[r extAttributes] error:&error];
		if (error)
		{
			DebugLog(@"CJSONSerializer Error: %@", error);
			extAttrData = [NSData data];
		}
		NSString * extAttrJSON = [[NSString alloc] initWithData:extAttrData encoding:NSUTF8StringEncoding];
		
		error = nil;
		
		// Serialize "versions" to JSON-String
		//-------------------------------------
		NSData * versionsData = [[CJSONSerializer serializer] serializeObject:[r versions] error:&error];
		if (error)
		{
			DebugLog(@"CJSONSerializer Error: %@", error);
			versionsData = [NSData data];
		}
		NSString * versionsJSON = [[NSString alloc] initWithData:versionsData encoding:NSUTF8StringEncoding];
		
		
		
		/*
		 Revisions-Table-Layout:
		 peerID TEXT,
		 relURL TEXT,
		 revision SQLITE3_INT64,
		 isSet INTEGER,
		 extAttributes TEXT,
		 versions TEXT,
		 isDir INTEGER,
		 lastMatchAttemptDate TEXT
		 isSymlink INTEGER,
		 targetPath TEXT
		 */
		
		
		// Perform SELECT to check if row exists
		//---------------------------------------
		
		NSString * querySELECT = [[NSString alloc] initWithFormat:@"SELECT isSet FROM revisions WHERE peerID='%@' AND relURL='%@';", [p peerID], [[r relURL] sqlString]];
		NSArray * rows;
		int rv = (int) [db performQuery:querySELECT rows:&rows error:&error];
		if (error)
		{
			DebugLog(@"ERROR during performQuery");
			return;
		}
		
		if (rv > 0)
		{
			// Try UPDATE
			//------------
			NSString * queryUPDATE = [NSString stringWithFormat:@"UPDATE revisions SET peerID='%@', relURL='%@', revision=%lld, fileSize=%lld, isSet=%i, extAttributes='%@', versions='%@', isDir=%i, lastMatchAttemptDate='%@', isSymlink=%i, targetPath='%@' WHERE peerID='%@' AND relURL='%@';", [p peerID], [[r relURL] sqlString], [[r revision] longLongValue],[[r fileSize] longLongValue], [[r isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString], [[r isDir] intValue], [r lastMatchAttempt], [[r isSymlink] intValue], [[r targetPath] sqlString], [p peerID], [[r relURL] sqlString]];
			//DebugLog(@"%@", queryUPDATE);
			rv = (int) [db performQuery:queryUPDATE rows:nil error:&error];
			if (error)
			{
				DebugLog(@"ERROR during UPDATE:\n%@", queryUPDATE);
			}
		}
		else
		{
			// Try INSERT
			//------------
			NSString * queryINSERT = [NSString stringWithFormat:@"INSERT INTO revisions (peerID, relURL, revision, fileSize, isSet, extAttributes, versions, isDir, lastMatchAttemptDate, isSymlink, targetPath) VALUES ('%@', '%@', %lld, %lld, %i, '%@', '%@', %i, '%@', %i, '%@');", [p peerID], [[r relURL] sqlString], [[r revision] longLongValue], [[r fileSize] longLongValue], [[r isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString], [[r isDir] intValue], [r lastMatchAttempt], [[r isSymlink] intValue], [[r targetPath] sqlString]];
			//DebugLog(@"%@", queryINSERT);
			rv = (int) [db performQuery:queryINSERT rows:nil error:&error];
			if (error)
			{
				DebugLog(@"ERROR during INSERT");
			}
		}
	}
}


- (void) removeRevision:(Revision*)r forPeer:(Peer*)p
{
	NSError * error;
	NSString * query = [NSString stringWithFormat:@"DELETE FROM revisions WHERE peerID='%@' AND relURL='%@';", [p peerID], [[r relURL] sqlString]];
	[db performQuery:query rows:nil error:&error];
}



/*
 Revisions-Table-Layout:
 peerID TEXT,
 relURL TEXT,
 revision SQLITE3_INT64,
 isSet INTEGER,
 extAttributes TEXT,
 versions TEXT,
 isDir INTEGER,
 lastMatchAttemptDate TEXT
 */

/**
 * Returns the next Revision to match (= download+match)
 */
- (Revision*) nextRevisionForPeer:(Peer*)p
{
	NSString * query = [[NSString alloc] initWithFormat:@"SELECT relURL, revision, isSet, extAttributes, versions, isDir, lastMatchAttemptDate, fileSize, isSymlink, targetPath FROM revisions WHERE peerID='%@' ORDER BY fileSize ASC LIMIT 1;", [p peerID]];
	
	NSArray * rows;
	NSError * error;
	long long rowCount = [db performQuery:query rows:&rows error:&error];
	
	if (rowCount == 0 || rowCount > 1)
	{
		return nil;
	}
	
	
	// Parsing the results-array into a Revision-Object
	//--------------------------------------------------
	Revision * rv = [[Revision alloc] init];
	
	[rv setRelURL:rows[0][0]];
	[rv setRevision:rows[0][1]];
	[rv setIsSet:rows[0][2]];
	
	error = nil;
	[rv setExtAttributes:[NSDictionary dictionaryWithJSONString:rows[0][3] error:&error]];
	if (error)
	{
		DebugLog(@"A JSON-Error was encountered!");
		return nil;
	}
	error = nil;
	[rv setVersions:[NSDictionary dictionaryWithJSONString:rows[0][4] error:&error]];
	if (error)
	{
		DebugLog(@"A JSON-Error was encountered!");
		return nil;
	}
	[rv setIsDir:rows[0][5]];
	[rv setLastMatchAttempt:[NSDate dateWithString:rows[0][6]]];
	[rv setFileSize:rows[0][7]];
	[rv setIsSymlink:rows[0][8]];
	[rv setTargetPath:rows[0][9]];
	
	// Setting the Peer-Attribute of the Revision
	//--------------------------------------------
	[rv setPeer:p];
	
	return rv;
	
}




#pragma mark -----------------------
#pragma mark Getter/Setter File

- (void) scanSubDirectoriesOfURL:(NSURL*)url
{
	NSArray * dirTree = [FileHelper scanDirectoryRecursive:url];
	for (NSURL * u in dirTree)
	{
		@autoreleasepool
		{
			[self scanURL:u recursive:NO];
		}
	}
}


- (void) scanURL:(NSURL*)fileURL recursive:(BOOL)recursive
{
	//DebugLog(@"scanURL: %@", [fileURL absoluteString]);
	
	if (![FileHelper URL:fileURL hasAsRootURL:[self root]])
	{
		return;
	}
	
	// Ignore .DS_Store
	//------------------
	if ([[fileURL lastPathComponent] isEqualToString:@".DS_Store"])
	{
		return;
	}
	
	
	// Handle files, folders, symlinks
	//---------------------------------
	BOOL exists = [FileHelper fileFolderSymlinkExists:[fileURL path]];

	if (exists)
	{
		// File exists on HD (ADDED/CHANGED)
		//-----------------------------------
		//DebugLog(@"File exists on HD");
		
		File * f = [self getFileForURL:fileURL];
		
		if (f == nil)
		{
			// File doesn't exist in Share
			//-----------------------------
			//DebugLog(@"File doesn't exist in Share");
			f = [[File alloc] initAsNewFileWithPath:[fileURL path]];
			if (f == nil)
			{
				return;
			}
			[self setFile:f];
			
			// Recursive scan on dirs
			//------------------------
			if (recursive && [f isDir])
			{
				[self scanSubDirectoriesOfURL:[f url]];
			}
		}
		else
		{
			// File exists in Share
			//----------------------
			//DebugLog(@"File exists in Share");

			// Handle symlinks
			//-----------------
		
			
			[f setUrl:fileURL];
			[f setIsSetBOOL:TRUE];
			[f updateSymlink];
			[f updateFileSize];
			[f updateContentModDate];
			[f updateAttributesModDate];
			if ([f isEqualToFile:[self getFileForURL:fileURL]])
			{
				return;	// DOING NOTHING
			}
			[f updateExtAttributes];
			if (![f updateVersions])
			{
				return;	// Update Versions failed
			}
			[self setFile:f];

			// Recursive scan on dirs
			//------------------------
			if (recursive && [f isDir])
			{
				[self scanSubDirectoriesOfURL:[f url]];
			}
		}
	}
	else
	{
		// File doesn't exist on HD (DELETE)
		//-----------------------------------
		//DebugLog(@"File doesn't exist on HD");
		File * f = [self getFileForURL:fileURL];
		if (f == nil)
		{
			// File doesn't exists in Share
			//------------------------------
			//DebugLog(@"File doesn't exists in Share: %@", fileURL);
			// DO NOTHING
		}
		else
		{
			// File exists in Share
			//DebugLog(@"File exists in Share");
			if (recursive && [f isDir])
			{
				// File is directory
				//DebugLog(@"File is directory");
				NSArray * filesToDelete = [self getURLsBelowURL:[f url] withIsSet:YES];
				for (NSArray * a in filesToDelete)
				{
					@autoreleasepool
					{
						File * g	= [self getFileForURL:[NSURL URLWithString:a[0]]];
						//DebugLog(@"filesToDelete: %@", a[0]);
						[g setIsSetBOOL:FALSE];
						[self setFile:g];
					}
				}
			}
			[f setIsSetBOOL:FALSE];
			[self setFile:f];
		}
	}
}



- (NSNumber*) nextRevision
{
	currentRevision = [NSNumber numberWithLongLong:[currentRevision longLongValue] + 1];
	return currentRevision;
}


- (NSNumber*) currentRevision
{
	return currentRevision;
}





/**
 * New setFile, that automatically sets the revision if something has changed
 */
- (int) setFile:(File*)f
{
	//DebugLog(@"setFile");
	@autoreleasepool
	{
		// 1. Determine if anything changed: SELECT current state
		//-------------------------------------------------------
		File * currentState = [self getFileForURL:[f url]];
		
		if (currentState)
		{
			if (![f isCoreEqualToFile:currentState]
			 || [[f revision] longLongValue] == 0)
			{
				[f setRevision:[self nextRevision]];
			}
		}
		else
		{
			[f setRevision:[self nextRevision]];
		}
		
		
		// Serialize "extAttrBase64Encoded" to JSON-String
		//-------------------------------------------------
		NSError * error;
		NSData * extAttrData = [[CJSONSerializer serializer] serializeObject:[f extAttributes] error:&error];
		if (error)
		{
			DebugLog(@"CJSONSerializer Error: %@", error);
			extAttrData = [NSData data];
		}
		NSString * extAttrJSON = [[NSString alloc] initWithData:extAttrData encoding:NSUTF8StringEncoding];
		
		error = nil;
		
		// Serialize "versions" to JSON-String
		//-------------------------------------
		NSData * versionsData = [[CJSONSerializer serializer] serializeObject:[f versions] error:&error];
		if (error)
		{
			DebugLog(@"CJSONSerializer Error: %@", error);
			versionsData = [NSData data];
		}
		NSString * versionsJSON = [[NSString alloc] initWithData:versionsData encoding:NSUTF8StringEncoding];
		
		int rv = 0;
		
		if (currentState)
		{
			// UPDATE
			//--------
			NSString * queryUPDATE = [NSString stringWithFormat:@"UPDATE files SET url='%@', revision=%lld, fileSize=%lld, contentModDate='%@', attributesModDate='%@', isSet=%i, extAttributes='%@', versions='%@', isSymlink=%i, targetPath='%@' WHERE uid='%@';",[[[f url] absoluteString] sqlString], [[f revision] longLongValue], [[f fileSize] longLongValue], [f contentModDate], [f attributesModDate], [[f isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString], [[f isSymlink] intValue], [[f targetPath] sqlString], [[[[f url] absoluteString] lowercaseString] sqlString]];
			rv = (int) [db performQuery:queryUPDATE rows:nil error:&error];
			if (error) {
				DebugLog(@"ERROR during UPDATE:\n%@", queryUPDATE);
			}
		}
		else
		{
			// INSERT
			//--------
			NSString * queryINSERT = [NSString stringWithFormat:@"INSERT INTO files (uid, url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions, isSymlink, targetPath) VALUES ('%@', '%@',%lld, %lld, '%@','%@',%i,'%@','%@',%i,'%@');", [[[[f url] absoluteString] lowercaseString] sqlString],[[[f url] absoluteString] sqlString], [[f revision] longLongValue], [[f fileSize] longLongValue], [f contentModDate], [f attributesModDate], [[f isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString] ,[[f isSymlink] intValue], [[f targetPath] sqlString]];
			rv = (int) [db performQuery:queryINSERT rows:nil error:&error];
			if (error) {
				DebugLog(@"ERROR during INSERT:\n%@", queryINSERT);
			}
		}
		return rv;
	}
}

- (void) removeFile:(File*)f
{
	NSError * error;
	NSString * query = [NSString stringWithFormat:@"DELETE FROM files WHERE uid='%@';",[[[[f url] absoluteString] lowercaseString] sqlString]];
	[db performQuery:query rows:nil error:&error];
}

- (File*) getFileForQuery:(NSString*) query
{
	NSArray * rows;
	NSError * error;
	long long rowCount = [db performQuery:query rows:&rows error:&error];
	
	if (rowCount == 0 || rowCount > 1)
	{
		return nil;
	}
	
	// Parsing the results-array into a File-Object
	//----------------------------------------------
	File * rv = [[File alloc] init];
	[rv setUrl:[NSURL URLWithString:rows[0][0]]];
	[rv setRevision:rows[0][1]];
	[rv setFileSize:rows[0][2]];
	[rv setContentModDate:[NSDate dateWithString:rows[0][3]]];
	[rv setAttributesModDate:[NSDate dateWithString:rows[0][4]]];
	[rv setIsSet:rows[0][5]];
	
	error = nil;
	[rv setExtAttributes:[NSMutableDictionary dictionaryWithJSONString:rows[0][6] error:&error]];
	if (error)
	{
		DebugLog(@"A JSON-Error was encountered!");
		return nil;
	}
	error = nil;
	[rv setVersions:[NSDictionary dictionaryWithJSONString:rows[0][7] error:&error]];
	if (error)
	{
		DebugLog(@"A JSON-Error was encountered!");
		return nil;
	}
	[rv setIsSymlink:rows[0][8]];
	[rv setTargetPath:rows[0][9]];
	return rv;
}


- (File*) getFileForURL: (NSURL*) u
{
	@autoreleasepool
	{
		NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions, isSymlink, targetPath FROM files WHERE uid='%@';", [[[u absoluteString] lowercaseString] sqlString]];
		return [self getFileForQuery:query];
	}
}


- (File*) getFileForRev: (NSNumber*) rev
{
	@autoreleasepool
	{
		NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions, isSymlink, targetPath FROM files WHERE revision=%lld;", [rev longLongValue]];
		return [self getFileForQuery:query];
	}
}




- (NSArray*) getURLsBelowURL: (NSURL*)u withIsSet: (BOOL)b
{
	NSArray * rows;
	NSError * error;
	NSString * urlPath = [[u absoluteString] sqlString];
	NSString * query = [NSString stringWithFormat:@"SELECT url FROM files WHERE isSet=%i AND url != '%@' AND url LIKE '%@%%' ORDER BY url DESC", b, urlPath, urlPath];
	[db performQuery:query rows:&rows error:&error];
	return rows;
}



/**
 * Returns an NSArray-Object
 * used for requests to /shares/<shareId>/revisions
 */
- (NSArray*) getFilesAsJSONwithLimit: (NSNumber*) limit
				 startingFromRev: (NSNumber*) rev
{
	NSArray * rows;
	NSError * error;
	NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions, isSymlink, targetPath FROM files WHERE revision >= %lld ORDER BY revision ASC LIMIT %lld;", [rev longLongValue], [limit longLongValue]];
	//DebugLog(@"%@", query);
	
	uint64_t rowCount = [db performQuery:query rows:&rows error:&error];
	if (error)
	{
		DebugLog(@"error: %@", error);
		return nil;
	}
	
	NSMutableArray * rv = [NSMutableArray array];
	if (rowCount == 0)
	{
		return rv;
	}
	
	// Parsing the results-array into a File-Object
	//----------------------------------------------
	for (int i = 0; i < rowCount; i++)
	{
		NSMutableDictionary * f = [NSMutableDictionary dictionary];
		
		// Revision
		//----------
		[f setObject:rows[i][1] forKey:@"revision"];
		
		// relUrl
		//--------
		NSString * relUrl = [rows[i][0] substringFromIndex:[[[self root] absoluteString] length]];
		[f setObject:relUrl forKey:@"relUrl"];
		
		// isSet
		//-------
		[f setObject:rows[i][5] forKey:@"isSet"];
		
		// extendedAttributes
		//--------------------
		NSError *theError = NULL;
		NSMutableDictionary * extAttr = [NSMutableDictionary dictionaryWithJSONString:rows[i][6] error:&theError];
		if (theError)
		{
			DebugLog(@"A JSON-Error was encountered!");
			return nil;
		}
		[f setObject:extAttr forKey:@"extendedAttributes"];
		
		// versions
		//----------
		NSMutableDictionary * versions = [NSMutableDictionary dictionaryWithJSONString:rows[i][7] error:&theError];
		[f setObject:versions forKey:@"versions"];
		
		// isSymlink
		//-----------
		[f setObject:rows[i][8] forKey:@"isSymlink"];
		
		// targetPath
		//-----------
		[f setObject:rows[i][9] forKey:@"targetPath"];
		
		// Finally add the new file to the Array that we return.
		//-------------------------------------------------------
		[rv addObject:f];
	}
	return rv;
}





/**
 * Returns an NSDictionary-Object with 'relUrl' as the keys
 * used for requests to /shares/<shareId>/revisionsDict
 */
- (NSDictionary*) getFilesAsJSONDictWithLimit: (NSNumber*) limit
						startingFromRev: (NSNumber*) rev
							biggestRev: (NSNumber**) biggestRev
{
	NSArray * rows;
	NSError * error;
	NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions, isSymlink, targetPath FROM files WHERE revision >= %lld ORDER BY revision ASC LIMIT %lld;", [rev longLongValue], [limit longLongValue]];
	//DebugLog(@"%@", query);
	
	uint64_t rowCount = [db performQuery:query rows:&rows error:&error];
	if (error)
	{
		DebugLog(@"error: %@", error);
		return nil;
	}
	
	NSMutableDictionary * rv = [NSMutableDictionary dictionary];
	if (rowCount == 0)
	{
		return rv;
	}
	
	// Parsing the results-array into a File-Object
	//---------------------------------------------
	for (int i = 0; i < rowCount; i++)
	{
		NSMutableDictionary * f = [NSMutableDictionary dictionary];
		
		// Revision
		//----------
		[f setObject:rows[i][1] forKey:@"revision"];
		
		// fileSize
		//----------
		[f setObject:rows[i][2] forKey:@"fileSize"];
		
		// isSet
		//-------
		[f setObject:rows[i][5] forKey:@"isSet"];
		
		// extendedAttributes
		//--------------------
		NSError *error2 = NULL;
		NSMutableDictionary * extAttr = [NSMutableDictionary dictionaryWithJSONString:rows[i][6] error:&error2];
		if (error2)
		{
			DebugLog(@"A JSON-Error was encountered!");
			return nil;
		}
		[f setObject:extAttr forKey:@"extendedAttributes"];
		
		// versions
		//----------
		NSMutableDictionary * versions = [NSMutableDictionary dictionaryWithJSONString:rows[i][7] error:&error2];
		[f setObject:versions forKey:@"versions"];
		
		// isSymlink
		//-----------
		[f setObject:rows[i][8] forKey:@"isSymlink"];
		
		// targetPath
		//-----------
		if ([rows[i][8] intValue] == 0)
		{
			[f setObject:@"" forKey:@"targetPath"];
		}
		else
		{
			[f setObject:rows[i][9] forKey:@"targetPath"];
		}

		// Finally add the new file to the NSDictionary that we return.
		//--------------------------------------------------------------
		NSString * relUrl = [rows[i][0] substringFromIndex:[[[self root] absoluteString] length]];
		[rv setObject:f forKey:relUrl];
	}
	
	// Set the biggest revision
	//--------------------------
	*biggestRev = [rows lastObject][1];
	
	return rv;
}



/**
 * Makes the Object printable with DebugLog(@"%@", (Share) s);
 */
- (NSString *)description
{
	return [NSString stringWithFormat: @"%@; %@; %@; %@", shareId, currentRevision, root, secret ];
}




@end
