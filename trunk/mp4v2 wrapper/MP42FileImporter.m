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

#if !__LP64__
#import "MP42QTImporter.h"
#endif

#import "MP42AVFImporter.h"

#include "MP42AudioConverter.h"

@implementation MP42FileImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    [self release];
    self = nil;
    if ([[URL pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [[URL pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame ||
        [[URL pathExtension] caseInsensitiveCompare: @"mks"] == NSOrderedSame)
        self = [[MP42MkvImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"mp4"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"m4v"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"m4a"] == NSOrderedSame)
        self = [[MP42Mp4Importer alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"srt"] == NSOrderedSame)
        self = [[MP42SrtImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"scc"] == NSOrderedSame)
        self = [[MP42CCImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"ac3"] == NSOrderedSame)
        self = [[MP42AC3Importer alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"aac"] == NSOrderedSame)
        self = [[MP42AACImporter alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"264"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"h264"] == NSOrderedSame)
        self = [[MP42H264Importer alloc] initWithDelegate:del andFile:URL error:outError];
    else if ([[URL pathExtension] caseInsensitiveCompare: @"idx"] == NSOrderedSame ||
             [[URL pathExtension] caseInsensitiveCompare: @"idx"] == NSOrderedSame)
        self = [[MP42VobSubImporter alloc] initWithDelegate:del andFile:URL error:outError];
#if !__LP64__
    else if ([[URL pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame) {
        self = [[MP42QTImporter alloc] initWithDelegate:del andFile:URL error:outError];
    }
#endif
    // If we are on 10.7 or later, use the AVFoundation path
    else if (NSClassFromString(@"AVAsset")) {
        if ([[URL pathExtension] caseInsensitiveCompare: @"m2ts"] == NSOrderedSame ||
            [[URL pathExtension] caseInsensitiveCompare: @"mts"] == NSOrderedSame ) {
            self = [[MP42AVFImporter alloc] initWithDelegate:del andFile:URL error:outError];
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

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    return nil;
}

- (AudioStreamBasicDescription)audioDescriptionForTrack:(MP42Track *)track
{
    AudioStreamBasicDescription desc = {0,0,0,0,0,0,0,0,0};
    return desc;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!_activeTracks)
        _activeTracks = [[NSMutableArray alloc] init];
    
    [_activeTracks addObject:track];
}

- (void)startReading
{
    for (MP42Track* track in _activeTracks) {
        dispatch_retain(track.muxer_helper->queue);
        [track.muxer_helper->fifo retain];
    }
}

- (void)stopReading
{
    while (!_done)
        usleep(2000);

    for (MP42Track* track in _activeTracks) {        
        dispatch_release(track.muxer_helper->queue);
        [track.muxer_helper->fifo release];
    }
}

- (BOOL)done
{
    return _done;
}

- (MP42SampleBuffer*)copyNextSample
{
    return nil;
}

- (MP42SampleBuffer*)nextSampleForTrack:(MP42Track *)track
{
    return nil;
}

- (CGFloat)progress
{
    return _progress;
}

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{
    return NO;
}

- (BOOL)containsTrack:(MP42Track*)track
{
    return [_tracksArray containsObject:track];
}

- (void)cancel
{
    _cancelled = 1;
}

- (void)dealloc
{
    [_metadata release], _metadata = nil;
    [_tracksArray release], _tracksArray = nil;
    [_activeTracks release], _activeTracks = nil;
	[_fileURL release], _fileURL = nil;
    [super dealloc];
}


@synthesize metadata = _metadata;
@synthesize tracks = _tracksArray;

@end