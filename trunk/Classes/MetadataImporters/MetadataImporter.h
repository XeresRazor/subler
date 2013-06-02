//
//  MetadataImporter.h
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import <Foundation/Foundation.h>

@class MetadataSearchController;
@class MP42Metadata;

@interface MetadataImporter : NSObject {
    MetadataSearchController *mCallback;
    BOOL isCancelled;
}

#pragma mark Helper routines
+ (NSString *) urlEncoded:(NSString *)s;
+ (NSData *) downloadDataOrGetFromCache:(NSURL *)url;

#pragma mark Static methods
+ (NSArray *) languagesForProvider:(NSString *)aProvider;
+ (MetadataImporter *) importerForProvider:(NSString *)aProviderName;
+ (MetadataImporter *) defaultMovieProvider;
+ (MetadataImporter *) defaultTVProvider;
+ (NSString *) defaultMovieLanguage;
+ (NSString *) defaultTVLanguage;

#pragma mark Asynchronous searching
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage callback:(MetadataSearchController *)aCallback;
- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum callback:(MetadataSearchController *)aCallback;
- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage callback:(MetadataSearchController *)aCallback;
- (void) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage callback:(MetadataSearchController *)aCallback;
- (void) cancel;

#pragma Methods to be overridden
- (NSArray *) languages;
- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage;
- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum;
- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage;
- (MP42Metadata*) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage;

@end
