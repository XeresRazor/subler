//
//  MP42Metadata.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42Metadata.h"
#import "MP42Utilities.h"
#import "MP42XMLReader.h"
#import "MP42Image.h"
#import "RegexKitLite.h"
#import "SBRatings.h"

typedef struct mediaKind_t
{
    uint8_t stik;
    NSString *english_name;
} mediaKind_t;

static const mediaKind_t mediaKind_strings[] = {
    {0, @"Home Video"},
    {1, @"Music"},
    {2, @"Audiobook"},
    {6, @"Music Video"},
    {9, @"Movie"},
    {10, @"TV Show"},
    {11, @"Booklet"},
    {14, @"Ringtone"},
    {21, @"Podcast"},
    {23, @"iTunes U"},
    {0, NULL},
};

typedef struct contentRating_t
{
    uint8_t rtng;
    NSString *english_name;
} contentRating_t;

static const contentRating_t contentRating_strings[] = {
    {0, @"None"},
    {2, @"Clean"},
    {4, @"Explicit"},
    {0, NULL},
};

typedef struct genreType_t
{
    uint8_t index;
    const char *short_name;
    const char *english_name;
} genreType_t;

static const genreType_t genreType_strings[] = {
    {1,   "blues",             "Blues" },
    {2,   "classicrock",       "Classic Rock" },
    {3,   "country",           "Country" },
    {4,   "dance",             "Dance" },
    {5,   "disco",             "Disco" },
    {6,   "funk",              "Funk" },
    {7,   "grunge",            "Grunge" },
    {8,   "hiphop",            "Hop-Hop" },
    {9,   "jazz",              "Jazz" },
    {10,  "metal",             "Metal" },
    {11,  "newage",            "New Age" },
    {12,  "oldies",            "Oldies" },
    {13,  "other",             "Other" },
    {14,  "pop",               "Pop" },
    {15,  "rand_b",            "R&B" },
    {16,  "rap",               "Rap" },
    {17,  "reggae",            "Reggae" },
    {18,  "rock",              "Rock" },
    {19,  "techno",            "Techno" },
    {20,  "industrial",        "Industrial" },
    {21,  "alternative",       "Alternative" },
    {22,  "ska",               "Ska" },
    {23,  "deathmetal",        "Death Metal" },
    {24,  "pranks",            "Pranks" },
    {25,  "soundtrack",        "Soundtrack" },
    {26,  "eurotechno",        "Euro-Techno" },
    {27,  "ambient",           "Ambient" },
    {28,  "triphop",           "Trip-Hop" },
    {29,  "vocal",             "Vocal" },
    {30,  "jazzfunk",          "Jazz+Funk" },
    {31,  "fusion",            "Fusion" },
    {32,  "trance",            "Trance" },
    {33,  "classical",         "Classical" },
    {34,  "instrumental",      "Instrumental" },
    {35,  "acid",              "Acid" },
    {36,  "house",             "House" },
    {37,  "game",              "Game" },
    {38,  "soundclip",         "Sound Clip" },
    {39,  "gospel",            "Gospel" },
    {40,  "noise",             "Noise" },
    {41,  "alternrock",        "AlternRock" },
    {42,  "bass",              "Bass" },
    {43,  "soul",              "Soul" },
    {44,  "punk",              "Punk" },
    {45,  "space",             "Space" },
    {46,  "meditative",        "Meditative" },
    {47,  "instrumentalpop",   "Instrumental Pop" },
    {48,  "instrumentalrock",  "Instrumental Rock" },
    {49,  "ethnic",            "Ethnic" },
    {50,  "gothic",            "Gothic" },
    {51,  "darkwave",          "Darkwave" },
    {52,  "technoindustrial",  "Techno-Industrial" },
    {53,  "electronic",        "Electronic" },
    {54,  "popfolk",           "Pop-Folk" },
    {55,  "eurodance",         "Eurodance" },
    {56,  "dream",             "Dream" },
    {57,  "southernrock",      "Southern Rock" },
    {58,  "comedy",            "Comedy" },
    {59,  "cult",              "Cult" },
    {60,  "gangsta",           "Gangsta" },
    {61,  "top40",             "Top 40" },
    {62,  "christianrap",      "Christian Rap" },
    {63,  "popfunk",           "Pop/Funk" },
    {64,  "jungle",            "Jungle" },
    {65,  "nativeamerican",    "Native American" },
    {66,  "cabaret",           "Cabaret" },
    {67,  "newwave",           "New Wave" },
    {68,  "psychedelic",       "Psychedelic" },
    {69,  "rave",              "Rave" },
    {70,  "showtunes",         "Showtunes" },
    {71,  "trailer",           "Trailer" },
    {72,  "lofi",              "Lo-Fi" },
    {73,  "tribal",            "Tribal" },
    {74,  "acidpunk",          "Acid Punk" },
    {75,  "acidjazz",          "Acid Jazz" },
    {76,  "polka",             "Polka" },
    {77,  "retro",             "Retro" },
    {78,  "musical",           "Musical" },
    {79,  "rockand_roll",      "Rock & Roll" },
    
    {80,  "hardrock",          "Hard Rock" },
    {81,  "folk",              "Folk" },
    {82,  "folkrock",          "Folk-Rock" },
    {83,  "nationalfolk",      "National Folk" },
    {84,  "swing",             "Swing" },
    {85,  "fastfusion",        "Fast Fusion" },
    {86,  "bebob",             "Bebob" },
    {87,  "latin",             "Latin" },
    {88,  "revival",           "Revival" },
    {89,  "celtic",            "Celtic" },
    {90,  "bluegrass",         "Bluegrass" },
    {91,  "avantgarde",        "Avantgarde" },
    {92,  "gothicrock",        "Gothic Rock" },
    {93,  "progressiverock",   "Progresive Rock" },
    {94,  "psychedelicrock",   "Psychedelic Rock" },
    {95,  "symphonicrock",     "SYMPHONIC_ROCK" },
    {96,  "slowrock",          "Slow Rock" },
    {97,  "bigband",           "Big Band" },
    {98,  "chorus",            "Chorus" },
    {99,  "easylistening",     "Easy Listening" },
    {100, "acoustic",          "Acoustic" },
    {101, "humour",            "Humor" },
    {102, "speech",            "Speech" },
    {103, "chanson",           "Chason" },
    {104, "opera",             "Opera" },
    {105, "chambermusic",      "Chamber Music" },
    {106, "sonata",            "Sonata" },
    {107, "symphony",          "Symphony" },
    {108, "bootybass",         "Booty Bass" },
    {109, "primus",            "Primus" },
    {110, "porngroove",        "Porn Groove" },
    {111, "satire",            "Satire" },
    {112, "slowjam",           "Slow Jam" },
    {113, "club",              "Club" },
    {114, "tango",             "Tango" },
    {115, "samba",             "Samba" },
    {116, "folklore",          "Folklore" },
    {117, "ballad",            "Ballad" },
    {118, "powerballad",       "Power Ballad" },
    {119, "rhythmicsoul",      "Rhythmic Soul" },
    {120, "freestyle",         "Freestyle" },
    {121, "duet",              "Duet" },
    {122, "punkrock",          "Punk Rock" },
    {123, "drumsolo",          "Drum Solo" },
    {124, "acapella",          "A capella" },
    {125, "eurohouse",         "Euro-House" },
    {126, "dancehall",         "Dance Hall" },
    {255, "none",              "none" },
    
    {0, "undefined" } // must be last
};

