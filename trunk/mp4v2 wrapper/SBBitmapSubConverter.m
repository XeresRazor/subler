//
//  SBVobSubConverter.m
//  Subler
//
//  Created by Damiano Galassi on 26/03/11.
//  VobSub code taken from Perian VobSubCodec.c
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBBitmapSubConverter.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MP42Sample.h"
#import "SubUtilities.h"
#import "SBOCRWrapper.h"

#define REGISTER_DECODER(x) { \
extern AVCodec ff_##x##_decoder; \
avcodec_register(&ff_##x##_decoder); }

void FFInitFFmpeg()
{
	static dispatch_once_t once;

	dispatch_once(&once, ^{
		REGISTER_DECODER(dvdsub);
        REGISTER_DECODER(pgssub);
	});
}

@implementation SBBitmapSubConverter

- (void) VobSubDecoderThreadMainRoutine: (id) sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    MP42SampleBuffer* subSample;

    while(1) {
        while (![inputSamplesBuffer count] && !fileReaderDone)
            usleep(1000);

        if (![inputSamplesBuffer count] && fileReaderDone)
            break;

        MP42SampleBuffer* sampleBuffer = [inputSamplesBuffer objectAtIndex:0];
        UInt8 *data = (UInt8 *) sampleBuffer->sampleData;
        int ret, got_sub;

        if(sampleBuffer->sampleSize < 4)
        {
            subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration, NO);
            @synchronized(outputSamplesBuffer) {
                [outputSamplesBuffer addObject:subSample];    
            }

            [subSample release];

            [inputSamplesBuffer removeObjectAtIndex:0];

            continue;
        }

        if (codecData == NULL) {
            codecData = av_malloc(sampleBuffer->sampleSize + 2);
            bufferSize = sampleBuffer->sampleSize + 2;
        }

        // make sure we have enough space to store the packet
        codecData = fast_realloc_with_padding(codecData, &bufferSize, sampleBuffer->sampleSize + 2);

        // the header of a spu PS packet starts 0x000001bd
        // if it's raw spu data, the 1st 2 bytes are the length of the data
        if (data[0] + data[1] == 0) {
            // remove the MPEG framing
            sampleBuffer->sampleSize = ExtractVobSubPacket(codecData, data, bufferSize, NULL, -1);
        } else {
            memcpy(codecData, sampleBuffer->sampleData, sampleBuffer->sampleSize);
        }

        AVPacket pkt;
        av_init_packet(&pkt);
        pkt.data = codecData;
        pkt.size = bufferSize;
        ret = avcodec_decode_subtitle2(avContext, &subtitle, &got_sub, &pkt);

        if (ret < 0 || !got_sub) {
            NSLog(@"Error decoding DVD subtitle %d / %ld", ret, (long)bufferSize);
            
            subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration, NO);
            @synchronized(outputSamplesBuffer) {
                [outputSamplesBuffer addObject:subSample];
            }
            [subSample release];
            
            [inputSamplesBuffer removeObjectAtIndex:0];

            continue;
        }

        unsigned int i, x, j, y;
        uint8_t *imageData;

        OSErr err = noErr;
        PacketControlData controlData;

        memcpy(paletteG, [srcMagicCookie bytes], sizeof(UInt32)*16);
        int ii;
        for ( ii = 0; ii <16; ii++ )
            paletteG[ii] = EndianU32_LtoN(paletteG[ii]);

        BOOL forced = NO;
        err = ReadPacketControls(codecData, paletteG, &controlData, &forced);
        int usePalette = 0;

        if (err == noErr)
            usePalette = true;

        for (i = 0; i < subtitle.num_rects; i++) {
            AVSubtitleRect *rect = subtitle.rects[i];

            imageData = malloc(sizeof(uint8_t) * rect->w * rect->h * 4);
            memset(imageData, 0, rect->w * rect->h * 4);

            uint8_t *line = (uint8_t *)imageData;
            uint8_t *sub = rect->pict.data[0];
            unsigned int w = rect->w;
            unsigned int h = rect->h;
            uint32_t *palette = (uint32_t *)rect->pict.data[1];

            if (usePalette) {
                for (j = 0; j < 4; j++)
                    palette[j] = EndianU32_BtoN(controlData.pixelColor[j]);
            }

            for (y = 0; y < h; y++) {
                uint32_t *pixel = (uint32_t *) line;
                
                for (x = 0; x < w; x++)
                    pixel[x] = palette[sub[x]];

                line += rect->w*4;
                sub += rect->pict.linesize[0];
            }

            size_t length = sizeof(uint8_t) * rect->w * rect->h * 4;
            uint8_t* imgData2 = (uint8_t*)imageData;
            for (i = 0; i < length; i +=4) {
                imgData2[i] = 255;
            }

            CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaFirst;
            CFDataRef imgData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, imageData, w*h*4, kCFAllocatorNull);
            CGDataProviderRef provider = CGDataProviderCreateWithCFData(imgData);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGImageRef cgImage = CGImageCreate(w,
                                               h,
                                               8,
                                               32,
                                               w*4,
                                               colorSpace,
                                               bitmapInfo,
                                               provider,
                                               NULL,
                                               NO,
                                               kCGRenderingIntentDefault);
            CGColorSpaceRelease(colorSpace);

            //NSBitmapImageRep *bitmapImage = [[NSBitmapImageRep alloc]initWithCGImage:(CGImageRef)cgImage];
            //[[bitmapImage representationUsingType:NSTIFFFileType properties:nil] writeToFile:@"/tmp/foo.tif" atomically:YES];
            //[bitmapImage release];

            NSString *text = [ocr performOCROnCGImage:cgImage];

            if (text)
                subSample = copySubtitleSample(trackId, text, sampleBuffer->sampleDuration, forced);
            else
                subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration, forced);

            @synchronized(outputSamplesBuffer) {
                [outputSamplesBuffer addObject:subSample];
            }

            [subSample release];

            CGImageRelease(cgImage);
            CGDataProviderRelease(provider);
            CFRelease(imgData);

            free(imageData);
        }

        avsubtitle_free(&subtitle);
        av_free_packet(&pkt);
        [inputSamplesBuffer removeObjectAtIndex:0];
    }

    encoderDone = YES;
    [pool drain];
}

