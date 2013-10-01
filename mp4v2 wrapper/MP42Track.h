//
//  MP42Track.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42ConverterProtocol.h"
#import "mp4v2.h"

@class MP42FileImporter;
@class MP42SampleBuffer;
@class MP42Fifo;

typedef struct muxer_helper {
    // Input helpers
    MP42FileImporter *importer;
    id demuxer_context;

    // Output helpers
    id <MP42ConverterProtocol> converter;
    MP42Fifo *fifo;
    
    BOOL done;
} muxer_helper;

@interface MP42Track : NSObject <NSCoding, NSCopying> {
    MP4TrackId  _Id;
    MP4TrackId  _sourceId;

    NSURL       *_sourceURL;
    NSString    *_format;
    NSString    *_sourceFormat;
    NSString    *_mediaType;

    NSString    *_name;
    NSString    *_language;

    BOOL        _enabled;
    uint64_t    _alternate_group;
    int64_t     _startOffset;

    BOOL    _isEdited;
    BOOL    _muxed;
    BOOL    _needConversion;

    uint64_t    _size;
	uint32_t    _timescale;
	uint32_t    _bitrate;
	MP4Duration _duration;

    NSMutableDictionary *_updatedProperty;
    muxer_helper *_helper;
}

@property(nonatomic, readwrite) MP4TrackId Id;
@property(nonatomic, readwrite) MP4TrackId sourceId;

@property(nonatomic, readwrite, retain) NSURL *sourceURL;
@property(nonatomic, readwrite, retain) NSString *format;
@property(nonatomic, readwrite, retain) NSString *sourceFormat;
@property(nonatomic, readonly, retain) NSString *mediaType;

@property(nonatomic, readwrite, retain) NSString *name;
@property(nonatomic, readwrite, retain) NSString *language;

@property(nonatomic, readwrite) BOOL     enabled;
@property(nonatomic, readwrite) uint64_t alternate_group;
@property(nonatomic, readwrite) int64_t  startOffset;

@property(nonatomic, readonly)  uint32_t timescale;
@property(nonatomic, readonly)  uint32_t bitrate;
@property(nonatomic, readwrite) MP4Duration duration;

@property(nonatomic, readwrite) BOOL isEdited;
@property(nonatomic, readwrite) BOOL muxed;
@property(nonatomic, readwrite) BOOL needConversion;

@property(nonatomic, readwrite) uint64_t dataLength;

@property(nonatomic, readonly) muxer_helper *muxer_helper;

- (id)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle;

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError;

- (void)setTrackImporterHelper:(MP42FileImporter *)helper;
- (MP42SampleBuffer *)copyNextSample;

- (NSString *)timeString;
- (NSString *)formatSummary;

@end
