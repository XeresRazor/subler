//
//  FileImport.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MP42FileImporter;
@class MP42Metadata;

@interface SBFileImport : NSWindowController <NSTableViewDelegate> {

    NSArray         *_fileURLs;
    NSMutableArray  *_fileImporters;
    NSMutableArray  *_tracks;
    
    NSMutableArray		*_importCheckArray;
    NSMutableArray      *_actionArray;

	id delegate;
	IBOutlet NSTableView * tableView;
	IBOutlet NSButton    * addTracksButton;
    IBOutlet NSButton    * importMetadata;
    IBOutlet NSProgressIndicator *loadProgressBar;
}

- (id)initWithDelegate:(id)del andFiles: (NSArray *)files error:(NSError **)outError;

- (IBAction)closeWindow:(id)sender;
- (IBAction)addTracks:(id)sender;

@end

@interface NSObject (FileImportDelegateMethod)
- (void)importDoneWithTracks:(NSArray *)tracksToBeImported andMetadata:(MP42Metadata *)metadata;

@end
