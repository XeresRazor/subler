//
//  SBAudioConverter.h
//  Subler
//
//  Created by Damiano Galassi on 16/09/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "sfifo.h"
#include "downmix.h"
#import "MP42ConverterProtocol.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CoreAudio/CoreAudio.h>

@class MP42SampleBuffer;
@class MP42Fifo;
@class MP42AudioTrack;

extern NSString * const SBMonoMixdown;
extern NSString * const SBStereoMixdown;
extern NSString * const SBDolbyMixdown;
extern NSString * const SBDolbyPlIIMixdown;

// a struct to hold info for the data proc
struct AudioFileIO
{    
    AudioConverterRef converter;
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;

    sfifo_t          *fifo;

	SInt64          pos;
	char *			srcBuffer;
	UInt32			srcBufferSize;
	UInt32			srcSizePerPacket;
	UInt32			numPacketsPerRead;

    AudioStreamBasicDescription     srcFormat;
	AudioStreamPacketDescription    *pktDescs;

    MP42Fifo      *inputSamplesBuffer;

    MP42SampleBuffer      *sample;
    int                   fileReaderDone;
} AudioFileIO;

@interface MP42AudioConverter : NSObject <MP42ConverterProtocol> {
    NSThread *decoderThread;
    NSThread *encoderThread;

    unsigned char *buffer;
    int bufferSize;
    sfifo_t fifo;

    BOOL readerDone;
    BOOL encoderDone;

    int32_t       _cancelled;

    NSUInteger  trackId;
    Float64     sampleRate;
    NSUInteger  inputChannelsCount;
    NSUInteger  outputChannelCount;
    NSUInteger  downmixType;
    NSUInteger  layout;
    hb_chan_map_t *ichanmap;

    MP42Fifo    *_inputSamplesBuffer;
    MP42Fifo    *_outputSamplesBuffer;

    NSData * outputMagicCookie;

    struct AudioFileIO decoderData;
    struct AudioFileIO encoderData;
}

- (id)initWithTrack:(MP42AudioTrack*)track andMixdownType:(NSString *)mixdownType error:(NSError **)outError;
- (void)setOutputTrack:(NSUInteger)outputTrackId;

- (void)addSample:(MP42SampleBuffer *)sample;
- (MP42SampleBuffer *)copyEncodedSample;

- (NSData *)magicCookie;

- (void)cancel;
- (BOOL)encoderDone;

- (BOOL)needMoreSample;
- (void)setInputDone;

@end
