//
//  MP42ConverterProtocol.h
//  Subler
//
//  Created by Damiano Galassi on 05/08/13.
//
//

#import <Foundation/Foundation.h>
#import "MP42Sample.h"

@protocol MP42ConverterProtocol <NSObject>

@optional
- (NSData *)magicCookie;

@required
- (void)addSample:(MP42SampleBuffer *)sample;
- (MP42SampleBuffer *)copyEncodedSample;

- (void)cancel;
- (BOOL)encoderDone;

- (void)setInputDone;

@end
