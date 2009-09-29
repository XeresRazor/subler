//
//  MKVFileImport.m
//  Subler
//
//  Created by Ryan Walklin on 10/09/09.
//  Copyright 2009 Test Toast. All rights reserved.
//

#import "MKVFileImport.h"
#import "MatroskaParser.h"
#import "MatroskaFile.h"
#import "lang.h"
#import "MP42File.h"

@implementation MKVFileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"FileImport"])
	{        
		delegate = del;
        filePath = [path retain];
	}
	return self;
}
- (void)awakeFromNib
{
    ioStream = calloc(1, sizeof(StdIoStream)); 
	matroskaFile = openMatroskaFile((char *)[filePath UTF8String], ioStream);
	
	NSInteger i = mkv_GetNumTracks(matroskaFile);
		
    importCheckArray = [[NSMutableArray alloc] initWithCapacity:i];
	
    while (i) {
        [importCheckArray addObject: [NSNumber numberWithBool:YES]];
        i--;
		[addTracksButton setEnabled:YES];       
    }
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !matroskaFile )
        return 0;
	
    return mkv_GetNumTracks(matroskaFile);
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
	TrackInfo *track = mkv_GetTrackInfo(matroskaFile, rowIndex);
    
	if (!track)
        return nil;
    if( [tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex: rowIndex];
	
    if ([tableColumn.identifier isEqualToString:@"trackId"])
        return [NSString stringWithFormat:@"%d", track->Number];
	
    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return [NSString stringWithFormat:@"%s", track->Name];
	
    if ([tableColumn.identifier isEqualToString:@"trackInfo"])
		return [NSString stringWithUTF8String:track->CodecID];
	
    if ([tableColumn.identifier isEqualToString:@"trackDuration"])
	{
		double trackTimecodeScale = (track->TimecodeScale.v >> 32);
		SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
		UInt64 scaledDuration = (UInt64)segInfo->Duration / (UInt32)segInfo->TimecodeScale * trackTimecodeScale;
		return SMPTEStringFromTime(scaledDuration, 1000);
	}
	
    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
	{
		iso639_lang_t *isoLanguage = lang_for_code2(track->Language);
		return [NSString stringWithUTF8String:isoLanguage->eng_name];
	}
    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"])
        [importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
}

- (IBAction) closeWindow: (id) sender
{
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:nil];
}

- (IBAction) addTracks: (id) sender
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSInteger i;
	
    for (i = 0; i < mkv_GetNumTracks(matroskaFile); i++) {
        if ([[importCheckArray objectAtIndex: i] boolValue])
		{
			TrackInfo *mkvTrack = mkv_GetTrackInfo(matroskaFile, i);
            MP42Track *newTrack = nil;
			
            // Video
            if (mkvTrack->Type == TT_VIDEO) 
			{
                newTrack = [[MP42VideoTrack alloc] init];
					
                [(MP42VideoTrack*)newTrack setTrackWidth:mkvTrack->AV.Video.PixelWidth];
                [(MP42VideoTrack*)newTrack setTrackHeight:mkvTrack->AV.Video.PixelHeight];
                
            }
			
            // Audio
            else if (mkvTrack->Type == TT_AUDIO)
                newTrack = [[MP42AudioTrack alloc] init];
			
            // Text
            else if (mkvTrack->Type == TT_SUB)
				newTrack = [[MP42SubtitleTrack alloc] init];
            
            if (newTrack) {
                newTrack.format = [NSString stringWithUTF8String:mkvTrack->CodecID];
                newTrack.Id = i;
                newTrack.sourcePath = filePath;
                newTrack.name = [NSString stringWithFormat:@"%s", mkvTrack->Name];
				iso639_lang_t *isoLanguage = lang_for_code2(mkvTrack->Language);
				newTrack.language = [NSString stringWithUTF8String:isoLanguage->eng_name];
                [tracks addObject:newTrack];
                [newTrack release];
            }
        }
    }
	
    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];
	
    [tracks release];
}

- (void) dealloc
{
    [importCheckArray release];
	[filePath release];
	
	/* close matroska parser */ 
	mkv_Close(matroskaFile); 
	
	/* close file */ 
	fclose(ioStream->fp); 

    [super dealloc];
}

@end
