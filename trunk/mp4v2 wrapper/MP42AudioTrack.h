//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@interface MP42AudioTrack : MP42Track <NSCoding, NSCopying> {
    float volume;
    UInt32 channels;
    UInt32 sourceChannels;
    UInt32 channelLayoutTag;

    MP4TrackId  fallbackTrackId;
    MP4TrackId  followsTrackId;

    NSString *mixdownType;
}

@property(nonatomic, readwrite) float volume;
@property(nonatomic, readwrite) UInt32 channels;
@property(nonatomic, readwrite) UInt32 sourceChannels;
@property(nonatomic, readwrite) UInt32 channelLayoutTag;

@property(nonatomic, readwrite) MP4TrackId fallbackTrackId;
@property(nonatomic, readwrite) MP4TrackId followsTrackId;

@property(nonatomic, readwrite, retain) NSString *mixdownType;

@end
