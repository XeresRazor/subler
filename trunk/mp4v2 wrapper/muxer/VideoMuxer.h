//
//  MP42SubtitleTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "mp4v2.h"

int muxMOVVideoTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId);
int muxMP4VideoTrack(MP4FileHandle fileHandle, NSString* filePath, MP4TrackId srcTrackId);
