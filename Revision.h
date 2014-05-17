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

#import "DownloadFile.h"

@class Peer, DownloadFile, File;


@protocol RevisionDelegate <NSObject>

- (void) revisionMatched:(Revision*) rev;

@end



@interface Revision : NSObject <DownloadFileDelegate>


- (id) initWithRelURL:(NSString*)u
		andRevision:(NSNumber*)r
		   andIsSet:(NSNumber*)i
		 andExtAttr:(NSDictionary*)e
		andVersions:(NSDictionary*)v
		    andPeer:(Peer*)p
		  andConfig:(Configuration*)c;

- (NSDictionary*) plistEncoded;

- (void) match;

- (void) updateLastMatchAttempt;


// Core attributes from /revisions-request
//-----------------------------------------
@property (nonatomic, readonly, strong) NSString * relURL;
@property (nonatomic, readonly, strong) NSNumber * revision;
@property (nonatomic, readonly, strong) NSNumber * isSet;
@property (nonatomic, readonly, strong) NSMutableDictionary * extAttributes;
@property (nonatomic, readonly, strong) NSMutableDictionary * versions;

// Additional attributes
//-----------------------
@property (nonatomic, readonly, strong) Peer * peer;
@property (nonatomic, readonly, strong) DownloadFile * download;	// generated IF necessary
@property (nonatomic, readonly, strong) NSDate * lastMatchAttempt; // generated
@property (nonatomic, readonly, strong) NSURL * absoluteURL; // generated
@property (nonatomic, readonly, strong) File * remoteState;	// generated
@property (nonatomic, readonly) BOOL isDir;	// generated
@property (nonatomic,assign) id <RevisionDelegate> delegate; // Instance of Peer-Class
@property (nonatomic,readonly,strong) Configuration * config;

@end
