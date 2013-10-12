//
//  MP42Sample.m
//  Subler
//
//  Created by Damiano Galassi on 29/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import "MP42Sample.h"


@implementation MP42SampleBuffer

- (id)init
{
    self = [super init];
    if (self) {
        _retainCount = 1;
    }
    return self;
}

- (void)dealloc {
    free(data);
    [super dealloc];
}

- (id)retain {
    OSAtomicIncrement32(&_retainCount);
    return self;
}

- (oneway void)release {
     OSAtomicDecrement32(&_retainCount);

    if (!_retainCount)
        [self dealloc];
}

@end
