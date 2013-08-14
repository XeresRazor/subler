//
//  MP42MkvFileImporter.h
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MP42FileImporter.h"

@interface MP42MkvImporter : MP42FileImporter {
    struct MatroskaFile	*_matroskaFile;
	struct StdIoStream  *_ioStream;

    u_int64_t   _fileDuration;
}

@end