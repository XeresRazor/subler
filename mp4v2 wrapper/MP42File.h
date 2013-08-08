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

@interface MP42File : NSObject <NSCoding> {
@private
    MP4FileHandle  fileHandle;
    NSURL          *fileURL;
    id delegate;

    NSMutableArray  *tracksToBeDeleted;
    NSMutableArray  *fileImporters;
    BOOL             hasFileRepresentation;
    BOOL             isCancelled;
    BOOL             operationIsRunning;

    uint64_t _size;
@protected
    NSMutableArray  *tracks;
    MP42Metadata    *metadata;
    MP42Muxer       *muxer;
}

@property (readwrite, assign) id delegate;
@property (readonly) NSURL  *URL;
@property (readonly) NSMutableArray  *tracks;
@property (readonly) MP42Metadata    *metadata;
@property (readonly) BOOL hasFileRepresentation;
@property (atomic, readwrite) BOOL operationIsRunning;

- (id)   initWithDelegate:(id)del;
- (id)   initWithExistingFile:(NSURL *)URL andDelegate:(id)del;

- (NSUInteger) movieDuration;
- (MP42ChapterTrack*) chapters;

- (NSUInteger) tracksCount;
- (id)   trackAtIndex:(NSUInteger)index;

- (void) addTrack:(id)object;

- (void) removeTrackAtIndex:(NSUInteger)index;
- (void) removeTracksAtIndexes:(NSIndexSet *)indexes;
- (void) moveTrackAtIndex:(NSUInteger)index toIndex:(NSUInteger)newIndex;

- (uint64_t)estimatedDataLength;

- (void) iTunesFriendlyTrackGroups;

- (BOOL) writeToUrl:(NSURL *)url withAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL) updateMP4FileWithAttributes:(NSDictionary *)attributes error:(NSError **)outError;
- (BOOL) optimize;

- (void) cancel;

@end

@interface NSObject (MP42FileDelegateMethod)
- (void)progressStatus: (CGFloat)progress;
- (void)endSave:(id)sender;

@end