- (void) PGSDecoderThreadMainRoutine: (id) sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    MP42SampleBuffer* subSample;

    while(1) {
        while (![inputSamplesBuffer count] && !fileReaderDone)
            usleep(1000);

        if (![inputSamplesBuffer count] && fileReaderDone)
            break;

        MP42SampleBuffer* sampleBuffer = [inputSamplesBuffer objectAtIndex:0];
        int ret, got_sub, i;
        uint32_t *imageData;
        BOOL forced = NO;

        AVPacket pkt;
        av_init_packet(&pkt);
        pkt.data = sampleBuffer->sampleData;
        pkt.size = sampleBuffer->sampleSize;

        ret = avcodec_decode_subtitle2(avContext, &subtitle, &got_sub, &pkt);

        if (ret < 0 || !got_sub || !subtitle.num_rects) {
            subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration, NO);

            @synchronized(outputSamplesBuffer) {
                [outputSamplesBuffer addObject:subSample];
            }

            [subSample release];
            [inputSamplesBuffer removeObjectAtIndex:0];

            continue;
        }

        for (i = 0; i < subtitle.num_rects; i++) {
            AVSubtitleRect *rect = subtitle.rects[i];
            NSString *text;

            imageData = malloc(sizeof(uint32_t) * rect->w * rect->h * 4);
            memset(imageData, 0, rect->w * rect->h * 4);

            int xx, yy;
            for (yy = 0; yy < rect->h; yy++)
            {
                for (xx = 0; xx < rect->w; xx++)
                {
                    uint32_t argb;
                    int pixel;
                    uint8_t color;

                    pixel = yy * rect->w + xx;
                    color = rect->pict.data[0][pixel];
                    argb = ((uint32_t*)rect->pict.data[1])[color];

                    imageData[yy * rect->w + xx] = EndianU32_BtoN(argb);
                    /* Remove the alpha channel, and set fully transparent pixel to black
                       TODO: real compositing on a black background */
                    if (!(imageData[yy * rect->w + xx] & 0xFF))
                        imageData[yy * rect->w + xx] = 0x000000FF;
                    else
                        imageData[yy * rect->w + xx] = (imageData[yy * rect->w + xx] & 0xFFFFFF00) + 0xFF;
                }
            }

            if (rect->flags & AV_SUBTITLE_FLAG_FORCED)
                forced = YES;

            CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaFirst;
            CFDataRef imgData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (uint8_t*)imageData,rect->w * rect->h * 4, kCFAllocatorNull);
            CGDataProviderRef provider = CGDataProviderCreateWithCFData(imgData);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGImageRef cgImage = CGImageCreate(rect->w,
                                               rect->h,
                                               8,
                                               32,
                                               rect->w * 4,
                                               colorSpace,
                                               bitmapInfo,
                                               provider,
                                               NULL,
                                               NO,
                                               kCGRenderingIntentDefault);
            CGColorSpaceRelease(colorSpace);

            if ((text = [ocr performOCROnCGImage:cgImage]))
                subSample = copySubtitleSample(trackId, text, sampleBuffer->sampleDuration, forced);
            else
                subSample = copyEmptySubtitleSample(trackId, sampleBuffer->sampleDuration, forced);

            @synchronized(outputSamplesBuffer) {
                [outputSamplesBuffer addObject:subSample];
            }

            [subSample release];

            CGImageRelease(cgImage);
            CGDataProviderRelease(provider);
            CFRelease(imgData);

            free(imageData);
        }

        avsubtitle_free(&subtitle);
        av_free_packet(&pkt);
        [inputSamplesBuffer removeObjectAtIndex:0];
    }

    encoderDone = YES;
    [pool drain];
}

