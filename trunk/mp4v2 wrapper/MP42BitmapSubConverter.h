//
//  SBVobSubConverter.h
//  Subler
//
//  Created by Damiano Galassi on 26/03/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MP42ConverterProtocol.h"

#include "avcodec.h"

@class MP42SampleBuffer;
@class MP42SubtitleTrack;
@class MP42OCRWrapper;

@interface MP42BitmapSubConverter : NSObject <MP42ConverterProtocol> {
    NSThread *decoderThread;
    NSThread *encoderThread;

    MP42OCRWrapper *ocr;
    
	AVCodec                 *avCodec;
	AVCodecContext          *avContext;
	AVSubtitle              subtitle;
    BOOL readerDone;
    BOOL encoderDone;

    NSUInteger  trackId;

    NSMutableArray * inputSamplesBuffer;
    NSMutableArray * outputSamplesBuffer;

    int                     compressed;
	UInt32                  paletteG[16];
    NSData * srcMagicCookie;

    uint8_t                 *codecData;
    unsigned int            bufferSize;
    
    BOOL                   fileReaderDone;
}

- (id)initWithTrack:(MP42SubtitleTrack *)track error:(NSError **)outError;

- (void)setOutputTrack:(NSUInteger)outputTrackId;
- (void)addSample: (MP42SampleBuffer *)sample;
- (MP42SampleBuffer *)copyEncodedSample;

- (BOOL)needMoreSample;

- (BOOL)encoderDone;
- (void)setDone:(BOOL)status;

@end
