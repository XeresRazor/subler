//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42VideoTrack.h"

@interface MP42SubtitleTrack : MP42VideoTrack <NSCoding> {
    BOOL verticalPlacement;
    BOOL someSamplesAreForced;
    BOOL allSamplesAreForced;

    MP4TrackId  forcedTrackId;
}

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error;

@property(nonatomic, readwrite) BOOL verticalPlacement;
@property(nonatomic, readwrite) BOOL someSamplesAreForced;
@property(nonatomic, readwrite) BOOL allSamplesAreForced;

@property MP4TrackId forcedTrackId;

@end
