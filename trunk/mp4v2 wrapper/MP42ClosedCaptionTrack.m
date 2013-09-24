//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42ClosedCaptionTrack.h"
#import "MP42MediaFormat.h"
#import "SBLanguages.h"

@implementation MP42ClosedCaptionTrack

- (id)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle];

    return self;
}

- (id)init
{
    if ((self = [super init])) {
        name = MP42MediaTypeClosedCaption;
        format = MP42ClosedCaptionFormatCEA608;
    }

    return self;
}

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (isEdited && !muxed)
        muxed = YES;

    [super writeToFile:fileHandle error:outError];

    return Id;
}

- (void)dealloc
{
    [super dealloc];
}

@end
