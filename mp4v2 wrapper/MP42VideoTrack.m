//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42VideoTrack.h"
#import "MP42MediaFormat.h"

@implementation MP42VideoTrack

- (id)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle])) {
        if ([self isMemberOfClass:[MP42VideoTrack class]]) {
            height = MP4GetTrackVideoHeight(fileHandle, _Id);
            width = MP4GetTrackVideoWidth(fileHandle, _Id);
        }

        _mediaType = MP42MediaTypeVideo;

        MP4GetTrackFloatProperty(fileHandle, _Id, "tkhd.width", &trackWidth);
        MP4GetTrackFloatProperty(fileHandle, _Id, "tkhd.height", &trackHeight);

        uint8_t *val;
        uint8_t nval[36];
        uint32_t *ptr32 = (uint32_t*) nval;
        uint32_t size;

        MP4GetTrackBytesProperty(fileHandle ,_Id, "tkhd.matrix", &val, &size);
        memcpy(nval, val, size);
        offsetX = CFSwapInt32BigToHost(ptr32[6]) / 0x10000;
        offsetY = CFSwapInt32BigToHost(ptr32[7]) / 0x10000;
        free(val);

        if (MP4HaveTrackAtom(fileHandle, _Id, "mdia.minf.stbl.stsd.*.pasp")) {
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", &hSpacing);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", &vSpacing);
        }
        else {
            hSpacing = 1;
            vSpacing = 1;
        }

        if (MP4HaveTrackAtom(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap")) {
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureWidthN", &cleanApertureWidthN);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureWidthD", &cleanApertureWidthD);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureHeightN", &cleanApertureHeightN);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureHeightD", &cleanApertureHeightD);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.horizOffN", &horizOffN);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.horizOffD", &horizOffD);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.vertOffN", &vertOffN);
            MP4GetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.vertOffD", &vertOffD);
        }

        if ([_format isEqualToString:MP42VideoFormatH264]) {
            MP4GetTrackH264ProfileLevel(fileHandle, trackID, &_origProfile, &_origLevel);
            _newProfile = _origProfile;
            _newLevel = _origLevel;
        }
    }

    return self;
}

- (id)init
{
    if ((self = [super init])) {
        _name = [self defaultName];
        _language = @"Unknown";
        _mediaType = MP42MediaTypeVideo;
    }

    return self;
}

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle)
        return NO;

    if (_Id) {
        [super writeToFile:fileHandle error:outError];

        if (trackWidth && trackHeight) {
            MP4SetTrackFloatProperty(fileHandle, _Id, "tkhd.width", trackWidth);

            MP4SetTrackFloatProperty(fileHandle, _Id, "tkhd.height", trackHeight);

            uint8_t *val;
            uint8_t nval[36];
            uint32_t *ptr32 = (uint32_t*) nval;
            uint32_t size;

            MP4GetTrackBytesProperty(fileHandle ,_Id, "tkhd.matrix", &val, &size);
            memcpy(nval, val, size);
            ptr32[6] = CFSwapInt32HostToBig(offsetX * 0x10000);
            ptr32[7] = CFSwapInt32HostToBig(offsetY * 0x10000);
            MP4SetTrackBytesProperty(fileHandle, _Id, "tkhd.matrix", nval, size);

            free(val);

            if ([_updatedProperty valueForKey:@"hSpacing"] || [_updatedProperty valueForKey:@"vSpacing"]) {
                if (hSpacing >= 1 && vSpacing >= 1) {
                    if (MP4HaveTrackAtom(fileHandle, _Id, "mdia.minf.stbl.stsd.*.pasp")) {
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", hSpacing);
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", vSpacing);
                    }
                    else
                        MP4AddPixelAspectRatio(fileHandle, _Id, hSpacing, vSpacing);
                }
            }

            if (cleanApertureWidthN >= 1 && cleanApertureHeightN >= 1) {
                    if (MP4HaveTrackAtom(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap")) {
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureWidthN", cleanApertureWidthN);
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureWidthD", cleanApertureWidthD);
                        
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureHeightN", cleanApertureHeightN);
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.cleanApertureHeightD", cleanApertureHeightD);
                        
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.horizOffN", horizOffN);
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.horizOffD", horizOffD);
                        
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.vertOffN", vertOffN);
                        MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*.clap.vertOffD", vertOffD);
                    }
                    else
                        MP4AddCleanAperture(fileHandle, _Id, cleanApertureWidthN, cleanApertureWidthD, cleanApertureHeightN, cleanApertureHeightD,
                                            horizOffN, horizOffD, vertOffN, vertOffD);
            }

            if ([_format isEqualToString:MP42VideoFormatH264]) {
                if ([_updatedProperty valueForKey:@"profile"]) {
                    MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*[0].avcC.AVCProfileIndication", _newProfile);
                    _origProfile = _newProfile;
                }
                if ([_updatedProperty valueForKey:@"level"]) {
                    MP4SetTrackIntegerProperty(fileHandle, _Id, "mdia.minf.stbl.stsd.*[0].avcC.AVCLevelIndication", _newLevel);
                    _origLevel = _newLevel;
                }
            }
        }
    }

    return _Id;
}

