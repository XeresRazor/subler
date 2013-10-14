//
//  MP42ChapterTrack.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@class SBTextSample;

@interface MP42ChapterTrack : MP42Track <NSCoding> {
    NSMutableArray *chapters;
}
- (instancetype)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle;
+ (instancetype)chapterTrackFromFile:(NSURL *)URL;

- (void)addChapter:(NSString *)title duration:(uint64_t)timestamp;
- (void)removeChapterAtIndex:(NSUInteger)index;

- (void)setTimestamp:(MP4Duration)timestamp forChapter:(SBTextSample *)chapterSample;
- (void)setTitle:(NSString*)title forChapter:(SBTextSample *)chapterSample;

- (SBTextSample *)chapterAtIndex:(NSUInteger)index;

- (NSInteger)chapterCount;

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error;

@property(nonatomic, readonly, retain) NSArray *chapters;

@end
