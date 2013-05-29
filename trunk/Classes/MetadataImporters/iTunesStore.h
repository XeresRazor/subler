//
//  iTunesStore.h
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MetadataSearchController;
@class MP42Metadata;

@interface iTunesStore : NSObject {
    MetadataSearchController *mCallback;
    BOOL isCancelled;
}

+ (NSArray *) languages;

#pragma mark Search for TV episode metadata
- (NSArray*) searchForResults:(NSString *)aSeriesName seriesLanguage:(NSString *)aSeriesLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)episodeNum;
- (void) searchForResults:(NSString *)aSeriesName seriesLanguage:(NSString *)aSeriesLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum callback:(MetadataSearchController *)aCallback;

#pragma mark Search for movie metadata
- (NSArray*) searchForResults:(NSString *)movieTitle movieLanguage:(NSString *)aMovieLanguage;
- (void) searchForResults:(NSString *)movieTitle movieLanguage:(NSString *)aMovieLanguage callback:(MetadataSearchController *)aCallback;
- (MP42Metadata*) loadAdditionalMetadata:(MP42Metadata *)metadata movieLanguage:(NSString *)aMovieLanguage;
- (void) loadAdditionalMetadata:(MP42Metadata *)metadata movieLanguage:(NSString *)aMovieLanguage callback:(MetadataSearchController *)callback;

#pragma mark Parse results
- (NSArray *) metadataForResults:(NSDictionary *)dict store:(NSDictionary *)store;

- (void) cancel;

@end
