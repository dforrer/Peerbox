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
	DownloadRevisions * downloadRevs;
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
	
	[db performQuery:@"BEGIN" rows:nil error:&error];
	
	// Schedule timer for commit and begin on database
	//------------------------------------------------
	[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(commitAndBegin) userInfo:nil repeats:YES];
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
	[db performQuery:@"PRAGMA auto_vacuum = FULL" rows:nil error:&error];


	// Create Table "files" + index
	//------------------------------
	[db performQuery:@"CREATE TABLE IF NOT EXISTS files (uid TEXT PRIMARY KEY, url TEXT, revision SQLITE3_INT64 UNIQUE, fileSize SQLITE3_INT64, contentModDate TEXT, attributesModDate TEXT, isSet INTEGER, extAttributes TEXT, versions TEXT)" rows:nil error:&error];
	[db performQuery:@"CREATE INDEX IF NOT EXISTS index_files_revision ON files (revision);" rows:nil error:&error];

	
	// Create Table "Revisions"
	//------------------------------------
	[db performQuery:@"CREATE TABLE IF NOT EXISTS revisions (peerID TEXT, relURL TEXT, revision SQLITE3_INT64, isSet INTEGER, extAttributes TEXT, versions TEXT, isDir INTEGER, lastMatchAttemptDate TEXT)" rows:nil error:&error];
}


- (void) commitAndBegin
{
	@autoreleasepool
	{
		// COMMIT Changes in "indexfile" if there are any
		int newTotalChanges = [db getTotalChanges];
		
		if (newTotalChanges > totalChanges)
		{
			[self filesDBCommit];
			DebugLog(@"uncommited: %i", (newTotalChanges-totalChanges));
			DebugLog(@"\tnewTotalChanges: %i", newTotalChanges);
			DebugLog(@"\ttotalChanges: %i", totalChanges);
			totalChanges = newTotalChanges;
			[self filesDBBegin];
		}
	}
}


- (void) filesDBBegin
{
	NSError * error;
	[db performQuery: @"BEGIN" rows:nil error:&error];
	if (error)
	{
		DebugLog(@"%@", error);
	}
}


- (void) filesDBCommit
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


- (void) setRevision:(Revision*)r forPeer:(Peer*)p;
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
		 */
		
		
		// Try INSERT
		//------------
		NSString * queryINSERT = [NSString stringWithFormat:@"INSERT INTO revisions (peerID, relURL, revision, isSet, extAttributes, versions, isDir, lastMatchAttemptDate) VALUES ('%@', '%@', %lld, %i, '%@', '%@', %i, '%@');", [p peerID], [r relURL], [[r revision] longLongValue], [[r isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString], [[r isDir] intValue], [r lastMatchAttempt]];
		int rv = (int) [db performQuery:queryINSERT rows:nil error:&error];
		if (error)
		{
			DebugLog(@"ERROR during INSERT");
		}
		
		// Check if the UPDATE failed
		//----------------------------
		if (rv == -1)
		{
			// Try UPDATE
			//------------
			NSString * queryUPDATE = [NSString stringWithFormat:@"UPDATE revisions SET peerID='%@', relURL='%@', revision=%lld, isSet=%i, extAttributes='%@', versions='%@', isDir=%i, lastMatchAttemptDate='%@' WHERE peerID='%@' AND relURL='%@';", [p peerID], [r relURL], [[r revision] longLongValue], [[r isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString], [[r isDir] intValue], [r lastMatchAttempt], [p peerID], [r relURL]];
			rv = (int) [db performQuery:queryUPDATE rows:nil error:&error];
			if (error)
			{
				DebugLog(@"ERROR during UPDATE");
			}
		}
	}
}



