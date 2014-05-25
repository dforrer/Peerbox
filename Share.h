//
//  Created by Daniel Forrer on 16.05.14.
//  Copyright (c) 2014 Forrer. All rights reserved.
//

@class File;
@class Peer;
@class DownloadRevisions;
@class Configuration;
@class Revision;

@interface Share : NSObject


// Initialization
//----------------
- (id) initShareWithID:(NSString*)i
		  andRootURL:(NSURL*)u
		  withSecret:(NSString*)s
		   andConfig:(Configuration*)c;


// File-Management
//-----------------
- (int) setFile:(File*)f;
- (File*) getFileForURL:(NSURL*)u;
- (File*) getFileForRev:(NSNumber*)rev;
- (void) removeFile:(File*)f;
- (NSArray*) getURLsBelowURL:(NSURL*)u
			    withIsSet:(BOOL)b;
- (NSArray*) getFilesAsJSONwithLimit:(NSNumber*)limit
				 startingFromRev:(NSNumber*)rev;
- (NSDictionary*) getFilesAsJSONDictWithLimit:(NSNumber*)limit
						startingFromRev:(NSNumber*)rev
							biggestRev:(NSNumber**)biggestRev;
- (NSNumber*) nextRevision;
- (NSNumber*) currentRevision;
- (void) filesDBBegin;
- (void) filesDBCommit;


// Peer-Management
//-----------------
- (Peer*) getPeerForID:(NSString*)i;
- (BOOL) setPeer:(Peer*)p;
- (NSArray*) allPeers;


// Revision-Management
//---------------------
- (void) setRevision:(Revision*)r forPeer:(Peer*)p;
- (void) removeRevision:(Revision*)r forPeer:(Peer*)p;
- (Revision*) nextRevisionForPeer:(Peer*)p;


// Other
//-------
- (NSString*) description;
- (NSDictionary*) plistEncoded;


// Model attributes
//------------------
@property (nonatomic, readonly, strong) NSString * shareId; // <shareId>.sql
@property (nonatomic, readonly, strong) NSURL * root;
@property (nonatomic, readonly, strong) NSString * secret; // SHA-256 of password
@property (nonatomic, readonly, strong) Configuration * config;

@end
