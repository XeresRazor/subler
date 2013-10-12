//
//  iTunesStore.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "iTunesStore.h"
#import "SBMetadataSearchController.h"
#import "MP42File.h"
#import "JSONKit.h"
#import "SBRatings.h"

@implementation iTunesStore

#pragma mark iTunes stores

- (NSArray *) languages {
	NSString* iTunesStoresJSON = [[NSBundle mainBundle] pathForResource:@"iTunesStores" ofType:@"json"];
	JSONDecoder *jsonDecoder = [JSONDecoder decoder];
	NSArray *iTunesStores = [jsonDecoder objectWithData:[NSData dataWithContentsOfFile:iTunesStoresJSON]];
	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:[iTunesStores count]];
	for (NSDictionary *store in iTunesStores) {
		[results addObject:[NSString stringWithFormat:@"%@ (%@)", [store valueForKey:@"country"], [store valueForKey:@"language"]]];
	}
	return [results autorelease];
}

+ (NSDictionary *) getStoreFor:(NSString *)aLanguageString {
	NSString* iTunesStoresJSON = [[NSBundle mainBundle] pathForResource:@"iTunesStores" ofType:@"json"];
	JSONDecoder *jsonDecoder = [JSONDecoder decoder];
	NSArray *iTunesStores = [jsonDecoder objectWithData:[NSData dataWithContentsOfFile:iTunesStoresJSON]];
	for (NSDictionary *store in iTunesStores) {
		if (aLanguageString && [aLanguageString isEqualToString:[NSString stringWithFormat:@"%@ (%@)", [store valueForKey:@"country"], [store valueForKey:@"language"]]]) {
			return store;
		}
	}
	return nil;
}

#pragma mark Search for TV episode metadata

NSInteger sortMP42Metadata(id ep1, id ep2, void *context)
{
    int v1 = [[[((MP42Metadata *) ep1) tagsDict] valueForKey:@"TV Episode #"] intValue];
    int v2 = [[[((MP42Metadata *) ep2) tagsDict] valueForKey:@"TV Episode #"] intValue];

    int s1 = [[[((MP42Metadata *) ep1) tagsDict] valueForKey:@"TV Season"] intValue];
    int s2 = [[[((MP42Metadata *) ep2) tagsDict] valueForKey:@"TV Season"] intValue];

    if (s1 == s2) {
        if (v1 < v2)
            return NSOrderedAscending;
        else if (v1 > v2)
            return NSOrderedDescending;
    }

    if (s1 < s2)
        return NSOrderedAscending;
    else if (s1 > s2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
}

- (NSArray *)filterResult:(NSArray *)results tvSeries:(NSString *)aSeriesName seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
    NSMutableArray *r = [[NSMutableArray alloc] init];
    for (MP42Metadata *m in results) {
        if (!aSeriesName || [[[m tagsDict] valueForKey:@"TV Show"] isEqualToString:aSeriesName]) {
            // Episode Number and Season Number
            if ((aEpisodeNum && [aEpisodeNum length]) && (aSeasonNum && [aSeasonNum length])) {
                if ([[[[m tagsDict] valueForKey:@"TV Episode #"] stringValue] isEqualToString:aEpisodeNum] &&
                    [[[m tagsDict] valueForKey:@"TV Season"] integerValue] == [aSeasonNum integerValue]) {
                    [r addObject:m];
                }

            }
            // Episode Number only
            else if ((aEpisodeNum && [aEpisodeNum length]) && !(aSeasonNum && [aSeasonNum length])) {
                if ([[[[m tagsDict] valueForKey:@"TV Episode #"] stringValue] isEqualToString:aEpisodeNum]) {
                    [r addObject:m];
                }

            }
            // Season Number only
            else if (!(aEpisodeNum && [aEpisodeNum length]) && (aSeasonNum && [aSeasonNum length])) {
                if ([[[m tagsDict] valueForKey:@"TV Season"] integerValue] == [aSeasonNum integerValue]) {
                    [r addObject:m];
                }
            }
            else if (!(aEpisodeNum && [aEpisodeNum length]) && !(aSeasonNum && [aSeasonNum length])) {
                [r addObject:m];
            }
        }
    }
    return [r autorelease];
}

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum
{
	NSString *country = @"US";
	NSString *language = @"EN";
	NSString *season = @"season";
	NSDictionary *store = [iTunesStore getStoreFor:aLanguage];
	if (store) {
		country = [store valueForKey:@"country2"];
		language = [store valueForKey:@"language2"];
		if ([store valueForKey:@"season"] && ![[store valueForKey:@"season"] isEqualToString:@""]) {
			season = [[store valueForKey:@"season"] lowercaseString];
		}
	}

	NSURL *url;
	if (aSeasonNum && [aSeasonNum length]) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&attribute=tvSeasonTerm&entity=tvEpisode&limit=200", country, [language lowercaseString], [MetadataImporter urlEncoded:[NSString stringWithFormat:@"%@ %@ %@", aSeriesName, season, aSeasonNum]]]];
	} else {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&attribute=showTerm&entity=tvEpisode&limit=200", country, [language lowercaseString], [MetadataImporter urlEncoded:aSeriesName]]];
	}
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *results = [iTunesStore metadataForResults:d store:store];
            if (([results count] == 0) && ![aLanguage isEqualToString:@"USA (English)"]) {
                return [self searchTVSeries:aSeriesName language:@"USA (English)" seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            }
            if (([results count] == 0) && aSeasonNum) {
                return [self searchTVSeries:aSeriesName language:@"USA (English)" seasonNum:nil episodeNum:aEpisodeNum];
            }

            // Filter results
            NSArray *r = [self filterResult:results tvSeries:aSeriesName seasonNum:aSeasonNum episodeNum:aEpisodeNum];

            // If we don't have any result for the exact series name, relax the filter
            if (![r count]) {
                r = [self filterResult:results tvSeries:nil seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            }

            NSArray *resultsSorted = [r sortedArrayUsingFunction:sortMP42Metadata context:NULL];
            return resultsSorted;
        }
	}
	return nil;
}

