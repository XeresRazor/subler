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
#import "SBLanguages.h"

@implementation MP42Track

-(id)init
{
    if ((self = [super init]))
    {
        enabled = YES;
        updatedProperty = [[NSMutableDictionary alloc] init];
        name = @"Unknown Track";
    }
    return self;
}

-(id)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
	if ((self = [super init]))
	{
		sourceURL = [URL retain];
		Id = trackID;
        isEdited = NO;
        muxed = YES;
        updatedProperty = [[NSMutableDictionary alloc] init];

        if (fileHandle) {
            format = [getHumanReadableTrackMediaDataName(fileHandle, Id) retain];
            name = [getTrackName(fileHandle, Id) retain];
            language = [getHumanReadableTrackLanguage(fileHandle, Id) retain];
            bitrate = MP4GetTrackBitRate(fileHandle, Id);
            duration = MP4ConvertFromTrackDuration(fileHandle, Id,
                                                   MP4GetTrackDuration(fileHandle, Id),
                                                   MP4_MSECS_TIME_SCALE);
            timescale = MP4GetTrackTimeScale(fileHandle, Id);
            startOffset = getTrackStartOffset(fileHandle, Id);

            _size = getTrackSize(fileHandle, Id);

            uint64_t temp;
            MP4GetTrackIntegerProperty(fileHandle, Id, "tkhd.flags", &temp);
            if (temp & TRACK_ENABLED) enabled = YES;
            else enabled = NO;
            MP4GetTrackIntegerProperty(fileHandle, Id, "tkhd.alternate_group", &alternate_group);
        }
	}

    return self;
}

- (BOOL) writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    BOOL success = YES;
    if (!fileHandle || !Id) {
        if ( outError != NULL) {
            *outError = MP42Error(@"Failed to modify track",
                                  nil,
                                  120);
            return NO;

        }
    }

    if ([updatedProperty valueForKey:@"name"]  || !muxed)
        if (![name isEqualToString:@"Video Track"] &&
            ![name isEqualToString:@"Sound Track"] &&
            ![name isEqualToString:@"Subtitle Track"] &&
            ![name isEqualToString:@"Text Track"] &&
            ![name isEqualToString:@"Chapter Track"] &&
            ![name isEqualToString:@"Unknown Track"] &&
            name != nil) {
            const char* cString = [name cStringUsingEncoding: NSMacOSRomanStringEncoding];
            if (cString)
                MP4SetTrackName(fileHandle, Id, cString);
        }
    if ([updatedProperty valueForKey:@"alternate_group"] || !muxed)
        MP4SetTrackIntegerProperty(fileHandle, Id, "tkhd.alternate_group", alternate_group);
    if ([updatedProperty valueForKey:@"start_offset"])
        setTrackStartOffset(fileHandle, Id, startOffset);
    if ([updatedProperty valueForKey:@"language"] || !muxed)
        MP4SetTrackLanguage(fileHandle, Id, lang_for_english([language UTF8String])->iso639_2);
    if ([updatedProperty valueForKey:@"enabled"] || !muxed) {
        if (enabled) enableTrack(fileHandle, Id);
        else disableTrack(fileHandle, Id);
    }

    return success;
}

- (void) dealloc
{
    if (_helper) {
        if (_helper->demuxer_context)
            [_helper->demuxer_context release];
        if (_helper->converter)
            [_helper->converter release];
        
        free(_helper);
    }

    [updatedProperty release];
    [format release];
    [sourceURL release];
    [name release];
    [language release];
    [sourceFileHandle release];
    [super dealloc];
}

- (NSString *) timeString
{
        return SMPTEStringFromTime(duration, 1000);
}

@synthesize sourceURL;
@synthesize Id;
@synthesize sourceId;
@synthesize sourceFileHandle;

@synthesize format;
@synthesize sourceFormat;
@synthesize name;

- (NSString *) name {
    return name;
}

- (void) setName: (NSString *) newName
{
    [name autorelease];
    name = [newName retain];
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"name"];
}

- (NSString *) language {
    return language;
}

- (void) setLanguage: (NSString *) newLang
{
    [language autorelease];
    language = [newLang retain];
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"language"];
}

- (BOOL) enabled {
    return enabled;
}

- (void) setEnabled: (BOOL) newState
{
    enabled = newState;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"enabled"];
}

- (uint64_t) alternate_group {
    return alternate_group;
}

- (void) setAlternate_group: (uint64_t) newGroup
{
    alternate_group = newGroup;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"alternate_group"];
}

- (int64_t) startOffset {
    return startOffset;
}

- (void) setStartOffset:(int64_t)newOffset
{
    startOffset = newOffset;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"start_offset"];
}

- (NSString *) formatSummary
{
    return [[format retain] autorelease];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:2 forKey:@"MP42TrackVersion"];

    [coder encodeInt64:Id forKey:@"Id"];
    [coder encodeInt64:sourceId forKey:@"sourceId"];

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
    [coder encodeObject:sourceURL forKey:@"sourceURL"];
