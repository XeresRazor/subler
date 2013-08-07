//
//  FileImport.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import "SBFileImport.h"
#import "MP42File.h"
#import "MP42FileImporter.h"

@implementation SBFileImport

- (id)initWithDelegate:(id)del andFiles: (NSArray *)files error:(NSError **)outError
{
	if ((self = [super initWithWindowNibName:@"FileImport"])) {
		delegate = del;
        _fileURLs = [files retain];
        _fileImporters = [[NSMutableArray alloc] initWithCapacity:[files count]];
        _tracks = [[NSMutableArray alloc] init];
        
        for (NSURL *file in files) {
            MP42FileImporter *importer = [[MP42FileImporter alloc] initWithDelegate:delegate andFile:file error:outError];
            if (importer) {
                [_tracks addObject:[file lastPathComponent]];
                [_fileImporters addObject:importer];
                [importer release];
                [_tracks addObjectsFromArray:importer.tracksArray];
            }
        }
	}

	return self;
}

- (void)awakeFromNib
{
    _importCheckArray = [[NSMutableArray alloc] initWithCapacity:[_tracks count]];
    _actionArray = [[NSMutableArray alloc] initWithCapacity:[_tracks count]];

    for (id object in _tracks) {
        if ([object isKindOfClass:[MP42Track class]]) {
            if (isTrackMuxable([object format]) || trackNeedConversion([object format]))
                [_importCheckArray addObject: [NSNumber numberWithBool:YES]];
            else
                [_importCheckArray addObject: [NSNumber numberWithBool:NO]];

            if ([[object format] isEqualToString:@"AC-3"] &&
                [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioConvertAC3"] boolValue])
                [_actionArray addObject:[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults]
                                                                 valueForKey:@"SBAudioMixdown"] integerValue]]];
            else if ([[object format] isEqualToString:@"DTS"])
                [_actionArray addObject:[NSNumber numberWithInteger:1]];
            else if ([[object format] isEqualToString:@"VobSub"] &&
                     [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBSubtitleConvertBitmap"] boolValue])
                [_actionArray addObject:[NSNumber numberWithInteger:1]];
            else if (!trackNeedConversion([object format]))
                [_actionArray addObject:[NSNumber numberWithInteger:0]];
            else if ([object isMemberOfClass:[MP42AudioTrack class]])
                [_actionArray addObject:[NSNumber numberWithInteger:[[[NSUserDefaults standardUserDefaults]
                                                                 valueForKey:@"SBAudioMixdown"] integerValue]]];
            else
                [_actionArray addObject:[NSNumber numberWithInteger:1]];
        }
        else {
            [_importCheckArray addObject: [NSNumber numberWithBool:YES]];
            [_actionArray addObject:[NSNumber numberWithInteger:0]];
        }
    }

    if ([[_fileImporters objectAtIndex:0] metadata])
        [importMetadata setEnabled:YES];
    else
        [importMetadata setEnabled:NO];

    [addTracksButton setEnabled:YES];
}

- (NSInteger) numberOfRowsInTableView: (NSTableView *) t
{
    return [_tracks count];
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    id object = [_tracks objectAtIndex:row];
    if ([object isKindOfClass:[MP42Track class]])
        return NO;

    return  YES;
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
    NSCell *cell = nil;
    MP42Track *track = [_tracks objectAtIndex:rowIndex];

    if ([track isKindOfClass:[MP42Track class]]) {
        if ([tableColumn.identifier isEqualToString:@"check"]) {
            NSButtonCell *buttonCell = [[NSButtonCell alloc] init];
            [buttonCell setButtonType:NSSwitchButton];
            [buttonCell setControlSize:NSSmallControlSize];
            [buttonCell setTitle:@""];

            return [buttonCell autorelease];
        }
        
        if ([tableColumn.identifier isEqualToString:@"trackAction"]) {
            NSPopUpButtonCell *actionCell = [[NSPopUpButtonCell alloc] init];
            [actionCell setAutoenablesItems:NO];
            [actionCell setFont:[NSFont systemFontOfSize:11]];
            [actionCell setControlSize:NSSmallControlSize];
            [actionCell setBordered:NO];
            
            if ([track isMemberOfClass:[MP42VideoTrack class]]) {
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:0];
                [item setEnabled:YES];
                [[actionCell menu] addItem:item];
                
                if (isTrackMuxable(track.format))
                    [item setEnabled:YES];
                else
                    [item setEnabled:NO];
            }
            
            else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
                NSInteger tag = 0;
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:tag++];
                if (!trackNeedConversion(track.format))
                    [item setEnabled:YES];
                else
                    [item setEnabled:NO];
                [[actionCell menu] addItem:item];
                
                NSArray *formatArray = [NSArray arrayWithObjects:@"3GPP Text", nil];
                for (NSString* format in formatArray) {
                    item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                    [item setTag:tag++];
                    [item setEnabled:YES];
                    [[actionCell menu] addItem:item];
                }
            }
            else if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                NSInteger tag = 0;
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:tag++];
                if (!trackNeedConversion(track.format))
                    [item setEnabled:YES];
                else
                    [item setEnabled:NO];
                [[actionCell menu] addItem:item];
                
                NSArray *formatArray = [NSArray arrayWithObjects:@"AAC - Dolby Pro Logic II", @"AAC - Dolby Pro Logic", @"AAC - Stereo", @"AAC - Mono", @"AAC - Multi-channel", nil];
                for (NSString* format in formatArray) {
                    item = [[[NSMenuItem alloc] initWithTitle:format action:NULL keyEquivalent:@""] autorelease];
                    [item setTag:tag++];
                    [item setEnabled:YES];
                    [[actionCell menu] addItem:item];
                }
            }
            else if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
                NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:@"Passthru" action:NULL keyEquivalent:@""] autorelease];
                [item setTag:0];
                [item setEnabled:YES];
                [[actionCell menu] addItem:item];
            }
            cell = actionCell;
            
            return [cell autorelease];
        }
    }

    return [tableColumn dataCell];
}

