//
//  SublerCLI.mm
//  Subler
//
//  Copyright 2009-2013 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "RegexKitLite.h"

void print_help()
{
    printf("usage:\n");

    printf("\t -dest <destination file> \n");
    printf("\t -dest options:\n");

    printf("\t\t -chapters <chapters file> \n");
    printf("\t\t -chapterspreview Create chapters preview images \n");
    printf("\t\t -remove Remove existing subtitles \n");
    printf("\t\t -optimize Optimize \n");
    printf("\t\t -metadata {Tag Name:Tag Value} \n");
    printf("\t\t -removemetadata remove all the tags \n");
    printf("\t\t -itunesfriendly enable tracks and create altenate groups in the iTunes friendly way\n");
    printf("\t\t -vprofile sets the video profile to any of <baseline, main, [high]>\n");
    printf("\t\t -vlevel sets the video level <21, 31, [41]>\n");
    printf("\n");

    printf("\t -source <source file> \n");
    printf("\t -source options:\n");
    printf("\t\t -listtracks For source file only, lists the tracks in the source movie. \n");
    printf("\t\t -listmetadata For source file only, lists the metadata in the source movie. \n");
    printf("\n");
    printf("\t\t -delay Delay in ms \n");
    printf("\t\t -height Height in pixel \n");
    printf("\t\t -language Track language (i.e. English) \n");
    printf("\t\t -downmix Downmix audio (mono, stereo, dolby, pl2) \n");
    printf("\t\t -64bitchunk 64bit file (only when -dest isn't an existing file) \n");
    printf("\n");

    printf("\t -help Print this help information \n");
    printf("\t -version Print version \n");
}

