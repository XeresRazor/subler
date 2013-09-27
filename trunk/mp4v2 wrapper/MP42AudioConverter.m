//
//  SBAudioConverter.m
//  Subler
//
//  Created by Damiano Galassi on 16/09/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import "MP42AudioConverter.h"
#import "MP42Track.h"
#import "MP42AudioTrack.h"
#import "MP42FileImporter.h"
#import "MP42MediaFormat.h"
#import "MP42Fifo.h"
#import "MP42Utilities.h"

#define FIFO_DURATION (0.5f)

NSString * const SBMonoMixdown = @"SBMonoMixdown";
NSString * const SBStereoMixdown = @"SBStereoMixdown";
NSString * const SBDolbyMixdown = @"SBDolbyMixdown";
NSString * const SBDolbyPlIIMixdown = @"SBDolbyPlIIMixdown";

@interface NSString (VersionStringCompare)
- (BOOL)isVersionStringOlderThan:(NSString *)older;
@end

@implementation NSString (VersionStringCompare)
- (BOOL)isVersionStringOlderThan:(NSString *)older
{
	if([self compare:older] == NSOrderedAscending)
		return TRUE;
	if([self hasPrefix:older] && [self length] > [older length] && [self characterAtIndex:[older length]] == 'b')
		//1.0b1 < 1.0, so check for it.
		return TRUE;
	return FALSE;
}
@end

#define ComponentNameKey @"Name"
#define ComponentArchiveNameKey @"ArchiveName"
#define ComponentTypeKey @"Type"

#define BundleVersionKey @"CFBundleVersion"
#define BundleIdentifierKey @"CFBundleIdentifier"

typedef enum
{
	InstallStatusInstalledInWrongLocation = 0,
	InstallStatusNotInstalled = 1,
	InstallStatusOutdatedWithAnotherInWrongLocation = 2,
	InstallStatusOutdated = 3,
	InstallStatusInstalledInBothLocations = 4,
	InstallStatusInstalled = 5
} InstallStatus;

typedef enum
{
	ComponentTypeQuickTime,
	ComponentTypeCoreAudio,
	ComponentTypeFramework
} ComponentType;

InstallStatus currentInstallStatus(InstallStatus status)
{
	return (status | 1);
}

InstallStatus setWrongLocationInstalled(InstallStatus status)
{
	return (status & ~1);
}

@implementation MP42AudioConverter

- (NSString *)installationBasePath:(BOOL)userInstallation
{
	if(userInstallation)
		return NSHomeDirectory();
	return @"/";
}

- (NSString *)quickTimeComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/QuickTime"];
}

- (NSString *)coreAudioComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/Audio/Plug-Ins/Components"];
}

- (NSString *)frameworkComponentDir:(BOOL)userInstallation
{
	return [[self installationBasePath:userInstallation] stringByAppendingPathComponent:@"Library/Frameworks"];
}

- (NSString *)basePathForType:(ComponentType)type user:(BOOL)userInstallation
{
	NSString *path = nil;
	
	switch(type)
	{
		case ComponentTypeCoreAudio:
			path = [self coreAudioComponentDir:userInstallation];
			break;
		case ComponentTypeQuickTime:
			path = [self quickTimeComponentDir:userInstallation];
			break;
		case ComponentTypeFramework:
			path = [self frameworkComponentDir:userInstallation];
			break;
	}
	return path;
}

- (InstallStatus)installStatusForComponent:(NSString *)component type:(ComponentType)type version:(NSString*) version;
{
	NSString *path = nil;
	InstallStatus ret = InstallStatusNotInstalled;

	path = [[self basePathForType:type user:YES] stringByAppendingPathComponent:component];

	NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict != nil)
	{
		NSString *currentVersion = [infoDict objectForKey:BundleVersionKey];;
		if([currentVersion isVersionStringOlderThan:version])
			ret = InstallStatusOutdated;
		else
			ret = InstallStatusInstalled;
	}

	/* Check other installation type */
	path = [[self basePathForType:type user:NO] stringByAppendingPathComponent:component];

	infoDict = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"]];
	if(infoDict != nil)
	{
		NSString *currentVersion = [infoDict objectForKey:BundleVersionKey];;
		if([currentVersion isVersionStringOlderThan:version])
			ret = InstallStatusOutdated;
		else
			ret = InstallStatusInstalled;
	}

	return (ret);
}