- (id) tableView:(NSTableView *)tableView 
objectValueForTableColumn:(NSTableColumn *)tableColumn 
             row:(NSInteger)rowIndex
{
    id object = [_tracks objectAtIndex:rowIndex];

    if (!object)
        return nil;

    if ([object isKindOfClass:[MP42Track class]]) {
        if( [tableColumn.identifier isEqualToString: @"check"] )
            return [_importCheckArray objectAtIndex:rowIndex];

        if ([tableColumn.identifier isEqualToString:@"trackId"])
            return [NSString stringWithFormat:@"%d", [object Id]];

        if ([tableColumn.identifier isEqualToString:@"trackName"])
            return [object name];

        if ([tableColumn.identifier isEqualToString:@"trackInfo"])
            return [object format];

        if ([tableColumn.identifier isEqualToString:@"trackDuration"])
            return [object timeString];

        if ([tableColumn.identifier isEqualToString:@"trackLanguage"])
            return [object language];

        if ([tableColumn.identifier isEqualToString:@"trackAction"])
            return [_actionArray objectAtIndex:rowIndex];
        }
    else if ([tableColumn.identifier isEqualToString:@"trackName"])
            return object;

    return nil;
}

- (void) tableView: (NSTableView *) tableView 
    setObjectValue: (id) anObject 
    forTableColumn: (NSTableColumn *) tableColumn 
               row: (NSInteger) rowIndex
{
    if ([tableColumn.identifier isEqualToString: @"check"])
        [_importCheckArray replaceObjectAtIndex:rowIndex withObject:anObject];
    if ([tableColumn.identifier isEqualToString:@"trackAction"])
        [_actionArray replaceObjectAtIndex:rowIndex withObject:anObject];
}

- (IBAction) closeWindow: (id) sender
{
    [tableView setDelegate:nil];
    [tableView setDataSource:nil];
    [NSApp endSheet:[self window] returnCode:NSOKButton];
    [[self window] orderOut:self];
}

- (IBAction) addTracks: (id) sender
{
    NSMutableArray *tracks = [[NSMutableArray alloc] init];
    NSInteger i = 0;

    for (id track in _tracks) {
        if ([track isKindOfClass:[MP42Track class]]) {
            if ([[_importCheckArray objectAtIndex: i] boolValue]) {
                NSUInteger conversion = [[_actionArray objectAtIndex:i] integerValue];
                
                if ([track isMemberOfClass:[MP42AudioTrack class]]) {
                    if (conversion)
                        [track setNeedConversion:YES];
                    
                    switch(conversion) {
                        case 5:
                            [(MP42AudioTrack*) track setMixdownType:nil];
                            break;
                        case 4:
                            [(MP42AudioTrack*) track setMixdownType:SBMonoMixdown];
                            break;
                        case 3:
                            [(MP42AudioTrack*) track setMixdownType:SBStereoMixdown];
                            break;
                        case 2:
                            [(MP42AudioTrack*) track setMixdownType:SBDolbyMixdown];
                            break;
                        case 1:
                            [(MP42AudioTrack*) track setMixdownType:SBDolbyPlIIMixdown];
                            break;
                        default:
                            [(MP42AudioTrack*) track setMixdownType:SBDolbyPlIIMixdown];
                            break;
                    }
                }
                else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
                    if (conversion)
                        [track setNeedConversion:YES];
                }
                
                for (MP42FileImporter *importer in _fileImporters)
                    if ([importer containsTrack:track]) {
                        [track setTrackImporterHelper:importer];
                        break;
                    }
                
                [tracks addObject:track];
            }
        }
        i++;
    }

    MP42Metadata *metadata = nil;
    if ([importMetadata state])
        metadata = [[[(MP42FileImporter*)[_fileImporters objectAtIndex:0] metadata] retain] autorelease];

    if ([delegate respondsToSelector:@selector(importDoneWithTracks:andMetadata:)]) 
        [delegate importDoneWithTracks:tracks andMetadata: metadata];

    [tracks release];

    [tableView setDelegate:nil];
    [tableView setDataSource:nil];
    [NSApp endSheet:[self window] returnCode:NSOKButton];
    [[self window] orderOut:self];
}

- (void) dealloc
{
    [_fileURLs release];
    [_fileImporters release];
    [_tracks release];

    [_importCheckArray release];
    [_actionArray release];

    [super dealloc];
}

@end
