//
//  SBQueueItem.h
//  Subler
//
//  Created by Damiano Galassi on 16/08/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MP42File;

enum {
    SBQueueItemtatusUnknown = 0,
    SBQueueItemStatusReady,
    SBQueueItemStatusWorking,
    SBQueueItemStatusCompleted,
    SBQueueItemStatusFailed,
    SBQueueItemStatusCancelled,
};
typedef NSInteger SBQueueItemStatus;


@interface SBQueueItem : NSObject <NSCoding> {
    MP42File *mp4File;
    NSURL   *fileURL;
    NSURL   *destURL;
    NSDictionary *attributes;

    SBQueueItemStatus status;
    BOOL humanEdited;
}

@property (atomic, readonly) NSDictionary *attributes;
@property (atomic, readonly) NSURL *URL;
@property (atomic, readonly) NSURL *destURL;
@property (atomic, readonly) MP42File *mp4File;
@property (atomic, readwrite) SBQueueItemStatus status;

- (id)initWithURL:(NSURL*)URL;
+ (id)itemWithURL:(NSURL*)URL;

- (id)initWithMP4:(MP42File*)MP4;
- (id)initWithMP4:(MP42File*)MP4 url:(NSURL*)URL attributes:(NSDictionary*)dict;

+ (id)itemWithMP4:(MP42File*)MP4;
+ (id)itemWithMP4:(MP42File*)MP4 url:(NSURL*)URL attributes:(NSDictionary*)dict;

@end
