//
//  SBAppDelegate.m
//  Subler
//
//  Created by Damiano Galassi on 29/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "SBAppDelegate.h"
#import "SBDocument.h"
#import "SBPresetManager.h"
#import "SBQueueController.h"
#import "SBPrefsController.h"

#import "mp4v2.h"

#define DONATE_NAG_TIME (60 * 60 * 24 * 7)

void logCallback(MP4LogLevel loglevel, const char* fmt, va_list ap)
{
    const char* level;

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"Debug"]) {
        switch (loglevel) {
            case 0:
                level = "None";
                break;
            case 1:
                level = "Error";
                break;
            case 2:
                level = "Warning";
                break;
            case 3:
                level = "Info";
                break;
            case 4:
                level = "Verbose1";
                break;
            case 5:
                level = "Verbose2";
                break;
            case 6:
                level = "Verbose3";
                break;
            case 7:
                level = "Verbose4";
                break;
            default:
                level = "Unknown";
                break;
        }
        printf("%s: ", level);
        vprintf(fmt, ap);
        printf("\n");
    }
}

@implementation SBAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    documentController = [[SBDocumentController alloc] init];

    [SBPrefsController registerUserDefaults];

    if ([[NSUserDefaults standardUserDefaults] valueForKey:@"SBShowQueueWindow"])
        [[SBQueueController sharedManager] showWindow:self];

    MP4SetLogCallback(logCallback);
    MP4LogSetLevel(MP4_LOG_ERROR);
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    SBPresetManager *presetManager = [SBPresetManager sharedManager];
    [presetManager savePresets];
    
    if ([[[SBQueueController sharedManager] window] isVisible])
        [[NSUserDefaults standardUserDefaults] setValue:@"YES" forKey:@"SBShowQueueWindow"];
    else
        [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"SBShowQueueWindow"];

    if (![[SBQueueController sharedManager] saveQueueToDisk])
        if ([[NSUserDefaults standardUserDefaults] valueForKey:@"Debug"])
            NSLog(@"Failed to save queue to disk!");
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
    SBQueueStatus status= [[SBQueueController sharedManager] status];
    NSInteger result;
    if (status == SBQueueStatusWorking) {
        result = NSRunCriticalAlertPanel(
                                         NSLocalizedString(@"Are you sure you want to quit Subler?", nil),
                                         NSLocalizedString(@"Your current queue will be lost. Do you want to quit anyway?", nil),
                                         NSLocalizedString(@"Quit", nil), NSLocalizedString(@"Don't Quit", nil), nil);
        
        if (result == NSAlertDefaultReturn)
            return NSTerminateNow;
        else
            return NSTerminateCancel;
    }

    return NSTerminateNow;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    BOOL firstLaunch = YES;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FirstLaunch"])
        firstLaunch = NO;

    if (![[NSUserDefaults standardUserDefaults] valueForKey:@"WarningDonate"]) {        
        NSDate * lastDonateDate = [[NSUserDefaults standardUserDefaults] valueForKey:@"DonateAskDate"];
        const BOOL timePassed = !lastDonateDate || (-1 * [lastDonateDate timeIntervalSinceNow]) >= DONATE_NAG_TIME;

        if (!firstLaunch && timePassed) {
            [[NSUserDefaults standardUserDefaults] setValue:[NSDate date] forKey:@"DonateAskDate"];

            NSAlert * alert = [[NSAlert alloc] init];
            [alert setMessageText: NSLocalizedString(@"Support Subler", "Donation -> title")];

            NSString * donateMessage = [NSString stringWithFormat: @"%@",
                                        NSLocalizedString(@" A lot of time and effort have gone into development, coding, and refinement."
                                                          " If you enjoy using it, please consider showing your appreciation with a donation.", "Donation -> message")];

            [alert setInformativeText:donateMessage];
            [alert setAlertStyle: NSInformationalAlertStyle];

            [alert addButtonWithTitle: NSLocalizedString(@"Donate", "Donation -> button")];
            NSButton * noDonateButton = [alert addButtonWithTitle: NSLocalizedString(@"Nope", "Donation -> button")];
            [noDonateButton setKeyEquivalent:@"\e"]; //escape key

            const BOOL allowNeverAgain = lastDonateDate != nil; //hide the "don't show again" check the first time - give them time to try the app
            [alert setShowsSuppressionButton:allowNeverAgain];
            if (allowNeverAgain)
                [[alert suppressionButton] setTitle:NSLocalizedString(@"Don't ask me about this ever again.", "Donation -> button")];

            const NSInteger donateResult = [alert runModal];
            if (donateResult == NSAlertFirstButtonReturn)
                [self linkDonate:self];

            if (allowNeverAgain)
                [[NSUserDefaults standardUserDefaults] setBool:([[alert suppressionButton] state] != NSOnState) forKey:@"WarningDonate"];

            [alert release];
        }
    }

    if (firstLaunch)
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FirstLaunch"];
    
    [SBQueueController sharedManager];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
    return NO;
}

- (IBAction) showBatchWindow: (id) sender
{
    [[SBQueueController sharedManager] showWindow:self];
}

- (IBAction) showPrefsWindow: (id) sender
{
    if (!prefController) {
        prefController = [[SBPrefsController alloc] init];
    }
    [prefController showWindow:self];
}

- (IBAction) donate:(id)sender
{
    [self linkDonate:sender];
}

- (IBAction) help:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
                                             URLWithString:@"http://code.google.com/p/subler/wiki/Documentation"]];
}

- (IBAction) linkDonate:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL
                                             URLWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=YKZHVC6HG6AFQ&lc=GB&item_name=Subler&currency_code=EUR&bn=PP%2dDonationsBF%3abtn_donateCC_LG%2egif%3aNonHosted"]];
}

@end

@implementation SBDocumentController

- (id) init
{
	return [super init];
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError {
    SBDocument *doc = nil;

    if ([[[absoluteURL path] pathExtension] caseInsensitiveCompare: @"mkv"] == NSOrderedSame ||
        [[[absoluteURL path] pathExtension] caseInsensitiveCompare: @"mka"] == NSOrderedSame ||
        [[[absoluteURL path] pathExtension] caseInsensitiveCompare: @"mks"] == NSOrderedSame ||
        [[[absoluteURL path] pathExtension] caseInsensitiveCompare: @"mov"] == NSOrderedSame) {
        doc = [self openUntitledDocumentAndDisplay:displayDocument error:outError];
        [doc performSelectorOnMainThread:@selector(showImportSheet:) withObject:[NSArray arrayWithObject:absoluteURL] waitUntilDone:NO];
        return doc;
    }
    else {
        return [super openDocumentWithContentsOfURL:absoluteURL display:displayDocument error:outError];
    }
}

@end
