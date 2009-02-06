//
//  MP4FileWrapper.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4FileWrapper.h"
#import "MP4ChapterTrackWrapper.h"

#include "MP4Utilities.h"

@implementation MP4FileWrapper

-(id)initWithExistingMP4File:(NSString *)mp4File
{
    if ((self = [super init]))
	{
		fileHandle = MP4Read([mp4File UTF8String], 0);

		if (!fileHandle)
			return nil;

        tracksArray = [[NSMutableArray alloc] init];
        int i, tracksCount = MP4GetNumberOfTracks( fileHandle, 0, 0);
        MP4TrackId chapterId = findChapterTrackId(fileHandle);
    
        for (i=0; i< tracksCount; i++) {
            id track;
            MP4TrackId trackId = MP4FindTrackId( fileHandle, i, 0, 0);
            if (trackId == chapterId)
                track = [[MP4ChapterTrackWrapper alloc] initWithSourcePath:mp4File trackID: trackId];
            else
                track = [[MP4TrackWrapper alloc] initWithSourcePath:mp4File trackID: trackId];

            [tracksArray addObject:track];
            [track release];
        }

        tracksToBeDeleted = [[NSMutableArray alloc] init];
	}

	return self;
}

- (NSInteger)tracksCount
{
    return [tracksArray count];
}

- (void) dealloc
{
    [tracksArray release];
    [tracksToBeDeleted release];
    [super dealloc];
}

@synthesize tracksArray;
@synthesize tracksToBeDeleted;


@end
