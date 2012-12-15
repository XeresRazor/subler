//
//  QTKitDecrap.h
//  Subler
//
//  Created by Damiano Galassi on 13/12/12.
//  Duplicate and fix QTMetadataItem so it can be compiled while targetting 10.6.
//  Who knows the reason, it's so easy in Cocoa to check if a class exists at runtime...
//  Oh and almost all the constants from QTMetadataItem all broken, @ instead of ©.
//  Plus define a QTKit costant.

#import "QTKitDecrap.h"

@implementation QTMovie (QTMovieSublerExtras)

- (QTTrack*) trackWithTrackID:(NSInteger)trackID
{
    for (QTTrack *track in [self tracks])
        if (trackID == [[track attributeForKey:QTTrackIDAttribute] integerValue])
            return track;
    return nil;
}

@end