OSStatus EncoderDataProc(AudioConverterRef              inAudioConverter, 
                         UInt32*                        ioNumberDataPackets,
                         AudioBufferList*				ioData,
                         AudioStreamPacketDescription**	outDataPacketDescription,
                         void*							inUserData)
{
	struct AudioFileIO* afio = (struct AudioFileIO*)inUserData;

	// figure out how much to read
	if (*ioNumberDataPackets > afio->numPacketsPerRead) *ioNumberDataPackets = afio->numPacketsPerRead;

    // read from the fifo    
	UInt32 outNumBytes;
    unsigned int wanted = MIN(*ioNumberDataPackets * afio->srcSizePerPacket, sfifo_used(afio->fifo));

    outNumBytes = sfifo_read(afio->fifo, afio->srcBuffer, wanted);
    OSStatus err = noErr;
	if (outNumBytes < wanted) {
        *ioNumberDataPackets = 0;
		printf ("Input Proc Read error: %d (%4.4s)\n", (int)err, (char*)&err);
		return err;
	}

    if (*ioNumberDataPackets == 0)
		printf ("End\n");

    // put the data pointer into the buffer list

	ioData->mBuffers[0].mData = afio->srcBuffer;
	ioData->mBuffers[0].mDataByteSize = outNumBytes;
	ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;

    *ioNumberDataPackets = ioData->mBuffers[0].mDataByteSize / afio->srcSizePerPacket;

    afio->pos += *ioNumberDataPackets;

	if (outDataPacketDescription) {
		if (afio->pktDescs)
			*outDataPacketDescription = afio->pktDescs;
		else
			*outDataPacketDescription = NULL;
	}

	return err;
}

