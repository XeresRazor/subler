//
//  MyDocument.h
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright __MyCompanyName__ 2009 . All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import "mp4v2/mp4v2.h"

@interface MyDocument : NSDocument
{
    MP4FileHandle   fileHandle;
    NSString*       filePath;

    IBOutlet NSTextField    *subtitleFilePath;
    IBOutlet NSTextField    *label;

    IBOutlet NSTableView    *fileTracksTable;
    IBOutlet NSWindow       *addSubtitleWindow;
    IBOutlet NSWindow       *documentWindow;

    IBOutlet NSPopUpButton  *langSelection;
    IBOutlet NSTextField    *delay;
    IBOutlet NSTextField    *trackHeight;
    IBOutlet NSButton       *addTrack;

    IBOutlet NSToolbarItem  *addTrackToolBar;
    IBOutlet NSToolbarItem  *deleteTrack;
}

- (IBAction) showSubititleWindow: (id) sender;
- (IBAction) closeSheet: (id) sender;
- (IBAction) openBrowse: (id) sender;
- (IBAction) startMuxing: (id) sender;
- (IBAction) deleteTrack: (id) sender;

- (void) reloadTable: (id) sender;

@end
