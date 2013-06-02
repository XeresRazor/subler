//
//  MetadataImporter.m
//  Subler
//
//  Created by Douglas Stebila on 2013-05-30.
//
//

#import "MetadataImporter.h"

#import "MetadataSearchController.h"
#import "MP42Metadata.h"
#import <CommonCrypto/CommonDigest.h>
#import "SBLanguages.h"

#import "iTunesStore.h"
#import "TheMovieDB3.h"
#import "TheTVDB.h"

@implementation MetadataImporter

#pragma mark Helper routines

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
	if ([[NSFileManager defaultManager] fileExistsAtPath:filename]) {
		NSDictionary* attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
		if (attrs) {
			NSDate *date = [attrs fileCreationDate];
			NSTimeInterval oldness = [date timeIntervalSinceNow];
			// if less than 2 hours old
			if (([[[[url absoluteString] pathExtension] lowercaseString] isEqualToString:@"jpg"]) || (oldness > -1000 * 60 * 60 * 2)) {
				return [[NSData alloc] initWithContentsOfFile:filename];
			}
		}
	}
	NSData *r = [[NSData alloc] initWithContentsOfURL:url];
	[r writeToFile:filename atomically:NO];
	return r;
}

#pragma mark Static methods

+ (MetadataImporter *) forProvider:(NSString *)aProvider {
	if ([aProvider isEqualToString:@"iTunes Store"]) {
		return [[iTunesStore alloc] init];
	} else if ([aProvider isEqualToString:@"TheMovieDB"]) {
		return [[TheMovieDB3 alloc] init];
	} else if ([aProvider isEqualToString:@"TheTVDB"]) {
		return [[TheTVDB alloc] init];
	}
	return nil;
}

+ (MetadataImporter *) defaultMovieProvider {
	return [MetadataImporter forProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|Movie"]];
}

+ (MetadataImporter *) defaultTVProvider {
	return [MetadataImporter forProvider:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBMetadataPreference|TV"]];
}

+ (NSString *) defaultMovieLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|Movie|%@|Language", [defaults valueForKey:@"SBMetadataPreference|Movie"]]];
}

+ (NSString *) defaultTVLanguage {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	return [defaults valueForKey:[NSString stringWithFormat:@"SBMetadataPreference|TV|%@|Language", [defaults valueForKey:@"SBMetadataPreference|TV"]]];
}

#pragma mark Static methods

+ (NSArray *) languagesForProvider:(NSString *)aProvider {
	MetadataImporter *m = [MetadataImporter forProvider:aProvider];
	NSArray *a = [m languages];
	[m release];
	return a;
}

+ (MetadataImporter *) importerForProvider:(NSString *)aProviderName {
	if ([aProviderName isEqualToString:@"iTunes Store"]) {
		return [[iTunesStore alloc] init];
	} else if ([aProviderName isEqualToString:@"TheMovieDB"]) {
		return [[TheMovieDB3 alloc] init];
	}
	return nil;
}

#pragma mark Asynchronous searching

- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage callback:(MetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *results = [self searchTVSeries:aSeries language:aLanguage];
        if (!isCancelled) {
            [mCallback performSelectorOnMainThread:@selector(searchTVSeriesNameDone:) withObject:results waitUntilDone:YES];
		}
        [pool release];
    });
}

- (void) searchTVSeries:(NSString *)aSeries language:(NSString *)aLanguage seasonNum:(NSString *)aSeasonNum episodeNum:(NSString *)aEpisodeNum callback:(MetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *results = [self searchTVSeries:aSeries language:aLanguage seasonNum:aSeasonNum episodeNum:aEpisodeNum];
        if (!isCancelled) {
            [mCallback performSelectorOnMainThread:@selector(searchForResultsDone:) withObject:results waitUntilDone:YES];
		}
        [pool release];
    });
}

- (void) searchMovie:(NSString *)aMovieTitle language:(NSString *)aLanguage callback:(MetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *results = [self searchMovie:aMovieTitle language:aLanguage];
        if (!isCancelled)
            [mCallback performSelectorOnMainThread:@selector(searchForResultsDone:) withObject:results waitUntilDone:YES];
		
        [pool release];
    });
}

- (void) loadMovieMetadata:(MP42Metadata *)aMetadata language:(NSString *)aLanguage callback:(MetadataSearchController *)aCallback {
    mCallback = aCallback;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [self loadMovieMetadata:aMetadata language:aLanguage];
        if (!isCancelled) {
            [mCallback performSelectorOnMainThread:@selector(loadAdditionalMetadataDone:) withObject:aMetadata waitUntilDone:YES];
		}
        [pool release];
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