@interface MP42Metadata (Private)

- (void)readMetaDataFromFileHandle:(MP4FileHandle)fileHandle;

@end

@implementation MP42Metadata

- (id)init
{
	if ((self = [super init]))
	{
        presetName = @"Unnamed Set";
		sourceURL = nil;
        tagsDict = [[NSMutableDictionary alloc] init];
        artworks = [[NSMutableArray alloc] init];
        isEdited = NO;
        isArtworkEdited = NO;
	}

    return self;
}

- (id)initWithSourceURL:(NSURL *)URL fileHandle:(MP4FileHandle)fileHandle
{
	if ((self = [super init]))
	{
		sourceURL = URL;
        tagsDict = [[NSMutableDictionary alloc] init];
        artworks = [[NSMutableArray alloc] init];

        [self readMetaDataFromFileHandle: fileHandle];
        isEdited = NO;
        isArtworkEdited = NO;
	}

    return self;
}

- (id)initWithFileURL:(NSURL *)URL;
{
    if ((self = [super init]))
	{
		sourceURL = URL;
        tagsDict = [[NSMutableDictionary alloc] init];
        artworks = [[NSMutableArray alloc] init];

        isEdited = NO;
        isArtworkEdited = NO;

        NSError *error;
        MP42XMLReader *xmlReader = [[MP42XMLReader alloc] initWithURL:URL error:&error];
        [self mergeMetadata:[xmlReader mMetadata]];
        [xmlReader release];
	}
    
    return self;
}

- (NSString *)stringFromArray:(NSArray *)array
{
    NSString *result = [NSString string];
    for (NSDictionary* name in array) {
        if ([result length])
            result = [result stringByAppendingString:@", "];
        result = [result stringByAppendingString:[name valueForKey:@"name"]];
    }
    return result;
}

- (NSArray *) dictArrayFromString:(NSString *)data
{
    NSString *splitElements  = @",\\s*+";
    NSArray *stringArray = [data componentsSeparatedByRegex:splitElements];
    NSMutableArray *dictElements = [[[NSMutableArray alloc] init] autorelease];
    for (NSString *name in stringArray) {
        [dictElements addObject:[NSDictionary dictionaryWithObject:name forKey:@"name"]];
    }
    return dictElements;
}

- (NSArray *) availableMetadata
{
    return [NSArray arrayWithObjects:
            @"Name",
            @"Artist",
            @"Album Artist",
            @"Album",
            @"Grouping",
            @"Composer",
			@"Comments",
            @"Genre",
            @"Release Date",
            @"Track #",
            @"Disk #",
            @"Tempo",
            @"TV Show",
            @"TV Episode #",
			@"TV Network",
            @"TV Episode ID",
            @"TV Season",
            @"Description",
            @"Long Description",
            @"Series Description",
            @"Rating",
            @"Rating Annotation",
            @"Studio",
            @"Cast",
            @"Director",
            @"Codirector",
            @"Producers",
            @"Screenwriters",
            @"Lyrics",
            @"Copyright",
            @"Encoding Tool",
            @"Encoded By",
            @"Keywords",
            @"Category",
            @"contentID",
            @"artistID",
            @"playlistID",
            @"genreID",
            @"composerID",
            @"XID",
            @"iTunes Account",
            @"iTunes Account Type",
            @"iTunes Country",
            @"Track Sub-Title",
            @"Song Description",
            @"Art Director",
            @"Arranger",
            @"Lyricist",
            @"Acknowledgement",
            @"Conductor",
            @"Linear Notes",
            @"Record Company",
            @"Original Artist",
            @"Phonogram Rights",
            @"Producer",
            @"Performer",
            @"Publisher",
            @"Sound Engineer",
            @"Soloist",
            @"Credits",
            @"Thanks",
            @"Online Extras",
            @"Executive Producer",
            @"Sort Name",
            @"Sort Artist",
            @"Sort Album Artist",
            @"Sort Album",
            @"Sort Composer",
            @"Sort TV Show", nil];
}

- (NSArray *) writableMetadata
{
    return [NSArray arrayWithObjects:
            @"Name",
            @"Artist",
            @"Album Artist",
            @"Album",
            @"Grouping",
            @"Composer",
			@"Comments",
            @"Genre",
            @"Release Date",
            @"Track #",
            @"Disk #",
            @"Tempo",
            @"TV Show",
            @"TV Episode #",
			@"TV Network",
            @"TV Episode ID",
            @"TV Season",
            @"Description",
            @"Long Description",
            @"Series Description",
            @"Rating",
            @"Rating Annotation",
            @"Studio",
            @"Cast",
            @"Director",
            @"Codirector",
            @"Producers",
            @"Screenwriters",
            @"Lyrics",
            @"Copyright",
            @"Encoding Tool",
            @"Encoded By",
            @"Keywords",
            @"Category",
            @"contentID",
            @"artistID",
            @"playlistID",
            @"genreID",
            @"composerID",
            @"XID",
            @"iTunes Account",
            @"iTunes Account Type",
            @"iTunes Country",
            @"Track Sub-Title",
            @"Song Description",
            @"Art Director",
            @"Arranger",
            @"Lyricist",
            @"Acknowledgement",
            @"Conductor",
            @"Linear Notes",
            @"Record Company",
            @"Original Artist",
            @"Phonogram Rights",
            @"Producer",
            @"Performer",
            @"Publisher",
            @"Sound Engineer",
            @"Soloist",
            @"Credits",
            @"Thanks",
            @"Online Extras",
            @"Executive Producer",
            @"Sort Name",
            @"Sort Artist",
            @"Sort Album Artist",
            @"Sort Album",
            @"Sort Composer",
            @"Sort TV Show", nil];
}

- (BOOL) setMediaKindFromString:(NSString *)mediaKindString;
{
    mediaKind_t *mediaKindList;
    for (mediaKindList = (mediaKind_t*) mediaKind_strings; mediaKindList->english_name; mediaKindList++) {
        if ([mediaKindString isEqualToString:mediaKindList->english_name]) {
            mediaKind = mediaKindList->stik;
            return YES;      
        }
    }
    return NO;
}