#endif

    [coder encodeObject:sourceFormat forKey:@"sourceFormat"];
    [coder encodeObject:format forKey:@"format"];
    [coder encodeObject:name forKey:@"name"];
    [coder encodeObject:language forKey:@"language"];

    [coder encodeBool:enabled forKey:@"enabled"];

    [coder encodeInt64:alternate_group forKey:@"alternate_group"];
    [coder encodeInt64:startOffset forKey:@"startOffset"];

    [coder encodeBool:isEdited forKey:@"isEdited"];
    [coder encodeBool:muxed forKey:@"muxed"];
    [coder encodeBool:needConversion forKey:@"needConversion"];

    [coder encodeInt32:timescale forKey:@"timescale"];
    [coder encodeInt32:bitrate forKey:@"bitrate"];
    [coder encodeInt64:duration forKey:@"duration"];
    
    [coder encodeInt64:_size forKey:@"dataLength"];

    [coder encodeObject:updatedProperty forKey:@"updatedProperty"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    NSInteger version = [decoder decodeInt32ForKey:@"MP42TrackVersion"];

    Id = [decoder decodeInt64ForKey:@"Id"];
    sourceId = [decoder decodeInt64ForKey:@"sourceId"];

    NSData *bookmarkData = [decoder decodeObjectForKey:@"bookmark"];
    if (bookmarkData) {
        BOOL bookmarkDataIsStale;
        NSError *error;
        sourceURL = [[NSURL
                    URLByResolvingBookmarkData:bookmarkData
                    options:NSURLBookmarkResolutionWithSecurityScope
                    relativeToURL:nil
                    bookmarkDataIsStale:&bookmarkDataIsStale
                    error:&error] retain];
    }
    else {
        sourceURL = [[decoder decodeObjectForKey:@"sourceURL"] retain];
    }

    sourceFormat = [[decoder decodeObjectForKey:@"sourceFormat"] retain];
    format = [[decoder decodeObjectForKey:@"format"] retain];
    name = [[decoder decodeObjectForKey:@"name"] retain];
    language = [[decoder decodeObjectForKey:@"language"] retain];

    enabled = [decoder decodeBoolForKey:@"enabled"];

    alternate_group = [decoder decodeInt64ForKey:@"alternate_group"];
    startOffset = [decoder decodeInt64ForKey:@"startOffset"];

    isEdited = [decoder decodeBoolForKey:@"isEdited"];
    muxed = [decoder decodeBoolForKey:@"muxed"];
    needConversion = [decoder decodeBoolForKey:@"needConversion"];

    timescale = [decoder decodeInt32ForKey:@"timescale"];
    bitrate = [decoder decodeInt32ForKey:@"bitrate"];
    duration = [decoder decodeInt64ForKey:@"duration"];
    
    if (version == 2)
        _size = [decoder decodeInt64ForKey:@"dataLength"];

    updatedProperty = [[decoder decodeObjectForKey:@"updatedProperty"] retain];

    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Track: %d, %@, %@, %llu kbit/s, %@", [self Id], [self name], [self timeString], [self dataLength] / [self duration] * 8, [self format]];
}

@synthesize timescale;
@synthesize bitrate;
@synthesize duration;
@synthesize isEdited;
@synthesize muxed;
@synthesize needConversion;

@synthesize updatedProperty;

@synthesize dataLength = _size;;

@synthesize muxer_helper = _helper;

- (muxer_helper*)muxer_helper
{
    if (_helper == NULL)
        _helper = calloc(1, sizeof(muxer_helper));

    return _helper;
}

- (void)setTrackImporterHelper:(MP42FileImporter *)importer
{
    if (_helper == NULL)
        _helper = calloc(1, sizeof(muxer_helper));
    
    _helper->importer = importer;
}

- (MP42SampleBuffer*)copyNextSample {
    __block MP42SampleBuffer *sample = nil;

    if (_helper->converter) {
        while ([_helper->converter needMoreSample] && [_helper->fifo count]) {
            dispatch_sync(_helper->queue, ^{
                sample = [_helper->fifo objectAtIndex:0];
                [sample retain];
                [_helper->fifo removeObjectAtIndex:0];
            });

            [_helper->converter addSample:sample];
            [sample release];
        }

        if (![_helper->fifo count] && [_helper->importer done])
            [_helper->converter setDone:YES];

        if ([_helper->converter encoderDone])
            _helper->done = YES;

        sample = [_helper->converter copyEncodedSample];
        return sample;
    }
    else {
        if ([_helper->importer done] && ![_helper->fifo count])
            _helper->done = YES;

        if ([_helper->fifo count]) {
            dispatch_sync(_helper->queue, ^{
                sample = [_helper->fifo objectAtIndex:0];
                [sample retain];
                [_helper->fifo removeObjectAtIndex:0];
            });
        }
    }

    return sample;
}

@end
