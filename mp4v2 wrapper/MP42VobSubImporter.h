//
//  SBVobSubImpoter.h
//  Subler
//
//  Created by Damiano Galassi on 20/12/12.
//
//

#import "MP42FileImporter.h"

@interface MP42VobSubImporter : MP42FileImporter {
    NSThread *dataReader;
    NSInteger readerStatus;

    NSArray *tracks;
    
    NSMutableArray *activeTracks;
    
    CGFloat progress;
}

@end
