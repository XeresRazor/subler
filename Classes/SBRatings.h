//
//  SBRatings.h
//  Subler
//
//  Created by Douglas Stebila on 2013-06-02.
//
//

#import <Foundation/Foundation.h>

@interface SBRatings : NSObject {
	NSMutableArray *ratingsDictionary;
	NSMutableArray *ratings;
	NSMutableArray *iTunesCodes;
}

@property(readonly) NSMutableArray *ratings;
@property(readonly) NSMutableArray *iTunesCodes;

+ (SBRatings *) defaultManager;

- (void)updateRatingsCountry;
- (NSArray *) ratingsCountries;

- (NSUInteger) unknownIndex;
- (NSUInteger) ratingIndexForiTunesCode:(NSString *)aiTunesCode;
- (NSUInteger) ratingIndexForiTunesCountry:(NSString *)aCountry media:(NSString *)aMedia ratingString:(NSString *)aRatingString;

@end
