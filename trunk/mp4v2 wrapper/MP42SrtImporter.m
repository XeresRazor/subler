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
        delegate = del;
        fileURL = [URL retain];

        NSInteger trackCount = 1;
        tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger success = 0;
        MP4Duration duration = 0;

        MP42SubtitleTrack *newTrack = [[MP42SubtitleTrack alloc] init];

        newTrack.format = @"3GPP Text";
        newTrack.sourceFormat = @"Srt";
        newTrack.sourceURL = fileURL;
        newTrack.alternate_group = 2;
        newTrack.language = getFilenameLanguage((CFStringRef)[fileURL path]);

        ss = [[SBSubSerializer alloc] init];
        if ([[fileURL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame) {
            success = LoadSRTFromPath([fileURL path], ss, &duration);
        }
        else if ([[fileURL pathExtension] caseInsensitiveCompare: @"smi"] == NSOrderedSame) {
            success = LoadSMIFromPath([fileURL path], ss, 1);
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

        [tracksArray addObject:newTrack];
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

- (void)start
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    MP42SampleBuffer *sample;
    MP4TrackId dstTrackId = [[activeTracks lastObject] Id];

    for (MP42Track * track in activeTracks) {
        muxer_helper *helper = track.muxer_helper;
        while (![ss isEmpty]) {
            SBSubLine *sl = [ss getSerializedPacket];

            if ([sl->line isEqualToString:@"\n"]) {
                if ((sample = copyEmptySubtitleSample(dstTrackId, sl->end_time - sl->begin_time, NO)))
                    @synchronized(helper->fifo) {
                        [helper->fifo addObject:sample];
                        [sample release];
                    }
            }
            else {
            CGSize trackSize;
            trackSize.width = [(MP42SubtitleTrack*)[tracksArray lastObject] trackWidth];
            trackSize.height = [(MP42SubtitleTrack*)[tracksArray lastObject] trackHeight];

            int top = (sl->top == INT_MAX) ? trackSize.height : sl->top;

            if ((sample = copySubtitleSample(dstTrackId, sl->line, sl->end_time - sl->begin_time, sl->forced, verticalPlacement, trackSize, top)))
                @synchronized(helper->fifo) {
                    [helper->fifo addObject:sample];
                    [sample release];
                }
            }
        }
    }
    
    [pool release];
    return;
}

- (BOOL)done
{
    return 1;
}


- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];
    
    [activeTracks addObject:track];
}

- (CGFloat)progress {
    return 100.0;
}

- (void) dealloc
{
    [ss release];
	[fileURL release];
    [tracksArray release];
    [activeTracks release];

    [super dealloc];
}

@end