void print_version()
{
    printf("\t\tversion 0.22\n");
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    NSString *destinationPath = nil;
    NSString *sourcePath = nil;
    NSString *chaptersPath = nil;
    NSString *metadata = nil;

    NSString *language = NULL;
    int delay = 0;
    unsigned int height = 0;
    BOOL removeExisting = false;
    BOOL chapterPreview = false;
    BOOL modified = false;
    BOOL optimize = false;
    
    BOOL listtracks = false;
    BOOL listmetadata = false;
    BOOL removemetadata = false;

    BOOL itunesfriendly = NO;

    BOOL _64bitchunk = NO;
    BOOL downmixAudio = NO;
    NSString *downmixArg = nil;
    NSString *downmixType = nil;
    
    unsigned int videoprofile = 100; //high
    unsigned int videolevel = 41;    //4.1

    if (argc == 1) {
        print_help();
        exit(-1);
    }

    argv += 1;
    argc--;

	while ( argc > 0 && **argv == '-' )
	{
		const char*	args = &(*argv)[1];
		
		argc--;
		argv++;
        
		if ( ! strcmp ( args, "source" ) )
		{
            sourcePath = @(*argv++);
			argc--;
		}
		else if (( ! strcmp ( args, "dest" )) || ( ! strcmp ( args, "destination" )) )
		{
			destinationPath = @(*argv++);
			argc--;
		}
        else if ( ! strcmp ( args, "chapters" ) )
		{
			chaptersPath = @(*argv++);
			argc--;
		}
        else if ( ! strcmp ( args, "chapterspreview" ) )
		{
			chapterPreview = YES;
		}
        else if ( ! strcmp ( args, "metadata" ) )
		{
			metadata = @(*argv++);
            argc--;
		}
        else if ( ! strcmp ( args, "optimize" ) )
		{
			optimize = YES;
		}
        else if ( ! strcmp ( args, "downmix" ) )
		{
            downmixAudio = YES;
            downmixArg = @(*argv++);
            if(![downmixArg caseInsensitiveCompare:@"mono"]) downmixType = SBMonoMixdown;
            else if(![downmixArg caseInsensitiveCompare:@"stereo"]) downmixType = SBStereoMixdown;
            else if(![downmixArg caseInsensitiveCompare:@"dolby"]) downmixType = SBDolbyMixdown;
            else if(![downmixArg caseInsensitiveCompare:@"pl2"]) downmixType = SBDolbyPlIIMixdown;
            else {
                printf( "Error: unsupported downmix type '%s'\n", optarg );
                printf( "Valid downmix types are: 'mono', 'stereo', 'dolby' and 'pl2'\n" );
                exit( -1 );
            }
            argc--;
		}
        else if ( ! strcmp ( args, "64bitchunk" ) )
        {
            _64bitchunk = YES;
        }
        else if ( ! strcmp ( args, "delay" ) )
		{
			delay = atoi(*argv++);
            argc--;
		}
        else if ( ! strcmp ( args, "height" ) )
		{
            height = atoi(*argv++);
            argc--;
		}
        else if ( ! strcmp ( args, "language" ) )
		{
            language = @(*argv++);
			argc--;
		}
        else if ( ! strcmp ( args, "remove" ) )
		{
            removeExisting = YES;
		}
		else if (( ! strcmp ( args, "version" )) || ( ! strcmp ( args, "v" )) )
		{
			print_version();
		}
		else if ( ! strcmp ( args, "help" ) )
		{
			print_help();
		}
        else if ( ! strcmp ( args, "listtracks" ) )
		{
			listtracks = YES;
		}
        else if ( ! strcmp ( args, "listmetadata" ) )
		{
			listmetadata = YES;
		}
        else if ( ! strcmp ( args, "removemetadata" ) )
		{
			removemetadata = YES;
		}
        else if ( ! strcmp ( args, "itunesfriendly" ) )
		{
			itunesfriendly = YES;
		}
        else if ( ! strcmp ( args, "vprofile" ) )
		{
            if (argc) {
                const char *arg = *argv++;
                
                if (!strcmp(arg, "baseline")) videoprofile = 66;
                else if(!strcmp(arg, "main")) videoprofile = 77;
                else if(!strcmp(arg, "high")) videoprofile = 100;
                else {
                    printf( "Error: unsupported profile '%s'\n", arg );
                    printf( "Valid profiles are: 'baseline', 'main' and 'high'\n" );
                    exit( -1 );
                }
                argc--;
			}
            else {
                print_help();
                exit(-1);
            }
		}
        else if ( ! strcmp ( args, "vlevel" ) )
		{
            if (argc) {
                videolevel = atoi(*argv++);
                argc--;
            }
            else {
                print_help();
                exit(-1);
            }
		}
		else {
			printf("Invalid input parameter: %s\n", args );
			print_help();
			return nil;
		}
	}

    // Don't let the user mux a file to the file itself
    if ([sourcePath isEqualToString:destinationPath]) {
        printf("The destination path need to be different from the source path\n");
        exit(1);
    }
    
    if (sourcePath && (listtracks || listmetadata)) {
        MP42File *mp4File;

        if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
            mp4File = [[MP42File alloc] initWithExistingFile:[NSURL fileURLWithPath:sourcePath]
                                                 andDelegate:nil];

        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be opened.");
            return -1;
        }

        if (listtracks) {
            for (MP42Track* track in mp4File.tracks) {
                printf("%s\n", [[track description] UTF8String]);
            }
        }

        if (listmetadata) {
            NSArray * availableMetadata = [[mp4File metadata] availableMetadata];
            NSDictionary * tagsDict = [[mp4File metadata] tagsDict];

            for (NSString* key in availableMetadata) {
                NSString* tag = [tagsDict valueForKey:key];
                if (tag) {
                    if ([tag isKindOfClass:[NSString class]])
                        printf("%s: %s\n", [key UTF8String], [tag UTF8String]);
                    if ([tag isKindOfClass:[NSNumber class]])
                        printf("%s: %ld\n", [key UTF8String], (long)[tag integerValue]);
                }
            }

            if ([[mp4File metadata] hdVideo]) {
                printf("HD Video: %d\n", [[mp4File metadata] hdVideo]);
            }
            if ([[mp4File metadata] gapless]) {
                printf("Gapless: %d\n", [[mp4File metadata] gapless]);
            }
            if ([[mp4File metadata] contentRating]) {
                printf("Content Rating: %d\n", [[mp4File metadata] contentRating]);
            }
            if ([[mp4File metadata] podcast]) {
                printf("Podcast: %d\n", [[mp4File metadata] podcast]);
            }
            if ([[mp4File metadata] mediaKind]) {
                printf("Media Kind: %d\n", [[mp4File metadata] mediaKind]);
            }
        }

        return 0;
    }
    
    NSMutableDictionary * attributes = [[NSMutableDictionary alloc] init];
    if (chapterPreview)
        [attributes setObject:@YES forKey:MP42CreateChaptersPreviewTrack];
    
    if ((sourcePath && [[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) || itunesfriendly || chaptersPath || removeExisting || metadata || chapterPreview || removemetadata)
    {
        NSError *outError;
        MP42File *mp4File;
        if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath])
            mp4File = [[MP42File alloc] initWithExistingFile:[NSURL fileURLWithPath:destinationPath]
                                                 andDelegate:nil];
        else
            mp4File = [[MP42File alloc] initWithDelegate:nil];

        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be opened.");
            return -1;
        }

        if (removemetadata) {
            for (NSString* key in mp4File.metadata.writableMetadata) {
                [mp4File.metadata removeTagForKey:key];
            }
            
            if ([[mp4File metadata] hdVideo]) {
                mp4File.metadata.hdVideo = 0;
            }
            if ([[mp4File metadata] gapless]) {
                mp4File.metadata.gapless = 0;
            }
            if ([[mp4File metadata] contentRating]) {
                mp4File.metadata.contentRating = 0;
            }
            if ([[mp4File metadata] podcast]) {
                mp4File.metadata.podcast = 0;
            }
            if ([[mp4File metadata] mediaKind]) {
                mp4File.metadata.mediaKind = 0;
            }
            
            modified = YES;
        }

        if (removeExisting) {
          NSMutableIndexSet *subtitleTrackIndexes = [[NSMutableIndexSet alloc] init];
          MP42Track *track;
          for (track in mp4File.tracks)
            if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
              [subtitleTrackIndexes addIndex:[mp4File.tracks indexOfObject:track]];
               modified = YES;
            }

          [mp4File removeTracksAtIndexes:subtitleTrackIndexes];
          [subtitleTrackIndexes release];
        }

        if ((sourcePath && [[NSFileManager defaultManager] fileExistsAtPath:sourcePath])) {
            NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
            MP42FileImporter *fileImporter = [[MP42FileImporter alloc] initWithURL:sourceURL
                                                                                error:&outError];

            for (MP42Track * track in [fileImporter tracks]) {
                if (language)
                    [track setLanguage:language];
                if (delay)
                    [track setStartOffset:delay];
                if (height && [track isMemberOfClass:[MP42SubtitleTrack class]])
                    [(MP42VideoTrack*)track setTrackHeight:height];

                [mp4File addTrack:track];
            }

            modified = YES;
        }

        if (chaptersPath) {
            MP42Track *oldChapterTrack = NULL;
            MP42ChapterTrack *newChapterTrack = NULL;

            MP42Track *track;
            for (track in mp4File.tracks)
              if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
                oldChapterTrack = track;
                break;
              }

          if(oldChapterTrack != NULL) {
            [mp4File removeTrackAtIndex:[mp4File.tracks indexOfObject:oldChapterTrack]];
            modified = YES;
          }

          newChapterTrack = [MP42ChapterTrack chapterTrackFromFile:[NSURL fileURLWithPath:chaptersPath]];

          if([newChapterTrack chapterCount] > 0) {
            [mp4File addTrack:newChapterTrack];            
            modified = YES;      
          }
        }

        if (downmixAudio) {
            for (MP42AudioTrack *track in [mp4File tracks]) {
                if (![track isKindOfClass: [MP42AudioTrack class]]) continue;

                [track setNeedConversion: YES];
                [track setMixdownType: downmixType];

                modified = YES;
            }
        }
        
        for (MP42VideoTrack *track in [mp4File tracks]) {
            if ([track isKindOfClass: [MP42VideoTrack class]] && [track.format isEqualToString:@"H.264"]) {
                track.newProfile = videoprofile;
                track.newLevel = videolevel;

                track.isEdited = YES;
                
                modified = YES;
            }
        }

        if (metadata) {
            NSString *searchString = metadata;
            NSString *regexCheck = @"(\\{[^:]*:[^\\}]*\\})*";

            // escaping the {, } and : charachters 
            NSString *left_normal = @"{";
            NSString *right_normal = @"}";
            NSString *semicolon_normal = @":";

            NSString *left_escaped = @"&#123;";
            NSString *right_escaped = @"&#125;";
            NSString *semicolon_escaped = @"&#58;";

            if (searchString != nil && [searchString isMatchedByRegex:regexCheck]) {

                NSString *regexSplitArgs = @"^\\{|\\}\\{|\\}$";
                NSString *regexSplitValue = @"([^:]*):(.*)";

                NSArray *argsArray = nil;
                NSString *arg = nil;
                NSString *key = nil;
                NSString *value = nil;
                argsArray = [searchString componentsSeparatedByRegex:regexSplitArgs];

                for (arg in argsArray) {
                    key = [arg stringByMatching:regexSplitValue capture:1L];
                    value = [arg stringByMatching:regexSplitValue capture:2L];

                    key = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                    value = [value stringByReplacingOccurrencesOfString:left_escaped withString:left_normal];
                    value = [value stringByReplacingOccurrencesOfString:right_escaped withString:right_normal];
                    value = [value stringByReplacingOccurrencesOfString:semicolon_escaped withString:semicolon_normal];

                    if (key != nil) {
                        if (value != nil && [value length] > 0) {                  
                            [mp4File.metadata setTag:value forKey:key];
                        }
                        else {
                            [mp4File.metadata removeTagForKey:key];                  
                        }
                        modified = YES;
                    }
                }
            }
        }

        if (chapterPreview)
            modified = YES;

        if (itunesfriendly) {
            [mp4File organizeAlternateGroups];
            modified = YES;
        }

        BOOL success;
        if (modified && [mp4File hasFileRepresentation])
            success = [mp4File updateMP4FileWithAttributes:attributes error:&outError];

        else if (modified && ![mp4File hasFileRepresentation] && destinationPath) {
            if ([mp4File dataSize] > 4100000000 || _64bitchunk)
                [attributes setObject:@YES forKey:MP42Create64BitData];

            success = [mp4File writeToUrl:[NSURL fileURLWithPath:destinationPath]
                           withAttributes:attributes
                                    error:&outError];
        }

        if (!success) {
            printf("Error: %s\n", [[outError localizedDescription] UTF8String]);
            return -1;
        }

        [mp4File release];
    }

    if (optimize) {
        MP42File *mp4File;
        mp4File = [[MP42File alloc] initWithExistingFile:[NSURL fileURLWithPath:destinationPath]
                                             andDelegate:nil];
        if (!mp4File) {
            printf("Error: %s\n", "the mp4 file couln't be opened.");
            return -1;
        }
        printf("Optimizing...\n");
        [mp4File optimize];
        [mp4File release];
        printf("Done.\n");
    }

    [attributes release];
    [pool drain];
    return 0;
}