#pragma mark Quick iTunes search for metadata

+ (MP42Metadata *) quickiTunesSearchTV:(NSString *)aSeriesName episodeTitle:(NSString *)aEpisodeTitle {
	NSDictionary *store = [iTunesStore getStoreFor:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|iTunes Store|Language"]];
	if (!store) {
		return nil;
	}
	NSString *country = [store valueForKey:@"country2"];
	NSString *language = [store valueForKey:@"language2"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=tvEpisode", country, [language lowercaseString], [MetadataImporter urlEncoded:[NSString stringWithFormat:@"%@ %@", aSeriesName, aEpisodeTitle]]]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *results = [iTunesStore metadataForResults:d store:store];
            if ([results count] > 0) {
                return [results objectAtIndex:0];
            }
        }
	}
	return nil;
}

+ (MP42Metadata *) quickiTunesSearchMovie:(NSString *)aMovieName {
	NSDictionary *store = [iTunesStore getStoreFor:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie|iTunes Store|Language"]];
	if (!store) {
		return nil;
	}
	NSString *country = [store valueForKey:@"country2"];
	NSString *language = [store valueForKey:@"language2"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=movie", country, language, [MetadataImporter urlEncoded:aMovieName]]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *results = [iTunesStore metadataForResults:d store:store];
            if ([results count] > 0) {
                return [results objectAtIndex:0];
            }
        }
	}
	return nil;
}

#pragma mark Search for movie metadata

- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage
{
	NSString *country = @"US";
	NSString *language = @"EN";
	NSDictionary *store = [iTunesStore getStoreFor:aLanguage];
	if (store) {
		country = [store valueForKey:@"country2"];
		language = [store valueForKey:@"language2"];
	}
	
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=movie&limit=150", country, language, [MetadataImporter urlEncoded:aMovieTitle]]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
        if ([d isKindOfClass:[NSDictionary class]]) {
            return [iTunesStore metadataForResults:d store:store];
        }
	}
	return nil;
}

#pragma mark Load additional metadata

- (MP42Metadata *) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	NSDictionary *store = [iTunesStore getStoreFor:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|iTunes Store|Language"]];
	if (!store) {
		return nil;
	}
	NSString *country = [store valueForKey:@"country2"];
	NSString *language = [store valueForKey:@"language2"];
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/lookup?country=%@&lang=%@&id=%@", country, [language lowercaseString], [[aMetadata tagsDict] valueForKey:@"playlistID"]]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
        if ([d isKindOfClass:[NSDictionary class]]) {
            NSArray *resultsArray = [d valueForKey:@"results"];
            if ([resultsArray count] > 0) {
                NSDictionary *r = [resultsArray objectAtIndex:0];
                [aMetadata setTag:[r valueForKey:@"longDescription"] forKey:@"Series Description"];
            }
        }
	}
	return aMetadata;
}

