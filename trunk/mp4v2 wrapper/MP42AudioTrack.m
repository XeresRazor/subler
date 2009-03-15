//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP42AudioTrack.h"
#import "AudioMuxer.h"

@implementation MP42AudioTrack

- (id) initWithSourcePath:(NSString *)source trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourcePath:source trackID:trackID fileHandle:fileHandle])
    {

    }

    return self;
}

-(id) init
{
    if (self = [super init])
    {
        name = @"Audio Track";
    }

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    else if (isEdited && !muxed && sourceId) {
        muxMP4AudioTrack(fileHandle, sourcePath, sourceId);
    }
    return YES;
}

- (void) dealloc
{
    [super dealloc];
}

@end
