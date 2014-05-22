//
//  File Unit Tests.m
//  Peerbox_OBJC_OO_HTTP
//
//  Created by Daniel Forrer on 14.04.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "File.h"

@interface File_Unit_Tests : XCTestCase

@end

@implementation File_Unit_Tests
{
	File * f1;
	File * f2;
}
- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.

	f1 = [[File alloc] init];
	f2 = [[File alloc] init];
	
	NSMutableDictionary * f1_versions = [[NSMutableDictionary alloc] init];
	NSMutableDictionary * f2_versions = [[NSMutableDictionary alloc] init];

	[f1 setVersions:f1_versions];
	[f2 setVersions:f2_versions];

}

- (void)tearDown
{
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	f1 = nil;
	f2 = nil;
	[super tearDown];
}

- (void)test1_files_have_same_history
{
	[[f1 versions] setObject:@"hash1" forKey:@"1"];
	[[f1 versions] setObject:@"hash2" forKey:@"2"];
	[[f1 versions] setObject:@"hash3" forKey:@"3"];
	[[f1 versions] setObject:@"hash4" forKey:@"4"];
	[[f1 versions] setObject:@"hash5" forKey:@"5"];
	
	[[f2 versions] setObject:@"hash2" forKey:@"2"];
	[[f2 versions] setObject:@"hash3" forKey:@"3"];
	[[f2 versions] setObject:@"hash4" forKey:@"4"];
	[[f2 versions] setObject:@"hash5" forKey:@"5"];
	[[f2 versions] setObject:@"hash6" forKey:@"6"];
	[[f2 versions] setObject:@"hash7" forKey:@"7"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertFalse(rv, @"First test failed");
}

- (void)test2_files_have_conflicting_history
{
	[[f1 versions] setObject:@"hash1" forKey:@"1"];
	[[f1 versions] setObject:@"hash2" forKey:@"2"];
	[[f1 versions] setObject:@"hash3" forKey:@"3"];
	[[f1 versions] setObject:@"hashXX" forKey:@"4"];
	[[f1 versions] setObject:@"hash5" forKey:@"5"];
	
	[[f2 versions] setObject:@"hash2" forKey:@"2"];
	[[f2 versions] setObject:@"hash3" forKey:@"3"];
	[[f2 versions] setObject:@"hash4" forKey:@"4"];
	[[f2 versions] setObject:@"hash5" forKey:@"5"];
	[[f2 versions] setObject:@"hash6" forKey:@"6"];
	[[f2 versions] setObject:@"hash7" forKey:@"7"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertTrue(rv, @"test2: should return false!");
}

- (void)test3_files_have_no_common_history
{
	[[f1 versions] setObject:@"hash1" forKey:@"1"];
	[[f1 versions] setObject:@"hash2" forKey:@"2"];
	[[f1 versions] setObject:@"hash3" forKey:@"3"];
	[[f1 versions] setObject:@"hashXX" forKey:@"4"];
	[[f1 versions] setObject:@"hash5" forKey:@"5"];
	
	[[f2 versions] setObject:@"hash2" forKey:@"6"];
	[[f2 versions] setObject:@"hash3" forKey:@"7"];
	[[f2 versions] setObject:@"hash4" forKey:@"8"];
	[[f2 versions] setObject:@"hash5" forKey:@"9"];
	[[f2 versions] setObject:@"hash6" forKey:@"10"];
	[[f2 versions] setObject:@"hash7" forKey:@"11"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertTrue(rv, @"test3");
}

- (void)test4_edge_case_only_one_common_version
{
	[[f1 versions] setObject:@"hash1" forKey:@"1"];
	[[f1 versions] setObject:@"hash2" forKey:@"2"];
	[[f1 versions] setObject:@"hash3" forKey:@"3"];
	[[f1 versions] setObject:@"hashXX" forKey:@"4"];
	[[f1 versions] setObject:@"hash5" forKey:@"5"];
	
	[[f2 versions] setObject:@"hash5" forKey:@"5"];
	[[f2 versions] setObject:@"hash6" forKey:@"6"];
	[[f2 versions] setObject:@"hash7" forKey:@"7"];
	[[f2 versions] setObject:@"hash8" forKey:@"8"];
	[[f2 versions] setObject:@"hash9" forKey:@"9"];
	[[f2 versions] setObject:@"hash10" forKey:@"10"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertFalse(rv, @"test4: edge case");
}


- (void)test5_edge_case_last_version_not_the_same
{
	[[f1 versions] setObject:@"hash1" forKey:@"111"];
	[[f1 versions] setObject:@"hash2" forKey:@"112"];
	[[f1 versions] setObject:@"hash3" forKey:@"113"];
	[[f1 versions] setObject:@"hash4" forKey:@"114"];
	[[f1 versions] setObject:@"hash5" forKey:@"115"];
	[[f1 versions] setObject:@"hash6" forKey:@"116"];
	[[f1 versions] setObject:@"hash7" forKey:@"117"];
	
	[[f2 versions] setObject:@"hash1" forKey:@"111"];
	[[f2 versions] setObject:@"hash2" forKey:@"112"];
	[[f2 versions] setObject:@"hash3" forKey:@"113"];
	[[f2 versions] setObject:@"hash4" forKey:@"114"];
	[[f2 versions] setObject:@"hash5" forKey:@"115"];
	[[f2 versions] setObject:@"hash6" forKey:@"116"];
	[[f2 versions] setObject:@"hashXX" forKey:@"117"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertTrue(rv, @"test5: edge case");
}

- (void)test6_only_one_version
{
	[[f2 versions] setObject:@"hash1" forKey:@"111"];
	
	[[f1 versions] setObject:@"hash1" forKey:@"111"];
	[[f1 versions] setObject:@"hash2" forKey:@"112"];
	[[f1 versions] setObject:@"hash3" forKey:@"113"];
	[[f1 versions] setObject:@"hash4" forKey:@"114"];
	[[f1 versions] setObject:@"hash5" forKey:@"115"];
	[[f1 versions] setObject:@"hash6" forKey:@"116"];
	[[f1 versions] setObject:@"hashXX" forKey:@"117"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertFalse(rv, @"test5: only one version");
}

- (void)test7_max_versions
{
	
	[[f2 versions] setObject:@"hash1" forKey:@"111"];
	
	[[f1 versions] setObject:@"hash1" forKey:@"111"];
	[[f1 versions] setObject:@"hash2" forKey:@"112"];
	[[f1 versions] setObject:@"hash3" forKey:@"113"];
	[[f1 versions] setObject:@"hash4" forKey:@"114"];
	[[f1 versions] setObject:@"hash5" forKey:@"115"];
	[[f1 versions] setObject:@"hash6" forKey:@"116"];
	[[f1 versions] setObject:@"hashXX" forKey:@"117"];
	
	BOOL rv = [f1 hasConflictingVersionsWithFile:f2];
	XCTAssertFalse(rv, @"test5: only one version");
}

@end
