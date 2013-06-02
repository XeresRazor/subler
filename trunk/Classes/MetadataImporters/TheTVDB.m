//
//  TheTVDB.m
//  Subler
//
//  Created by Douglas Stebila on 2011/01/27.
//  Copyright 2011 Douglas Stebila. All rights reserved.
//

#import "TheTVDB.h"

#import "MetadataImporter.h"
#import "MP42File.h"
#import "iTunesStore.h"

@interface TheTVDB (Private)
#pragma mark Parse metadata
- (NSString *) cleanPeopleList:(NSString *)s;
- (NSArray *) metadataForResults:(NSDictionary *)results;
@end

@implementation TheTVDB

- (NSArray *) languages {
	return [NSArray arrayWithObjects:@"Chinese", @"Croatian", @"Czech", @"Danish", @"Dutch", @"English", @"Finnish", @"French", @"German", @"Greek, Modern", @"Hebrew", @"Hungarian", @"Italian", @"Japanese", @"Korean", @"Norwegian", @"Polish", @"Portuguese", @"Russian", @"Slovenian", @"Spanish", @"Swedish", @"Turkish", nil];
}

#pragma mark Search for TV series name

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage {
    NSMutableArray *results = [[NSMutableArray alloc] initWithCapacity:3];
    NSURL *u = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"http://www.thetvdb.com/api/GetSeries.php?seriesname=%@", [MetadataImporter urlEncoded:aSeriesName]]];
    if (u != nil) {
        NSXMLDocument *x = [[NSXMLDocument alloc] initWithContentsOfURL:u options:0 error:NULL];
        if (x != nil) {
            NSArray *nodes = [x nodesForXPath:@"./Data/Series" error:NULL];
            for (NSXMLElement *element in nodes) {
                NSArray *node = [element nodesForXPath:@"./SeriesName" error:NULL];
                if ([node count]) [results addObject:[[node objectAtIndex:0] stringValue]];
            }
        }
        [x release];
    }
    [u release];
    return [results autorelease];
}

#pragma mark Search for episode metadata

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
    // load data from tvdb via python on command line
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:4];
    [args addObject:@"tvdb_main.py"];
    [args addObject:aSeriesName];
	[args addObject:aLanguage];
    if ([aSeasonNum length]) [args addObject:aSeasonNum];
    if ([aEpisodeNum length]) [args addObject:aEpisodeNum];
    NSPipe *outputPipe = [NSPipe pipe];
    NSTask *cmd = [[NSTask alloc] init];
    [cmd setArguments:args];
    [cmd setCurrentDirectoryPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"tvdb_py" ofType:@""]];
    [cmd setLaunchPath:@"/usr/bin/python"];
    [cmd setStandardOutput:outputPipe];
    [cmd launch];
    [cmd waitUntilExit];
    // read output into dictionary
    NSFileHandle *outputFile = [outputPipe fileHandleForReading];
    NSData *outputData = [outputFile readDataToEndOfFile];
    NSString *plistFilename = [[[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:plistFilename];
    // construct result
    NSArray *results = [self metadataForResults:plist];
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistFilename])
        [[NSFileManager defaultManager] removeItemAtPath:plistFilename error:NULL];
    // return results

    [args release];
    [cmd release];

    return results;
}

#pragma mark Parse metadata

- (NSString *) cleanPeopleList:(NSString *)s {
    NSArray *a = [[[s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] 
                          stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"|"]] 
                         componentsSeparatedByString:@"|"];
    return [a componentsJoinedByString:@", "];
}

