//
//  SBRatings.m
//  Subler
//
//  Created by Douglas Stebila on 2013-06-02.
//
//

#import "SBRatings.h"

#import "JSONKit.h"

@implementation SBRatings

@synthesize ratings;
@synthesize iTunesCodes;

+ (SBRatings *) defaultManager {
    static dispatch_once_t sharedRatingsPred;
    static SBRatings *sharedRatingsManager = nil;
    dispatch_once(&sharedRatingsPred, ^{ sharedRatingsManager = [[self alloc] init]; });
    return sharedRatingsManager;
}

- (id) init {
	if (self = [super init]) {
		NSString* ratingsJSON = [[NSBundle mainBundle] pathForResource:@"Ratings" ofType:@"json"];
        if (!ratingsJSON) {
            [self release];
            return nil;
        }

		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		ratingsDictionary = [[jsonDecoder objectWithData:[NSData dataWithContentsOfFile:ratingsJSON]] retain];
		// construct movie ratings
		ratings = [[NSMutableArray alloc] init];
		iTunesCodes = [[NSMutableArray alloc] init];
		// if a specific country is picked, include the USA ratings at the end
		NSDictionary *usaRatings = nil;
		for (NSDictionary *countryRatings in ratingsDictionary) {
			NSString *countryName = [countryRatings valueForKey:@"country"];
			if ([countryName isEqualToString:@"USA"]) {
				usaRatings = countryRatings;
			}
			if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"SBRatingsCountry"] isEqualToString:@"All countries"]) {
				if (![countryName isEqualToString:@"Unknown"] && ![countryName isEqualToString:[[NSUserDefaults standardUserDefaults] valueForKey:@"SBRatingsCountry"]]) {
					continue;
				}
																								
			}
			for (NSDictionary *rating in [countryRatings valueForKey:@"ratings"]) {
				[ratings addObject:[NSString stringWithFormat:@"%@ %@: %@", countryName, [rating valueForKey:@"media"], [rating valueForKey:@"description"]]];
				[iTunesCodes addObject:[NSString stringWithFormat:@"%@|%@|%@|", [rating valueForKey:@"prefix"], [rating valueForKey:@"itunes-code"], [rating valueForKey:@"itunes-value"]]];
			}
		}
		if (![[[NSUserDefaults standardUserDefaults] valueForKey:@"SBRatingsCountry"] isEqualToString:@"All countries"] && ![[[NSUserDefaults standardUserDefaults] valueForKey:@"SBRatingsCountry"] isEqualToString:@"USA"]) {
            if (usaRatings) {
                for (NSDictionary *rating in [usaRatings valueForKey:@"ratings"]) {
                    [ratings addObject:[NSString stringWithFormat:@"%@ %@: %@", @"USA", [rating valueForKey:@"media"], [rating valueForKey:@"description"]]];
                    [iTunesCodes addObject:[NSString stringWithFormat:@"%@|%@|%@|", [rating valueForKey:@"prefix"], [rating valueForKey:@"itunes-code"], [rating valueForKey:@"itunes-value"]]];
                }
            }
		}
	}
	return self;
}

- (NSArray *) ratingsCountries {
	NSMutableArray *countries = [[NSMutableArray alloc] init];
	for (NSDictionary *countryRatings in ratingsDictionary) {
		NSString *countryName = [countryRatings valueForKey:@"country"];
		if ([countryName isEqualToString:@"Unknown"]) {
			[countries addObject:@"All countries"];
		} else {
			[countries addObject:countryName];
		}
	}
	return [countries autorelease];
}

- (void)updateRatingsCountry {
	[ratings release];
	[iTunesCodes release];
	[self init];
}

- (NSArray *) ratings {
	return [NSArray arrayWithArray:ratings];
}

- (NSUInteger) unknownIndex {
	return 0;
}

- (NSUInteger) ratingIndexForiTunesCode:(NSString *)aiTunesCode {
	for (int i = 0; i < [iTunesCodes count]; i++) {
		if ([[iTunesCodes objectAtIndex:i] isEqualToString:aiTunesCode]) {
			return i;
		}
	}
	return [self unknownIndex];
}

- (NSUInteger) ratingIndexForiTunesCountry:(NSString *)aCountry media:(NSString *)aMedia ratingString:(NSString *)aRatingString {
	NSString *target1 = [[NSString stringWithFormat:@"%@ %@: %@", aCountry, aMedia, aRatingString] lowercaseString];
	NSString *target2 = [[NSString stringWithFormat:@"%@ %@: %@", aCountry, @"movie & TV", aRatingString] lowercaseString];
	for (int i = 0; i < [ratings count]; i++) {
		if ([[[ratings objectAtIndex:i] lowercaseString] isEqualToString:target1] || [[[ratings objectAtIndex:i] lowercaseString] isEqualToString:target2]) {
			return i;
		}
	}
	if (aRatingString != nil) {
		NSLog(@"Unknown rating information: %@", target1);
	}
	for (NSDictionary *countryRatings in ratingsDictionary) {
		if ([[countryRatings valueForKey:@"country"] isEqualToString:aCountry]) {
			for (NSDictionary *rating in [countryRatings valueForKey:@"ratings"]) {
				if ([[rating valueForKey:@"itunes-value"] isEqualToString:@"???"]) {
					return [self ratingIndexForiTunesCode:[NSString stringWithFormat:@"%@|%@|%@|", [rating valueForKey:@"prefix"], [rating valueForKey:@"itunes-code"], [rating valueForKey:@"itunes-value"]]];
				}
			}
		}
	}
	return [self unknownIndex];
}

@end