- (NSString *)defaultName {
    return MP42MediaTypeVideo;
}

- (void)dealloc
{
    [super dealloc];
}

@synthesize width;
@synthesize height;

@synthesize trackWidth;
@synthesize trackHeight;


- (uint64_t)hSpacing {
    return hSpacing;
}

- (void)setHSpacing:(uint64_t)newHSpacing
{
    hSpacing = newHSpacing;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"hSpacing"];
}

- (uint64_t)vSpacing {
    return vSpacing;
}

- (void)setVSpacing:(uint64_t)newVSpacing
{
    vSpacing = newVSpacing;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"vSpacing"];
}

@synthesize offsetX;
@synthesize offsetY;

@synthesize cleanApertureHeightD, cleanApertureHeightN, cleanApertureWidthD, cleanApertureWidthN;
@synthesize horizOffD, horizOffN, vertOffD, vertOffN;

@synthesize origProfile = _origProfile;
@synthesize origLevel = _origLevel;

- (uint8_t)newProfile {
    return _newProfile;
}

- (void)setNewProfile:(uint8_t)newProfile
{
    _newProfile = newProfile;
    _isEdited = YES;

    if (_newProfile == _origProfile)
        [_updatedProperty setValue:@"False" forKey:@"profile"];
    else
        [_updatedProperty setValue:@"True" forKey:@"profile"];
}

- (uint8_t)newLevel {
    return _newLevel;
}

- (void)setNewLevel:(uint8_t)newLevel
{
    _newLevel = newLevel;
    _isEdited = YES;

    if (_newLevel == _origLevel)
        [_updatedProperty setValue:@"False" forKey:@"level"];
    else
        [_updatedProperty setValue:@"True" forKey:@"level"];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeInt:1 forKey:@"MP42VideoTrackVersion"];

    [coder encodeInt64:width forKey:@"width"];
    [coder encodeInt64:height forKey:@"height"];

    [coder encodeFloat:trackWidth forKey:@"trackWidth"];
    [coder encodeFloat:trackHeight forKey:@"trackHeight"];

    [coder encodeInt64:hSpacing forKey:@"hSpacing"];
    [coder encodeInt64:vSpacing forKey:@"vSpacing"];

    [coder encodeInt32:offsetX forKey:@"offsetX"];
    [coder encodeInt32:offsetY forKey:@"offsetY"];

    [coder encodeInt:_origProfile forKey:@"origProfile"];
    [coder encodeInt:_origLevel forKey:@"origLevel"];

    [coder encodeInt:_newProfile forKey:@"newProfile"];
    [coder encodeInt:_newLevel forKey:@"newLevel"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    width = [decoder decodeInt64ForKey:@"width"];
    height = [decoder decodeInt64ForKey:@"height"];

    trackWidth = [decoder decodeFloatForKey:@"trackWidth"];
    trackHeight = [decoder decodeFloatForKey:@"trackHeight"];

    hSpacing = [decoder decodeInt64ForKey:@"hSpacing"];
    vSpacing = [decoder decodeInt64ForKey:@"vSpacing"];

    offsetX = [decoder decodeInt32ForKey:@"offsetX"];
    offsetY = [decoder decodeInt32ForKey:@"offsetY"];

    _origProfile = [decoder decodeInt32ForKey:@"origProfile"];
    _origLevel = [decoder decodeInt32ForKey:@"origLevel"];

    _newProfile = [decoder decodeInt32ForKey:@"newProfile"];
    _newLevel = [decoder decodeInt32ForKey:@"newLevel"];

    return self;
}

- (NSString *)description {
    return [[super description] stringByAppendingFormat:@", %lld x %lld", width, height];
}

@end