- (BOOL) setContentRatingFromString:(NSString *)contentRatingString;
{
    contentRating_t *contentRatingList;
    for ( contentRatingList = (contentRating_t*) contentRating_strings; contentRatingList->english_name; contentRatingList++) {
        if ([contentRatingString isEqualToString:contentRatingList->english_name]) {
            contentRating = contentRatingList->rtng;
            return YES;      
        }
    }
    return NO;
}

- (BOOL) setArtworkFromFilePath:(NSString *)imageFilePath;
{
    if(imageFilePath != nil && [imageFilePath length] > 0) {
        NSImage *artworkImage = nil;
        artworkImage = [[NSImage alloc] initByReferencingFile:imageFilePath];
        if([artworkImage isValid]) {
            MP42Image *artwork = [[MP42Image alloc] initWithImage:artworkImage];
            [artworks addObject:artwork];
            [artworkImage release];
            [artwork release];
            isEdited =YES;
            isArtworkEdited = YES;
            return YES;
        } else {
            [artworkImage release];
            return NO;
        }
    } else {
        [artworks release];
        artworks = nil;
        isEdited =YES;
        isArtworkEdited = YES;
        return YES;
    }
}

- (NSString *) genreFromIndex: (NSInteger)index {
    if ((index >= 0 && index < 127) || index == 255) {
        genreType_t *genre = (genreType_t*) genreType_strings;
        genre += index - 1;
        return [NSString stringWithUTF8String:genre->english_name];
    }
    else return nil;
}

- (NSInteger) genreIndexFromString: (NSString *)genreString {
    NSInteger genreIndex = 0;
    genreType_t *genreList;
    NSInteger k = 0;
    for ( genreList = (genreType_t*) genreType_strings; genreList->english_name; genreList++, k++ ) {
        if ([genreString isEqualToString:[NSString stringWithUTF8String:genreList->english_name]])
            genreIndex = k + 1;
    }
    return genreIndex;
}

- (NSArray *) availableGenres
{
    return [NSArray arrayWithObjects:  @"Animation", @"Classic TV", @"Comedy", @"Drama", 
            @"Fitness & Workout", @"Kids", @"Non-Fiction", @"Reality TV", @"Sci-Fi & Fantasy",
            @"Sports", nil];
}

- (void) removeTagForKey:(NSString *)aKey
{
    [tagsDict removeObjectForKey:aKey];
    isEdited = YES;
}

- (BOOL) setTag:(id)value forKey:(NSString *)key;
{
    BOOL noErr = YES;
    NSString *regexPositive = @"YES|Yes|yes|1|2";
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    if ([key isEqualToString:@"HD Video"]) {
        if ([value isKindOfClass:[NSNumber class]])
            hdVideo = [value integerValue];
        else if( value != nil && [value length] > 0 && [value isMatchedByRegex:regexPositive])
            hdVideo = [value integerValue];
        else
            hdVideo = 0;

        isEdited = YES;
    }
    else if ([key isEqualToString:@"Genre"]) {
        if ([value isKindOfClass:[NSNumber class]]) {
            [tagsDict setValue:[self genreFromIndex:[value integerValue]] forKey:key];
            isEdited = YES;
        }
        else if ([value isKindOfClass:[NSData class]]) {
            if ([value length] >= 2) {
                uint8_t* bytes = (uint8_t*)malloc([value length]);
                memcpy(bytes, [value bytes], [value length]);
                int genre = ((bytes[0]) <<  8)
                            | ((bytes[1])    );

                free(bytes);
                [tagsDict setValue:[self genreFromIndex:genre] forKey:key];
                isEdited = YES;
            }
        }
        else {
            [tagsDict setValue:value forKey:key];
            isEdited = YES;
        }
    }
    else if ([key isEqualToString:@"Gapless"]) {
        if ([value isKindOfClass:[NSNumber class]]) {
            gapless = [value integerValue];
            isEdited = YES;
        }
        else if( value != nil && [value length] > 0 && [value isMatchedByRegex:regexPositive]) {
            gapless = 1;
            isEdited = YES;
        }
        else {
            gapless = 0;
            isEdited = YES;
        }
    }
    else if ([key isEqualToString:@"Track #"]) {
        isEdited = YES;
        if ([value isKindOfClass:[NSData class]]) {
            uint8_t* bytes = (uint8_t*)malloc([value length]);
            memcpy(bytes, [value bytes], [value length]);
            int index = ((bytes[2]) <<  8)
                      | ((bytes[3])      );
            int total = ((bytes[4]) <<  8)
                      | ((bytes[5])      );

            free(bytes);
            NSString *trackN = [NSString stringWithFormat:@"%d/%d", index, total];
            [tagsDict setValue:trackN forKey:key];
        }
        else {
            [tagsDict setValue:value forKey:key];
        }
    }
    else if ([key isEqualToString:@"Disk #"]) {
        isEdited = YES;
        if ([value isKindOfClass:[NSData class]]) {
            uint8_t* bytes = (uint8_t*)malloc([value length]);
            memcpy(bytes, [value bytes], [value length]);
            int index = ((bytes[2]) <<  8)
            | ((bytes[3])      );
            int total = ((bytes[4]) <<  8)
            | ((bytes[5])      );

            free(bytes);
            NSString *diskN = [NSString stringWithFormat:@"%d/%d", index, total];
            [tagsDict setValue:diskN forKey:key];
        }
        else {
            [tagsDict setValue:value forKey:key];
        }
    }
    else if ([key isEqualToString:@"Content Rating"]) {
        isEdited = YES;
        if ([value isKindOfClass:[NSNumber class]]) {
            contentRating = [value integerValue];
        }
        else
            [self setContentRatingFromString:value];
        
    }
    else if ([key isEqualToString:@"Media Kind"]) {
        isEdited = YES;
        if ([value isKindOfClass:[NSNumber class]]) {
            mediaKind = [value integerValue];
        }
        else
            [self setMediaKindFromString:value];
    }
    else if ([key isEqualToString:@"Artwork"]) {
         [self setArtworkFromFilePath:value];
	}
    else if (![[tagsDict valueForKey:key] isEqualTo:value]) {
        [tagsDict setValue:value forKey:key];
        isEdited = YES;
    }
    else
        noErr = NO;
    
    [pool release];
    return noErr;
}

- (NSString *) stringFromMetadata:(const char*)cString {
    NSString *string;
    
    if ((string = [NSString stringWithCString:cString encoding: NSUTF8StringEncoding]))
        return string;

    if ((string = [NSString stringWithCString:cString encoding: NSASCIIStringEncoding]))
        return string;
    
    if ((string = [NSString stringWithCString:cString encoding: NSUTF16StringEncoding]))
        return string;

    return @"";
}

