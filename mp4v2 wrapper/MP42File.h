//
//  MP42File.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "mp4v2.h"
#import "MP42Track.h"
#import "MP42VideoTrack.h"
#import "MP42AudioTrack.h"
#import "MP42SubtitleTrack.h"
#import "MP42ClosedCaptionTrack.h"
#import "MP42ChapterTrack.h"
#import "MP42Metadata.h"

#import "MP42Utilities.h"
#import "MP42MediaFormat.h"

@class MP42Muxer;

extern NSString * const MP42Create64BitData;
extern NSString * const MP42Create64BitTime;
extern NSString * const MP42CreateChaptersPreviewTrack;

@interface MP42File : NSObject <NSCoding> {
@private
    MP4FileHandle   _fileHandle;
    NSURL          *_fileURL;
    id              _delegate;

    NSMutableArray      *_tracksToBeDeleted;
    NSMutableDictionary *_importers;

    uint64_t    _size;
    BOOL        _hasFileRepresentation;
    BOOL        _cancelled;

@protected
    NSMutableArray  *_tracks;
    MP42Metadata    *_metadata;
    MP42Muxer       *_muxer;
}

@property(readwrite, assign) id delegate;

@property(readonly) NSURL *URL;
@property(readonly) MP42Metadata *metadata;
@property(readonly, copy) NSMutableArray *tracks;

@property(readonly) BOOL hasFileRepresentation;

- (id)initWithDelegate:(id)del;
- (id)initWithExistingFile:(NSURL *)URL andDelegate:(id)del;

- (NSUInteger)movieDuration;
- (MP42ChapterTrack *)chapters;

- (NSUInteger)tracksCount;
- (id)trackAtIndex:(NSUInteger)index;
- (id)trackWithTrackID:(NSUInteger)trackId;
- (NSArray *)tracksWithMediaType:(NSString *)mediaType;

- (void)addTrack:(MP42Track *)track;

- (void)removeTrackAtIndex:(NSUInteger)index;
- (void)removeTracksAtIndexes:(NSIndexSet *)indexes;
- (void)moveTrackAtIndex:(NSUInteger)index toIndex:(NSUInteger)newIndex;

- (uint64_t)estimatedDataLength;

- (void)iTunesFriendlyTrackGroups;

- (BOOL)writeToUrl:(NSURL *)url withAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL)updateMP4FileWithAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL)optimize;

- (void)cancel;

@end

@interface NSObject (MP42FileDelegateMethod)
- (void)progressStatus:(CGFloat)progress;
- (void)endSave:(id)sender;

@end
