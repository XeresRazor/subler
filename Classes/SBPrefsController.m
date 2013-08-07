//
//  SBPrefsController.m
//
//  Created by Damiano Galassi on 13/05/08.
//  Copyright 2008 Damiano Galassi. All rights reserved.
//

#import "SBPrefsController.h"
#import "MetadataSearchController.h"
#import "SBPresetManager.h"
#import "SBTableView.h"
#import "MP42Metadata.h"
#import "MovieViewController.h"
#import "SBRatings.h"

#define TOOLBAR_GENERAL     @"TOOLBAR_GENERAL"
#define TOOLBAR_ADVANCED       @"TOOLBAR_ADVANCED"
#define TOOLBAR_SETS        @"TOOLBAR_SETS"

@interface SBPrefsController (Private)

- (void) setPrefView: (id) sender;
- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image;

@end

@implementation SBPrefsController

+ (void)registerUserDefaults
{    
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                                                             @"m4v",            @"SBSaveFormat",
                                                             @"0",              @"defaultSaveFormat",
                                                             @"YES",            @"SBQueueOptimize",
                                                             @"1",              @"SBAudioMixdown",
                                                             @"96",             @"SBAudioBitrate",
                                                             @"YES",            @"SBAudioConvertAC3",
                                                             @"YES",            @"SBSubtitleConvertBitmap",
                                                             @"All countries",  @"SBRatingsCountry",
                                                             @"m4v",            @"SBSaveFormat",
                                                             @"NO",             @"mp464bitOffset",
                                                             @"YES",            @"chaptersPreviewTrack",
                                                             @"iTunes Store",   @"SBMetadataPreference|Movie",
                                                             @"USA (English)",  @"SBMetadataPreference|Movie|iTunes Store|Language",
                                                             @"English",        @"SBMetadataPreference|Movie|TheMovieDB|Language",
                                                             @"iTunes Store",   @"SBMetadataPreference|TV",
                                                             @"USA (English)",  @"SBMetadataPreference|TV|iTunes Store|Language",
                                                             @"English",        @"SBMetadataPreference|TV|TheTVDB|Language",
                                                             nil]];
}

-(id) init
{
    if ((self = [super initWithWindowNibName:@"Prefs"])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateTableView:)
                                                     name:@"SBPresetManagerUpdatedNotification" object:nil];
    }

    return self;
}

- (void) awakeFromNib
{
    NSToolbar * toolbar = [[[NSToolbar alloc] initWithIdentifier: @"Preferences Toolbar"] autorelease];
    [toolbar setDelegate: self];
    [toolbar setAllowsUserCustomization: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [toolbar setSizeMode: NSToolbarSizeModeRegular];
    [[self window] setToolbar: toolbar];

    [toolbar setSelectedItemIdentifier: TOOLBAR_GENERAL];
    [self setPrefView:nil];
}

- (NSToolbarItem *)toolbar: (NSToolbar *)toolbar
     itemForItemIdentifier: (NSString *)ident
 willBeInsertedIntoToolbar: (BOOL)flag
{
    if ([ident isEqualToString:TOOLBAR_GENERAL]) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"General", @"Preferences General Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNamePreferencesGeneral]];
    }
    else if ([ident isEqualToString:TOOLBAR_ADVANCED]) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Advanced", @"Preferences Audio Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNameAdvanced]];
    }
    else if ([ident isEqualToString:TOOLBAR_SETS]) {
        return [self toolbarItemWithIdentifier:ident
                                         label:NSLocalizedString(@"Sets", @"Preferences Sets Toolbar Item")
                                         image:[NSImage imageNamed:NSImageNameFolderSmart]];
    }    

    return nil;
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarDefaultItemIdentifiers: toolbar];
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
    return [self toolbarAllowedItemIdentifiers: toolbar];
}

- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    return [NSArray arrayWithObjects: TOOLBAR_GENERAL, TOOLBAR_SETS, TOOLBAR_ADVANCED, nil];
}

- (IBAction) clearRecentSearches:(id) sender {
    [MetadataSearchController clearRecentSearches];
}

- (IBAction) deleteCachedMetadata:(id) sender {
    [MetadataSearchController deleteCachedMetadata];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    return [[presetManager presets] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
    if ([aTableColumn.identifier isEqualToString:@"name"]) {
        SBPresetManager *presetManager = [SBPresetManager sharedManager];
        return [[[presetManager presets] objectAtIndex:rowIndex] presetName];
    }
    return nil;
}

- (IBAction) deletePreset:(id) sender
{
    [self closePopOver:self];

    NSInteger rowIndex = [tableView selectedRow];
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager removePresetAtIndex:rowIndex];
    [tableView reloadData];
}