- (void)EncoderThreadMainRoutine:(id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    encoderDone = NO;
    OSStatus err;

    // set up aac converter
    AudioConverterRef converterEnc;
    AudioStreamBasicDescription inputFormat, encoderFormat;

    bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
	inputFormat.mSampleRate = sampleRate;
	inputFormat.mFormatID = kAudioFormatLinearPCM ;
	inputFormat.mFormatFlags =  kLinearPCMFormatFlagIsFloat | kAudioFormatFlagsNativeEndian;
    inputFormat.mBytesPerPacket = 4 * outputChannelCount;
    inputFormat.mFramesPerPacket = 1;
	inputFormat.mBytesPerFrame = inputFormat.mBytesPerPacket * inputFormat.mFramesPerPacket;
	inputFormat.mChannelsPerFrame = outputChannelCount;
	inputFormat.mBitsPerChannel = 32; 

    bzero( &encoderFormat, sizeof( AudioStreamBasicDescription ) );
    encoderFormat.mFormatID = kAudioFormatMPEG4AAC;
    encoderFormat.mSampleRate = ( Float64 ) inputFormat.mSampleRate;
    encoderFormat.mChannelsPerFrame = inputFormat.mChannelsPerFrame;    

    err = AudioConverterNew( &inputFormat, &encoderFormat, &converterEnc );
    if (err)
        NSLog(@"Boom encoder converter init failed");

    UInt32 tmp, tmpsiz = sizeof( tmp );

    // set encoder quality to maximum
    tmp = kAudioConverterQuality_Max;
    AudioConverterSetProperty( converterEnc, kAudioConverterCodecQuality,
                              sizeof( tmp ), &tmp );

    // set encoder bitrate control mode to constrained variable
    tmp = kAudioCodecBitRateControlMode_VariableConstrained;
    AudioConverterSetProperty( converterEnc, kAudioCodecPropertyBitRateControlMode,
                              sizeof( tmp ), &tmp );

    // set bitrate
    UInt32 bitrate = [[[NSUserDefaults standardUserDefaults] valueForKey:@"SBAudioBitrate"] integerValue];
    if (!bitrate) bitrate = 80;

    // get available bitrates
    AudioValueRange *bitrates;
    ssize_t bitrateCounts;
    err = AudioConverterGetPropertyInfo( converterEnc, kAudioConverterApplicableEncodeBitRates,
                                        &tmpsiz, NULL);
    if (err) {
        NSLog(@"err kAudioConverterApplicableEncodeBitRates From AudioConverter");
    }
    bitrates = malloc( tmpsiz );
    err = AudioConverterGetProperty( converterEnc, kAudioConverterApplicableEncodeBitRates,
                                    &tmpsiz, bitrates);
    if (err) {
        NSLog(@"err kAudioConverterApplicableEncodeBitRates From AudioConverter");
    }
    bitrateCounts = tmpsiz / sizeof( AudioValueRange );
    
    // set bitrate
    tmp = bitrate * outputChannelCount * 1000;
    if( tmp < bitrates[0].mMinimum )
        tmp = bitrates[0].mMinimum;
    if( tmp > bitrates[bitrateCounts-1].mMinimum )
        tmp = bitrates[bitrateCounts-1].mMinimum;
    free( bitrates );

    AudioConverterSetProperty( converterEnc, kAudioConverterEncodeBitRate,
                              sizeof( tmp ), &tmp );

    // get real input
    tmpsiz = sizeof( inputFormat );
    AudioConverterGetProperty( converterEnc,
                              kAudioConverterCurrentInputStreamDescription,
                              &tmpsiz, &inputFormat );
    
    // get real output
    tmpsiz = sizeof( encoderFormat );
    AudioConverterGetProperty( converterEnc,
                              kAudioConverterCurrentOutputStreamDescription,
                              &tmpsiz, &encoderFormat );

    // set up buffers and data proc info struct
	encoderData.srcBufferSize = 32768;
	encoderData.srcBuffer = (char *)malloc( encoderData.srcBufferSize );
	encoderData.pos = 0;
	encoderData.srcFormat = inputFormat;
    encoderData.srcSizePerPacket = inputFormat.mBytesPerPacket;
    encoderData.numPacketsPerRead = encoderData.srcBufferSize / encoderData.srcSizePerPacket;
    encoderData.pktDescs = NULL;
    encoderData.fifo = &fifo;

    // set up our output buffers

	int outputSizePerPacket = encoderFormat.mBytesPerPacket; // this will be non-zero if the format is CBR
    UInt32 size = sizeof(outputSizePerPacket);
    err = AudioConverterGetProperty(converterEnc, kAudioConverterPropertyMaximumOutputPacketSize,
                                    &size, &outputSizePerPacket);
    if (err)
        NSLog(@"Boom kAudioConverterPropertyMaximumOutputPacketSize");

	UInt32 theOutputBufSize = outputSizePerPacket;
	char* outputBuffer = (char*)malloc(theOutputBufSize);

    // grab the cookie from the converter and write it to the file
	UInt32 cookieSize = 0;
	err = AudioConverterGetPropertyInfo(converterEnc, kAudioConverterCompressionMagicCookie, &cookieSize, NULL);
    // if there is an error here, then the format doesn't have a cookie, so on we go
	if (!err && cookieSize) {
		char* cookie = (char *) malloc(cookieSize);
        UInt8* cookieBuffer;
        int size;

		err = AudioConverterGetProperty(converterEnc, kAudioConverterCompressionMagicCookie, &cookieSize, cookie);
		if (err) {
            NSLog(@"err Get Cookie From AudioConverter");
        }
        ReadESDSDescExt(cookie, &cookieBuffer, &size, 1);
        outputMagicCookie = [[NSData dataWithBytes:cookieBuffer length:size] retain];

        free(cookieBuffer);
		free(cookie);
	}

    // loop to convert data
	SInt64 outputPos = 0;
    
	while (1) {
        AudioStreamPacketDescription odesc = {0};
        
		// set up output buffer list
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
		fillBufList.mBuffers[0].mData = outputBuffer;
        
        while ((sfifo_used(&fifo) < (inputFormat.mBytesPerPacket * encoderFormat.mFramesPerPacket * 4)) && !readerDone)
            usleep(500);
        
        // convert data
		UInt32 ioOutputDataPackets = 1;
		err = AudioConverterFillComplexBuffer(converterEnc, EncoderDataProc, &encoderData, &ioOutputDataPackets,
                                              &fillBufList, &odesc);
        if (err)
            NSLog(@"Error converterEnc %ld", (long)err);
        if (ioOutputDataPackets == 0) {
			// this is the EOF conditon
			break;
		}
        
        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
        sample->data = malloc(fillBufList.mBuffers[0].mDataByteSize);
        memcpy(sample->data, outputBuffer, fillBufList.mBuffers[0].mDataByteSize);

        sample->size = fillBufList.mBuffers[0].mDataByteSize;
        sample->duration = 1024;
        sample->offset = 0;
        sample->timestamp = outputPos;
        sample->isSync = YES;

        while ([_outputSamplesBuffer isFull] && !_cancelled)
            usleep(500);

        [_outputSamplesBuffer enqueue:sample];
        [sample release];

		outputPos += ioOutputDataPackets;
    }

    free(outputBuffer);
    
    AudioConverterDispose(converterEnc);

    [pool release];

    encoderDone = YES;

    return;
}

