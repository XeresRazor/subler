//
//  MP42Muxer.m
//  Subler
//
//  Created by Damiano Galassi on 30/06/10.
//  Copyright 2010 Damiano Galassi. All rights reserved.
//

#import "MP42Muxer.h"
#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MP42Sample.h"

@implementation MP42Muxer

-(id)init
{
    if ((self = [super init]))
    {
        workingTracks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addTrack:(MP42Track*)track{
    [workingTracks addObject:track];
}

- (void)startWork:(MP4FileHandle)fileHandle
{
    for (MP42Track * track in workingTracks)
    {
        MP4TrackId dstTrackId;
        NSData *magicCookie = [[track trackImporterHelper] magicCookieForTrack:track];
        NSInteger timeScale = [[track trackImporterHelper] timescaleForTrack:track];

        if ([track isMemberOfClass:[MP42VideoTrack class]] && [track.format isEqualToString:@"H.264"]) {
            NSSize size = [[track trackImporterHelper] sizeForTrack:track];

            uint8_t* avcCAtom = (uint8_t*)[magicCookie bytes];
            dstTrackId = MP4AddH264VideoTrack(fileHandle, timeScale,
                                              MP4_INVALID_DURATION,
                                              size.width, size.height,
                                              avcCAtom[1],  // AVCProfileIndication
                                              avcCAtom[2],  // profile_compat
                                              avcCAtom[3],  // AVCLevelIndication
                                              avcCAtom[4]); // lengthSizeMinusOne

            SInt64 i;
            int8_t spsCount = (avcCAtom[5] & 0x1f);
            uint8_t ptrPos = 6;
            for (i = 0; i < spsCount; i++) {
                uint16_t spsSize = (avcCAtom[ptrPos++] << 8) & 0xff00;
                spsSize += avcCAtom[ptrPos++] & 0xff;
                MP4AddH264SequenceParameterSet(fileHandle, dstTrackId,
                                               avcCAtom+ptrPos, spsSize);
                ptrPos += spsSize;
            }

            int8_t ppsCount = avcCAtom[ptrPos++];
            for (i = 0; i < ppsCount; i++) {
                uint16_t ppsSize = (avcCAtom[ptrPos++] << 8) & 0xff00;
                ppsSize += avcCAtom[ptrPos++] & 0xff;
                MP4AddH264PictureParameterSet(fileHandle, dstTrackId,
                                              avcCAtom+ptrPos, ppsSize);
                ptrPos += ppsSize;
            }

            MP4SetVideoProfileLevel(fileHandle, 0x15);
        }
        else if ([track isMemberOfClass:[MP42VideoTrack class]] && [track.format isEqualToString:@"MPEG-4 Visual"]) {
            MP4SetVideoProfileLevel(fileHandle, MPEG4_SP_L3);
            // Add video track
            dstTrackId = MP4AddVideoTrack(fileHandle, timeScale,
                                          MP4_INVALID_DURATION,
                                          [(MP42VideoTrack*)track width], [(MP42VideoTrack*)track height],
                                          MP4_MPEG4_VIDEO_TYPE);
            MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                                       [magicCookie bytes],
                                       [magicCookie length]);
            
        }
        else if ([track isMemberOfClass:[MP42AudioTrack class]] && [track.format isEqualToString:@"AAC"]) {
            dstTrackId = MP4AddAudioTrack(fileHandle,
                                          timeScale,
                                          1024, MP4_MPEG4_AUDIO_TYPE);

            MP4SetTrackESConfiguration(fileHandle, dstTrackId,
                                       [magicCookie bytes],
                                       [magicCookie length]);
        }
        else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
            NSSize videoSize = [[track trackImporterHelper] sizeForTrack:track];
            const uint8_t textColor[4] = { 255,255,255,255 };
            dstTrackId = MP4AddSubtitleTrack(fileHandle, timeScale, videoSize.width, 80);

            MP4SetTrackDurationPerChunk(fileHandle, dstTrackId, timeScale / 8);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.alternate_group", 2);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.layer", -1);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.horizontalJustification", 1);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.verticalJustification", -1);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.bgColorAlpha", 255);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", 80);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", videoSize.width);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontSize", 24);

            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorRed", textColor[0]);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorGreen", textColor[1]);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorBlue", textColor[2]);
            MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorAlpha", textColor[3]);

            /* translate the track */
            uint8_t* val;
            uint8_t nval[36];
            uint32_t *ptr32 = (uint32_t*) nval;
            uint32_t size;

            MP4GetTrackBytesProperty(fileHandle, dstTrackId, "tkhd.matrix", &val, &size);
            memcpy(nval, val, size);
            ptr32[7] = CFSwapInt32HostToBig( (videoSize.width - 80) * 0x10000);

            MP4SetTrackBytesProperty(fileHandle, dstTrackId, "tkhd.matrix", nval, size);
            free(val);
        }
        track.Id = dstTrackId;
    }
}

- (void)work:(MP4FileHandle)fileHandle
{
    for (MP42Track * track in workingTracks) {

        MP42SampleBuffer * sampleBuffer;
        MP42FileImporter * helper = [track trackImporterHelper];

        while ((sampleBuffer = [helper nextSampleForTrack:track]) != nil) {

            MP4WriteSample(fileHandle, sampleBuffer->sampleTrackId,
                           sampleBuffer->sampleData, sampleBuffer->sampleSize,
                           sampleBuffer->sampleDuration, sampleBuffer->sampleOffset,
                           sampleBuffer->sampleIsSync);

            [sampleBuffer release];
        }
    }
}

- (void)stopWork:(MP4FileHandle)fileHandle
{
    
}

- (void) dealloc
{
    [workingTracks release], workingTracks = nil;
    [super dealloc];
}

@end