- (MP42Metadata *) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	NSData *xmlData = [MetadataImporter downloadDataOrGetFromCache:[NSURL URLWithString:[[aMetadata tagsDict] valueForKey:@"iTunes URL"]]];
	if (xmlData) {
		NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:xmlData options:NSXMLDocumentTidyHTML error:NULL];
		NSArray *p = [iTunesStore readPeople:@"Actor" fromXML:xml];
		if (p && [p count]) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Cast"];
		p = [iTunesStore readPeople:@"Director" fromXML:xml];
		if (p && [p count]) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Director"];
		if (p && [p count]) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Artist"];
		p = [iTunesStore readPeople:@"Producer" fromXML:xml];
		if (p && [p count]) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Producers"];
		p = [iTunesStore readPeople:@"Screenwriter" fromXML:xml];
		if (p && [p count]) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Screenwriters"];
		NSArray *nodes = [xml nodesForXPath:[NSString stringWithFormat:@"//li[@class='copyright']"] error:NULL];
		for (NSXMLNode *n in nodes) {
			NSString *copyright = [n stringValue];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All Rights Reserved." withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All rights reserved." withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All Rights Reserved" withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@". All rights reserved" withString:@""];
			copyright = [copyright stringByReplacingOccurrencesOfString:@" by " withString:@" "];
			[aMetadata setTag:copyright forKey:@"Copyright"];
		}
        [xml release];
    }
	
    return aMetadata;
}

#pragma mark Parse results

/* Scrape people from iTunes Store website HTML */
+ (NSArray *) readPeople:(NSString *)aPeople fromXML:(NSXMLDocument *)aXml {
	if (aXml) {
		NSArray *nodes = [aXml nodesForXPath:[NSString stringWithFormat:@"//div[starts-with(@metrics-loc,'Titledbox_%@')]", aPeople] error:NULL];
		for (NSXMLNode *n in nodes) {
			NSXMLDocument *subXML = [[NSXMLDocument alloc] initWithXMLString:[n XMLString] options:0 error:NULL];
			if (subXML) {
				NSArray *subNodes = [subXML nodesForXPath:@"//a" error:NULL];
				NSMutableArray *r = [[NSMutableArray alloc] initWithCapacity:[subNodes count]];
				for (NSXMLNode *sub in subNodes) {
					[r addObject:[sub stringValue]];
				}
				[subXML release];
				return [r autorelease];
			}
		}
	}
	return nil;
}

