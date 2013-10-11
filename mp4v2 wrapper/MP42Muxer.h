//
//  MP42Muxer.h
//  Subler
//
//  Created by Damiano Galassi on 30/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

@class MP42Track;

@protocol MP42MuxerDelegate
- (void)progressStatus:(CGFloat)progress;
@end

@interface MP42Muxer : NSObject {
    MP4FileHandle   _fileHandle;
    id              _delegate;

    NSMutableArray *_workingTracks;
    int32_t         _cancelled;
}

- (instancetype)initWithDelegate:(id <MP42MuxerDelegate>)del;

- (void)addTrack:(MP42Track *)track;

- (BOOL)setup:(MP4FileHandle)fileHandle error:(NSError **)outError;
- (void)work;
- (void)cancel;

@end
