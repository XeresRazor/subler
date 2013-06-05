//
//  TheMovieDB3.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import "TheMovieDB3.h"
#import "MP42Metadata.h"
#import "MetadataSearchController.h"
#import "JSONKit.h"
#import "iTunesStore.h"
#import "SBLanguages.h"

#define API_KEY @"b0073bafb08b4f68df101eb2325f27dc"

@implementation TheMovieDB3

- (NSArray *) languages {
	return [[SBLanguages defaultManager] languages];
}

- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage {
	NSString *lang = [SBLanguages iso6391CodeFor:aLanguage];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/search/movie?api_key=%@&query=%@&language=%@", API_KEY, [MetadataImporter urlEncoded:aMovieTitle], lang]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
		return [TheMovieDB3 metadataForResults:d];
	}
	return nil;
}

- (MP42Metadata*) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	NSString *lang = [SBLanguages iso6391CodeFor:aLanguage];
	NSNumber *theMovieDBID = [[aMetadata tagsDict] valueForKey:@"TheMovieDB ID"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/movie/%@?api_key=%@&language=%@&append_to_response=casts", theMovieDBID, API_KEY, lang]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
		MP42Metadata *r = [TheMovieDB3 metadataForResult:d];
		if (r) {
			[aMetadata mergeMetadata:r];
		}
	}
	return aMetadata;
}

#pragma mark Parse results

+ (NSString *) commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey {
	if (!aArray || ([aArray count] == 0)) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray arrayWithCapacity:[aArray count]];
	for (NSDictionary *d in aArray) {
		if ([d valueForKey:aKey]) {
			[r addObject:[d valueForKey:aKey]];
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (NSString *) commaJoinedSubentriesOf:(NSArray *)aArray forKey:(NSString *)aKey withKey:(NSString *)aWithKey equalTo:(NSString *)aEqualTo {
	if (!aArray || ([aArray count] == 0)) {
		return nil;
	}
	NSMutableArray *r = [NSMutableArray array];
	for (NSDictionary *d in aArray) {
		if ([d valueForKey:aKey]) {
			if ([d valueForKey:aWithKey] && [[d valueForKey:aWithKey] isEqualToString:aEqualTo]) {
				[r addObject:[d valueForKey:aKey]];
			}
		}
	}
	return [r componentsJoinedByString:@", "];
}

+ (MP42Metadata *) metadataForResult:(NSDictionary *)r {
	MP42Metadata *metadata = [[MP42Metadata alloc] init];
	metadata.mediaKind = 9; // movie
	[metadata setTag:[r valueForKey:@"id"] forKey:@"TheMovieDB ID"];
	[metadata setTag:[r valueForKey:@"title"] forKey:@"Name"];
	[metadata setTag:[r valueForKey:@"release_date"] forKey:@"Release Date"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[r valueForKey:@"genres"] forKey:@"name"] forKey:@"Genre"];
	[metadata setTag:[r valueForKey:@"overview"] forKey:@"Description"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[r valueForKey:@"production_companies"] forKey:@"name"] forKey:@"Studio"];
	NSDictionary *casts = [r valueForKey:@"casts"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"cast"] forKey:@"name"] forKey:@"Cast"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Director"] forKey:@"Director"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Producer"] forKey:@"Producers"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Executive Producer"] forKey:@"Executive Producer"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"department" equalTo:@"Writing"] forKey:@"Screenwriters"];
	[metadata setTag:[TheMovieDB3 commaJoinedSubentriesOf:[casts valueForKey:@"crew"] forKey:@"name" withKey:@"job" equalTo:@"Original Music Composer"] forKey:@"Composer"];
	// artwork
	NSMutableArray *artworkThumbURLs = [[NSMutableArray alloc] initWithCapacity:2];
	NSMutableArray *artworkFullsizeURLs = [[NSMutableArray alloc] initWithCapacity:1];
	NSMutableArray *artworkProviderNames = [[NSMutableArray alloc] initWithCapacity:1];
	// add iTunes artwork
	MP42Metadata *iTunesMetadata = [iTunesStore quickiTunesSearchMovie:[[metadata tagsDict] valueForKey:@"Name"]];
	if (iTunesMetadata && [iTunesMetadata artworkThumbURLs] && [iTunesMetadata artworkFullsizeURLs] && ([[iTunesMetadata artworkThumbURLs] count] == [[iTunesMetadata artworkFullsizeURLs] count])) {
		[artworkThumbURLs addObjectsFromArray:[iTunesMetadata artworkThumbURLs]];
		[artworkFullsizeURLs addObjectsFromArray:[iTunesMetadata artworkFullsizeURLs]];
		[artworkProviderNames addObjectsFromArray:[iTunesMetadata artworkProviderNames]];
	}
	// load image variables from configuration
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://api.themoviedb.org/3/configuration?api_key=%@", API_KEY]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *config = [jsonDecoder objectWithData:jsonData];
		if ([config valueForKey:@"images"]) {
			NSString *imageBaseUrl = [[config valueForKey:@"images"] valueForKey:@"secure_base_url"];
			NSString *posterThumbnailSize = [[[config valueForKey:@"images"] valueForKey:@"poster_sizes"] objectAtIndex:0];
			NSString *backdropThumbnailSize = [[[config valueForKey:@"images"] valueForKey:@"backdrop_sizes"] objectAtIndex:0];
			if ([r valueForKey:@"poster_path"] && ([r valueForKey:@"backdrop_path"] != [NSNull null])) {
				[artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, posterThumbnailSize, [r valueForKey:@"poster_path"]]]];
				[artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", [r valueForKey:@"poster_path"]]]];
				[artworkProviderNames addObject:@"TheMovieDB|poster"];
			}
			if ([r valueForKey:@"backdrop_path"] && ([r valueForKey:@"backdrop_path"] != [NSNull null])) {
				[artworkThumbURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, backdropThumbnailSize, [r valueForKey:@"backdrop_path"]]]];
				[artworkFullsizeURLs addObject:[NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", imageBaseUrl, @"original", [r valueForKey:@"backdrop_path"]]]];
				[artworkProviderNames addObject:@"TheMovieDB|backdrop"];
			}
		}
	}
	[metadata setArtworkThumbURLs:artworkThumbURLs];
	[metadata setArtworkFullsizeURLs:artworkFullsizeURLs];
	[metadata setArtworkProviderNames:artworkProviderNames];
	[artworkThumbURLs release];
	[artworkFullsizeURLs release];
	[artworkProviderNames release];
    return [metadata autorelease];
}

+ (NSArray *) metadataForResults:(NSDictionary *)dict {
	NSArray *resultsArray = [dict valueForKey:@"results"];
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:[resultsArray count]];
	for (NSDictionary *r in resultsArray) {
        MP42Metadata *metadata = [TheMovieDB3 metadataForResult:r];
        [returnArray addObject:metadata];
	}
    return [returnArray autorelease];
}

@end