// decoder input data proc callback

OSStatus DecoderDataProc(AudioConverterRef              inAudioConverter, 
                         UInt32*                        ioNumberDataPackets,
                         AudioBufferList*				ioData,
                         AudioStreamPacketDescription**	outDataPacketDescription,
                         void*							inUserData)
{
    OSStatus err = noErr;
    struct AudioFileIO * afio = inUserData;

    if (afio->sample)
        [afio->sample release];

    // figure out how much to read
	if (*ioNumberDataPackets > afio->numPacketsPerRead) *ioNumberDataPackets = afio->numPacketsPerRead;

    // read from the buffer    
    while (![afio->inputSamplesBuffer count] && !afio->fileReaderDone)
        usleep(250);

    if (![afio->inputSamplesBuffer count] && afio->fileReaderDone) {
        *ioNumberDataPackets = 0;
        return err;
    }
    else {
        afio->sample = [afio->inputSamplesBuffer deque];
    }

    // advance input file packet position
	afio->pos += *ioNumberDataPackets;

    // put the data pointer into the buffer list
	ioData->mBuffers[0].mData = afio->sample->data;
	ioData->mBuffers[0].mDataByteSize = afio->sample->size;
	ioData->mBuffers[0].mNumberChannels = afio->srcFormat.mChannelsPerFrame;

	if (outDataPacketDescription) {
		if (afio->pktDescs) {
            afio->pktDescs->mStartOffset = 0;
            afio->pktDescs->mVariableFramesInPacket = *ioNumberDataPackets;
            afio->pktDescs->mDataByteSize = afio->sample->size;
			*outDataPacketDescription = afio->pktDescs;
        }
		else
			*outDataPacketDescription = NULL;
	}

	return err;
}

