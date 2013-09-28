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
    float _volume;
    UInt32 _channels;
    UInt32 _sourceChannels;
    UInt32 _channelLayoutTag;

    MP4TrackId  _fallbackTrackId;
    MP4TrackId  _followsTrackId;

    MP42Track  *_fallbackTrack;
    MP42Track  *_followsTrack;
    
    NSString *_mixdownType;
}

@property(nonatomic, readwrite) float volume;
@property(nonatomic, readwrite) UInt32 channels;
@property(nonatomic, readwrite) UInt32 sourceChannels;
@property(nonatomic, readwrite) UInt32 channelLayoutTag;

@property(nonatomic, readonly) MP4TrackId fallbackTrackId;
@property(nonatomic, readonly) MP4TrackId followsTrackId;

@property(nonatomic, readwrite, assign) MP42Track *fallbackTrack;
@property(nonatomic, readwrite, assign) MP42Track *followsTrack;

@property(nonatomic, readwrite, retain) NSString *mixdownType;

@end
