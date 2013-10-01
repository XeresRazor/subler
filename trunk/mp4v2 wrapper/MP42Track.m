//
//  MP42Track.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42Track.h"
#import "MP42Utilities.h"
#import "MP42FileImporter.h"
#import "MP42Sample.h"
#import "MP42Fifo.h"
#import "SBLanguages.h"

@implementation MP42Track

- (id)init
{
    if ((self = [super init])) {
        _enabled = YES;
        _updatedProperty = [[NSMutableDictionary alloc] init];
        _name = @"Unknown Track";
    }
    return self;
}

- (id)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
	if ((self = [super init])) {
		_sourceURL = [URL retain];
		_Id = trackID;
        _isEdited = NO;
        _muxed = YES;
        _updatedProperty = [[NSMutableDictionary alloc] init];

        if (fileHandle) {
            _format = [getHumanReadableTrackMediaDataName(fileHandle, _Id) retain];
            _name = [getTrackName(fileHandle, _Id) retain];
            _language = [getHumanReadableTrackLanguage(fileHandle, _Id) retain];
            _bitrate = MP4GetTrackBitRate(fileHandle, _Id);
            _duration = MP4ConvertFromTrackDuration(fileHandle, _Id,
                                                   MP4GetTrackDuration(fileHandle, _Id),
                                                   MP4_MSECS_TIME_SCALE);
            _timescale = MP4GetTrackTimeScale(fileHandle, _Id);
            _startOffset = getTrackStartOffset(fileHandle, _Id);

            _size = getTrackSize(fileHandle, _Id);

            uint64_t temp;
            MP4GetTrackIntegerProperty(fileHandle, _Id, "tkhd.flags", &temp);
            if (temp & TRACK_ENABLED) _enabled = YES;
            else _enabled = NO;
            MP4GetTrackIntegerProperty(fileHandle, _Id, "tkhd.alternate_group", &_alternate_group);
        }
	}

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MP42Track *copy = [[[self class] alloc] init];

    if (copy) {
        copy->_Id = _Id;
        copy->_sourceId = _sourceId;

        copy->_sourceURL = [_sourceURL retain];
        copy->_sourceFormat = [_sourceFormat retain];
        copy->_format = [_format retain];
        copy->_name = [_name retain];
        copy->_language = [_language retain];
        copy->_enabled = _enabled;
        copy->_alternate_group = _alternate_group;
        copy->_startOffset = _startOffset;

        copy->_size = _size;

        copy->_timescale = _timescale;
        copy->_bitrate = _bitrate;
        copy->_duration = _duration;

        [copy->_updatedProperty release];
        copy->_updatedProperty = [_updatedProperty mutableCopy];

        if (_helper) {
            copy->_helper = calloc(1, sizeof(muxer_helper));
            copy->_helper->importer = _helper->importer;
        }
    }

    return copy;
}

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    BOOL success = YES;
    if (!fileHandle || !_Id) {
        if ( outError != NULL) {
            *outError = MP42Error(@"Failed to modify track",
                                  nil,
                                  120);
            return NO;

        }
    }

    if ([_updatedProperty valueForKey:@"name"] || !_muxed) {
        if (![_name isEqualToString:@"Video Track"] &&
            ![_name isEqualToString:@"Sound Track"] &&
            ![_name isEqualToString:@"Subtitle Track"] &&
            ![_name isEqualToString:@"Text Track"] &&
            ![_name isEqualToString:@"Chapter Track"] &&
            ![_name isEqualToString:@"Closed Caption Track"] &&
            ![_name isEqualToString:@"Unknown Track"] &&
            _name != nil) {
            const char* cString = [_name cStringUsingEncoding: NSMacOSRomanStringEncoding];
            if (cString)
                MP4SetTrackName(fileHandle, _Id, cString);
        }
        else
            MP4SetTrackName(fileHandle, _Id, "\0");
    }
    if ([_updatedProperty valueForKey:@"alternate_group"] || !_muxed)
        MP4SetTrackIntegerProperty(fileHandle, _Id, "tkhd.alternate_group", _alternate_group);
    if ([_updatedProperty valueForKey:@"start_offset"])
        setTrackStartOffset(fileHandle, _Id, _startOffset);
    if ([_updatedProperty valueForKey:@"language"] || !_muxed)
        MP4SetTrackLanguage(fileHandle, _Id, lang_for_english([_language UTF8String])->iso639_2);
    if ([_updatedProperty valueForKey:@"enabled"] || !_muxed) {
        if (_enabled) enableTrack(fileHandle, _Id);
        else disableTrack(fileHandle, _Id);
    }

    return success;
}

