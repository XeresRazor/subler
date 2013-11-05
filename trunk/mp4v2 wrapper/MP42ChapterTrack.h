//
//  MP42ChapterTrack.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"
#import "MP42Image.h"

@class MP42TextSample;

@interface MP42ChapterTrack : MP42Track <NSCoding> {
    NSMutableArray *chapters;
    BOOL _areChaptersEdited;
}

- (instancetype)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle;
+ (instancetype)chapterTrackFromFile:(NSURL *)URL;

- (NSUInteger)addChapter:(NSString *)title duration:(uint64_t)timestamp;
- (NSUInteger)addChapter:(NSString *)title image:(MP42Image *)image duration:(uint64_t)timestamp;

- (void)removeChapterAtIndex:(NSUInteger)index;
- (void)removeChaptersAtIndexes:(NSIndexSet *)indexes;

- (NSUInteger)indexOfChapter:(MP42TextSample *)chapterSample;

- (void)setTimestamp:(MP4Duration)timestamp forChapter:(MP42TextSample *)chapterSample;
- (void)setTitle:(NSString*)title forChapter:(MP42TextSample *)chapterSample;

- (MP42TextSample *)chapterAtIndex:(NSUInteger)index;

- (NSInteger)chapterCount;

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error;

@property(nonatomic, readonly, retain) NSArray *chapters;

@end
