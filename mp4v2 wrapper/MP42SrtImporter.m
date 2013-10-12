//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42SrtImporter.h"

#import "MP42File.h"
#import "MP42SubUtilities.h"
#import "SBLanguages.h"

@implementation MP42SrtImporter

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError
{
    if ((self = [super init])) {
        _fileURL = [fileURL retain];

        NSInteger trackCount = 1;
        _tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger success = 0;
        MP4Duration duration = 0;

        MP42SubtitleTrack *newTrack = [[MP42SubtitleTrack alloc] init];

        newTrack.format = MP42SubtitleFormatTx3g;
        newTrack.sourceURL = _fileURL;
        newTrack.alternate_group = 2;
        newTrack.language = getFilenameLanguage((CFStringRef)[_fileURL path]);

        _ss = [[SBSubSerializer alloc] init];
        if ([[_fileURL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame) {
            success = LoadSRTFromPath([_fileURL path], _ss, &duration);
        } else if ([[_fileURL pathExtension] caseInsensitiveCompare: @"smi"] == NSOrderedSame) {
            success = LoadSMIFromPath([_fileURL path], _ss, 1);
        }

        [newTrack setDuration:duration];

        if (!success) {
            if (outError)
                *outError = MP42Error(@"The file could not be opened.", @"The file is not a srt file, or it does not contain any subtitles.", 100);
            
            [newTrack release];
            [self release];

            return nil;
        }

        [_ss setFinished:YES];
        
        if ([_ss positionInformation]) {
            newTrack.verticalPlacement = YES;
            _verticalPlacement = YES;
        }
        if ([_ss forced])
            newTrack.someSamplesAreForced = YES;

        [_tracksArray addObject:newTrack];
        [newTrack release];
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return 1000;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42SubtitleTrack*)track trackWidth], [(MP42SubtitleTrack*) track trackHeight]);
}

- (void)demux:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    MP42SampleBuffer *sample;

    for (MP42SubtitleTrack *track in _inputTracks) {
        CGSize trackSize;
        trackSize.width = track.trackWidth;
        trackSize.height = track.trackHeight;

        while (![_ss isEmpty] && !_cancelled) {
            SBSubLine *sl = [_ss getSerializedPacket];

            if ([sl->line isEqualToString:@"\n"]) {
                sample = copyEmptySubtitleSample(track.sourceId, sl->end_time - sl->begin_time, NO);
            }
            else {
                int top = (sl->top == INT_MAX) ? trackSize.height : sl->top;
                sample = copySubtitleSample(track.sourceId, sl->line, sl->end_time - sl->begin_time, sl->forced, _verticalPlacement, trackSize, top);
            }

            [self enqueue:sample];
            [sample release];
        }
    }

    _progress = 100.0;

    [self setDone:YES];
    [pool release];
}

- (void)startReading
{
    [super startReading];
    
    if (!_demuxerThread && !_done) {
        _demuxerThread = [[NSThread alloc] initWithTarget:self selector:@selector(demux:) object:self];
        [_demuxerThread setName:@"Srt Demuxer"];
        [_demuxerThread start];
    }
}

- (void) dealloc
{
    [_ss release];

    [super dealloc];
}

@end