- (void)DecoderThreadMainRoutine:(id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    OSStatus    err;

    // set up buffers and data proc info struct
	decoderData.srcBufferSize = 32768;
	decoderData.srcBuffer = (char *)malloc( decoderData.srcBufferSize );
	decoderData.pos = 0;
	decoderData.srcFormat = decoderData.inputFormat;    
    decoderData.numPacketsPerRead = 1;
    decoderData.pktDescs = (AudioStreamPacketDescription*)malloc(decoderData.numPacketsPerRead);
    decoderData.inputSamplesBuffer = _inputSamplesBuffer;

    // set up our output buffers
	AudioStreamPacketDescription* outputPktDescs = NULL;
	int outputSizePerPacket = decoderData.outputFormat.mBytesPerPacket; // this will be non-zero if the format is CBR
	UInt32 theOutputBufSize = 32768;
	char* outputBuffer = (char*)malloc(theOutputBufSize);

	UInt32 numOutputPackets = theOutputBufSize / outputSizePerPacket;

    // Launch the encoder thread
    encoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(EncoderThreadMainRoutine:) object:self];
    [encoderThread setName:@"AAC Encoder"];
    [encoderThread start];

    // Set up our fifo
    int ringbuffer_len = sampleRate * FIFO_DURATION * 4 * 23;
    sfifo_init(&fifo, ringbuffer_len );
    bufferSize = ringbuffer_len >> 1;
    buffer = (unsigned char *)malloc(bufferSize);

    decoderData.fifo = &fifo;

    // Check if we need to do any downmix
    hb_downmix_t    *downmix = NULL;
    hb_sample_t     *downmix_buffer = NULL;

    if (downmixType && inputChannelsCount == 6) {
        downmix = hb_downmix_init(HB_INPUT_CH_LAYOUT_3F2R | HB_INPUT_CH_LAYOUT_HAS_LFE, 
                                  downmixType);
    }
    else if (downmixType && inputChannelsCount == 5) {
        downmix = hb_downmix_init(HB_INPUT_CH_LAYOUT_3F2R, 
                                  downmixType);
    }
    else if (downmixType && inputChannelsCount == 4) {
        downmix = hb_downmix_init(HB_INPUT_CH_LAYOUT_3F1R, 
                                  downmixType);
    }
    else if (downmixType && inputChannelsCount == 3) {
        downmix = hb_downmix_init(HB_INPUT_CH_LAYOUT_STEREO | HB_INPUT_CH_LAYOUT_HAS_LFE, 
                                  downmixType);
    }
    else if (downmixType && inputChannelsCount == 2) {
        downmix = hb_downmix_init(HB_INPUT_CH_LAYOUT_STEREO, 
                                  downmixType);
    }

    // loop to convert data
	while (1) {
		// set up output buffer list
		AudioBufferList fillBufList;
		fillBufList.mNumberBuffers = 1;
		fillBufList.mBuffers[0].mNumberChannels = decoderData.inputFormat.mChannelsPerFrame;
		fillBufList.mBuffers[0].mDataByteSize = theOutputBufSize;
		fillBufList.mBuffers[0].mData = outputBuffer;

        // convert data
		UInt32 ioOutputDataPackets = numOutputPackets;
		err = AudioConverterFillComplexBuffer(decoderData.converter, DecoderDataProc, &decoderData, &ioOutputDataPackets,
                                              &fillBufList, outputPktDescs);
        if (err)
            NSLog(@"Error converterDec %ld", (long)err);
        if (ioOutputDataPackets == 0) {
			// this is the EOF conditon
			break;
		}

        
        if( ichanmap != &hb_qt_chan_map )  { 
            hb_layout_remap( ichanmap, &hb_qt_chan_map, layout, 
                            (float*)outputBuffer, 
                            ioOutputDataPackets ); 
        } 
        // Dowmnix the audio if needed
        if (downmix) {
            size_t samplesBufferSize = ioOutputDataPackets * outputChannelCount * sizeof(float);
            downmix_buffer = (float *)outputBuffer;

            hb_sample_t *samples = (hb_sample_t *)malloc(samplesBufferSize);
            hb_downmix(downmix, samples, downmix_buffer, ioOutputDataPackets);

            while (sfifo_space(&fifo) < (samplesBufferSize))
                usleep(5000);

            sfifo_write(&fifo, samples, samplesBufferSize);
            free(samples);
        }
        else {
            UInt32 inNumBytes = fillBufList.mBuffers[0].mDataByteSize;

            while (sfifo_space(&fifo) < inNumBytes)
                usleep(5000);

            sfifo_write(&fifo, outputBuffer, inNumBytes);
        }
    }
    readerDone = YES;

    free(outputBuffer);

    if (downmix)
        hb_downmix_close(&downmix);

    AudioConverterDispose(decoderData.converter);

    [pool drain];
    return;
}

