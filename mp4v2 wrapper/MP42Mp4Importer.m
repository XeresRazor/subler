//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42Mp4Importer.h"
#import "SBLanguages.h"
#import "MP42Sample.h"

@interface MP4DemuxkHelper : NSObject {
@public
    MP4SampleId     currentSampleId;
    uint64_t        totalSampleNumber;
    MP4Timestamp    currentTime;
    uint64_t        timeScale;

    uint32_t        done;
}
@end

@implementation MP4DemuxkHelper
@end

@implementation MP42Mp4Importer

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError;
{
    if ((self = [super init])) {
        _fileURL = [fileURL retain];

        MP42File *sourceFile = [[MP42File alloc] initWithExistingFile:_fileURL andDelegate:self];

        if(!sourceFile) {
            if (outError) {
                *outError = MP42Error(@"The movie could not be opened.", @"The file is not a mp4 file.", 100);          
            }

            [self release];
            return nil;
        }

        _tracksArray = [[sourceFile tracks] mutableCopy];
        _metadata = [[sourceFile metadata] retain];

        [sourceFile release];
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return MP4GetTrackTimeScale(_fileHandle, [track sourceId]);
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    MP42VideoTrack* currentTrack = (MP42VideoTrack*) track;

    return NSMakeSize([currentTrack width], [currentTrack height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    if (!_fileHandle)
        _fileHandle = MP4Read([[_fileURL path] UTF8String]);

    NSData *magicCookie = nil;
    MP4TrackId srcTrackId = [track sourceId];

    const char *trackType = MP4GetTrackType(_fileHandle, srcTrackId);
    const char *media_data_name = MP4GetTrackMediaDataName(_fileHandle, srcTrackId);

    if (MP4_IS_AUDIO_TRACK_TYPE(trackType))
    {
        if (!strcmp(media_data_name, "ac-3")) {
            uint64_t fscod, bsid, bsmod, acmod, lfeon, bit_rate_code;
            MP4GetTrackIntegerProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.fscod", &fscod);
            MP4GetTrackIntegerProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bsid", &bsid);
            MP4GetTrackIntegerProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bsmod", &bsmod);
            MP4GetTrackIntegerProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.acmod", &acmod);
            MP4GetTrackIntegerProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.lfeon", &lfeon);
            MP4GetTrackIntegerProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.ac-3.dac3.bit_rate_code", &bit_rate_code);

            NSMutableData *ac3Info = [[NSMutableData alloc] init];
            [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bit_rate_code length:sizeof(uint64_t)];

            return [ac3Info autorelease];
            
        } else if (!strcmp(media_data_name, "alac")) {
            if (MP4HaveTrackAtom(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.alac.alac")) {
                uint8_t*     ppValue;
                uint32_t     pValueSize;
                MP4GetTrackBytesProperty(_fileHandle, srcTrackId, "mdia.minf.stbl.stsd.alac.alac.AppleLosslessMagicCookie", &ppValue, &pValueSize);
                magicCookie = [NSData dataWithBytes:ppValue length:pValueSize];
            }
        }
        else {
            uint8_t *ppConfig; uint32_t pConfigSize;
            MP4GetTrackESConfiguration(_fileHandle, srcTrackId, &ppConfig, &pConfigSize);
            magicCookie = [NSData dataWithBytes:ppConfig length:pConfigSize];
            free(ppConfig);
        }
        return magicCookie;
    }

    else if (!strcmp(trackType, MP4_SUBPIC_TRACK_TYPE)) {
        uint8_t *ppConfig; uint32_t pConfigSize;
        MP4GetTrackESConfiguration(_fileHandle, srcTrackId, &ppConfig, &pConfigSize);

        UInt32* paletteG = (UInt32 *) ppConfig;

        int ii;
        for ( ii = 0; ii < 16; ii++ )
            paletteG[ii] = yuv2rgb(EndianU32_BtoN(paletteG[ii]));

        magicCookie = [NSData dataWithBytes:paletteG length:pConfigSize];
        free(paletteG);

        return magicCookie;
    }

    else if (MP4_IS_VIDEO_TRACK_TYPE(trackType))
    {
        if (!strcmp(media_data_name, "avc1")) {
            // Extract and rewrite some kind of avcC extradata from the mp4 file.
            NSMutableData *avcCData = [[[NSMutableData alloc] init] autorelease];

            uint8_t configurationVersion = 1;
            uint8_t AVCProfileIndication;
            uint8_t profile_compat;
            uint8_t AVCLevelIndication;
            uint32_t sampleLenFieldSizeMinusOne;
            uint64_t temp;

            if (MP4GetTrackH264ProfileLevel(_fileHandle, srcTrackId,
                                            &AVCProfileIndication,
                                            &AVCLevelIndication) == false) {
                return nil;
            }
            if (MP4GetTrackH264LengthSize(_fileHandle, srcTrackId,
                                          &sampleLenFieldSizeMinusOne) == false) {
                return nil;
            }
            sampleLenFieldSizeMinusOne--;
            if (MP4GetTrackIntegerProperty(_fileHandle, srcTrackId,
                                           "mdia.minf.stbl.stsd.*[0].avcC.profile_compatibility",
                                           &temp) == false) return nil;
            profile_compat = temp & 0xff;

            [avcCData appendBytes:&configurationVersion length:sizeof(uint8_t)];
            [avcCData appendBytes:&AVCProfileIndication length:sizeof(uint8_t)];
            [avcCData appendBytes:&profile_compat length:sizeof(uint8_t)];
            [avcCData appendBytes:&AVCLevelIndication length:sizeof(uint8_t)];
            [avcCData appendBytes:&sampleLenFieldSizeMinusOne length:sizeof(uint8_t)];

            uint8_t **seqheader, **pictheader;
            uint32_t *pictheadersize, *seqheadersize;
            uint32_t ix, iy;
            MP4GetTrackH264SeqPictHeaders(_fileHandle, srcTrackId,
                                          &seqheader, &seqheadersize,
                                          &pictheader, &pictheadersize);
            NSMutableData *seqData = [[NSMutableData alloc] init];
            for (ix = 0 , iy = 0; seqheadersize[ix] != 0; ix++) {
                uint16_t temp = seqheadersize[ix] << 8;
                [seqData appendBytes:&temp length:sizeof(uint16_t)];
                [seqData appendBytes:seqheader[ix] length:seqheadersize[ix]];
                iy++;
                free(seqheader[ix]);
            }
            [avcCData appendBytes:&iy length:sizeof(uint8_t)];
            [avcCData appendData:seqData];

            free(seqheader);
            free(seqheadersize);

            NSMutableData *pictData = [[NSMutableData alloc] init];
            for (ix = 0, iy = 0; pictheadersize[ix] != 0; ix++) {
                uint16_t temp = pictheadersize[ix] << 8;
                [pictData appendBytes:&temp length:sizeof(uint16_t)];
                [pictData appendBytes:pictheader[ix] length:pictheadersize[ix]];
                iy++;
                free(pictheader[ix]);
            }

            [avcCData appendBytes:&iy length:sizeof(uint8_t)];
            [avcCData appendData:pictData];

            free(pictheader);
            free(pictheadersize);
            
            magicCookie = [avcCData copy];
            [seqData release];
            [pictData release];

            return [magicCookie autorelease];
        }
    }

    return nil;
}

- (void)demux:(id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    NSInteger tracksNumber = [_inputTracks count];
    NSInteger tracksDone = 0;
    MP4DemuxkHelper *demuxHelper;

    if (!_fileHandle)
        return;

    for (MP42Track *track in _inputTracks) {
        track.muxer_helper->demuxer_context = [[MP4DemuxkHelper alloc] init];
        demuxHelper = track.muxer_helper->demuxer_context;
        demuxHelper->totalSampleNumber = MP4GetTrackNumberOfSamples(_fileHandle, track.sourceId);
        demuxHelper->timeScale = MP4GetTrackTimeScale(_fileHandle, track.sourceId);
        demuxHelper->done = 0;
    }

    MP4Timestamp currentTime = 1;
    MP4Duration duration = MP4GetDuration(_fileHandle);
    MP4Duration timescale = MP4GetTimeScale(_fileHandle);

    while (tracksDone != tracksNumber) {
        for (MP42Track *track in _inputTracks) {
            muxer_helper *helper = track.muxer_helper;
            demuxHelper = helper->demuxer_context;

            while (!_cancelled && demuxHelper->currentTime < demuxHelper->timeScale * currentTime && !demuxHelper->done) {
                MP4TrackId srcTrackId = [track sourceId];
                uint8_t *pBytes = NULL;
                uint32_t numBytes = 0;
                MP4Duration duration;
                MP4Duration renderingOffset;
                MP4Timestamp pStartTime;
                bool isSyncSample;

                demuxHelper->currentSampleId = demuxHelper->currentSampleId + 1;

                if (!MP4ReadSample(_fileHandle,
                                   srcTrackId,
                                   demuxHelper->currentSampleId,
                                   &pBytes, &numBytes,
                                   &pStartTime, &duration, &renderingOffset,
                                   &isSyncSample)) {
                    demuxHelper->done++;
                    tracksDone++;
                    break;
                }

                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->data = pBytes;
                sample->size = numBytes;
                sample->duration = duration;
                sample->offset = renderingOffset;
                sample->timestamp = pStartTime;
                sample->isSync = isSyncSample;
                sample->trackId = track.sourceId;

                [self enqueue:sample];
                [sample release];

                demuxHelper->currentTime = pStartTime;
            }
        }

        _progress = ((CGFloat)currentTime * timescale / duration) * 100;
        currentTime += 3;
    }

    [self setDone: YES];
    [pool release];
}

- (void)startReading
{
    if (!_fileHandle)
        _fileHandle = MP4Read([[_fileURL path] UTF8String]);

    [super startReading];

    if (!_demuxerThread && !_done) {
        _demuxerThread = [[NSThread alloc] initWithTarget:self selector:@selector(demux:) object:self];
        [_demuxerThread setName:@"MP4 Demuxer"];
        [_demuxerThread start];
    }
}

- (BOOL)cleanUp:(MP4FileHandle)dstFileHandle
{
    for (MP42Track *track in _outputsTracks) {
        MP4TrackId srcTrackId = track.sourceId;
        MP4TrackId dstTrackId = track.Id;

        MP4Duration trackDuration = 0;
        uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(_fileHandle, srcTrackId);
        while (i <= trackEditCount) {
            MP4Timestamp editMediaStart = MP4GetTrackEditMediaStart(_fileHandle, srcTrackId, i);
            MP4Duration editDuration = MP4ConvertFromMovieDuration(_fileHandle,
                                                                   MP4GetTrackEditDuration(_fileHandle, srcTrackId, i),
                                                                   MP4GetTimeScale(dstFileHandle));
            trackDuration += editDuration;
            int8_t editDwell = MP4GetTrackEditDwell(_fileHandle, srcTrackId, i);
            
            MP4AddTrackEdit(dstFileHandle, dstTrackId, i, editMediaStart, editDuration, editDwell);
            i++;
        }
        if (trackEditCount)
            MP4SetTrackIntegerProperty(dstFileHandle, dstTrackId, "tkhd.duration", trackDuration);
        else if (MP4GetSampleRenderingOffset(dstFileHandle, dstTrackId, 1)) {
            uint32_t firstFrameOffset = MP4GetSampleRenderingOffset(dstFileHandle, dstTrackId, 1);
            MP4Duration editDuration = MP4ConvertFromTrackDuration(_fileHandle,
                                                                   srcTrackId,
                                                                   MP4GetTrackDuration(_fileHandle, srcTrackId),
                                                                   MP4GetTimeScale(dstFileHandle));
            MP4AddTrackEdit(dstFileHandle, dstTrackId, MP4_INVALID_EDIT_ID, firstFrameOffset,
                            editDuration, 0);
        }
    }

    return YES;
}

- (void)dealloc
{
    if (_fileHandle)
        MP4Close(_fileHandle, 0);

    [super dealloc];
}

@end