- (NSString *)timeString
{
    return SMPTEStringFromTime(_duration, 1000);
}

@synthesize sourceURL = _sourceURL;
@synthesize Id = _Id;
@synthesize sourceId = _sourceId;

@synthesize format = _format;
@synthesize sourceFormat = _sourceFormat;
@synthesize name = _name;

- (NSString *)name {
    return [[_name retain] autorelease];
}

- (NSString *)defaultName {
    return @"Unknown Track";
}

- (void)setName:(NSString *)newName
{
    [_name autorelease];
    if ([newName length])
        _name = [newName retain];
    else
        _name = [self defaultName];
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"name"];
}

- (NSString *)language {
    return [[_language retain] autorelease];
}

- (void)setLanguage:(NSString *)newLang
{
    [_language autorelease];
    _language = [newLang retain];
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"language"];
}

- (BOOL)enabled {
    return _enabled;
}

- (void)setEnabled:(BOOL)newState
{
    _enabled = newState;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"enabled"];
}

- (uint64_t)alternate_group {
    return _alternate_group;
}

- (void)setAlternate_group:(uint64_t)newGroup
{
    _alternate_group = newGroup;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"alternate_group"];
}

- (int64_t)startOffset {
    return _startOffset;
}

- (void)setStartOffset:(int64_t)newOffset
{
    _startOffset = newOffset;
    _isEdited = YES;
    [_updatedProperty setValue:@"True" forKey:@"start_offset"];
}

- (NSString *)formatSummary
{
    return [[_format retain] autorelease];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:2 forKey:@"MP42TrackVersion"];

    [coder encodeInt64:_Id forKey:@"Id"];
    [coder encodeInt64:_sourceId forKey:@"sourceId"];

#ifdef SB_SANDBOX
    if ([sourceURL respondsToSelector:@selector(startAccessingSecurityScopedResource)]) {
        NSData *bookmarkData = nil;
        NSError *error = nil;
        bookmarkData = [sourceURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                         includingResourceValuesForKeys:nil
                                          relativeToURL:nil // Make it app-scoped
                                                  error:&error];
        if (error) {
            NSLog(@"Error creating bookmark for URL (%@): %@", sourceURL, error);
        }
        
        [coder encodeObject:bookmarkData forKey:@"bookmark"];
    }
    else {
        [coder encodeObject:sourceURL forKey:@"sourceURL"];
    }
#else
    [coder encodeObject:_sourceURL forKey:@"sourceURL"];