-(void) readMetaDataFromFileHandle:(MP4FileHandle)sourceHandle
{
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, sourceHandle );

    if (tags->name)
        [tagsDict setObject:[self stringFromMetadata:tags->name]
                     forKey:@"Name"];

    if (tags->artist)
        [tagsDict setObject:[self stringFromMetadata:tags->artist]
                     forKey:@"Artist"];

    if (tags->albumArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->albumArtist]
                     forKey:@"Album Artist"];

    if (tags->album)
        [tagsDict setObject:[self stringFromMetadata:tags->album]
                     forKey:@"Album"];

    if (tags->grouping)
        [tagsDict setObject:[self stringFromMetadata:tags->grouping]
                     forKey:@"Grouping"];

    if (tags->composer)
        [tagsDict setObject:[self stringFromMetadata:tags->composer]
                     forKey:@"Composer"];

    if (tags->comments)
        [tagsDict setObject:[self stringFromMetadata:tags->comments]
                     forKey:@"Comments"];

    if (tags->genre)
        [tagsDict setObject:[self stringFromMetadata:tags->genre]
                     forKey:@"Genre"];
    
    if (tags->genreType && !tags->genre) {
        [tagsDict setObject:[self genreFromIndex:*tags->genreType]
                     forKey:@"Genre"];
    }

    if (tags->releaseDate)
        [tagsDict setObject:[self stringFromMetadata:tags->releaseDate]
                     forKey:@"Release Date"];

    if (tags->track)
        [tagsDict setObject:[NSString stringWithFormat:@"%d/%d", tags->track->index, tags->track->total]
                     forKey:@"Track #"];
    
    if (tags->disk)
        [tagsDict setObject:[NSString stringWithFormat:@"%d/%d", tags->disk->index, tags->disk->total]
                     forKey:@"Disk #"];

    if (tags->tempo)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tempo]
                     forKey:@"Tempo"];

    if (tags->trackSubTitle)
        [tagsDict setObject:[self stringFromMetadata:tags->trackSubTitle]
                     forKey:@"Track Sub-Title"];

    if (tags->songDescription)
        [tagsDict setObject:[self stringFromMetadata:tags->songDescription]
                     forKey:@"Song Description"];

    if (tags->artDirector)
        [tagsDict setObject:[self stringFromMetadata:tags->artDirector]
                     forKey:@"Art Director"];

    if (tags->arranger)
        [tagsDict setObject:[self stringFromMetadata:tags->arranger]
                     forKey:@"Arranger"];

    if (tags->lyricist)
        [tagsDict setObject:[self stringFromMetadata:tags->lyricist]
                     forKey:@"Lyricist"];

    if (tags->acknowledgement)
        [tagsDict setObject:[self stringFromMetadata:tags->acknowledgement]
                     forKey:@"Acknowledgement"];

    if (tags->conductor)
        [tagsDict setObject:[self stringFromMetadata:tags->conductor]
                     forKey:@"Conductor"];

    if (tags->linearNotes)
        [tagsDict setObject:[self stringFromMetadata:tags->linearNotes]
                     forKey:@"Linear Notes"];

    if (tags->recordCompany)
        [tagsDict setObject:[self stringFromMetadata:tags->recordCompany]
                     forKey:@"Record Company"];

    if (tags->originalArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->originalArtist]
                     forKey:@"Original Artist"];

    if (tags->phonogramRights)
        [tagsDict setObject:[self stringFromMetadata:tags->phonogramRights]
                     forKey:@"Phonogram Rights"];
    
    if (tags->producer)
        [tagsDict setObject:[self stringFromMetadata:tags->producer]
                     forKey:@"Producer"];

    if (tags->performer)
        [tagsDict setObject:[self stringFromMetadata:tags->performer]
                     forKey:@"Performer"];

    if (tags->publisher)
        [tagsDict setObject:[self stringFromMetadata:tags->publisher]
                     forKey:@"Publisher"];

    if (tags->soundEngineer)
        [tagsDict setObject:[self stringFromMetadata:tags->soundEngineer]
                     forKey:@"Sound Engineer"];

    if (tags->soloist)
        [tagsDict setObject:[self stringFromMetadata:tags->soloist]
                     forKey:@"Soloist"];

    if (tags->credits)
        [tagsDict setObject:[self stringFromMetadata:tags->credits]
                     forKey:@"Credits"];

    if (tags->thanks)
        [tagsDict setObject:[self stringFromMetadata:tags->thanks]
                     forKey:@"Thanks"];

    if (tags->onlineExtras)
        [tagsDict setObject:[self stringFromMetadata:tags->onlineExtras]
                     forKey:@"Online Extras"];
    
    if (tags->executiveProducer)
        [tagsDict setObject:[self stringFromMetadata:tags->executiveProducer]
                     forKey:@"Executive Producer"];

    if (tags->tvShow)
        [tagsDict setObject:[self stringFromMetadata:tags->tvShow]
                     forKey:@"TV Show"];

    if (tags->tvEpisodeID)
        [tagsDict setObject:[self stringFromMetadata:tags->tvEpisodeID]
                     forKey:@"TV Episode ID"];

    if (tags->tvSeason)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tvSeason]
                     forKey:@"TV Season"];

    if (tags->tvEpisode)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->tvEpisode]
                     forKey:@"TV Episode #"];

    if (tags->tvNetwork)
        [tagsDict setObject:[self stringFromMetadata:tags->tvNetwork]
                     forKey:@"TV Network"];

    if (tags->description)
        [tagsDict setObject:[self stringFromMetadata:tags->description]
                     forKey:@"Description"];

    if (tags->longDescription)
        [tagsDict setObject:[self stringFromMetadata:tags->longDescription]
                     forKey:@"Long Description"];

    if (tags->seriesDescription)
        [tagsDict setObject:[self stringFromMetadata:tags->seriesDescription]
                     forKey:@"Series Description"];

    if (tags->lyrics)
        [tagsDict setObject:[self stringFromMetadata:tags->lyrics]
                     forKey:@"Lyrics"];

    if (tags->copyright)
        [tagsDict setObject:[self stringFromMetadata:tags->copyright]
                     forKey:@"Copyright"];

    if (tags->encodingTool)
        [tagsDict setObject:[self stringFromMetadata:tags->encodingTool]
                     forKey:@"Encoding Tool"];

    if (tags->encodedBy)
        [tagsDict setObject:[self stringFromMetadata:tags->encodedBy]
                     forKey:@"Encoded By"];

    if (tags->hdVideo)
        hdVideo = *tags->hdVideo;

    if (tags->mediaType)
        mediaKind = *tags->mediaType;
    
    if (tags->contentRating)
        contentRating = *tags->contentRating;
    
    if (tags->gapless)
        gapless = *tags->gapless;

    if (tags->purchaseDate)
        [tagsDict setObject:[self stringFromMetadata:tags->purchaseDate]
                     forKey:@"Purchase Date"];

    if (tags->iTunesAccount)
        [tagsDict setObject:[self stringFromMetadata:tags->iTunesAccount]
                     forKey:@"iTunes Account"];

    if( tags->iTunesAccountType )
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->iTunesAccountType]
                     forKey:@"iTunes Account Type"];

    if (tags->iTunesCountry)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->iTunesCountry]
                     forKey:@"iTunes Country"];

    if (tags->contentID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->contentID]
                     forKey:@"contentID"];

    if (tags->artistID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->artistID]
                     forKey:@"artistID"];

    if (tags->playlistID)
        [tagsDict setObject:[NSString stringWithFormat:@"%lld", *tags->playlistID]
                     forKey:@"playlistID"];

    if (tags->genreID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->genreID]
                     forKey:@"genreID"];

    if (tags->composerID)
        [tagsDict setObject:[NSString stringWithFormat:@"%d", *tags->composerID]
                     forKey:@"composerID"];

    if (tags->xid)
        [tagsDict setObject:[self stringFromMetadata:tags->xid]
                     forKey:@"XID"];    

    if (tags->sortName)
        [tagsDict setObject:[self stringFromMetadata:tags->sortName]
                     forKey:@"Sort Name"];

    if (tags->sortArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->sortArtist]
                     forKey:@"Sort Artist"];

    if (tags->sortAlbumArtist)
        [tagsDict setObject:[self stringFromMetadata:tags->sortAlbumArtist]
                     forKey:@"Sort Album Artist"];

    if (tags->sortAlbum)
        [tagsDict setObject:[self stringFromMetadata:tags->sortAlbum]
                     forKey:@"Sort Album"];

    if (tags->sortComposer)
        [tagsDict setObject:[self stringFromMetadata:tags->sortComposer]
                     forKey:@"Sort Composer"];

    if (tags->sortTVShow)
        [tagsDict setObject:[self stringFromMetadata:tags->sortTVShow]
                     forKey:@"Sort TV Show"];

    if (tags->podcast)
        podcast = *tags->podcast;

    if (tags->keywords)
        [tagsDict setObject:[self stringFromMetadata:tags->keywords]
                     forKey:@"Keywords"];

    if (tags->category)
        [tagsDict setObject:[self stringFromMetadata:tags->category]
                     forKey:@"Category"];

    if (tags->artwork) {
        uint32_t i;
        for (i = 0; i < tags->artworkCount; i++) {
            MP42Image *artwork = [[MP42Image alloc] initWithBytes:tags->artwork[i].data length:tags->artwork[i].size type:tags->artwork[i].type];
            [artworks addObject:artwork];
            [artwork release];
        }
    }

    MP4TagsFree(tags);

    /* read the remaining iTMF items */
    MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(sourceHandle, "com.apple.iTunes", "iTunEXTC");
    if (list) {
        uint32_t i;
        for (i = 0; i < list->size; i++) {
            MP4ItmfItem* item = &list->elements[i];
            uint32_t j;
            for (j = 0; j < item->dataList.size; j++) {
                MP4ItmfData* data = &item->dataList.elements[j];
                NSString *ratingString = [[NSString alloc] initWithBytes:data->value length: data->valueSize encoding:NSUTF8StringEncoding];
                NSString *splitElements  = @"\\|";
                NSArray *ratingItems = [ratingString componentsSeparatedByRegex:splitElements];
                [ratingString release];
				ratingiTunesCode = [[NSString stringWithFormat:@"%@|%@|%@|",[ratingItems objectAtIndex:0], [ratingItems objectAtIndex:1], [ratingItems objectAtIndex:2]] retain];
				[tagsDict setObject:[NSNumber numberWithUnsignedInteger:[[SBRatings defaultManager] ratingIndexForiTunesCode:ratingiTunesCode]] forKey:@"Rating"];
                if ([ratingItems count] >= 4)
                    [tagsDict setObject:[ratingItems objectAtIndex:3] forKey:@"Rating Annotation"];
            }
        }
        MP4ItmfItemListFree(list);
    }

    list = MP4ItmfGetItemsByMeaning(sourceHandle, "com.apple.iTunes", "iTunMOVI");
    if (list) {
        uint32_t i;
        for (i = 0; i < list->size; i++) {
            MP4ItmfItem* item = &list->elements[i];
            uint32_t j;
            for(j = 0; j < item->dataList.size; j++) {
                MP4ItmfData* data = &item->dataList.elements[j];
                NSData *xmlData = [NSData dataWithBytes:data->value length:data->valueSize];
                NSDictionary *dma = (NSDictionary *)[NSPropertyListSerialization
                                                         propertyListFromData:xmlData
                                                         mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                         format:nil
                                                         errorDescription:nil];
                
                NSString *tag;
                if ([tag = [self stringFromArray:[dma valueForKey:@"cast"]] length])
                    [tagsDict setObject:tag forKey:@"Cast"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"directors"]] length])
                    [tagsDict setObject:tag forKey:@"Director"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"codirectors"]] length])
                    [tagsDict setObject:tag forKey:@"Codirector"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"producers"]] length])
                    [tagsDict setObject:tag forKey:@"Producers"];
                if ([tag = [self stringFromArray:[dma valueForKey:@"screenwriters"]] length])
                    [tagsDict setObject:tag forKey:@"Screenwriters"];
                if ([tag = [dma valueForKey:@"studio"] length])
                    [tagsDict setObject:tag forKey:@"Studio"];
            }
        }
        MP4ItmfItemListFree(list);
    }
}

