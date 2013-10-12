//
//  MP42FileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42FileImporter.h"
#import "MP42MkvImporter.h"
#import "MP42Mp4Importer.h"
#import "MP42SrtImporter.h"
#import "MP42CCImporter.h"
#import "MP42AC3Importer.h"
#import "MP42AACImporter.h"
#import "MP42H264Importer.h"
#import "MP42VobSubImporter.h"
#import "MP42Track.h"
#import "MP42Fifo.h"

#if !__LP64__
#import "MP42QTImporter.h"
#endif

#import "MP42AVFImporter.h"

#include "MP42AudioConverter.h"

@implementation MP42FileImporter

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError;
{
    [self release];
    self = nil;
    if ([[fileURL pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [[fileURL pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame ||
        [[fileURL pathExtension] caseInsensitiveCompare: @"mks"] == NSOrderedSame)
        self = [MP42MkvImporter alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
             [[fileURL pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
             [[fileURL pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame)
        self = [MP42Mp4Importer alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame)
        self = [MP42SrtImporter alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"scc"] == NSOrderedSame)
        self = [MP42CCImporter alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"ac3"] == NSOrderedSame)
        self = [MP42AC3Importer alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"aac"] == NSOrderedSame)
        self = [MP42AACImporter alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"264"] == NSOrderedSame ||
             [[fileURL pathExtension] caseInsensitiveCompare: @"h264"] == NSOrderedSame)
        self = [MP42H264Importer alloc];
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"idx"] == NSOrderedSame ||
             [[fileURL pathExtension] caseInsensitiveCompare: @"idx"] == NSOrderedSame)
        self = [MP42VobSubImporter alloc];
#if !__LP64__
    else if ([[fileURL pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame) {
        self = [MP42QTImporter alloc];
    }
#endif
    // If we are on 10.7 or later, use the AVFoundation path
    else if (NSClassFromString(@"AVAsset")) {
        if ([[fileURL pathExtension] caseInsensitiveCompare: @"m2ts"] == NSOrderedSame ||
            [[fileURL pathExtension] caseInsensitiveCompare: @"mts"] == NSOrderedSame ) {
            self = [MP42AVFImporter alloc];
        }
    }

    if (self) {
        self = [self initWithURL:fileURL error:outError];

        if (self) {
            for (MP42Track *track in _tracksArray)
                track.muxer_helper->importer = self;
        }
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return 0;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    return NSMakeSize(0,0);
}

- (NSData *)magicCookieForTrack:(MP42Track *)track
{
    return nil;
}

- (AudioStreamBasicDescription)audioDescriptionForTrack:(MP42Track *)track
{
    AudioStreamBasicDescription desc = {0,0,0,0,0,0,0,0,0};
    return desc;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!_inputTracks) {
        _inputTracks = [[NSMutableArray alloc] init];
        _outputsTracks = [[NSMutableArray alloc] init];
    }

    BOOL alreadyAdded = NO;
    for (MP42Track *inputTrack in _inputTracks)
        if (inputTrack.sourceId == track.sourceId)
            alreadyAdded = YES;

    if (!alreadyAdded)
        [_inputTracks addObject:track];

    [_outputsTracks addObject:track];
}

- (void)startReading
{
    for (MP42Track *track in _outputsTracks)
        track.muxer_helper->fifo = [[MP42Fifo alloc] init];

    _doneSem = dispatch_semaphore_create(0);
}

- (void)cancelReading
{
    OSAtomicIncrement32(&_cancelled);

    for (MP42Track *track in _outputsTracks) {
        [track.muxer_helper->fifo cancel];
    }

    // wait until the demuxer thread exits
    dispatch_semaphore_wait(_doneSem, DISPATCH_TIME_FOREVER);

    // stop all the related converters
    for (MP42Track *track in _outputsTracks) {
        [track.muxer_helper->converter cancel];
    }
}

- (void)enqueue:(MP42SampleBuffer *)sample {
    for (MP42Track *track in _outputsTracks) {
        if (track.sourceId == sample->trackId) {
            if (track.muxer_helper->converter) {
                [track.muxer_helper->converter addSample:sample];
            } else {
                [track.muxer_helper->fifo enqueue:sample];
            }
        }
    }
}

- (BOOL)done
{
    return _done;
}

- (void)setDone:(BOOL)status {
    OSAtomicIncrement32(&_done);
    dispatch_semaphore_signal(_doneSem);
}

- (CGFloat)progress
{
    return _progress;
}

- (BOOL)cleanUp:(MP4FileHandle)fileHandle
{
    return NO;
}

- (BOOL)containsTrack:(MP42Track *)track
{
    return [_tracksArray containsObject:track];
}

- (MP42Track *)inputTrackWithTrackID:(MP4TrackId)trackId
{
    for (MP42Track *track in _inputTracks) {
        if (track.sourceId == trackId) {
            return track;;
        }
    }

    return nil;
}

- (void)dealloc
{
    for (MP42Track *track in _inputTracks) {
        [track.muxer_helper->demuxer_context release];
    }
    
    for (MP42Track *track in _outputsTracks) {
        [track.muxer_helper->fifo release];
        [track.muxer_helper->converter release];
    }

    [_metadata release], _metadata = nil;
    [_tracksArray release], _tracksArray = nil;
    [_inputTracks release], _inputTracks = nil;
    [_outputsTracks release], _outputsTracks = nil;

	[_fileURL release], _fileURL = nil;
    [_demuxerThread release], _demuxerThread = nil;

    if (_doneSem)
        dispatch_release(_doneSem);

    [super dealloc];
}

@synthesize metadata = _metadata;
@synthesize tracks = _tracksArray;

@end
