//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42AudioTrack.h"
#import "MP42Utilities.h"
#import "MP42MediaFormat.h"

extern u_int8_t MP4AV_AacConfigGetChannels(u_int8_t* pConfig);

@implementation MP42AudioTrack

- (instancetype)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle])) {
        MP4GetTrackFloatProperty(fileHandle, _Id, "tkhd.volume", &_volume);
        _mediaType = MP42MediaTypeAudio;

        u_int8_t audioType = 
		MP4GetTrackEsdsObjectTypeId(fileHandle, _Id);

        if (audioType != MP4_INVALID_AUDIO_TYPE) {
            if (MP4_IS_AAC_AUDIO_TYPE(audioType)) {
                u_int8_t* pAacConfig = NULL;
                u_int32_t aacConfigLength;

                if (MP4GetTrackESConfiguration(fileHandle, 
                                               _Id,
                                               &pAacConfig,
                                               &aacConfigLength) == true)
                    if (pAacConfig != NULL || aacConfigLength >= 2) {
                        _channels = MP4AV_AacConfigGetChannels(pAacConfig);
                        free(pAacConfig);
                    }
            } else if ((audioType == MP4_PCM16_LITTLE_ENDIAN_AUDIO_TYPE) ||
                       (audioType == MP4_PCM16_BIG_ENDIAN_AUDIO_TYPE)) {
                u_int32_t samplesPerFrame =
                MP4GetSampleSize(fileHandle, _Id, 1) / 2;

                MP4Duration frameDuration =
                MP4GetSampleDuration(fileHandle, _Id, 1);

                if (frameDuration != 0) {
                    // assumes track time scale == sampling rate
                    _channels = samplesPerFrame / frameDuration;
                }
            }
        }
        if (audioType == 0xA9) {
            uint64_t channels_count = 0;
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.mp4a.channels", &channels_count);
            _channels = channels_count;
        }
        else if (MP4HaveTrackAtom(fileHandle, _Id, "mdia.minf.stbl.stsd.ac-3.dac3")) {
            uint64_t acmod, lfeon;

            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.ac-3.dac3.acmod", &acmod);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.ac-3.dac3.lfeon", &lfeon);

            readAC3Config(acmod, lfeon, &_channels, &_channelLayoutTag);
        }
        else if (MP4HaveTrackAtom(fileHandle, _Id, "mdia.minf.stbl.stsd.alac")) {
            uint64_t channels_count = 0;
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.alac.channels", &channels_count);
            _channels = channels_count;
        }

        if (MP4HaveTrackAtom(fileHandle, _Id, "tref.fall")) {
            uint64_t fallbackId = 0;
            MP4GetTrackIntegerProperty(fileHandle, _Id, "tref.fall.entries.trackId", &fallbackId);
            _fallbackTrackId = (MP4TrackId) fallbackId;
        }
        
        if (MP4HaveTrackAtom(fileHandle, _Id, "tref.folw")) {
            uint64_t followsId = 0;
            MP4GetTrackIntegerProperty(fileHandle, _Id, "tref.folw.entries.trackId", &followsId);
            _followsTrackId = (MP4TrackId) followsId;
        }

    }

    return self;
}