- (BOOL) writeMetadataWithFileHandle: (MP4FileHandle *)fileHandle
{
    if (!fileHandle)
        return NO;

    const MP4Tags* tags = MP4TagsAlloc();

    MP4TagsFetch(tags, fileHandle);

    MP4TagsSetName(tags, [[tagsDict valueForKey:@"Name"] UTF8String]);

    MP4TagsSetArtist(tags, [[tagsDict valueForKey:@"Artist"] UTF8String]);

    MP4TagsSetAlbumArtist(tags, [[tagsDict valueForKey:@"Album Artist"] UTF8String]);

    MP4TagsSetAlbum(tags, [[tagsDict valueForKey:@"Album"] UTF8String]);

    MP4TagsSetGrouping(tags, [[tagsDict valueForKey:@"Grouping"] UTF8String]);

    MP4TagsSetComposer(tags, [[tagsDict valueForKey:@"Composer"] UTF8String]);

    MP4TagsSetComments(tags, [[tagsDict valueForKey:@"Comments"] UTF8String]);

    uint16_t genreType = [self genreIndexFromString:[tagsDict valueForKey:@"Genre"]];
    if (genreType) {
        MP4TagsSetGenre(tags, NULL);
        MP4TagsSetGenreType(tags, &genreType);
    }
    else {
        MP4TagsSetGenreType(tags, NULL);
        MP4TagsSetGenre(tags, [[tagsDict valueForKey:@"Genre"] UTF8String]);
    }

    MP4TagsSetReleaseDate(tags, [[tagsDict valueForKey:@"Release Date"] UTF8String]);

    if ([tagsDict valueForKey:@"Track #"]) {
        MP4TagTrack dtrack; int trackNum = 0, totalTrackNum = 0;
        char separator;
        sscanf([[tagsDict valueForKey:@"Track #"] UTF8String],"%u%[/- ]%u", &trackNum, &separator, &totalTrackNum);
        dtrack.index = trackNum;
        dtrack.total = totalTrackNum;
        MP4TagsSetTrack(tags, &dtrack);
    }
    else
        MP4TagsSetTrack(tags, NULL);
    
    if ([tagsDict valueForKey:@"Disk #"]) {
        MP4TagDisk ddisk; int diskNum = 0, totalDiskNum = 0;
        char separator;
        sscanf([[tagsDict valueForKey:@"Disk #"] UTF8String],"%u%[/- ]%u", &diskNum, &separator, &totalDiskNum);
        ddisk.index = diskNum;
        ddisk.total = totalDiskNum;
        MP4TagsSetDisk(tags, &ddisk);
    }
    else
        MP4TagsSetDisk(tags, NULL);    
    
    if ([tagsDict valueForKey:@"Tempo"]) {
        const uint16_t i = [[tagsDict valueForKey:@"Tempo"] integerValue];
        MP4TagsSetTempo(tags, &i);
    }
    else
        MP4TagsSetTempo(tags, NULL);

    MP4TagsSetTrackSubTitle(tags, [[tagsDict valueForKey:@"Track Sub-Title"] UTF8String]);

    MP4TagsSetSongDescription(tags, [[tagsDict valueForKey:@"Song Description"] UTF8String]);

    MP4TagsSetArtDirector(tags, [[tagsDict valueForKey:@"Art Director"] UTF8String]);

    MP4TagsSetArranger(tags, [[tagsDict valueForKey:@"Arranger"] UTF8String]);

    MP4TagsSetLyricist(tags, [[tagsDict valueForKey:@"Lyricist"] UTF8String]);

    MP4TagsSetAcknowledgement(tags, [[tagsDict valueForKey:@"Acknowledgement"] UTF8String]);

    MP4TagsSetConductor(tags, [[tagsDict valueForKey:@"Conductor"] UTF8String]);

    MP4TagsSetLinearNotes(tags, [[tagsDict valueForKey:@"Linear Notes"] UTF8String]);

    MP4TagsSetRecordCompany(tags, [[tagsDict valueForKey:@"Record Company"] UTF8String]);

    MP4TagsSetOriginalArtist(tags, [[tagsDict valueForKey:@"Original Artist"] UTF8String]);

    MP4TagsSetPhonogramRights(tags, [[tagsDict valueForKey:@"Phonogram Rights"] UTF8String]);

    MP4TagsSetProducer(tags, [[tagsDict valueForKey:@"Producer"] UTF8String]);

    MP4TagsSetPerformer(tags, [[tagsDict valueForKey:@"Performer"] UTF8String]);

    MP4TagsSetPublisher(tags, [[tagsDict valueForKey:@"Publisher"] UTF8String]);

    MP4TagsSetSoundEngineer(tags, [[tagsDict valueForKey:@"Sound Engineer"] UTF8String]);

    MP4TagsSetSoloist(tags, [[tagsDict valueForKey:@"Soloist"] UTF8String]);

    MP4TagsSetCredits(tags, [[tagsDict valueForKey:@"Credits"] UTF8String]);

    MP4TagsSetThanks(tags, [[tagsDict valueForKey:@"Thanks"] UTF8String]);

    MP4TagsSetOnlineExtras(tags, [[tagsDict valueForKey:@"Online Extras"] UTF8String]);

    MP4TagsSetExecutiveProducer(tags, [[tagsDict valueForKey:@"Executive Producer"] UTF8String]);

    MP4TagsSetTVShow(tags, [[tagsDict valueForKey:@"TV Show"] UTF8String]);

    MP4TagsSetTVNetwork(tags, [[tagsDict valueForKey:@"TV Network"] UTF8String]);

    MP4TagsSetTVEpisodeID(tags, [[tagsDict valueForKey:@"TV Episode ID"] UTF8String]);

    if ([tagsDict valueForKey:@"TV Season"]) {
        const uint32_t i = [[tagsDict valueForKey:@"TV Season"] integerValue];
        MP4TagsSetTVSeason(tags, &i);
    }
    else
        MP4TagsSetTVSeason(tags, NULL);

    if ([tagsDict valueForKey:@"TV Episode #"]) {
        const uint32_t i = [[tagsDict valueForKey:@"TV Episode #"] integerValue];
        MP4TagsSetTVEpisode(tags, &i);
    }
    else
        MP4TagsSetTVEpisode(tags, NULL);

    MP4TagsSetDescription(tags, [[tagsDict valueForKey:@"Description"] UTF8String]);

    MP4TagsSetLongDescription(tags, [[tagsDict valueForKey:@"Long Description"] UTF8String]);
    
    MP4TagsSetSeriesDescription(tags, [[tagsDict valueForKey:@"Series Description"] UTF8String]);

    MP4TagsSetLyrics(tags, [[tagsDict valueForKey:@"Lyrics"] UTF8String]);

    MP4TagsSetCopyright(tags, [[tagsDict valueForKey:@"Copyright"] UTF8String]);

    MP4TagsSetEncodingTool(tags, [[tagsDict valueForKey:@"Encoding Tool"] UTF8String]);

    MP4TagsSetEncodedBy(tags, [[tagsDict valueForKey:@"Encoded By"] UTF8String]);

    MP4TagsSetPurchaseDate(tags, [[tagsDict valueForKey:@"Purchase Date"] UTF8String]);

    MP4TagsSetITunesAccount(tags, [[tagsDict valueForKey:@"iTunes Account"] UTF8String]);

    if (mediaKind != 0)
        MP4TagsSetMediaType(tags, &mediaKind);
    else
        MP4TagsSetMediaType(tags, NULL);

    if (mediaKind == 21) {
        const uint8_t n = 1;
        MP4TagsSetPodcast(tags, &n);
    }
    else
        MP4TagsSetPodcast(tags, NULL);

    if (mediaKind == 23) {
        const uint8_t n = 1;
        MP4TagsSetITunesU(tags, &n);
    }
    else
        MP4TagsSetITunesU(tags, NULL);

    if(hdVideo)
        MP4TagsSetHDVideo(tags, &hdVideo);
    else
        MP4TagsSetHDVideo(tags, NULL);
    
    if(gapless)
        MP4TagsSetGapless(tags, &gapless);
    else
        MP4TagsSetGapless(tags, NULL);
    
    if(podcast)
        MP4TagsSetPodcast(tags, &podcast);
    else
        MP4TagsSetPodcast(tags, NULL);

    MP4TagsSetKeywords(tags, [[tagsDict valueForKey:@"Keywords"] UTF8String]);

    MP4TagsSetCategory(tags, [[tagsDict valueForKey:@"Category"] UTF8String]);

    MP4TagsSetContentRating(tags, &contentRating);

    if ([tagsDict valueForKey:@"iTunes Country"]) {
        const uint32_t i = [[tagsDict valueForKey:@"iTunes Country"] integerValue];
        MP4TagsSetITunesCountry(tags, &i);
    }
    else
        MP4TagsSetITunesCountry(tags, NULL);    

    if ([tagsDict valueForKey:@"contentID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"contentID"] integerValue];
        MP4TagsSetContentID(tags, &i);
    }
    else
        MP4TagsSetContentID(tags, NULL);

    if ([tagsDict valueForKey:@"genreID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"genreID"] integerValue];
        MP4TagsSetGenreID(tags, &i);
    }
    else
        MP4TagsSetGenreID(tags, NULL);

    if ([tagsDict valueForKey:@"artistID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"artistID"] integerValue];
        MP4TagsSetArtistID(tags, &i);
    }
    else
        MP4TagsSetArtistID(tags, NULL);

    if ([tagsDict valueForKey:@"playlistID"]) {
        const uint64_t i = [[tagsDict valueForKey:@"playlistID"] integerValue];
        MP4TagsSetPlaylistID(tags, &i);
    }
    else
        MP4TagsSetPlaylistID(tags, NULL);

    if ([tagsDict valueForKey:@"composerID"]) {
        const uint32_t i = [[tagsDict valueForKey:@"composerID"] integerValue];
        MP4TagsSetComposerID(tags, &i);
    }
    else
        MP4TagsSetComposerID(tags, NULL);

    MP4TagsSetXID(tags, [[tagsDict valueForKey:@"XID"] UTF8String]);

    MP4TagsSetSortName(tags, [[tagsDict valueForKey:@"Sort Name"] UTF8String]);

    MP4TagsSetSortArtist(tags, [[tagsDict valueForKey:@"Sort Artist"] UTF8String]);

    MP4TagsSetSortAlbumArtist(tags, [[tagsDict valueForKey:@"Sort Album Artist"] UTF8String]);

    MP4TagsSetSortAlbum(tags, [[tagsDict valueForKey:@"Sort Album"] UTF8String]);

    MP4TagsSetSortComposer(tags, [[tagsDict valueForKey:@"Sort Composer"] UTF8String]);

    MP4TagsSetSortTVShow(tags, [[tagsDict valueForKey:@"Sort TV Show"] UTF8String]);

    uint32_t j;
    for (j = 0; j < tags->artworkCount; j++)
        MP4TagsRemoveArtwork(tags, j);

    if ([artworks count] && isArtworkEdited) {
        uint32_t i;
        for (i = 0; i < [artworks count]; i++) {
            MP42Image *artwork;
            MP4TagArtwork newArtwork;
            NSArray *representations;
            NSData *bitmapData;

            artwork = [artworks objectAtIndex:i];
            if (artwork.data) {
                newArtwork.data = (void *)[artwork.data bytes];
                newArtwork.size = [artwork.data length];
                newArtwork.type = artwork.type;
            }
            else {
                representations = [artwork.image representations];
                bitmapData = [NSBitmapImageRep representationOfImageRepsInArray:representations
                                                                      usingType:NSPNGFileType properties:nil];

                newArtwork.data = (void *)[bitmapData bytes];
                newArtwork.size = [bitmapData length];
                newArtwork.type = MP4_ART_PNG;
            }

            if (tags->artworkCount > i)
                MP4TagsSetArtwork(tags, i, &newArtwork);
            else
                MP4TagsAddArtwork(tags, &newArtwork);
        }
    }

    MP4TagsStore(tags, fileHandle);
    MP4TagsFree(tags);

    /* Rewrite extended metadata using the generic iTMF api */

    if ([tagsDict valueForKey:@"Rating"]) {
        MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunEXTC");
        if (list) {
            uint32_t i;
            for (i = 0; i < list->size; i++) {
                MP4ItmfItem* item = &list->elements[i];
                MP4ItmfRemoveItem(fileHandle, item);
            }
        }
        MP4ItmfItemListFree(list);

        MP4ItmfItem* newItem = MP4ItmfItemAlloc( "----", 1 );
        newItem->mean = strdup( "com.apple.iTunes" );
        newItem->name = strdup( "iTunEXTC" );

        MP4ItmfData* data = &newItem->dataList.elements[0];

		if ([[tagsDict valueForKey:@"Rating"] unsignedIntegerValue] == [[SBRatings defaultManager] unknownIndex]) {
			if (!ratingiTunesCode) {
				ratingiTunesCode = [[[SBRatings defaultManager] iTunesCodes] objectAtIndex:[[SBRatings defaultManager] unknownIndex]];
			}
		} else {
			ratingiTunesCode = [[[SBRatings defaultManager] iTunesCodes] objectAtIndex:[[tagsDict valueForKey:@"Rating"] unsignedIntegerValue]];
		}
		NSString *ratingString = ratingiTunesCode;
        if ([[tagsDict valueForKey:@"Rating Annotation"] length] && [ratingString length]) {
			ratingString = [NSString stringWithFormat:@"%@%@", ratingString, [tagsDict valueForKey:@"Rating Annotation"]];
		}
        data->typeCode = MP4_ITMF_BT_UTF8;
        data->valueSize = strlen([ratingString UTF8String]);
        data->value = (uint8_t*)malloc( data->valueSize );
        memcpy( data->value, [ratingString UTF8String], data->valueSize );

        MP4ItmfAddItem(fileHandle, newItem);
        MP4ItmfItemFree(newItem);
    }
    else {
        MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunEXTC");
        if (list) {
            uint32_t i;
            for (i = 0; i < list->size; i++) {
                MP4ItmfItem* item = &list->elements[i];
                MP4ItmfRemoveItem(fileHandle, item);
            }
        }
        MP4ItmfItemListFree(list);
    }

    MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunMOVI");
    NSMutableDictionary *iTunMovi = [[NSMutableDictionary alloc] init];;
    if (list) {
        uint32_t i;
        for (i = 0; i < list->size; i++) {
            MP4ItmfItem* item = &list->elements[i];
            uint32_t j;
            for(j = 0; j < item->dataList.size; j++) {
                MP4ItmfData* data = &item->dataList.elements[j];
                NSData *xmlData = [NSData dataWithBytes:data->value length:data->valueSize];
                NSDictionary *dma = (NSDictionary *)[NSPropertyListSerialization
                                                     propertyListFromData:xmlData
                                                     mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                     format:nil
                                                     errorDescription:nil];
                [iTunMovi release];
                iTunMovi = [dma mutableCopy];
            }
        }
        MP4ItmfItemListFree(list);
    }

    if (iTunMovi) {
        if ([tagsDict valueForKey:@"Cast"])
            [iTunMovi setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Cast"]] forKey:@"cast"];
        else
            [iTunMovi removeObjectForKey:@"cast"];

        if ([tagsDict valueForKey:@"Director"])
            [iTunMovi setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Director"]] forKey:@"directors"];
        else
            [iTunMovi removeObjectForKey:@"directors"];

        if ([tagsDict valueForKey:@"Codirector"])
            [iTunMovi setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Codirector"]] forKey:@"codirectors"];
        else
            [iTunMovi removeObjectForKey:@"codirectors"];

        if ([tagsDict valueForKey:@"Producers"])
            [iTunMovi setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Producers"]] forKey:@"producers"];
        else
            [iTunMovi removeObjectForKey:@"producers"];

        if ([tagsDict valueForKey:@"Screenwriters"])
            [iTunMovi setObject:[self dictArrayFromString:[tagsDict valueForKey:@"Screenwriters"]] forKey:@"screenwriters"];
        else
            [iTunMovi removeObjectForKey:@"screenwriters"];

        if ([tagsDict valueForKey:@"Studio"])
            [iTunMovi setObject:[tagsDict valueForKey:@"Studio"] forKey:@"studio"];
        else
            [iTunMovi removeObjectForKey:@"studio"];

        NSData *serializedPlist = [NSPropertyListSerialization
                                        dataFromPropertyList:iTunMovi
                                        format:NSPropertyListXMLFormat_v1_0
                                        errorDescription:nil];
        if ([iTunMovi count]) {
            MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunMOVI");
            if (list) {
                uint32_t i;
                for (i = 0; i < list->size; i++) {
                    MP4ItmfItem* item = &list->elements[i];
                    MP4ItmfRemoveItem(fileHandle, item);
                }
            }
            MP4ItmfItemListFree(list);

            MP4ItmfItem* newItem = MP4ItmfItemAlloc( "----", 1 );
            newItem->mean = strdup( "com.apple.iTunes" );
            newItem->name = strdup( "iTunMOVI" );

            MP4ItmfData* data = &newItem->dataList.elements[0];
            data->typeCode = MP4_ITMF_BT_UTF8;
            data->valueSize = [serializedPlist length];
            data->value = (uint8_t*)malloc( data->valueSize );
            memcpy( data->value, [serializedPlist bytes], data->valueSize );

            MP4ItmfAddItem(fileHandle, newItem);
            MP4ItmfItemFree(newItem);
        }
        else {
            MP4ItmfItemList* list = MP4ItmfGetItemsByMeaning(fileHandle, "com.apple.iTunes", "iTunMOVI");
            if (list) {
                uint32_t i;
                for (i = 0; i < list->size; i++) {
                    MP4ItmfItem* item = &list->elements[i];
                    MP4ItmfRemoveItem(fileHandle, item);
                }
            }
            MP4ItmfItemListFree(list);
        }
    }

    [iTunMovi release];

    return YES;
}

- (BOOL) mergeMetadata: (MP42Metadata *) newMetadata
{
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    NSString * tagValue;

    [newMetadata retain];

    for (NSString * key in [self writableMetadata])
            if((tagValue = [newMetadata.tagsDict valueForKey:key]))
                [tagsDict setObject:tagValue forKey:key];

    for (NSImage *artwork in newMetadata.artworks) {
        isArtworkEdited = YES;
        [artworks addObject:artwork];
    }

    mediaKind = newMetadata.mediaKind;
    contentRating = newMetadata.contentRating;
    gapless = newMetadata.gapless;
    hdVideo = newMetadata.hdVideo;

    isEdited = YES;

    [newMetadata release];

    [pool release];

    return YES;
}

@synthesize presetName;

@synthesize isEdited;

@synthesize artworks;

@synthesize isArtworkEdited;
@synthesize artworkURL;
@synthesize artworkThumbURLs;
@synthesize artworkFullsizeURLs;
@synthesize artworkProviderNames;

@synthesize mediaKind;
@synthesize contentRating;
@synthesize hdVideo;
@synthesize gapless;
@synthesize podcast;

@synthesize tagsDict;


- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:2 forKey:@"MP42TagEncodeVersion"];

    [coder encodeObject:presetName forKey:@"MP42SetName"];
    [coder encodeObject:tagsDict forKey:@"MP42TagsDict"];
    [coder encodeObject:artworks forKey:@"MP42Artwork"];
    [coder encodeBool:isArtworkEdited forKey:@"MP42ArtworkEdited"];

    [coder encodeInt:mediaKind forKey:@"MP42MediaKind"];
    [coder encodeInt:contentRating forKey:@"MP42ContentRating"];
    [coder encodeInt:hdVideo forKey:@"MP42HDVideo"];
    [coder encodeInt:gapless forKey:@"MP42Gapless"];
    [coder encodeInt:podcast forKey:@"MP42Podcast"];

    [coder encodeBool:isEdited forKey:@"MP42Edited"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    presetName = [[decoder decodeObjectForKey:@"MP42SetName"] retain];

    tagsDict = [[decoder decodeObjectForKey:@"MP42TagsDict"] retain];
    // Add version 1 support
    artworks = [[decoder decodeObjectForKey:@"MP42Artwork"] retain];
    isArtworkEdited = [decoder decodeBoolForKey:@"MP42ArtworkEdited"];

    mediaKind = [decoder decodeIntForKey:@"MP42MediaKind"];
    contentRating = [decoder decodeIntForKey:@"MP42ContentRating"];
    hdVideo = [decoder decodeIntForKey:@"MP42HDVideo"];
    gapless = [decoder decodeIntForKey:@"MP42Gapless"];
    podcast = [decoder decodeIntForKey:@"MP42Podcast"];

    isEdited = [decoder decodeBoolForKey:@"MP42Edited"];

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    MP42Metadata *newObject = [[MP42Metadata allocWithZone:zone] init];

    if (presetName)
        newObject.presetName = presetName;

    [newObject mergeMetadata:self];

    newObject.contentRating = contentRating;
    newObject.gapless = gapless;
    newObject.hdVideo = hdVideo;
    newObject.podcast = podcast;

    return newObject;
}

-(void) dealloc
{
    [presetName release];

    [artworks release];

    [artworkURL release];
    [artworkThumbURLs release];
    [artworkFullsizeURLs release];
    [artworkProviderNames release];

    [tagsDict release];
    [super dealloc];
}

@end
