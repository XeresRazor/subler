//
//  TheTVDB.m
//  Subler
//
//  Created by Douglas Stebila on 2013-06-06.
//
//

#import "TheTVDB.h"

#import "iTunesStore.h"
#import "MP42Metadata.h"
#import "SBLanguages.h"
#import "XMLReader.h"
#import "SBRatings.h"

#define API_KEY @"3498815BE9484A62"

@implementation TheTVDB

- (NSArray *) languages {
	return [[SBLanguages defaultManager] languages];
}

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage {
	NSURL *url;
	// search for series
	url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/GetSeries.php?seriesname=%@", [MetadataImporter urlEncoded:aSeriesName]]];
	NSData *seriesXML = [MetadataImporter downloadDataOrGetFromCache:url];
	NSDictionary *series = [XMLReader dictionaryForXMLData:seriesXML error:NULL];
	if (!series) return nil;
	NSArray *seriesArray = [series retrieveArrayForPath:@"Data.Series"];
	NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:[seriesArray count]];
	for (NSDictionary *s in seriesArray) {
		[results addObject:[s retrieveForPath:@"SeriesName.text"]];
	}
	return [results autorelease];
}

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
	NSString *lang = [SBLanguages iso6391CodeFor:aLanguage];
	if (!lang) lang = @"en";
	NSURL *url;

	// search for series
	url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/GetSeries.php?seriesname=%@", [MetadataImporter urlEncoded:aSeriesName]]];
	NSData *seriesXML = [MetadataImporter downloadDataOrGetFromCache:url];
	NSDictionary *series = [XMLReader dictionaryForXMLData:seriesXML error:NULL];

	if (!series) return nil;

	NSArray *seriesObject = [series retrieveForPath:@"Data.Series"];
	NSMutableArray *seriesIDs = [[NSMutableArray alloc] init];;
	if ([seriesObject isKindOfClass:[NSArray class]]) {
        for (NSDictionary *s in seriesObject)
            if ([aSeriesName isEqualToString:[s retrieveForPath:@"SeriesName.text"]])
                [seriesIDs addObject:[s retrieveForPath:@"seriesid.text"]];

        if (![seriesIDs count])
            [seriesIDs addObject:[series retrieveForPath:@"Data.Series.0.seriesid.text"]];
	}
    else {
        NSString *seriesID = [series retrieveForPath:@"Data.Series.seriesid.text"];
        if (seriesID)
            [seriesIDs addObject:seriesID];
	}
    NSMutableArray *results = [[NSMutableArray alloc] init];

    if ([seriesIDs count]) {
        for (NSString *seriesID in seriesIDs) {
            if (!seriesID || [seriesID isEqualToString:@""])
                continue;

            url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/%@/series/%@/all/%@.xml", API_KEY, seriesID, lang]];
            NSData *episodesXML = [MetadataImporter downloadDataOrGetFromCache:url];
            NSDictionary *episodes = [XMLReader dictionaryForXMLData:episodesXML error:NULL];

            if (!episodes)
                continue;

            NSArray *episodesArray = [episodes retrieveArrayForPath:@"Data.Episode"];
            NSDictionary *thisSeries = [episodes retrieveForPath:@"Data.Series"];

            for (NSDictionary *episode in episodesArray) {
                if (aSeasonNum && ![aSeasonNum isEqualToString:@""]) {
                    if ([[episode retrieveForPath:@"SeasonNumber.text"] isEqualToString:aSeasonNum]) {
                        if (aEpisodeNum && ![aEpisodeNum isEqualToString:@""]) {
                            if ([[episode retrieveForPath:@"EpisodeNumber.text"] isEqualToString:aEpisodeNum]) {
                                [results addObject:[TheTVDB metadataForEpisode:episode series:thisSeries]];
                            }
                        } else {
                            [results addObject:[TheTVDB metadataForEpisode:episode series:thisSeries]];
                        }
                    }
                } else {
                    [results addObject:[TheTVDB metadataForEpisode:episode series:thisSeries]];
                }
            }
        }
    }

    [seriesIDs release];

	return [results autorelease];
}