- (IBAction)closePopOver:(id)sender
{
    if(_popover) {
        if (!NSClassFromString(@"NSPopover")) {
            [[self window] removeChildWindow:_popover];
            [_popover orderOut:self];
        }
        else
            [_popover close];

        [_popover release];
        _popover = nil;
        [_controller release];
        _controller = nil;
    }
}

- (IBAction)toggleInfoWindow:(id)sender
{
    if (_currentRow == [tableView clickedRow] && _popover)
        [self closePopOver:sender];
    else {
        _currentRow = [tableView clickedRow];
        [self closePopOver:sender];
        
        SBPresetManager *presetManager = [SBPresetManager sharedManager];
        _controller = [[MovieViewController alloc] initWithNibName:@"MovieView" bundle:nil];
        [_controller setMetadata:[[presetManager presets] objectAtIndex:_currentRow]];
        
        if (NSClassFromString(@"NSPopover")) {
            _popover = [[NSPopover alloc] init];
            ((NSPopover *)_popover).contentViewController = _controller;
            ((NSPopover *)_popover).contentSize = NSMakeSize(480.0f, 500.0f);
            
            [_popover showRelativeToRect:[tableView frameOfCellAtColumn:1 row:_currentRow] ofView:tableView preferredEdge:NSMaxYEdge];
        }
        else {
            NSInteger row = [tableView selectedRow];
            
            NSRect cellFrame = [tableView frameOfCellAtColumn:1 row:row];
            NSRect tableFrame = [[[tableView superview] superview]frame];
            
            NSPoint windowPoint = NSMakePoint(NSMidX(cellFrame) + 20,
                                              NSHeight(tableFrame) + tableFrame.origin.y - cellFrame.origin.y - (cellFrame.size.height / 2) - 8);
            
            
            _popover = [[MAAttachedWindow alloc] initWithView:[_controller view]
                                              attachedToPoint:windowPoint
                                                     inWindow:[self window]
                                                       onSide:MAPositionBottom
                                                   atDistance:0];
            
            [_popover setBackgroundColor:[NSColor colorWithCalibratedRed:0.98 green:0.98 blue:1 alpha:0.9]];
            [_popover setDelegate:self];
            [_popover setCornerRadius:6];
            
            [[self window] addChildWindow:_popover ordered:NSWindowAbove];
            
            [_popover setAlphaValue:0.0];
            
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setDuration:0.2];
            [_popover makeKeyAndOrderFront:self];
            [[_popover animator] setAlphaValue:1.0];
            [NSAnimationContext endGrouping];
        }
    }
}

- (void)updateTableView:(id)sender
{
    [tableView reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    if ([tableView selectedRow] != -1)
        [removeSet setEnabled:YES];
    else
        [removeSet setEnabled:NO];
}

- (NSArray *) ratingsCountries {
	return [[SBRatings defaultManager] ratingsCountries];
}

- (IBAction) updateRatingsCountry:(id)sender {
	[[SBRatings defaultManager] updateRatingsCountry];
}

@end

@implementation SBPrefsController (Private)

- (void) setPrefView: (id) sender
{
    NSView * view = generalView;
    if( sender ) {
        NSString * identifier = [sender itemIdentifier];
        if( [identifier isEqualToString: TOOLBAR_ADVANCED] )
            view = advancedView;
        else if( [identifier isEqualToString: TOOLBAR_SETS] )
            view = setsView;
        else;
    }

    NSWindow * window = [self window];
    if( [window contentView] == view )
        return;

    NSRect windowRect = [window frame];
    CGFloat difference = ( [view frame].size.height - [[window contentView] frame].size.height );
    windowRect.origin.y -= difference;
    windowRect.size.height += difference;

    [view setHidden: YES];
    [window setContentView: view];
    [window setFrame: windowRect display: YES animate: YES];
    [view setHidden: NO];

    //set title label
    if( sender )
        [window setTitle: [sender label]];
    else {
        NSToolbar * toolbar = [window toolbar];
        NSString * itemIdentifier = [toolbar selectedItemIdentifier];
        for( NSToolbarItem * item in [toolbar items] )
            if( [[item itemIdentifier] isEqualToString: itemIdentifier] ) {
                [window setTitle: [item label]];
                break;
            }
    }
}

- (NSToolbarItem *)toolbarItemWithIdentifier: (NSString *)identifier
                                       label: (NSString *)label
                                       image: (NSImage *)image
{
    NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    [item setLabel:label];
    [item setImage:image];
    [item setAction:@selector(setPrefView:)];
    [item setAutovalidates:NO];
    return [item autorelease];
}

@end