- (NSArray *) metadataForResults:(NSDictionary *)dict {
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:1];
    NSArray *episodesList = [dict valueForKey:@"episodes"];
    NSEnumerator *episodesEnum = [episodesList objectEnumerator];
    NSDictionary *episodeDict;
    while ((episodeDict = (NSDictionary *) [episodesEnum nextObject])) {
        MP42Metadata *metadata = [[MP42Metadata alloc] init];
        metadata.mediaKind = 10; // TV show
        [metadata setTag:[dict valueForKey:@"seriesname"] forKey:@"TV Show"];
        [metadata setTag:[episodeDict valueForKey:@"seasonnumber"] forKey:@"TV Season"];
        [metadata setTag:[episodeDict valueForKey:@"episodenumber"] forKey:@"TV Episode #"];
        [metadata setTag:[episodeDict valueForKey:@"productioncode"] forKey:@"TV Episode ID"];
        [metadata setTag:[episodeDict valueForKey:@"seasonnumber"] forKey:@"TV Season"];
        [metadata setTag:[episodeDict valueForKey:@"episodename"] forKey:@"Name"];
        [metadata setTag:[episodeDict valueForKey:@"firstaired"] forKey:@"Release Date"];
        [metadata setTag:[episodeDict valueForKey:@"overview"] forKey:@"Description"];
        [metadata setTag:[episodeDict valueForKey:@"overview"] forKey:@"Long Description"];
        [metadata setTag:[self cleanPeopleList:[episodeDict valueForKey:@"director"]] forKey:@"Director"];
        [metadata setTag:[self cleanPeopleList:[episodeDict valueForKey:@"director"]] forKey:@"Artist"];
        [metadata setTag:[self cleanPeopleList:[episodeDict valueForKey:@"writer"]] forKey:@"Screenwriters"];
        [metadata setTag:[episodeDict valueForKey:@"episodenumber"] forKey:@"Track #"];
        // artwork
        NSMutableArray *artworkThumbURLs = [[NSMutableArray alloc] initWithCapacity:10];
        NSMutableArray *artworkFullsizeURLs = [[NSMutableArray alloc] initWithCapacity:10];
        NSMutableArray *artworkProviderNames = [[NSMutableArray alloc] initWithCapacity:10];
        NSURL *u;
        if ([episodeDict valueForKey:@"filename"]) {
            u = [NSURL URLWithString:[episodeDict valueForKey:@"filename"]];
            [artworkThumbURLs addObject:u];
            [artworkFullsizeURLs addObject:u];
            [artworkProviderNames addObject:@"TheTVDB|episode"];
        }
		// add iTunes artwork
		MP42Metadata *iTunesMetadata = [iTunesStore quickiTunesSearchTV:[dict valueForKey:@"seriesname"] episodeTitle:[episodeDict valueForKey:@"episodename"]];
		if (iTunesMetadata && [iTunesMetadata artworkThumbURLs] && [iTunesMetadata artworkFullsizeURLs] && ([[iTunesMetadata artworkThumbURLs] count] == [[iTunesMetadata artworkFullsizeURLs] count])) {
			[artworkThumbURLs addObjectsFromArray:[iTunesMetadata artworkThumbURLs]];
			[artworkFullsizeURLs addObjectsFromArray:[iTunesMetadata artworkFullsizeURLs]];
            [artworkProviderNames addObjectsFromArray:[iTunesMetadata artworkProviderNames]];
		}
        if ([dict valueForKey:@"artwork_season"]) {
            NSString *s;
            NSEnumerator *e = [((NSArray *) [dict valueForKey:@"artwork_season"]) objectEnumerator];
            while ((s = (NSString *) [e nextObject])) {
                u = [NSURL URLWithString:s];
                [artworkThumbURLs addObject:u];
                [artworkFullsizeURLs addObject:u];
				[artworkProviderNames addObject:@"TheTVDB|season"];
            }
        }
        if ([dict valueForKey:@"artwork_posters"]) {
            NSString *s;
            NSEnumerator *e = [((NSArray *) [dict valueForKey:@"artwork_posters"]) objectEnumerator];
            while ((s = (NSString *) [e nextObject])) {
                u = [NSURL URLWithString:s];
                [artworkThumbURLs addObject:u];
                [artworkFullsizeURLs addObject:u];
				[artworkProviderNames addObject:@"TheTVDB|poster"];
            }
        }
        [metadata setArtworkThumbURLs: artworkThumbURLs];
        [metadata setArtworkFullsizeURLs: artworkFullsizeURLs];
		[metadata setArtworkProviderNames:artworkProviderNames];
        
        [artworkThumbURLs release];
        [artworkFullsizeURLs release];
		[artworkProviderNames release];

        // cast
        NSString *actors = [((NSArray *) [dict valueForKey:@"actors"]) componentsJoinedByString:@", "];
        NSString *gueststars = [self cleanPeopleList:[episodeDict valueForKey:@"gueststars"]];
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
        // TheTVDB does not provide the following fields normally associated with TV shows in MP42Metadata:
        // "TV Network", "Genre", "Copyright", "Comments", "Rating", "Producers", "Artist"
        [returnArray addObject:metadata];
        [metadata release];
    }
    return [returnArray autorelease];
}

#pragma mark Privacy

+ (void) deleteCachedMetadata {
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:4];
    [args addObject:@"-c"];
    [args addObject:@"import tempfile\nprint tempfile.gettempdir()"];
    NSPipe *outputPipe = [NSPipe pipe];
    NSTask *cmd = [[NSTask alloc] init];
    [cmd setArguments:args];
    [cmd setLaunchPath:@"/usr/bin/python"];
    [cmd setStandardOutput:outputPipe];
    [cmd launch];
    [cmd waitUntilExit];
    // read output into dictionary
    NSFileHandle *outputFile = [outputPipe fileHandleForReading];
    NSData *outputData = [outputFile readDataToEndOfFile];
    NSString *output = [[[[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] autorelease] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [[NSFileManager defaultManager] removeItemAtPath:[output stringByAppendingPathComponent:@"tvdb_api"] error:NULL];
    [cmd release];
    [args release];
}

@end
