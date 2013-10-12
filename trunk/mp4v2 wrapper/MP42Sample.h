//
//  MP42Sample.h
//  Subler
//
//  Created by Damiano Galassi on 29/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

@class MP42Track;

@interface MP42SampleBuffer : NSObject {
    @public
	void         *data;
    uint64_t      size;
    MP4Duration   duration;
    int64_t       offset;
    MP4Timestamp  timestamp;
    MP4TrackId    trackId;
    BOOL          isSync;
    BOOL          isCompressed;
    BOOL          isForced;
}

@end