- (BOOL)errorMessageForFormat:(NSString *)format error:(NSError **)outError
{
    // Check if perian is installed
    InstallStatus installStatus = [self installStatusForComponent:@"Perian.component" type:ComponentTypeQuickTime version:@"1.2"];

    if(currentInstallStatus(installStatus) == InstallStatusNotInstalled) {
        if (outError)
            *outError = MP42Error(@"Perian is not installed.",
                                  @"Perian is necessary for audio conversion in Subler. You can download it from http://perian.org/",
                                  130);
        
        return YES;
    }

    // Check if xiphqt is installed
    if ([format isEqualToString:MP42AudioFormatFLAC]) {
        InstallStatus installStatus = [self installStatusForComponent:@"XiphQT.component" type:ComponentTypeQuickTime version:@"0.1.9"];

        if(currentInstallStatus(installStatus) == InstallStatusNotInstalled) {
            installStatus = [self installStatusForComponent:@"XiphQT (decoders).component" type:ComponentTypeQuickTime version:@"0.1.9"];
            
            if(currentInstallStatus(installStatus) == InstallStatusNotInstalled) {
                if (outError)
                    *outError = MP42Error(@"XiphQT is not installed.",
                                          @"XiphQT is necessary for Flac audio conversion in Subler. You can download it from http://xiph.org/quicktime/",
                                          130);
                
                return YES;
            }
        }
    }
    
    if (outError)
        *outError = MP42Error(@"Unknown Error.",
                              @"Something went wrong in the audio converter",
                              130);

    return YES;
}