- (id) initWithTrack: (MP42SubtitleTrack*) track error:(NSError **)outError
{
    if ((self = [super init])) {
        if (!avCodec) {
            FFInitFFmpeg();

            if (([track.sourceFormat isEqualToString:@"VobSub"]))
                avCodec = avcodec_find_decoder(AV_CODEC_ID_DVD_SUBTITLE);
            else if (([track.sourceFormat isEqualToString:@"PGS"]))
                avCodec = avcodec_find_decoder(AV_CODEC_ID_HDMV_PGS_SUBTITLE);

            avContext = avcodec_alloc_context3(NULL);

            if (avcodec_open2(avContext, avCodec, NULL)) {
                NSLog(@"Error opening subtitle decoder");
                av_freep(&avContext);
                return nil;
            }
        }

        outputSamplesBuffer = [[NSMutableArray alloc] init];
        inputSamplesBuffer = [[NSMutableArray alloc] init];

        srcMagicCookie = [[[track trackImporterHelper] magicCookieForTrack:track] retain];

        ocr = [[SBOCRWrapper alloc] initWithLanguage:[track language]];

        if (([track.sourceFormat isEqualToString:@"VobSub"])) {
            // Launch the vobsub decoder thread.
            decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(VobSubDecoderThreadMainRoutine:) object:self];
            [decoderThread setName:@"VobSub Decoder"];
            [decoderThread start];
        }
        else if (([track.sourceFormat isEqualToString:@"PGS"])) {
            // Launch the pgs decoder thread.
            decoderThread = [[NSThread alloc] initWithTarget:self selector:@selector(PGSDecoderThreadMainRoutine:) object:self];
            [decoderThread setName:@"PGS Decoder"];
            [decoderThread start];
        }

    }

    return self;
}

- (void) setOutputTrack: (NSUInteger) outputTrackId {
    trackId = outputTrackId;
}

- (void) addSample:(MP42SampleBuffer*)sample
{
    @synchronized(inputSamplesBuffer) {
        [inputSamplesBuffer addObject:sample];
    }
}

- (MP42SampleBuffer*) copyEncodedSample
{
    MP42SampleBuffer *sample;
    if (![outputSamplesBuffer count]) {
        return nil;
    }
    @synchronized(outputSamplesBuffer) {
        sample = [outputSamplesBuffer objectAtIndex:0];
        [sample retain];
        [outputSamplesBuffer removeObjectAtIndex:0];
    }
    
    return sample;
}

- (BOOL) needMoreSample
{
    if ([inputSamplesBuffer count])
        return NO;

    return YES;
}

- (void) setDone:(BOOL)status
{
    fileReaderDone = YES;
}

- (BOOL) encoderDone
{
    return encoderDone;
}

- (void) dealloc
{
    int i;

    if (codecData) {
        av_freep(&codecData);
    }
    if (avCodec) {
        avcodec_close(avContext);
    }
    if (avContext) {
        av_freep(&avContext);
    }
    if (subtitle.rects) {
        for (i = 0; i < subtitle.num_rects; i++) {
            av_freep(&subtitle.rects[i]->pict.data[0]);
            av_freep(&subtitle.rects[i]->pict.data[1]);
            av_freep(&subtitle.rects[i]);
        }
        av_freep(&subtitle.rects);
    }

    [srcMagicCookie release];
    [outputSamplesBuffer release];
    [inputSamplesBuffer release];

    [decoderThread release];
    [ocr release];
    [super dealloc];
}

@end
