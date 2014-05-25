//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

/*
{
	"peerId":"8aed3573025b08170f8be3e305390953bc765c56",
	"revisions":
	{
		"Google/ABC.txt":
		{
			"revision":13 ,
			"isSet":1,
			"extendedAttributes":
			{
			},
			"versions":
			{
				"1":"521d3573025b08170f8be3e305390953bc765c56"
			}
		},
		"Apple/":
		{
			"revision":15,
			"isSet":0,
			"extendedAttributes":
			{
			},
			"versions":
			{
				"1":"0"
			}
		}
	}
} 
*/


@class Peer;


@interface Revision : NSObject

- (void) updateLastMatchAttempt;
- (BOOL) isZeroLengthFile;
- (BOOL) canBeMatchedInstantly;
- (NSString *) getLastVersionHash;
- (NSString *) getLastVersionKey;

// Core attributes from /revisions-request
//-----------------------------------------
@property (nonatomic, readwrite, strong) NSString * relURL;
@property (nonatomic, readwrite, strong) NSNumber * revision;
@property (nonatomic, readwrite, strong) NSNumber * isSet;
@property (nonatomic, readwrite, strong) NSNumber * fileSize;
@property (nonatomic, readwrite, strong) NSDictionary * extAttributes;
@property (nonatomic, readwrite, strong) NSDictionary * versions;
@property (nonatomic, readwrite, strong) NSNumber * isDir;
@property (nonatomic, readwrite, strong) NSDate * lastMatchAttempt;
@property (nonatomic, readwrite, strong) Peer * peer;

 
@end
