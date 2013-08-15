//
//  MP42VideoTrack.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42Track.h"

@interface MP42VideoTrack : MP42Track <NSCoding> {
    uint64_t width, height;
    float trackWidth, trackHeight;

    // Pixel Aspect Ratio
    uint64_t hSpacing, vSpacing;

    // Clean Aperture
    uint64_t cleanApertureWidthN, cleanApertureWidthD;
    uint64_t cleanApertureHeightN, cleanApertureHeightD;
    uint64_t horizOffN, horizOffD;
    uint64_t vertOffN, vertOffD;

    // Matrix
    uint32_t offsetX, offsetY;

    // H.264 profile
    uint8_t origProfile, origLevel;
    uint8_t newProfile, newLevel;
}

@property(readwrite) uint64_t width;
@property(readwrite) uint64_t height;

@property(readwrite) float trackWidth;
@property(readwrite) float trackHeight;

@property(readwrite) uint64_t hSpacing;
@property(readwrite) uint64_t vSpacing;

@property(readwrite) uint64_t cleanApertureWidthN;
@property(readwrite) uint64_t cleanApertureWidthD;
@property(readwrite) uint64_t cleanApertureHeightN;
@property(readwrite) uint64_t cleanApertureHeightD;
@property(readwrite) uint64_t horizOffN;
@property(readwrite) uint64_t horizOffD;
@property(readwrite) uint64_t vertOffN;
@property(readwrite) uint64_t vertOffD;

@property(readwrite) uint32_t offsetX;
@property(readwrite) uint32_t offsetY;

@property(readwrite) uint8_t origProfile;
@property(readwrite) uint8_t origLevel;
@property(readwrite) uint8_t newProfile;
@property(readwrite) uint8_t newLevel;

@end
