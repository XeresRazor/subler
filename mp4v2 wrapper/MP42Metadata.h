//
//  MP42Metadata.h
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "mp4v2.h"

@interface MP42Metadata : NSObject <NSCoding, NSCopying> {
    NSString                *presetName;
    NSURL                   *sourceURL;
    NSMutableDictionary     *tagsDict;

    NSMutableArray          *artworks;
    
    NSArray                 *artworkThumbURLs;
    NSArray                 *artworkFullsizeURLs;
    NSArray                 *artworkProviderNames;
	
	NSString *ratingiTunesCode;

    uint8_t mediaKind;
    uint8_t contentRating;
    uint8_t hdVideo;
    uint8_t gapless;
    uint8_t podcast;
    BOOL isEdited;
    BOOL isArtworkEdited;
}

- (instancetype) initWithSourceURL:(NSURL *)URL fileHandle:(MP4FileHandle)fileHandle;
- (instancetype) initWithFileURL:(NSURL *)URL;

- (NSArray *) availableMetadata;
- (NSArray *) writableMetadata;

- (NSArray *) availableGenres;

- (void) removeTagForKey:(NSString *)aKey;
- (BOOL) setTag:(id)value forKey:(NSString *)key;
- (BOOL) setMediaKindFromString:(NSString *)mediaKindString;
- (BOOL) setContentRatingFromString:(NSString *)contentRatingString;
- (BOOL) setArtworkFromFilePath:(NSString *)imageFilePath;

- (BOOL) writeMetadataWithFileHandle: (MP4FileHandle *) fileHandle;

- (BOOL) mergeMetadata: (MP42Metadata *) newMetadata;

@property(readonly) NSMutableDictionary *tagsDict;

@property(readwrite, retain) NSString   *presetName;

@property(readwrite, retain) NSMutableArray *artworks;

@property(readwrite, retain) NSArray    *artworkThumbURLs;
@property(readwrite, retain) NSArray    *artworkFullsizeURLs;
@property(readwrite, retain) NSArray    *artworkProviderNames;

@property(readwrite) uint8_t    mediaKind;
@property(readwrite) uint8_t    contentRating;
@property(readwrite) uint8_t    hdVideo;
@property(readwrite) uint8_t    gapless;
@property(readwrite) uint8_t    podcast;
@property(readwrite) BOOL       isEdited;
@property(readwrite) BOOL       isArtworkEdited;

@end