+ (NSArray *) metadataForResults:(NSDictionary *)dict store:(NSDictionary *)store {
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:[[dict valueForKey:@"resultCount"] integerValue]];
	NSArray *resultsArray = [dict valueForKey:@"results"];
	for (int i = 0; i < [resultsArray count]; i++) {
		NSDictionary *r = [resultsArray objectAtIndex:i];

        // Skip if the result is not a track (for example an artist or a collection)
        if (![[r valueForKey:@"wrapperType"] isEqualToString:@"track"])
            continue;

        MP42Metadata *metadata = [[MP42Metadata alloc] init];
		if ([[r valueForKey:@"kind"] isEqualToString:@"feature-movie"]) {
			metadata.mediaKind = 9; // movie
			[metadata setTag:[r valueForKey:@"trackName"] forKey:@"Name"];
			[metadata setTag:[r valueForKey:@"artistName"] forKey:@"Director"];
            [metadata setTag:[r valueForKey:@"artistName"] forKey:@"Artist"];
		} else if ([[r valueForKey:@"kind"] isEqualToString:@"tv-episode"]) {
			metadata.mediaKind = 10; // TV show
			[metadata setTag:[r valueForKey:@"artistName"] forKey:@"TV Show"];
            [metadata setTag:[r valueForKey:@"artistName"] forKey:@"Artist"];
			NSString *s = [r valueForKey:@"collectionName"];
            NSString *season = nil;
			if (![[store valueForKey:@"season"] isEqualToString:@""]) {
				NSArray *sa = [[s lowercaseString] componentsSeparatedByString:[NSString stringWithFormat:@", %@ ", [store valueForKey:@"season"]]];
				if ([sa count] > 1) {
                    season = [sa objectAtIndex:1];
				} else {
					season = @"1";
				}
			}
            if (season) {
                [metadata setTag:season forKey:@"TV Season"];
                NSString *episodeID = [NSString stringWithFormat:@"%ld%02ld", (long)[season integerValue],
                                       (long)[[r valueForKey:@"trackNumber"] integerValue]];
                [metadata setTag:episodeID forKey:@"TV Episode ID"];
                [metadata setTag:[NSString stringWithFormat:@"%@, Season %@", [r valueForKey:@"artistName"], season] forKey:@"Album"];
            }
			[metadata setTag:[r valueForKey:@"trackNumber"] forKey:@"TV Episode #"];
			[metadata setTag:[r valueForKey:@"trackName"] forKey:@"Name"];
			[metadata setTag:[NSString stringWithFormat:@"%@/%@", [r valueForKey:@"trackNumber"], [r valueForKey:@"trackCount"]] forKey:@"Track #"];
			[metadata setTag:[r valueForKey:@"artistId"] forKey:@"artistID"];
			[metadata setTag:[r valueForKey:@"collectionId"] forKey:@"playlistID"];
		}
		// metadata common to both TV episodes and movies
		[metadata setTag:[(NSString *) [r valueForKey:@"releaseDate"] substringToIndex:10] forKey:@"Release Date"];
        if ([r valueForKey:@"shortDescription"])
            [metadata setTag:[r valueForKey:@"shortDescription"] forKey:@"Description"];
        else
            [metadata setTag:[r valueForKey:@"longDescription"] forKey:@"Description"];
		[metadata setTag:[r valueForKey:@"longDescription"] forKey:@"Long Description"];
		[metadata setTag:[r valueForKey:@"primaryGenreName"] forKey:@"Genre"];
		[metadata setTag:[NSNumber numberWithUnsignedInteger:[[SBRatings defaultManager] ratingIndexForiTunesCountry:[store valueForKey:@"country"] media:(metadata.mediaKind == 9 ? @"movie" : @"TV") ratingString:[r valueForKey:@"contentAdvisoryRating"]]] forKey:@"Rating"];
		[metadata setTag:[r valueForKey:@"trackViewUrl"] forKey:@"iTunes URL"];
		if ([store valueForKey:@"storeCode"]) {
			[metadata setTag:[[store valueForKey:@"storeCode"] stringValue] forKey:@"iTunes Country"];
		}
		NSString *trackExplicitness = [r valueForKey:@"trackExplicitness"];
		[metadata setTag:[r valueForKey:@"trackId"] forKey:@"contentID"];
		if ([trackExplicitness isEqualToString:@"explicit"]) {
			[metadata setContentRating:4];
		} else if ([trackExplicitness isEqualToString:@"cleaned"]) {
			[metadata setContentRating:2];
		}
		// artwork
		NSString *artworkString = [r valueForKey:@"artworkUrl100"];
        if (artworkString) {
            NSMutableArray *artworkThumbURLs = [[NSMutableArray alloc] initWithCapacity:1];
            [artworkThumbURLs addObject:[NSURL URLWithString:artworkString]];
            [metadata setArtworkThumbURLs: artworkThumbURLs];
            [artworkThumbURLs release];
            artworkString = [artworkString stringByReplacingOccurrencesOfString:@"100x100-75." withString:@""];
            NSMutableArray *artworkFullsizeURLs = [[NSMutableArray alloc] initWithCapacity:1];
            [artworkFullsizeURLs addObject:[NSURL URLWithString:artworkString]];
            [metadata setArtworkFullsizeURLs: artworkFullsizeURLs];
            [artworkFullsizeURLs release];
            NSMutableArray *artworkProviderNames = [[NSMutableArray alloc] initWithCapacity:1];
            [artworkProviderNames addObject:@"iTunes"];
            [metadata setArtworkProviderNames:artworkProviderNames];
            [artworkProviderNames release];
        }

		// add to array
        [returnArray addObject:metadata];
        [metadata release];
		
	}
    return [returnArray autorelease];
}

@end