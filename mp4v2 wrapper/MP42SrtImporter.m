//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42SrtImporter.h"
#import "SubUtilities.h"
#import "SBLanguages.h"
#import "MP42File.h"


@implementation MP42SrtImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    if ((self = [super init])) {
        _delegate = del;
        _fileURL = [URL retain];

        NSInteger trackCount = 1;
        _tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger success = 0;
        MP4Duration duration = 0;

        MP42SubtitleTrack *newTrack = [[MP42SubtitleTrack alloc] init];

        newTrack.format = MP42SubtitleFormatTx3g;
        newTrack.sourceFormat = @"Srt";
        newTrack.sourceURL = _fileURL;
        newTrack.alternate_group = 2;
        newTrack.language = getFilenameLanguage((CFStringRef)[_fileURL path]);

        ss = [[SBSubSerializer alloc] init];
        if ([[_fileURL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame) {
            success = LoadSRTFromPath([_fileURL path], ss, &duration);
        }
        else if ([[_fileURL pathExtension] caseInsensitiveCompare: @"smi"] == NSOrderedSame) {
            success = LoadSMIFromPath([_fileURL path], ss, 1);
        }

        [newTrack setDuration:duration];

        if (!success) {
            if (outError)
                *outError = MP42Error(@"The file could not be opened.", @"The file is not a srt file, or it does not contain any subtitles.", 100);
            
            [newTrack release];
            [self release];

            return nil;
        }

        [ss setFinished:YES];
        
        if ([ss positionInformation]) {
            newTrack.verticalPlacement = YES;
            verticalPlacement = YES;
        }
        if ([ss forced])
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

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    return nil;
}

- (MP42SampleBuffer*)nextSampleForTrack:(MP42Track *)track
{
    return [[self copyNextSample] autorelease];
}

- (void)startReading
{
    [super startReading];

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    MP42SampleBuffer *sample;
    MP4TrackId dstTrackId = [[_activeTracks lastObject] Id];

    for (MP42Track * track in _activeTracks) {
        muxer_helper *helper = track.muxer_helper;
        while (![ss isEmpty]) {
            SBSubLine *sl = [ss getSerializedPacket];

            if ([sl->line isEqualToString:@"\n"]) {
                if ((sample = copyEmptySubtitleSample(dstTrackId, sl->end_time - sl->begin_time, NO)))
                    dispatch_async(helper->queue, ^{
                        [helper->fifo addObject:sample];
                        [sample release];
                    });
            }
            else {
            CGSize trackSize;
            trackSize.width = [(MP42SubtitleTrack*)[_tracksArray lastObject] trackWidth];
            trackSize.height = [(MP42SubtitleTrack*)[_tracksArray lastObject] trackHeight];

            int top = (sl->top == INT_MAX) ? trackSize.height : sl->top;

            if ((sample = copySubtitleSample(dstTrackId, sl->line, sl->end_time - sl->begin_time, sl->forced, verticalPlacement, trackSize, top)))
                dispatch_async(helper->queue, ^{
                    [helper->fifo addObject:sample];
                    [sample release];
                });
            }
        }
    }
    
    _done = 1;
    _progress = 100.0;

    [pool release];
    return;
}

- (void) dealloc
{
    [ss release];

    [super dealloc];
}

@end
