//
//  SBVobSubImpoter.h
//  Subler
//
//  Created by Damiano Galassi on 20/12/12.
//
//

#import "MP42FileImporter.h"

@interface SBVobSubSample : NSObject
{
@public
	long		timeStamp;
	long		fileOffset;
}

- (id)initWithTime:(long)time offset:(long)offset;
@end

@interface SBVobSubTrack : NSObject
{
@public
	NSArray         *privateData;
	NSString		*language;
	int				index;
    long            duration;
	NSMutableArray	*samples;
}

- (id)initWithPrivateData:(NSArray *)idxPrivateData language:(NSString *)lang andIndex:(int)trackIndex;
- (void)addSample:(SBVobSubSample *)sample;
- (void)addSampleTime:(long)time offset:(long)offset;

@end

@interface MP42VobSubImporter : MP42FileImporter {
    NSThread *dataReader;
    NSInteger readerStatus;

    NSArray *tracks;
    
    NSMutableArray *samplesBuffer;
    NSMutableArray *activeTracks;
    
    CGFloat progress;
}

@end
