
// HEADER
#import "FSWatcher.h"

#import <Foundation/Foundation.h>
#import "Singleton.h"


@implementation FSWatcher
{
	FSEventStreamRef streamRef;
	int flags;
}



@synthesize watchedPaths, observeFiles, ignoreSelf, isWatching;


/**
 * Initializer
 */
- (id) init
{
	if (self = [super init])
	{
		observeFiles = TRUE;
		ignoreSelf = TRUE;
		[self updateFlags];

		isWatching = FALSE;
	}
	return self;
}


/**
 * PRIVATE FUNCTION
 */
- (void) updateFlags
{
	// Switch between "Observe folders only" / "Observe Files and Folders"
	// Set ignoreSelf-flag
	//--------------------------------------------------------------------
	flags = kFSEventStreamCreateFlagUseCFTypes|kFSEventStreamCreateFlagWatchRoot;
	if (observeFiles)
	{
		flags |= kFSEventStreamCreateFlagFileEvents;
	}
	if (ignoreSelf)
	{
		flags |= kFSEventStreamCreateFlagIgnoreSelf;
	}
}

- (void) shouldObserveFiles: (BOOL) b
{
	observeFiles = b;
	[self updateFlags];
}

- (void) shouldIgnoreSelf: (BOOL) b
{
	ignoreSelf = b;
	[self updateFlags];
}

- (void) setPaths:(NSArray *) paths
{
	watchedPaths = paths;
}

- (void) startWatching
{
	if (isWatching)
	{
		[self stopWatching];
	}
	
	// Check if "paths" is empty
	//--------------------------
	if ( [watchedPaths count] == 0 )
	{
		isWatching = FALSE;
		return;
	}
		
	CFTimeInterval latency = 0.2;
	FSEventStreamContext context = {0,(__bridge void *)self,NULL,NULL,NULL};
	

	// 1. Step in FSEventsStream-Lifecycle: FSEventStreamCreate
	//----------------------------------------------------------
	streamRef = FSEventStreamCreate(kCFAllocatorDefault,&callback,&context,CFBridgingRetain(watchedPaths),kFSEventStreamEventIdSinceNow,latency, flags);
	
	// 2. Step in FSEventsStream-Lifecycle: FSEventStreamScheduleWithRunLoop
	//-----------------------------------------------------------------------
	FSEventStreamScheduleWithRunLoop(streamRef,[[NSRunLoop mainRunLoop] getCFRunLoop],kCFRunLoopDefaultMode);
	
	// 3. Step in FSEventsStream-Lifecycle: FSEventStreamStart
	//---------------------------------------------------------
	FSEventStreamStart(streamRef);
	
	isWatching = TRUE;
	
}

- (void) stopWatching
{
	if (!isWatching)
	{
		return;
	}

	// 4. Step in FSEventsStream-Lifecycle: FSEventStreamStop
	//--------------------------------------------------------
	FSEventStreamStop(streamRef);
	
	// 5. Step in FSEventsStream-Lifecycle: FSEventStreamInvalidate
	//--------------------------------------------------------------
	FSEventStreamInvalidate(streamRef);
	
	// 6. Step in FSEventsStream-Lifecycle: FSEventStreamRelease
	//-----------------------------------------------------------
	FSEventStreamRelease(streamRef);
	
	isWatching = FALSE;
}



/**
 * Callback function
 */
static void callback(ConstFSEventStreamRef streamRef,
				 void *clientCallBackInfo,
				 size_t numEvents,
				 void *eventPaths,
				 const FSEventStreamEventFlags eventFlags[],
				 const FSEventStreamEventId eventIds[])
{
	// First, make a copy of the event path so we can modify it.
	//-----------------------------------------------------------
	NSArray * paths = (__bridge NSArray *)(eventPaths);
	
	// Loop through all FSEvents
	//---------------------------
	for ( int i = 0 ; i < numEvents ; i++ )
	{
		/* Single & means BITWISE AND
		 *     0101 (decimal 5)
		 * AND 0011 (decimal 3)
		 *   = 0001 (decimal 1)
		 */
		
		if ( eventFlags[i] & kFSEventStreamEventFlagItemIsDir )
		{
			NSURL * u = [NSURL fileURLWithPath:[paths objectAtIndex:i] isDirectory:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventIsDir" object:u];
			
		}
		else if (eventFlags[i] & kFSEventStreamEventFlagItemIsFile)
		{
			NSURL * u = [NSURL fileURLWithPath:[paths objectAtIndex:i] isDirectory:NO];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventIsFile" object:u];
		}
		else if (eventFlags[i] & kFSEventStreamEventFlagItemIsSymlink)
		{
			NSURL * u = [NSURL fileURLWithPath:[paths objectAtIndex:i]];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventIsSymlink" object:u];
		}
		else if ( eventFlags[i] & kFSEventStreamEventFlagMustScanSubDirs )
		{
			if (eventFlags[i] & kFSEventStreamEventFlagUserDropped)
			{
				printf("BAD NEWS! We dropped events.\n");
			}
			else if (eventFlags[i] & kFSEventStreamEventFlagKernelDropped)
			{
				printf("REALLY BAD NEWS! The kernel dropped events.\n");
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherEventMustScanSubDirs" object:nil];
		}
		else if (eventFlags[i] & kFSEventStreamEventFlagRootChanged)
		{
			printf("The Root-folder has been moved!");
			[[NSNotificationCenter defaultCenter] postNotificationName:@"fsWatcherRootChanged" object:nil];
		}
	}
}

@end

/*
 enum {
 kFSEventStreamEventFlagNone = 0x00000000,
 kFSEventStreamEventFlagMustScanSubDirs = 0x00000001,
 kFSEventStreamEventFlagUserDropped = 0x00000002,
 kFSEventStreamEventFlagKernelDropped = 0x00000004,
 kFSEventStreamEventFlagEventIdsWrapped = 0x00000008,
 kFSEventStreamEventFlagHistoryDone = 0x00000010,
 kFSEventStreamEventFlagRootChanged = 0x00000020,
 kFSEventStreamEventFlagMount = 0x00000040,
 kFSEventStreamEventFlagUnmount = 0x00000080,
 
 // These flags are only set if you specified the
 // FileEventsflags when creating the stream.
 
 kFSEventStreamEventFlagItemCreated = 0x00000100,
 kFSEventStreamEventFlagItemRemoved = 0x00000200,
 kFSEventStreamEventFlagItemInodeMetaMod = 0x00000400,
 kFSEventStreamEventFlagItemRenamed = 0x00000800,
 kFSEventStreamEventFlagItemModified = 0x00001000,
 kFSEventStreamEventFlagItemFinderInfoMod = 0x00002000,
 kFSEventStreamEventFlagItemChangeOwner = 0x00004000,
 kFSEventStreamEventFlagItemXattrMod = 0x00008000,
 kFSEventStreamEventFlagItemIsFile = 0x00010000,
 kFSEventStreamEventFlagItemIsDir = 0x00020000,
 kFSEventStreamEventFlagItemIsSymlink = 0x00040000
 };
 
 */

