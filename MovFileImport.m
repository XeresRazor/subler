//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 15/03/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MovFileImport.h"
#import <QuickTime/QuickTime.h>

@implementation MovFileImport

- (id)initWithDelegate:(id)del andFile: (NSString *)path
{
	if (self = [super initWithWindowNibName:@"FileImport"])
	{        
		delegate = del;
        filePath = path;
        sourceFile = [[QTMovie alloc] initWithFile:filePath error:nil];
        NSInteger i = [[sourceFile tracks] count];
        importCheckArray = [[NSMutableArray alloc] initWithCapacity:i];

        while (i) {
            [importCheckArray addObject: [NSNumber numberWithBool:YES]];
            i--;
        }
    }

	return self;
}

- (NSString*)summaryForTrack: (QTTrack *)track;
{
    NSString* result = @"";
    ImageDescriptionHandle idh = (ImageDescriptionHandle) NewHandleClear(sizeof(ImageDescription));
    GetMediaSampleDescription([[track media] quickTimeMedia], 1,
                              (SampleDescriptionHandle)idh);
    
    switch ((*idh)->cType) {
        case kH264CodecType:
            result = @"H.264";
            break;
        case kMPEG4VisualCodecType:
            result = @"MPEG-4 Visual";
            break;
        case 'mp4a':
            result = @"AAC";
            break;
        case kAudioFormatAC3:
        case 'ms \0':
            result = @"AC-3";
            break;
        case kAudioFormatAMR:
            result = @"AMR Narrow Band";
            break;
        case 'text':
            result = @"Text";
            break;
        case 'tx3g':
            result = @"3GPP Text";
            break;
        case 'SRT ':
            result = @"Text";
            break;
        case 'SSA ':
            result = @"SSA";
            break;
        default:
            result = @"Unknown";
            break;
    }
    DisposeHandle((Handle)idh);
    return result;
}

- (NSString*)langForTrack: (QTTrack *)track;
{
    short lang = GetMediaLanguage([[track media] quickTimeMedia]);

    return [NSString stringWithFormat:@"d", lang];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    if( !sourceFile )
        return 0;

    return [[sourceFile tracks] count];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    QTTrack *track = [[sourceFile tracks] objectAtIndex:rowIndex];

    if (!track)
        return nil;
    
    if( [tableColumn.identifier isEqualToString: @"check"] )
        return [importCheckArray objectAtIndex: rowIndex];

    if ([tableColumn.identifier isEqualToString:@"trackId"]) {
        return [track attributeForKey:QTTrackIDAttribute];
    }

    if ([tableColumn.identifier isEqualToString:@"trackName"])
        return [track attributeForKey:QTTrackDisplayNameAttribute];

    if ([tableColumn.identifier isEqualToString:@"trackInfo"]) {
        return [self summaryForTrack:track];
    }

    if ([tableColumn.identifier isEqualToString:@"trackDuration"]) {
        return QTStringFromTime([[track attributeForKey:QTTrackRangeAttribute] QTTimeRangeValue].duration);
    }
    if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
        return [self langForTrack:track];

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

    for (i = 0; i < [[sourceFile tracks] count]; i++) {
        if ([[importCheckArray objectAtIndex: i] boolValue]) {
            QTTrack *track = [[sourceFile tracks] objectAtIndex:i];
            NSString* mediaType = [track attributeForKey:QTTrackMediaTypeAttribute];
            MP42Track *newTrack;

            if ([mediaType isEqualToString:QTMediaTypeVideo])
                newTrack = [[MP42VideoTrack alloc] init];
            else if ([mediaType isEqualToString:QTMediaTypeSound])
                newTrack = [[MP42AudioTrack alloc] init];

            newTrack.format = [self summaryForTrack:track];
            newTrack.Id = i;//[[track attributeForKey:QTTrackIDAttribute] integerValue];
            newTrack.sourcePath = filePath;
            newTrack.name = [track attributeForKey:QTTrackDisplayNameAttribute];
            newTrack.language = @"English";
            [tracks addObject:newTrack];
        }
    }

    if ([delegate respondsToSelector:@selector(importDone:)]) 
        [delegate importDone:tracks];
    [tracks release];
}

- (void) dealloc
{
    [sourceFile release];
    [importCheckArray release];
    [super dealloc];
}

@end
