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
#import "MP42Muxer.h"

extern NSString * const MP42Create64BitData;
extern NSString * const MP42Create64BitTime;
extern NSString * const MP42CreateChaptersPreviewTrack;
extern NSString * const MP42OrganizeAlternateGroups;

@protocol MP42FileDelegate
@optional
- (void)progressStatus:(CGFloat)progress;
- (void)endSave:(id)sender;
@end

@interface MP42File : NSObject <NSCoding, MP42MuxerDelegate> {
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

@property(readwrite, assign) id <MP42FileDelegate> delegate;

@property(readonly) NSURL *URL;
@property(readonly) MP42Metadata *metadata;
@property(readonly, copy) NSArray *tracks;

@property(readonly) BOOL hasFileRepresentation;

- (instancetype)initWithDelegate:(id <MP42FileDelegate>)del;
- (instancetype)initWithExistingFile:(NSURL *)URL andDelegate:(id <MP42FileDelegate>)del;

- (NSUInteger)movieDuration;
- (MP42ChapterTrack *)chapters;

- (NSUInteger)tracksCount;
- (MP42Track *)trackAtIndex:(NSUInteger)index;
- (MP42Track *)trackWithTrackID:(NSUInteger)trackId;
- (NSArray *)tracksWithMediaType:(NSString *)mediaType;

- (void)addTrack:(MP42Track *)track;

- (void)removeTrackAtIndex:(NSUInteger)index;
- (void)removeTracksAtIndexes:(NSIndexSet *)indexes;
- (void)moveTrackAtIndex:(NSUInteger)index toIndex:(NSUInteger)newIndex;

- (uint64_t)estimatedDataLength;

- (void)organizeAlternateGroups;

- (BOOL)writeToUrl:(NSURL *)url withAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL)updateMP4FileWithAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL)optimize;

- (void)cancel;

@end
