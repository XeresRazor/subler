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

- (instancetype)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if (self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle]) {
        _mediaType = MP42MediaTypeClosedCaption;
    }

    return self;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _name = [self defaultName];
        _format = MP42ClosedCaptionFormatCEA608;
        _mediaType = MP42MediaTypeClosedCaption;
    }

    return self;
}

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (_isEdited && !_muxed)
        _muxed = YES;

    [super writeToFile:fileHandle error:outError];

    return _Id;
}

- (NSString *)defaultName {
    return MP42MediaTypeClosedCaption;
}

- (void)dealloc
{
    [super dealloc];
}

@end