- (id)initWithTrack:(MP42AudioTrack *)track andMixdownType:(NSString *) mixdownType error:(NSError **)outError
{
    if ((self = [super init])) {
        OSStatus err;

        // Set the right mixdown to use
        sampleRate = [track.muxer_helper->importer timescaleForTrack:track];
        inputChannelsCount = [track sourceChannels];
        outputChannelCount = [track channels];

        if ([mixdownType isEqualToString:SBMonoMixdown] && inputChannelsCount > 1) {
            downmixType = HB_AMIXDOWN_MONO;
            outputChannelCount = 1;
        }
        else if ([mixdownType isEqualToString:SBStereoMixdown] && inputChannelsCount > 2) {
            downmixType = HB_AMIXDOWN_STEREO;
            outputChannelCount = 2;
        }
        else if ([mixdownType isEqualToString:SBDolbyMixdown] && inputChannelsCount > 2) {
            downmixType = HB_AMIXDOWN_DOLBY;
            outputChannelCount = 2;
        }
        else if ([mixdownType isEqualToString:SBDolbyPlIIMixdown] && inputChannelsCount > 2) {
            downmixType = HB_AMIXDOWN_DOLBYPLII;
            outputChannelCount = 2;
        }

        if (([track.sourceFormat isEqualToString:@"True HD"] || [track.sourceFormat isEqualToString:MP42AudioFormatAC3]) && inputChannelsCount == 6 ) {
            ichanmap = &hb_smpte_chan_map;
            layout = HB_INPUT_CH_LAYOUT_3F2R | HB_INPUT_CH_LAYOUT_HAS_LFE;
        }
        else {
            ichanmap = &hb_qt_chan_map;
        }

        _outputSamplesBuffer = [[MP42Fifo alloc] init];
        _inputSamplesBuffer = [[MP42Fifo alloc] init];

        // Decoder initialization
        CFDataRef   magicCookie = NULL;
        NSData * srcMagicCookie = [track.muxer_helper->importer magicCookieForTrack:track];
        AudioStreamBasicDescription inputFormat, outputFormat;

        bzero( &inputFormat, sizeof( AudioStreamBasicDescription ) );
        inputFormat.mSampleRate = sampleRate;
        inputFormat.mChannelsPerFrame = track.sourceChannels;

        if (track.sourceFormat) {
            if ([track.sourceFormat isEqualToString:MP42AudioFormatAAC]) {
                inputFormat.mFormatID = kAudioFormatMPEG4AAC;

                size_t cookieSize;
                uint8_t * cookie = CreateEsdsFromSetupData((uint8_t *)[srcMagicCookie bytes], [srcMagicCookie length], &cookieSize, 1, true, false);
                magicCookie = (CFDataRef) [[NSData dataWithBytes:cookie length:cookieSize] retain];
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatALAC]) {
                inputFormat.mFormatID = kAudioFormatAppleLossless;
                
                magicCookie = (CFDataRef) [srcMagicCookie retain];
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatVorbis]) {
                inputFormat.mFormatID = 'XiVs';

                magicCookie = createDescExt_XiphVorbis([srcMagicCookie length], [srcMagicCookie bytes]);
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatFLAC]) {
                inputFormat.mFormatID = 'XiFL';

                magicCookie = createDescExt_XiphFLAC([srcMagicCookie length], [srcMagicCookie bytes]);
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatAC3]) {
                inputFormat.mFormatID = kAudioFormatAC3;
                inputFormat.mFramesPerPacket = 1536;
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatDTS]) {
                inputFormat.mFormatID = 'DTS ';
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatMP3]) {
                inputFormat.mFormatID = kAudioFormatMPEGLayer3;
                inputFormat.mFramesPerPacket = 1152;
            }
            else if ([track.sourceFormat isEqualToString:@"True HD"]) {
                inputFormat.mFormatID = 'trhd';
            }
            else if ([track.sourceFormat isEqualToString:MP42AudioFormatPCM]) {
                AudioStreamBasicDescription temp = [track.muxer_helper->importer audioDescriptionForTrack:track];
                if (temp.mFormatID)
                    inputFormat = temp;
                else
                    inputFormat.mFormatID = kAudioFormatLinearPCM;
            }
        }

        bzero( &outputFormat, sizeof( AudioStreamBasicDescription ) );
        outputFormat.mSampleRate = sampleRate;
        outputFormat.mFormatID = kAudioFormatLinearPCM ;
        outputFormat.mFormatFlags =  kLinearPCMFormatFlagIsFloat | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
        outputFormat.mBytesPerPacket = 4 * track.sourceChannels;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mBytesPerFrame = outputFormat.mBytesPerPacket * outputFormat.mFramesPerPacket;
        outputFormat.mChannelsPerFrame = track.sourceChannels;
        outputFormat.mBitsPerChannel = 32;

        // initialize the decoder
        err = AudioConverterNew( &inputFormat, &outputFormat, &decoderData.converter );
        if ( err != noErr) {
            if (outError)
                if (![self errorMessageForFormat:track.sourceFormat error:outError]) {
                *outError = MP42Error(@"Audio Converter Error.",
                                      @"The Audio Converter can not be initialized",
                                      130);
                }
            if (magicCookie)
                CFRelease(magicCookie);
            [self release];
            return nil;
        }

        // set the decoder magic cookie
        if (magicCookie) {
            err = AudioConverterSetProperty(decoderData.converter, kAudioConverterDecompressionMagicCookie,
                                            CFDataGetLength(magicCookie) , CFDataGetBytePtr(magicCookie) );
            if( err != noErr)
                NSLog(@"Boom Magic Cookie %ld",(long)err);
            CFRelease(magicCookie);
        }

        // Try to set the input channel layout 
        /*UInt32 propertySize = 0;
        AudioChannelLayout * layout = NULL;
        err = AudioConverterGetPropertyInfo(decoderData.converter, kAudioConverterInputChannelLayout, &propertySize, NULL);

        if (err == noErr && propertySize > 0) {
            layout = malloc(sizeof(propertySize));
            err = AudioConverterGetProperty(decoderData.converter, kAudioConverterInputChannelLayout, &propertySize, layout);
            if (err) {
                NSLog(@"Unable to read the channel layout %ld",(long)err);
            }
            if (layout->mChannelLayoutTag != kAudioChannelLayoutTag_MPEG_5_1_D && inputChannelsCount > 2) {
                AudioChannelLayout * newLayout = malloc(sizeof(AudioChannelLayout));
                bzero( newLayout, sizeof( AudioChannelLayout ) );
                newLayout->mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_D;
                err = AudioConverterSetProperty(decoderData.converter, kAudioConverterInputChannelLayout, sizeof(AudioChannelLayout), newLayout);
                if(err)
                    NSLog(@"Unable to set the new channel layout %ld",(long)err);
                free(newLayout);
            }
            free(layout);
        }*/

        /*if (([track.sourceFormat isEqualToString:@"True HD"] || [track.sourceFormat isEqualToString:MP42AudioFormatAC3]) && inputChannelsCount == 6 ) {
            SInt32 channelMap[6] = { 2, 0, 1, 4, 5, 3 };
            AudioConverterSetProperty( decoderData.converter, kAudioConverterChannelMap,
                                      sizeof( channelMap ), channelMap );
        }*/

        // Read the complete inputStreamDescription from the audio converter.
        UInt32 size = sizeof(inputFormat);
        err = AudioConverterGetProperty( decoderData.converter, kAudioConverterCurrentInputStreamDescription,
                                        &size, &inputFormat);
        if( err != noErr)
            NSLog(@"Boom kAudioConverterCurrentInputStreamDescription %ld",(long)err);

        // Read the complete outputStreamDescription from the audio converter.
        size = sizeof(outputFormat);
        err = AudioConverterGetProperty(decoderData.converter, kAudioConverterCurrentOutputStreamDescription,
                                        &size, &outputFormat);
        if( err != noErr)
            NSLog(@"Boom kAudioConverterCurrentOutputStreamDescription %ld",(long)err);

        decoderData.inputFormat = inputFormat;
        decoderData.outputFormat = outputFormat;

        // Launch the decoder thread.
        decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(DecoderThreadMainRoutine:) object:self];
        [decoderThread setName:@"Audio Decoder"];
        [decoderThread start];
    }

    return self;
}