- (instancetype)init
{
    if ((self = [super init]))
    {
        _name = [self defaultName];
        _language = @"Unknown";
        _volume = 1;
        _mixdownType = SBDolbyPlIIMixdown;
        _mediaType = MP42MediaTypeAudio;
    }

    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    MP42AudioTrack *copy = [super copyWithZone:zone];

    if (copy) {
        copy->_volume = _volume;
        copy->_channels = _channels;
        copy->_channelLayoutTag = _channelLayoutTag;

        copy->_fallbackTrackId = _fallbackTrackId;
        copy->_followsTrackId = _followsTrackId;

        copy->_mixdownType = [_mixdownType retain];
    }
    
    return copy;
}

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    if (_Id)
        [super writeToFile:fileHandle error:outError];

    if ([_updatedProperty valueForKey:@"volume"] || !_muxed)
        MP4SetTrackFloatProperty(fileHandle, _Id, "tkhd.volume", _volume);

    if ([_updatedProperty valueForKey:@"fallback"] || !_muxed) {
        if (_fallbackTrack)
            _fallbackTrackId = _fallbackTrack.Id;

        if (MP4HaveTrackAtom(fileHandle, _Id, "tref.fall") && (_fallbackTrackId == 0)) {
            MP4RemoveAllTrackReferences(fileHandle, "tref.fall", _Id);
        }
        else if (MP4HaveTrackAtom(fileHandle, _Id, "tref.fall") && (_fallbackTrackId)) {
            MP4SetTrackIntegerProperty(fileHandle, _Id, "tref.fall.entries.trackId", _fallbackTrackId);
        }
        else if (_fallbackTrackId)
            MP4AddTrackReference(fileHandle, "tref.fall", _fallbackTrackId, _Id);
    }
    
    if ([_updatedProperty valueForKey:@"follows"] || !_muxed) {
        if (_followsTrack)
            _followsTrackId = _followsTrack.Id;

        if (MP4HaveTrackAtom(fileHandle, _Id, "tref.folw") && (_followsTrackId == 0)) {
            MP4RemoveAllTrackReferences(fileHandle, "tref.folw", _Id);
        }
        else if (MP4HaveTrackAtom(fileHandle, _Id, "tref.folw") && (_followsTrackId)) {
            MP4SetTrackIntegerProperty(fileHandle, _Id, "tref.folw.entries.trackId", _followsTrackId);
        }
        else if (_followsTrackId)
            MP4AddTrackReference(fileHandle, "tref.folw", _followsTrackId, _Id);
    }

    return _Id;
}

- (NSString *)defaultName {
    return MP42MediaTypeAudio;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)setVolume:(float)newVolume
{
    _volume = newVolume;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"volume"];
}

- (float)volume
{
    return _volume;
}

- (void)setFallbackTrack:(MP42Track *)newFallbackTrack
{
    _fallbackTrack = newFallbackTrack;
    _fallbackTrackId = 0;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"fallback"];
}

- (MP42Track *)fallbackTrack
{
    return _fallbackTrack;
}

- (void)setFollowsTrack:(MP42Track *)newFollowsTrack
{
    _followsTrack = newFollowsTrack;
    _followsTrackId = 0;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"follows"];
}

- (MP42Track *)followsTrack
{
    return _followsTrack;
}

- (NSString *)formatSummary
{
    return [NSString stringWithFormat:@"%@, %u ch", _format, (unsigned int)_channels];
}

- (NSString *)description {
    return [[super description] stringByAppendingFormat:@", %u ch", (unsigned int)_channels];
}

@synthesize channels = _channels;
@synthesize sourceChannels = _sourceChannels;
@synthesize mixdownType = _mixdownType;
@synthesize channelLayoutTag = _channelLayoutTag;
@synthesize fallbackTrackId = _fallbackTrackId;
@synthesize followsTrackId = _followsTrackId;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeInt:1 forKey:@"MP42AudioTrackVersion"];

    [coder encodeFloat:_volume forKey:@"volume"];

    [coder encodeInt64:_channels forKey:@"channels"];
    [coder encodeInt64:_channelLayoutTag forKey:@"channelLayoutTag"];

    [coder encodeInt64:_fallbackTrackId forKey:@"fallbackTrackId"];

    [coder encodeObject:_mixdownType forKey:@"mixdownType"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    _volume = [decoder decodeFloatForKey:@"volume"];

    _channels = [decoder decodeInt64ForKey:@"channels"];
    _channelLayoutTag = [decoder decodeInt64ForKey:@"channelLayoutTag"];

    _fallbackTrackId = [decoder decodeInt64ForKey:@"fallbackTrackId"];

    _mixdownType = [[decoder decodeObjectForKey:@"mixdownType"] retain];

    return self;
}

@end
