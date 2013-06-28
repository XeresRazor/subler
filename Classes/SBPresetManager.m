//
//  SBPresetManager.m
//  Subler
//
//  Created by Damiano Galassi on 02/01/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SBPresetManager.h"
#import "MP42File.h"

/// Notification sent to update presets lists.
NSString *SBPresetManagerUpdatedNotification = @"SBPresetManagerUpdatedNotification";

@interface SBPresetManager (Private)
- (BOOL) loadPresets;
- (BOOL) savePresets;
- (NSString *) appSupportPath;
- (BOOL) removePresetWithName:(NSString*)name;

@end

@implementation SBPresetManager

+ (SBPresetManager*)sharedManager
{
    static dispatch_once_t pred;
    static SBPresetManager *sharedPresetManager = nil;
    
    dispatch_once(&pred, ^{ sharedPresetManager = [[self alloc] init]; });
    return sharedPresetManager;
}

- (id)init {
    if ((self = [super init])) {
        presets = [[NSMutableArray alloc] init];
        
        [self loadPresets];
    }
    
    return self;
}

- (void)updateNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPresetManagerUpdatedNotification object:self];    
}

- (void) newSetFromExistingMetadata:(MP42Metadata*)set
{
    id newSet = [set copy];
    [presets addObject:newSet];
    [newSet release];

    [self savePresets];
    [self updateNotification];
}

- (NSString *) appSupportPath
{
    NSString *appSupportPath = nil;

    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count])
        appSupportPath = [[allPaths objectAtIndex:0] stringByAppendingPathComponent:@"Subler"];

    return appSupportPath;
}

- (BOOL) loadPresets
{
    NSString *file;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    MP42Metadata *newPreset;

    NSString *appSupportPath = [self appSupportPath];

    if (!appSupportPath)
        return NO;

    NSDirectoryEnumerator *dirEnum = [fileManager enumeratorAtPath:appSupportPath];
    while ((file = [dirEnum nextObject]))
    {
        if ([[file pathExtension] isEqualToString: @"sbpreset"])
        {
            @try {
            newPreset = [NSKeyedUnarchiver unarchiveObjectWithFile:[appSupportPath stringByAppendingPathComponent:file]];
            }
            @catch ( NSException *exception) {
                continue;
            }

            newPreset.isEdited = NO;
            [presets addObject:newPreset];
        }
    }

    if ( ![presets count] )
        return NO;
    else
        return YES;
}

- (BOOL) savePresets
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL noErr = YES;

    NSString *appSupportPath = [self appSupportPath];

    if (!appSupportPath)
            return NO;

    if( ![fileManager fileExistsAtPath:appSupportPath] )
        [fileManager createDirectoryAtPath:appSupportPath withIntermediateDirectories:noErr attributes:nil error:NULL];

    MP42Metadata *object;

    for( object in presets ) {
        if ([object isEdited]) {
            NSString * saveLocation = [NSString stringWithFormat:@"%@/%@.sbpreset", appSupportPath, [object presetName]];
                noErr = [NSKeyedArchiver archiveRootObject:object
                                                toFile:saveLocation];
        }
    }
    return noErr;
}

- (BOOL) removePresetAtIndex:(NSUInteger)index
{
    NSString *name = [[presets objectAtIndex:index] presetName];
    [presets removeObjectAtIndex:index];

    [self updateNotification];

    return [self removePresetWithName:name];
}


- (BOOL) removePresetWithName:(NSString*)name
{
    BOOL err = NO;
    NSString *appSupportPath = [self appSupportPath];

    if (!appSupportPath)
        return NO;

    NSFileManager *fileManager = [NSFileManager defaultManager];
    err = [fileManager removeItemAtPath: [NSString stringWithFormat:@"%@/%@.sbpreset", appSupportPath, name]
                                  error: NULL];

    return err;
}

@synthesize presets;

@end
