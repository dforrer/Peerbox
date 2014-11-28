/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:	Thread-safe
 */

// HEADER
#import "SQLiteDatabase.h"

#import <Foundation/Foundation.h>
#import <sqlite3.h>


@implementation SQLiteDatabase
{
	sqlite3 * sqliteConnection;
}


/**
 * Initializes a new SQLiteDatabase-Object
 */
- (id) initCreateAtPath: (NSString *)path
{
	if ( self = [super init] )
	{
		// Try opening the database-connection

		int retval = sqlite3_open([path UTF8String], &sqliteConnection);
		
		// Handle Error (and return)
		
		if (retval != SQLITE_OK)
		{
			NSLog(@"[SQLITE] Unable to open database!");
			return nil; // if it fails, return nil obj
		}
	}
	return self;
}

/** 
 * Returns TRUE if the first word of the nsstring "query"
 * is equal to "SELECT". This function checks case insensitively.
 */
- (BOOL) queryCommandIsSELECT:(NSString*) query
{
	return [[[query componentsSeparatedByString:@" "] objectAtIndex:0] caseInsensitiveCompare:@"SELECT"] == NSOrderedSame;
}

/**
 * SELECT
 * Private function, only used by "performQuery: ..."
 */
- (long long) performSELECT: (NSString*) query
				   rows: (NSArray**) rows
				  error: (NSError**) error
{
	sqlite3_stmt *stmt = nil;
	int retval = sqlite3_prepare_v2(sqliteConnection, [query UTF8String], -1, &stmt, NULL);
	
	// Handle Error (and return)

	if ( retval != SQLITE_OK )
	{
		NSString * errorString = [NSString stringWithFormat:@"[SQLITE] Error when preparing query!: %@", query];
		*error = [NSError errorWithDomain: errorString code:retval userInfo:nil];
		return 0;
	}
	
	// Continue with SELECT (=No error)
	
	NSMutableArray *result = [[NSMutableArray alloc] init];
	while (sqlite3_step(stmt) == SQLITE_ROW)
	{
		@autoreleasepool
		{
			NSMutableArray *row = [[NSMutableArray alloc] init];
			for (int i=0; i < sqlite3_column_count(stmt); i++)
			{
				int colType = sqlite3_column_type(stmt, i);
				id value;
				if (colType == SQLITE_TEXT)
				{
					const char *col = (const char*) sqlite3_column_text(stmt, i);
					value = [[NSString alloc] initWithCString:col encoding:NSUTF8StringEncoding];
				}
				else if (colType == SQLITE_INTEGER)
				{
					int64_t col = sqlite3_column_int64(stmt, i);
					value = [[NSNumber alloc] initWithLongLong:col];
				}
				else if (colType == SQLITE_FLOAT)
				{
					double col = sqlite3_column_double(stmt, i);
					value = [[NSNumber alloc] initWithDouble:col];
				}
				else if (colType == SQLITE_NULL)
				{
					value = [NSNull null];
				}
				else
				{
					NSLog(@"[SQLITE] UNKNOWN DATATYPE");
				}
				if (value != nil)
				{
					[row addObject:value];
				}
			}
			[result addObject:row];
		}
	}
	sqlite3_finalize(stmt);
	*rows = result;
	return [result count];

}

/**
 * INSERT, UPDATE, DELETE, CREATE
 * Private function, only used by "performQuery: ..."
 */
- (long long) performOtherCommand: (NSString*) query
					    rows: (NSArray**) rows
					   error: (NSError**) error
{
	int retval = sqlite3_exec(sqliteConnection,[query cStringUsingEncoding:NSUTF8StringEncoding],NULL,NULL,NULL);
	
	// Handle Error (and return)
	
	if ( retval != SQLITE_OK )
	{
		NSString * errorString = [NSString stringWithFormat:@"[SQLITE] Error when executing query!: %@", query];
		*error = [NSError errorWithDomain: errorString code:retval userInfo:nil];
		return 0;
	}
	
	// Continue (= No error)
	
	return sqlite3_changes(sqliteConnection);
}


/**
 * Performs a 'query' and returns the number of rows found or changed
 * The rows themselves are accessible in the 'rows'-Array
 *
 * IMPORTENT: NSString variables need
 * to be bound using the
 * NSStringSqliteExtension
 * [string sqlString]!
 *
 * Supports: INSERT, UPDATE, DELETE, SELECT, etc.
 **/
- (long long) performQuery: (NSString*) query
				  rows: (NSArray**) rows
				 error: (NSError**) error
{
	@synchronized( self )
	{
		if ( [self queryCommandIsSELECT:query] )
		{
			return [self performSELECT: query
							  rows: rows
							 error: error];
		}
		else
		{
			return [self performOtherCommand: query
								   rows: rows
								  error: error];
		}
	}
}


/**
 * This function returns the number of row changes
 * caused by INSERT, UPDATE or DELETE statements
 * since the database connection was opened.
 */
- (int) getTotalChanges
{
	return sqlite3_total_changes(sqliteConnection);
}

/**
 * This function returns the number of database rows
 * that were changed or inserted or deleted by the most
 * recently completed SQL statement
 */
- (int) getChanges
{
	return sqlite3_changes(sqliteConnection);
}


@end


/*
 #define SQLITE_OK           0   // Successful result //
 #define SQLITE_ERROR        1   // SQL error or missing database
 #define SQLITE_INTERNAL     2   // Internal logic error in SQLite
 #define SQLITE_PERM         3   // Access permission denied
 #define SQLITE_ABORT        4   // Callback routine requested an abort
 #define SQLITE_BUSY         5   // The database file is locked
 #define SQLITE_LOCKED       6   // A table in the database is locked
 #define SQLITE_NOMEM        7   // A malloc() failed
 #define SQLITE_READONLY     8   // Attempt to write a readonly database
 #define SQLITE_INTERRUPT    9   // Operation terminated by sqlite3_interrupt()
 #define SQLITE_IOERR       10   // Some kind of disk I/O error occurred
 #define SQLITE_CORRUPT     11   // The database disk image is malformed
 #define SQLITE_NOTFOUND    12   // Unknown opcode in sqlite3_file_control()
 #define SQLITE_FULL        13   // Insertion failed because database is full
 #define SQLITE_CANTOPEN    14   // Unable to open the database file
 #define SQLITE_PROTOCOL    15   // Database lock protocol error
 #define SQLITE_EMPTY       16   // Database is empty
 #define SQLITE_SCHEMA      17   // The database schema changed
 #define SQLITE_TOOBIG      18   // String or BLOB exceeds size limit
 #define SQLITE_CONSTRAINT  19   // Abort due to constraint violation
 #define SQLITE_MISMATCH    20   // Data type mismatch
 #define SQLITE_MISUSE      21   // Library used incorrectly
 #define SQLITE_NOLFS       22   // Uses OS features not supported on host
 #define SQLITE_AUTH        23   // Authorization denied
 #define SQLITE_FORMAT      24   // Auxiliary database format error
 #define SQLITE_RANGE       25   // 2nd parameter to sqlite3_bind out of range
 #define SQLITE_NOTADB      26   // File opened that is not a database file
 #define SQLITE_NOTICE      27   // Notifications from sqlite3_log()
 #define SQLITE_WARNING     28   // Warnings from sqlite3_log()
 #define SQLITE_ROW         100  // sqlite3_step() has another row ready
 #define SQLITE_DONE        101  // sqlite3_step() has finished executing
 
 */
