//
//  MP42Sample.h
//  Subler
//
//  Created by Damiano Galassi on 29/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

@interface MP42SampleBuffer : NSObject {
    @public
	void         *sampleData;
    uint64_t      sampleSize;
    MP4Duration   sampleDuration;
    MP4Duration   sampleOffset;
    MP4Timestamp  sampleTimestamp;
    MP4TrackId    sampleTrackId;
    BOOL          sampleIsSync;
}

@property(readwrite) void         *sampleData;
@property(readwrite) uint64_t      sampleSize;
@property(readwrite) MP4Duration   sampleDuration;
@property(readwrite) MP4Duration   sampleOffset;
@property(readwrite) MP4Timestamp  sampleTimestamp;
@property(readwrite) MP4TrackId    sampleTrackId;
@property(readwrite) BOOL          sampleIsSync;

@end