- (MP42Metadata*) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	// add iTunes artwork
	MP42Metadata *iTunesMetadata = [iTunesStore quickiTunesSearchTV:[[aMetadata tagsDict] valueForKey:@"TV Show"] episodeTitle:[[aMetadata tagsDict] valueForKey:@"Name"]];
	NSMutableArray * newArtworkThumbURLs = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray * newArtworkFullsizeURLs = [[[NSMutableArray alloc] init] autorelease];
	NSMutableArray * newArtworkProviderNames = [[[NSMutableArray alloc] init] autorelease];
	if (iTunesMetadata && [iTunesMetadata artworkThumbURLs] && [iTunesMetadata artworkFullsizeURLs] && ([[iTunesMetadata artworkThumbURLs] count] == [[iTunesMetadata artworkFullsizeURLs] count])) {
		[newArtworkThumbURLs addObjectsFromArray:[iTunesMetadata artworkThumbURLs]];
		[newArtworkFullsizeURLs addObjectsFromArray:[iTunesMetadata artworkFullsizeURLs]];
		[newArtworkProviderNames addObjectsFromArray:[iTunesMetadata artworkProviderNames]];
	}
	[newArtworkThumbURLs addObjectsFromArray:[aMetadata artworkThumbURLs]];
	[newArtworkFullsizeURLs addObjectsFromArray:[aMetadata artworkFullsizeURLs]];
	[newArtworkProviderNames addObjectsFromArray:[aMetadata artworkProviderNames]];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/api/%@/series/%@/banners.xml", API_KEY, [[aMetadata tagsDict] valueForKey:@"TheTVDB Series ID"]]];
	NSData *bannersXML = [MetadataImporter downloadDataOrGetFromCache:url];
	NSDictionary *banners = [XMLReader dictionaryForXMLData:bannersXML error:NULL];
	if (!banners) return nil;
	NSArray *bannersArray = [banners retrieveArrayForPath:@"Banners.Banner"];
	NSURL *u;
	for (NSDictionary *banner in bannersArray) {
		if ([[banner retrieveForPath:@"BannerType.text"] isEqualToString:@"season"] && [[banner retrieveForPath:@"BannerType2.text"] isEqualToString:@"season"] && [[banner retrieveForPath:@"Season.text"] isEqualToString:[[aMetadata tagsDict] valueForKey:@"TV Season"]]) {
			u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [banner retrieveForPath:@"BannerPath.text"]]];
			[newArtworkThumbURLs addObject:u];
			[newArtworkFullsizeURLs addObject:u];
			[newArtworkProviderNames addObject:[NSString stringWithFormat:@"TheTVDB|season %@", [[aMetadata tagsDict] valueForKey:@"TV Season"]]];
		}
	}
	for (NSDictionary *banner in bannersArray) {
		if ([[banner retrieveForPath:@"BannerType.text"] isEqualToString:@"poster"]) {
			u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [banner retrieveForPath:@"BannerPath.text"]]];
			[newArtworkThumbURLs addObject:u];
			[newArtworkFullsizeURLs addObject:u];
			[newArtworkProviderNames addObject:@"TheTVDB|poster"];
		}
	}
	[aMetadata setArtworkThumbURLs:newArtworkThumbURLs];
	[aMetadata setArtworkFullsizeURLs:newArtworkFullsizeURLs];
	[aMetadata setArtworkProviderNames:newArtworkProviderNames];
	return aMetadata;
}

+ (NSString *) cleanPeopleList:(NSString *)s {
    NSArray *a = [[[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
				   stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"|"]]
				  componentsSeparatedByString:@"|"];
    return [a componentsJoinedByString:@", "];
}

