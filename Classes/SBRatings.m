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
	if (self) {
		NSString* ratingsJSON = [[NSBundle mainBundle] pathForResource:@"Ratings" ofType:@"json"];
		JSONDecoder *jsonDecoder = [JSONDecoder decoder];
		ratingsDictionary = [[jsonDecoder objectWithData:[NSData dataWithContentsOfFile:ratingsJSON]] retain];
		// construct movie ratings
		ratings = [[NSMutableArray alloc] init];
		iTunesCodes = [[NSMutableArray alloc] init];
		for (NSDictionary *countryRatings in ratingsDictionary) {
			NSString *countryName = [countryRatings valueForKey:@"country"];
			for (NSDictionary *rating in [countryRatings valueForKey:@"ratings"]) {
				[ratings addObject:[NSString stringWithFormat:@"%@ %@: %@", countryName, [rating valueForKey:@"media"], [rating valueForKey:@"description"]]];
				[iTunesCodes addObject:[NSString stringWithFormat:@"%@|%@|%@|", [rating valueForKey:@"prefix"], [rating valueForKey:@"itunes-code"], [rating valueForKey:@"itunes-value"]]];
			}
		}
	}
	return self;
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
