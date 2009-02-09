//
//  MP4Metadata.m
//  Subler
//
//  Created by Damiano Galassi on 06/02/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MP4Metadata.h"
#import "MP4Utilities.h"

@implementation MP4Metadata

-(id)initWithSourcePath:(NSString *)source
{
	if ((self = [super init]))
	{
		sourcePath = source;
        tagsDict = [[NSMutableDictionary alloc] init];
	}
	[self readMetaData];
	edited = NO;
    
    return self;
}

-(void) readMetaData
{
    MP4FileHandle *sourceHandle = MP4Read([sourcePath UTF8String], 0);
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, sourceHandle );

    if (tags->name)
        [tagsDict setObject:[NSString stringWithCString:tags->name encoding: NSUTF8StringEncoding]
                     forKey:@"Name"];

    if (tags->artist)
        [tagsDict setObject:[NSString stringWithCString:tags->artist encoding: NSUTF8StringEncoding]
                     forKey:@"Artist"];

    if (tags->albumArtist)
        [tagsDict setObject:[NSString stringWithCString:tags->albumArtist encoding: NSUTF8StringEncoding]
                     forKey:@"Album Artist"];

    if (tags->album)
        [tagsDict setObject:[NSString stringWithCString:tags->album encoding: NSUTF8StringEncoding]
                     forKey:@"Album"];

    if (tags->grouping)
        [tagsDict setObject:[NSString stringWithCString:tags->grouping encoding: NSUTF8StringEncoding]
                     forKey:@"Grouping"];

    if (tags->composer)
        [tagsDict setObject:[NSString stringWithCString:tags->composer encoding: NSUTF8StringEncoding]
                     forKey:@"Composer"];

    if (tags->comments)
        [tagsDict setObject:[NSString stringWithCString:tags->comments encoding: NSUTF8StringEncoding]
                     forKey:@"Comments"];

    if (tags->genre)
        [tagsDict setObject:[NSString stringWithCString:tags->genre encoding: NSUTF8StringEncoding]
                     forKey:@"Genre"];

    if (tags->releaseDate)
        [tagsDict setObject:[NSString stringWithCString:tags->releaseDate encoding: NSUTF8StringEncoding]
                     forKey:@"Date"];

    if (tags->tvShow)
        [tagsDict setObject:[NSString stringWithCString:tags->tvShow encoding: NSUTF8StringEncoding]
                     forKey:@"TV Show"];

    if (tags->tvEpisodeID)
        [tagsDict setObject:[NSString stringWithCString:tags->tvEpisodeID encoding: NSUTF8StringEncoding]
                     forKey:@"TV Episode ID"];

    if (tags->description)
        [tagsDict setObject:[NSString stringWithCString:tags->description encoding: NSUTF8StringEncoding]
                     forKey:@"Description"];

    if (tags->longDescription)
        [tagsDict setObject:[NSString stringWithCString:tags->longDescription encoding: NSUTF8StringEncoding]
                     forKey:@"Long Description"];
    
    if (tags->encodingTool)
        [tagsDict setObject:[NSString stringWithCString:tags->encodingTool encoding: NSUTF8StringEncoding]
                     forKey:@"Encoding Tool"];

    if (tags->purchaseDate)
        [tagsDict setObject:[NSString stringWithCString:tags->purchaseDate encoding: NSUTF8StringEncoding]
                     forKey:@"Purchase Date"];

    MP4TagsFree( tags );
    MP4Close(sourceHandle);
}

- (BOOL) writeMetadata
{
    MP4FileHandle *fileHandle = MP4Modify( [sourcePath UTF8String], MP4_DETAILS_ERROR, 0 );
    const MP4Tags* tags = MP4TagsAlloc();
    MP4TagsFetch( tags, fileHandle );
    
    if ([tagsDict valueForKey:@"Name"])
        MP4TagsSetName( tags, [[tagsDict valueForKey:@"Name"] UTF8String] );

    if ([tagsDict valueForKey:@"Artist"])
        MP4TagsSetArtist( tags, [[tagsDict valueForKey:@"Artist"] UTF8String] );

    if ([tagsDict valueForKey:@"Album"])
        MP4TagsSetAlbum( tags, [[tagsDict valueForKey:@"Album"] UTF8String] );

    if ([tagsDict valueForKey:@"Date"])
        MP4TagsSetReleaseDate( tags, [[tagsDict valueForKey:@"Date"] UTF8String] );

    if ([tagsDict valueForKey:@"Comments"])
        MP4TagsSetComments( tags, [[tagsDict valueForKey:@"Comments"] UTF8String] );

    if ([tagsDict valueForKey:@"Description"])
        MP4TagsSetDescription( tags, [[tagsDict valueForKey:@"Description"] UTF8String] );

    if ([tagsDict valueForKey:@"Genre"])
        MP4TagsSetGenre( tags, [[tagsDict valueForKey:@"Genre"] UTF8String] );

    if ([tagsDict valueForKey:@"Composer"])
        MP4TagsSetComposer( tags, [[tagsDict valueForKey:@"Composer"] UTF8String] );

    MP4TagsStore( tags, fileHandle );
    MP4TagsFree( tags );
    MP4Close( fileHandle );
    
    return YES;
}

@synthesize edited;

-(void) dealloc
{
    [super dealloc];
    [tagsDict release];
}

@synthesize tagsDict;

@end