+ (MP42Metadata *) metadataForEpisode:(NSDictionary *)aEpisode series:(NSDictionary *)aSeries {
	MP42Metadata *metadata = [[MP42Metadata alloc] init];
	metadata.mediaKind = 10; // TV show
	[metadata setTag:[aSeries retrieveForPath:@"id.text"] forKey:@"TheTVDB Series ID"];
	[metadata setTag:[aSeries retrieveForPath:@"SeriesName.text"] forKey:@"TV Show"];
    [metadata setTag:[aSeries retrieveForPath:@"Overview.text"] forKey:@"Series Description"];
    [metadata setTag:[TheTVDB cleanPeopleList:[aSeries retrieveForPath:@"Genre.text"]] forKey:@"Genre"];

    [metadata setTag:[NSNumber numberWithUnsignedInteger:
                      [[SBRatings defaultManager] ratingIndexForiTunesCountry:@"USA" media:@"TV" ratingString:[aSeries retrieveForPath:@"ContentRating.text"]]] forKey:@"Rating"];

    [metadata setTag:[aSeries retrieveForPath:@"Network.text"] forKey:@"TV Network"];
	[metadata setTag:[aEpisode retrieveForPath:@"SeasonNumber.text"] forKey:@"TV Season"];
	[metadata setTag:[aEpisode retrieveForPath:@"EpisodeNumber.text"] forKey:@"TV Episode #"];

    NSString *episodeID = [NSString stringWithFormat:@"%ld%02ld", (long)[[aEpisode retrieveForPath:@"SeasonNumber.text"] integerValue],
                            (long)[[aEpisode retrieveForPath:@"EpisodeNumber.text"] integerValue]];
	[metadata setTag:episodeID forKey:@"TV Episode ID"];

	[metadata setTag:[aEpisode retrieveForPath:@"SeasonNumber.text"] forKey:@"TV Season"];
	[metadata setTag:[aEpisode retrieveForPath:@"EpisodeName.text"] forKey:@"Name"];
	[metadata setTag:[aEpisode retrieveForPath:@"FirstAired.text"] forKey:@"Release Date"];
	[metadata setTag:[aEpisode retrieveForPath:@"Overview.text"] forKey:@"Description"];
	[metadata setTag:[aEpisode retrieveForPath:@"Overview.text"] forKey:@"Long Description"];
	[metadata setTag:[aEpisode retrieveForPath:@"EpisodeNumber.text"] forKey:@"Track #"];
	[metadata setTag:[TheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"Director.text"]] forKey:@"Director"];

	[metadata setTag:[NSString stringWithFormat:@"%@, Season %@", [aSeries retrieveForPath:@"SeriesName.text"], [aEpisode retrieveForPath:@"SeasonNumber.text"]] forKey:@"Artist"];

	[metadata setTag:[TheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"Writer.text"]] forKey:@"Screenwriters"];
	// cast
	NSString *actors = [TheTVDB cleanPeopleList:[aSeries retrieveForPath:@"Actors.text"]];
	NSString *gueststars = [TheTVDB cleanPeopleList:[aEpisode retrieveForPath:@"GuestStars.text"]];
	if ([actors length]) {
		if ([gueststars length]) {
			[metadata setTag:[NSString stringWithFormat:@"%@, %@", actors, gueststars] forKey:@"Cast"];
		} else {
			[metadata setTag:actors forKey:@"Cast"];
		}
	} else {
		if ([gueststars length]) {
			[metadata setTag:gueststars forKey:@"Cast"];
		}
	}
	// artwork
	NSMutableArray *artworkThumbURLs = [[NSMutableArray alloc] initWithCapacity:10];
	NSMutableArray *artworkFullsizeURLs = [[NSMutableArray alloc] initWithCapacity:10];
	NSMutableArray *artworkProviderNames = [[NSMutableArray alloc] initWithCapacity:10];
	NSURL *u;
	if ([aEpisode retrieveForPath:@"filename.text"]) {
		u = [NSURL URLWithString:[NSString stringWithFormat:@"http://thetvdb.com/banners/%@", [aEpisode retrieveForPath:@"filename.text"]]];
		[artworkThumbURLs addObject:u];
		[artworkFullsizeURLs addObject:u];
		[artworkProviderNames addObject:@"TheTVDB|episode"];
	}
	[metadata setArtworkThumbURLs: artworkThumbURLs];
	[metadata setArtworkFullsizeURLs: artworkFullsizeURLs];
	[metadata setArtworkProviderNames:artworkProviderNames];
	[artworkThumbURLs release];
	[artworkFullsizeURLs release];
	[artworkProviderNames release];
	// TheTVDB does not provide the following fields normally associated with TV shows in MP42Metadata:
	// "Copyright", "Comments", "Producers", "Artist"
	return [metadata autorelease];
}

@end
