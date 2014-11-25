/**
 * AUTHOR:	Daniel Forrer
 * FEATURES:	Thread-safe
 */


@interface SQLiteDatabase : NSObject


- (id) initCreateAtPath:(NSString *)path;
- (long long) performQuery: (NSString*) query
				  rows: (NSArray**) rows
				 error: (NSError**) error;
- (int) getTotalChanges;
- (int) getChanges;


@end


/**
 * Here we extend NSString with a new function "sqlString"
 */

@interface NSString (Sqlite)

- (NSString *)sqlString;

@end

@implementation NSString (Sqlite)

/**
 * Replaces Occurrences of ' with the appropriate characters,
 * so that Sqlite can handle it.
 */

- (NSString *) sqlString
{
	if ([self rangeOfString:@"'"].location == NSNotFound)
	{
		return self;
	}
	NSMutableString *mutString = [NSMutableString stringWithString:self];
	[mutString replaceOccurrencesOfString: @"'"
						  withString: @"''"
							options: 0
							  range: NSMakeRange(0,[mutString length])];
	return mutString;
}

@end



/*
 nonatomic vs. atomic - "atomic" is the default. Always use "nonatomic". I don't know why, but the book I read said there is "rarely a reason" to use "atomic". (BTW: The book I read is the BNR "iOS Programming" book.)
 
 readwrite vs. readonly - "readwrite" is the default. When you @synthesize, both a getter and a setter will be created for you. If you use "readonly", no setter will be created. Use it for a value you don't want to ever change after the instantiation of the object.
 
 retain vs. copy vs. assign
 
 "assign" is the default. In the setter that is created by @synthesize, the value will simply be assigned to the attribute. My understanding is that "assign" should be used for non-pointer attributes.
 "retain" is needed when the attribute is a pointer to an object. The setter generated by @synthesize will retain (aka add a retain count) the object. You will need to release the object when you are finished with it.
 "copy" is needed when the object is mutable. Use this if you need the value of the object as it is at this moment, and you don't want that value to reflect any changes made by other owners of the object. You will need to release the object when you are finished with it because you are retaining the copy.
 */
