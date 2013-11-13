//
//  MetadataImporter.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import "MetadataImporter.h"

#import "SBMetadataSearchController.h"
#import "SBLanguages.h"

#import "MP42Metadata.h"
#import <CommonCrypto/CommonDigest.h>

#import "iTunesStore.h"
#import "TheMovieDB3.h"
#import "TheTVDB.h"

#import "RegexKitLite.h"

@implementation MetadataImporter

#pragma mark Helper routines

+ (NSDictionary *) parseFilename: (NSString *) filename
{
    NSMutableDictionary *results = nil;
    
    if (!filename || ![filename length]) {
        return results;
    }
    
    NSString *regexString  = @"^\\[(.+)\\](?:(?:\\s|_)+)?([^()]+)(?:(?:\\s|_)+)(?:(?:-\\s|-_|Ep)+)([0-9][0-9]?)";
    NSDictionary *resultDictionary = [filename dictionaryByMatchingRegex:regexString
                                                     withKeysAndCaptures:@"fanSubGroup", 1, @"seriesName", 2,  @"episodeNumber", 3, nil];
    
    if (resultDictionary != nil && [resultDictionary count]) {
        results = [[NSMutableDictionary alloc] initWithCapacity:2];
        NSString *seriesName = [[resultDictionary valueForKey:@"seriesName"] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        NSInteger episodeNumber = [[resultDictionary valueForKey:@"episodeNumber"] integerValue];
        [results setValue:@"tv" forKey:@"type"];
        [results setValue:seriesName forKey:@"seriesName"];
        [results setValue:@"1" forKey:@"seasonNum"];
        [results setValue:[NSString stringWithFormat:@"%ld", (long) episodeNumber] forKey:@"episodeNum"];
        
        return [results autorelease];
    }
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/bin/perl"];
    
    NSMutableArray *args = [[NSMutableArray alloc] initWithCapacity:3];
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"ParseFilename" ofType:@""];
    [args addObject:[NSString stringWithFormat:@"-I%@/lib", path]];
    [args addObject:[NSString stringWithFormat:@"%@/ParseFilename.pl", path]];
    [args addObject:filename];
    [task setArguments:args];
    
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSFileHandle *stdOutWrite = [stdOut fileHandleForWriting];
    [task setStandardOutput:stdOutWrite];
    
    [task launch];
    [task waitUntilExit];
    [stdOutWrite closeFile];
    
    NSData *outputData = [[stdOut fileHandleForReading] readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
    NSArray *lines = [outputString componentsSeparatedByString:@"\n"];
    
    if ([lines count]) {
        if ([(NSString *) [lines objectAtIndex:0] isEqualToString:@"tv"]) {
            if ([lines count] >= 4) {
                results = [[NSMutableDictionary alloc] initWithCapacity:4];
                [results setValue:@"tv" forKey:@"type"];
				NSString *newSeriesName=[[lines objectAtIndex:1]
                                         stringByReplacingOccurrencesOfString:@"."
                                         withString:@" "];
                [results setValue:newSeriesName forKey:@"seriesName"];
                [results setValue:[lines objectAtIndex:2] forKey:@"seasonNum"];
                [results setValue:[lines objectAtIndex:3] forKey:@"episodeNum"];
            }
        } else if ([(NSString *) [lines objectAtIndex:0] isEqualToString:@"movie"]) {
            if ([lines count] >= 2) {
                results = [[NSMutableDictionary alloc] initWithCapacity:4];
                [results setValue:@"movie" forKey:@"type"];
				NSString *newTitle=[[lines objectAtIndex:1]
                                    stringByReplacingOccurrencesOfString:@"."
                                    withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"(" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@")" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"[" withString:@" "];
                newTitle = [newTitle stringByReplacingOccurrencesOfString:@"]" withString:@" "];
                newTitle = [newTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [results setValue:newTitle forKey:@"title"];
            }
        }
    }
    
    [outputString release];
    [stdOut release];
    [args release];
    [task release];
    
    return [results autorelease];
}

+ (NSString *) urlEncoded:(NSString *)s {
    CFStringRef urlString = CFURLCreateStringByAddingPercentEscapes(
                                                                    NULL,
                                                                    (CFStringRef) s,
                                                                    NULL,
                                                                    (CFStringRef) @"!*'\"();:@&=+$,/?%#[]% ",
                                                                    kCFStringEncodingUTF8);
    return [(NSString *)urlString autorelease];
}

+ (NSString *) md5String:(NSString *) s {
	const char *cStr = [s UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5(cStr, strlen(cStr), result);
	NSMutableString *r = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
	for(int i = 0; i < CC_MD5_DIGEST_LENGTH; ++i) {
		[r appendFormat:@"%02x", result[i]];
	}
	return [NSString stringWithString:r];
}

+ (NSData *)downloadDataOrGetFromCache:(NSURL *)url {
	NSString *path = nil;
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	if ([paths count]) {
		NSString *bundleName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"];
		path = [[paths objectAtIndex:0] stringByAppendingPathComponent:bundleName];
	}
	NSString *filename = [path stringByAppendingPathComponent:[MetadataImporter md5String:[url absoluteString]]];
	NSString *extension = [[url path] pathExtension];
	filename = [filename stringByAppendingPathExtension:extension];
	if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
		NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
		if (attrs) {
			NSDate *date = [attrs fileCreationDate];
			NSTimeInterval oldness = [date timeIntervalSinceNow];
			// if less than 2 hours old
			if (([[[[url absoluteString] pathExtension] lowercaseString] isEqualToString:@"jpg"]) || (oldness > -60 * 60 * 2)) {
				return [NSData dataWithContentsOfFile:filename];
			}
		}
	}
    NSError *outError = nil;
	NSData *r = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&outError];
    
    if (!outError && r)
        [r writeToFile:filename atomically:NO];

	return r;
}

#pragma mark Static methods

+ (NSArray *) languagesForProvider:(NSString *)aProvider {
	MetadataImporter *m = [MetadataImporter importerForProvider:aProvider];
	NSArray *a = [m languages];
	return a;
}

+ (instancetype) importerForProvider:(NSString *)aProvider {
	if ([aProvider isEqualToString:@"iTunes Store"]) {
		return [[[iTunesStore alloc] init] autorelease];
	} else if ([aProvider isEqualToString:@"TheMovieDB"]) {
		return [[[TheMovieDB3 alloc] init] autorelease];
	} else if ([aProvider isEqualToString:@"TheTVDB"]) {
		return [[[TheTVDB alloc] init] autorelease];
	}
	return nil;
}

+ (instancetype) defaultMovieProvider {
	return [MetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie"]];
}

+ (instancetype) defaultTVProvider {
	return [MetadataImporter importerForProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV"]];
}

+ (NSString *) defaultMovieLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", [defaults valueForKey:@"SBMetadataPreference|Movie"]]];
}

+ (NSString *) defaultTVLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", [defaults valueForKey:@"SBMetadataPreference|TV"]]];
}

#pragma mark Asynchronous searching

- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage];
            if (!isCancelled) {
                [mCallback performSelectorOnMainThread:@selector(searchTVSeriesNameDone:) withObject:results waitUntilDone:YES];
            }
        }
    });
}

- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum callback:(SBMetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            NSArray *results = [self searchTVSeries:aSeries language:aLanguage seasonNum:aSeasonNum episodeNum:aEpisodeNum];
            if (!isCancelled) {
                [mCallback performSelectorOnMainThread:@selector(searchForResultsDone:) withObject:results waitUntilDone:YES];
            }
        }
    });
}

- (void) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            [self loadTVMetadata:aMetadata language:aLanguage];
            if (!isCancelled) {
                [mCallback performSelectorOnMainThread:@selector(loadAdditionalMetadataDone:) withObject:aMetadata waitUntilDone:YES];
            }
        }
    });
}

- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            NSArray *results = [self searchMovie:aMovieTitle language:aLanguage];
            if (!isCancelled)
                [mCallback performSelectorOnMainThread:@selector(searchForResultsDone:) withObject:results waitUntilDone:YES];
        }
    });
}

- (void) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage callback:(SBMetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            [self loadMovieMetadata:aMetadata language:aLanguage];
            if (!isCancelled) {
                [mCallback performSelectorOnMainThread:@selector(loadAdditionalMetadataDone:) withObject:aMetadata waitUntilDone:YES];
            }
        }
    });
}

- (void)cancel {
    @synchronized(self) {
        isCancelled = YES;
    }
}

#pragma mark Methods to be overridden

- (NSArray *) languages {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage  {
	TheTVDB *searcher = [[TheTVDB alloc] init];
	NSArray *a = [searcher searchTVSeries:aSeriesName language:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV|TheTVDB|Language"]];
	[searcher release];
	return a;
}

- (NSArray *) searchTVSeries:(NSString *)aSeriesName language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (MP42Metadata*) loadTVMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (NSArray *) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

- (MP42Metadata*) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage {
	@throw [NSException exceptionWithName:NSInternalInconsistencyException
								   reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
								 userInfo:nil];
}

#pragma mark Finishing up

- (void) dealloc {
    mCallback = nil;
    [super dealloc];
}

@end
