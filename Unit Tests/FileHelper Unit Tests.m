//
//  FileHelper Unit Tests.m
//  Peerbox_OBJC_OO_HTTP
//
//  Created by Daniel on 15.04.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FileHelper.h"


@interface FileHelper_Unit_Tests : XCTestCase

@end

@implementation FileHelper_Unit_Tests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test1
{
	NSString * hashA = @"da39a3ee5e6b4b0d3255bfef95601890afd80709";
	NSString * hashB = @"df4f783b5d383c000c6ecfbd9252a8d62b77e36a";
	BOOL rv = [FileHelper hashA:hashA isSmallerThanHashB:hashB];
	XCTAssertTrue(rv, @"AssertTrue");
}

- (void)test2
{
	NSString * hashA = @"aa39a3ee5e6b4b0d3255bfef95601890afd80709";
	NSString * hashB = @"bf4f783b5d383c000c6ecfbd9252a8d62b77e36a";
	BOOL rv = [FileHelper hashA:hashA isSmallerThanHashB:hashB];
	XCTAssertTrue(rv, @"AssertTrue");
}

- (void)test3
{
	NSString * hashA = @"bf4f783b5d383c000c6ecfbd9252a8d62b77e36b";
	NSString * hashB = @"bf4f783b5d383c000c6ecfbd9252a8d62b77e36a";
	BOOL rv = [FileHelper hashA:hashA isSmallerThanHashB:hashB];
	XCTAssertFalse(rv, @"AssertTrue");
}

- (void)test4
{
	NSString * hashA = @"1f4f783b5d383c000c6ecfbd9252a8d62b77e36b";
	NSString * hashB = @"1f4f783b5d383c000c6ecfbd9252a8d62b77e36b";
	BOOL rv = [FileHelper hashA:hashA isSmallerThanHashB:hashB];
	XCTAssertFalse(rv, @"AssertTrue");
}

@end
