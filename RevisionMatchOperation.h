//
//  Created by Daniel on 23.05.14.
//  Copyright (c) 2014 putitinthebox.com. All rights reserved.
//

@class Revision;
@class Configuration;

@interface RevisionMatchOperation : NSOperation

- (id) initWithRevision:(Revision*)r andConfig:(Configuration*)c;

@end