- (void) removeRevision:(Revision*)r forPeer:(Peer*)p;
{
	NSError * error;
	NSString * query = [NSString stringWithFormat:@"DELETE FROM revisions WHERE peerID='%@' AND relURL='%@';", [p peerID], [r relURL]];
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
	NSString * query = [[NSString alloc] initWithFormat:@"SELECT relURL, revision, isSet, extAttributes, versions, isDir, lastMatchAttemptDate FROM revisions WHERE peerID='%@' ORDER BY relURL DESC, isDir DESC, isSet ASC LIMIT 1;", [p peerID]];
	
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
		exit(-1);
	}
	error = nil;
	[rv setVersions:[NSDictionary dictionaryWithJSONString:rows[0][4] error:&error]];
	if (error)
	{
		DebugLog(@"A JSON-Error was encountered!");
		exit(-1);
	}
	[rv setIsDir:rows[0][5]];
	[rv setLastMatchAttempt:[NSDate dateWithString:rows[0][6]]];

	
	// Setting the Peer-Attribute of the Revision
	//--------------------------------------------
	[rv setPeer:p];
	
	return rv;

}




#pragma mark -----------------------
#pragma mark Getter/Setter File


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
	@autoreleasepool
	{
		// 1. Determine if anything changed: SELECT current state
		//-------------------------------------------------------
		File * currentState = [self getFileForURL:[f url]];
		
		if (currentState)
		{
			if (![f isCoreEqualToFile:currentState])
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
			NSString * queryUPDATE = [NSString stringWithFormat:@"UPDATE files SET url='%@', revision=%lld, fileSize=%lld, contentModDate='%@', attributesModDate='%@', isSet=%i, extAttributes='%@', versions='%@' WHERE uid='%@';",[[[f url] absoluteString] sqlString], [[f revision] longLongValue], [[f fileSize] longLongValue], [f contentModDate], [f attributesModDate], [[f isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString], [[[[f url] absoluteString] lowercaseString] sqlString]];
			rv = (int) [db performQuery:queryUPDATE rows:nil error:&error];
			if (error) {
				DebugLog(@"ERROR during UPDATE");
			}
		}
		else
		{
			// INSERT
			//--------
			NSString * queryINSERT = [NSString stringWithFormat:@"INSERT INTO files (uid, url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions) VALUES ('%@', '%@',%lld, %lld, '%@','%@',%i,'%@','%@');", [[[[f url] absoluteString] lowercaseString] sqlString],[[[f url] absoluteString] sqlString], [[f revision] longLongValue], [[f fileSize] longLongValue], [f contentModDate], [f attributesModDate], [[f isSet] intValue], [extAttrJSON sqlString], [versionsJSON sqlString]];
			rv = (int) [db performQuery:queryINSERT rows:nil error:&error];
			if (error) {
				DebugLog(@"ERROR during INSERT");
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
		exit(-1);
	}
	error = nil;
	[rv setVersions:[NSDictionary dictionaryWithJSONString:rows[0][7] error:&error]];
	if (error)
	{
		DebugLog(@"A JSON-Error was encountered!");
		exit(-1);
	}
	
	return rv;
}


- (File*) getFileForURL: (NSURL*) u
{
	@autoreleasepool
	{
		NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions FROM files WHERE uid='%@';", [[[u absoluteString] lowercaseString] sqlString]];
		return [self getFileForQuery:query];
	}
}


- (File*) getFileForRev: (NSNumber*) rev
{
	@autoreleasepool
	{
		NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions FROM files WHERE revision=%lld;", [rev longLongValue]];
		return [self getFileForQuery:query];
	}
}




- (NSArray*) getURLsBelowURL: (NSURL*)u withIsSet: (BOOL)b
{
	NSArray * rows;
	NSError * error;
	NSString * urlPath = [[u absoluteString] sqlString];
	NSString * query = [NSString stringWithFormat:@"SELECT url FROM files WHERE isSet=%i AND url != '%@' AND url LIKE '%@%%'", b, urlPath, urlPath];
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
	NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions FROM files WHERE revision >= %lld ORDER BY revision ASC LIMIT %lld;", [rev longLongValue], [limit longLongValue]];
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
	NSString * query = [[NSString alloc] initWithFormat:@"SELECT url, revision, fileSize, contentModDate, attributesModDate, isSet, extAttributes, versions FROM files WHERE revision >= %lld ORDER BY revision ASC LIMIT %lld;", [rev longLongValue], [limit longLongValue]];
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