- (void)addSample:(MP42SampleBuffer *)sample
{
    [_inputSamplesBuffer enqueue:sample];
}

- (MP42SampleBuffer *)copyEncodedSample
{
    if (![_outputSamplesBuffer count])
        return nil;

    return [_outputSamplesBuffer deque];
}

- (BOOL)needMoreSample
{
    if ([_inputSamplesBuffer isFull])
        return NO;

    return YES;
}

- (void)setInputDone
{
    decoderData.fileReaderDone = YES;
    encoderData.fileReaderDone = YES;
}

- (void)cancel
{
    OSAtomicIncrement32(&_cancelled);

    decoderData.fileReaderDone = YES;
    encoderData.fileReaderDone = YES;

    [_inputSamplesBuffer cancel];
    [_outputSamplesBuffer cancel];

    while (!(readerDone && encoderDone))
        usleep(500);
}

- (BOOL)encoderDone
{
    return encoderDone && [_outputSamplesBuffer isEmpty];
}

- (NSData *)magicCookie
{
    return [[outputMagicCookie retain] autorelease];
}

- (void)dealloc
{
    sfifo_close(&fifo);

    free(decoderData.srcBuffer);
    free(decoderData.pktDescs);

    free(encoderData.srcBuffer);
    free(encoderData.pktDescs);

    [outputMagicCookie release];

    [decoderThread release];
    [encoderThread release];

    [_outputSamplesBuffer release];
    [_inputSamplesBuffer release];

    [super dealloc];
}

@end