#endif

    [coder encodeObject:_sourceFormat forKey:@"sourceFormat"];
    [coder encodeObject:_format forKey:@"format"];
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_language forKey:@"language"];

    [coder encodeBool:_enabled forKey:@"enabled"];

    [coder encodeInt64:_alternate_group forKey:@"alternate_group"];
    [coder encodeInt64:_startOffset forKey:@"startOffset"];

    [coder encodeBool:_isEdited forKey:@"isEdited"];
    [coder encodeBool:_muxed forKey:@"muxed"];
    [coder encodeBool:_needConversion forKey:@"needConversion"];

    [coder encodeInt32:_timescale forKey:@"timescale"];
    [coder encodeInt32:_bitrate forKey:@"bitrate"];
    [coder encodeInt64:_duration forKey:@"duration"];
    
    [coder encodeInt64:_size forKey:@"dataLength"];

    [coder encodeObject:_updatedProperty forKey:@"updatedProperty"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    NSInteger version = [decoder decodeInt32ForKey:@"MP42TrackVersion"];

    _Id = [decoder decodeInt64ForKey:@"Id"];
    _sourceId = [decoder decodeInt64ForKey:@"sourceId"];

    NSData *bookmarkData = [decoder decodeObjectForKey:@"bookmark"];
    if (bookmarkData) {
        BOOL bookmarkDataIsStale;
        NSError *error;
        _sourceURL = [[NSURL
                    URLByResolvingBookmarkData:bookmarkData
                    options:NSURLBookmarkResolutionWithSecurityScope
                    relativeToURL:nil
                    bookmarkDataIsStale:&bookmarkDataIsStale
                    error:&error] retain];
    }
    else {
        _sourceURL = [[decoder decodeObjectForKey:@"sourceURL"] retain];
    }

    _sourceFormat = [[decoder decodeObjectForKey:@"sourceFormat"] retain];
    _format = [[decoder decodeObjectForKey:@"format"] retain];
    _name = [[decoder decodeObjectForKey:@"name"] retain];
    _language = [[decoder decodeObjectForKey:@"language"] retain];

    _enabled = [decoder decodeBoolForKey:@"enabled"];

    _alternate_group = [decoder decodeInt64ForKey:@"alternate_group"];
    _startOffset = [decoder decodeInt64ForKey:@"startOffset"];

    _isEdited = [decoder decodeBoolForKey:@"isEdited"];
    _muxed = [decoder decodeBoolForKey:@"muxed"];
    _needConversion = [decoder decodeBoolForKey:@"needConversion"];

    _timescale = [decoder decodeInt32ForKey:@"timescale"];
    _bitrate = [decoder decodeInt32ForKey:@"bitrate"];
    _duration = [decoder decodeInt64ForKey:@"duration"];
    
    if (version == 2)
        _size = [decoder decodeInt64ForKey:@"dataLength"];

    _updatedProperty = [[decoder decodeObjectForKey:@"updatedProperty"] retain];

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Track: %d, %@, %@, %llu kbit/s, %@", [self Id], [self name], [self timeString], [self dataLength] / [self duration] * 8, [self format]];
}

@synthesize timescale = _timescale;
@synthesize bitrate = _bitrate;
@synthesize duration = _duration;
@synthesize isEdited = _isEdited;
@synthesize muxed = _muxed;
@synthesize needConversion = _needConversion;
@synthesize dataLength = _size;
@synthesize mediaType = _mediaType;

@synthesize muxer_helper = _helper;

- (muxer_helper *)muxer_helper
{
    if (_helper == NULL)
        _helper = calloc(1, sizeof(muxer_helper));

    return _helper;
}

- (void)setTrackImporterHelper:(MP42FileImporter *)importer
{
    self.muxer_helper->importer = importer;
}

- (MP42SampleBuffer *)copyNextSample {
    MP42SampleBuffer *sample = nil;

    if (_helper->converter) {
        while ([_helper->converter needMoreSample] && [_helper->fifo count]) {
            sample = [_helper->fifo deque];
            [_helper->converter addSample:sample];
            [sample release];
        }

        if ([_helper->fifo isEmpty] && [_helper->importer done])
            [_helper->converter setInputDone];

        if ([_helper->converter encoderDone])
            _helper->done = YES;

        sample = [_helper->converter copyEncodedSample];
    }
    else {
        if ([_helper->fifo isEmpty] && [_helper->importer done])
            _helper->done = YES;

        if ([_helper->fifo count])
            sample = [_helper->fifo deque];
    }

    return sample;
}

- (void)dealloc
{
    free(_helper);
    
    [_updatedProperty release];
    [_format release];
    [_sourceURL release];
    [_name release];
    [_language release];
    [super dealloc];
}

@end
