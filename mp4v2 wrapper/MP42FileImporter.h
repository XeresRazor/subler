//
//  MP42FileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "MP42Sample.h"
#import "MP42Utilities.h"

#import "mp4v2.h"

@class MP42Sample;
@class MP42Metadata;
@class MP42Track;

@interface MP42FileImporter : NSObject {
    NSURL   *_fileURL;

    NSInteger       _chapterId;
    MP42Metadata   *_metadata;

    NSMutableArray *_tracksArray;
    NSMutableArray *_inputTracks;
    NSMutableArray *_outputsTracks;
    NSThread       *_demuxerThread;

    CGFloat       _progress;
    int32_t       _cancelled;
    int32_t       _done;
    dispatch_semaphore_t _doneSem;
}

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError;

- (BOOL)containsTrack:(MP42Track*)track;
- (MP42Track *)inputTrackWithTrackID:(MP4TrackId)trackId;

- (NSUInteger)timescaleForTrack:(MP42Track *)track;
- (NSSize)sizeForTrack:(MP42Track *)track;
- (NSData *)magicCookieForTrack:(MP42Track *)track;
- (AudioStreamBasicDescription)audioDescriptionForTrack:(MP42Track *)track;

- (void)setActiveTrack:(MP42Track *)track;

- (void)startReading;
- (void)cancelReading;

- (void)enqueue:(MP42SampleBuffer *)sample;

- (CGFloat)progress;

- (BOOL)done;
- (void)setDone:(BOOL)status;

- (BOOL)cleanUp:(MP4FileHandle) fileHandle;

@property(readwrite, retain) MP42Metadata *metadata;
@property(readonly) NSMutableArray  *tracks;

@end
