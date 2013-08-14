//
//  iTunesStore.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/28.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "iTunesStore.h"
#import "MetadataSearchController.h"
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
    if (v1 < v2)
        return NSOrderedAscending;
    else if (v1 > v2)
        return NSOrderedDescending;
    else
        return NSOrderedSame;
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
	if (aSeasonNum && ![aSeasonNum isEqualToString:@""]) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&attribute=tvSeasonTerm&entity=tvEpisode", country, [language lowercaseString], [MetadataImporter urlEncoded:[NSString stringWithFormat:@"%@ %@ %@", aSeriesName, season, aSeasonNum]]]];
	} else {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&attribute=showTerm&entity=tvEpisode", country, [language lowercaseString], [MetadataImporter urlEncoded:aSeriesName]]];
	}
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
		NSArray *results = [iTunesStore metadataForResults:d store:store];
		if (([results count] == 0) && ![aLanguage isEqualToString:@"USA (English)"]) {
			return [self searchTVSeries:aSeriesName language:@"USA (English)" seasonNum:aSeasonNum episodeNum:aEpisodeNum];
		}
		if (([results count] == 0) && aSeasonNum) {
			return [self searchTVSeries:aSeriesName language:@"USA (English)" seasonNum:nil episodeNum:aEpisodeNum];
		}
		if (aEpisodeNum && ![aEpisodeNum isEqualToString:@""]) {
			NSEnumerator *resultsEnum = [results objectEnumerator];
			MP42Metadata *m;
			while ((m = (MP42Metadata *) [resultsEnum nextObject])) {
				if ([[[[m tagsDict] valueForKey:@"TV Episode #"] stringValue] isEqualToString:aEpisodeNum]) {
					return [NSArray arrayWithObject:m];
				}
			}
		}
		NSArray *resultsSorted = [results sortedArrayUsingFunction:sortMP42Metadata context:NULL];
		return resultsSorted;
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
		NSArray *results = [iTunesStore metadataForResults:d store:store];
		if ([results count] > 0) {
			return [results objectAtIndex:0];
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
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?country=%@&lang=%@&term=%@&entity=movie", country, [language lowercaseString], [MetadataImporter urlEncoded:aMovieName]]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
		NSArray *results = [iTunesStore metadataForResults:d store:store];
		if ([results count] > 0) {
			return [results objectAtIndex:0];
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
	
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://itunes.apple.com/search?&country=%@&lang=%@&term=%@&entity=movie", country, language, [MetadataImporter urlEncoded:aMovieTitle]]];
	NSData *jsonData = [MetadataImporter downloadDataOrGetFromCache:url];
	if (jsonData) {
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		NSDictionary *d = [jsonDecoder objectWithData:jsonData];
		return [iTunesStore metadataForResults:d store:store];
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
		NSArray *resultsArray = [d valueForKey:@"results"];
		if ([resultsArray count] > 0) {
			NSDictionary *r = [resultsArray objectAtIndex:0];
			[aMetadata setTag:[r valueForKey:@"longDescription"] forKey:@"Series Description"];
		}
	}
	return aMetadata;
}

- (MP42Metadata *) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	NSData *xmlData = [MetadataImporter downloadDataOrGetFromCache:[NSURL URLWithString:[[aMetadata tagsDict] valueForKey:@"iTunes URL"]]];
	if (xmlData) {
		NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:xmlData options:NSXMLDocumentTidyHTML error:NULL];
		NSArray *p = [iTunesStore readPeople:@"Actor" fromXML:xml];
		if (p) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Cast"];
		p = [iTunesStore readPeople:@"Director" fromXML:xml];
		if (p) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Director"];
		if (p) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Artist"];
		p = [iTunesStore readPeople:@"Producer" fromXML:xml];
		if (p) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Producers"];
		p = [iTunesStore readPeople:@"Screenwriter" fromXML:xml];
		if (p) [aMetadata setTag:[p componentsJoinedByString:@", "] forKey:@"Screenwriters"];
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
        MP42Metadata *metadata = [[MP42Metadata alloc] init];
		if ([[r valueForKey:@"kind"] isEqualToString:@"feature-movie"]) {
			metadata.mediaKind = 9; // movie
			[metadata setTag:[r valueForKey:@"trackName"] forKey:@"Name"];
			[metadata setTag:[r valueForKey:@"artistName"] forKey:@"Director"];
		} else if ([[r valueForKey:@"kind"] isEqualToString:@"tv-episode"]) {
			metadata.mediaKind = 10; // TV show
			[metadata setTag:[r valueForKey:@"artistName"] forKey:@"TV Show"];
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
            }
			[metadata setTag:[r valueForKey:@"trackNumber"] forKey:@"TV Episode #"];
			[metadata setTag:[r valueForKey:@"trackName"] forKey:@"Name"];
			[metadata setTag:[NSString stringWithFormat:@"%@/%@", [r valueForKey:@"trackNumber"], [r valueForKey:@"trackCount"]] forKey:@"Track #"];
			[metadata setTag:[r valueForKey:@"artistId"] forKey:@"artistID"];
			[metadata setTag:[r valueForKey:@"collectionId"] forKey:@"playlistID"];
		}
		// metadata common to both TV episodes and movies
		[metadata setTag:[(NSString *) [r valueForKey:@"releaseDate"] substringToIndex:10] forKey:@"Release Date"];
		[metadata setTag:[r valueForKey:@"shortDescription"] forKey:@"Description"];
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
		// add to array
        [returnArray addObject:metadata];
        [metadata release];
		
	}
    return [returnArray autorelease];
}

@end