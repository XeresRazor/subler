//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42MkvImporter.h"

#import "MP42File.h"
#import "MP42SubUtilities.h"
#import "SBLanguages.h"

#import "MatroskaParser.h"
#import "MatroskaFile.h"
#include "avutil.h"

u_int32_t MP4AV_Ac3GetSamplingRate(u_int8_t* pHdr);

@interface MatroskaSample : NSObject {
@public
    unsigned long long startTime;
    unsigned long long endTime;
    unsigned long long filePos;
    unsigned int frameSize;
    unsigned int frameFlags;
}
@end

@implementation MatroskaSample
@end

@interface MatroskaDemuxHelper : NSObject {
    @public
    NSMutableArray *queue;
    NSMutableArray *offsetsArray;

    NSMutableArray *samplesBuffer;
    uint64_t        current_time;
    int64_t         minDisplayOffset;
    unsigned int buffer, samplesWritten, bufferFlush;

    MP42SampleBuffer *previousSample;
    SBSubSerializer *ss;
}
@end

@implementation MatroskaDemuxHelper

- (id)init
{
    if ((self = [super init])) {
        queue = [[NSMutableArray alloc] init];
        offsetsArray = [[NSMutableArray alloc] init];
        
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:100];
    }
    return self;
}

- (void) dealloc {
    [queue release], queue = nil;
    [offsetsArray release], offsetsArray = nil;
    [samplesBuffer release], samplesBuffer = nil;
    [ss release], ss = nil;

    [super dealloc];
}
@end

int readMkvPacket(struct StdIoStream  *ioStream, TrackInfo *trackInfo, uint64_t FilePos, uint8_t** frame, uint32_t *FrameSize)
{
    uint8_t *packet = NULL;
    uint32_t iSize = *FrameSize;

    if (fseeko(ioStream->fp, FilePos, SEEK_SET)) {
        fprintf(stderr,"fseeko(): %s\n", strerror(errno));
        return 0;
    }

    if (trackInfo->CompMethodPrivateSize != 0) {
        packet = malloc(iSize + trackInfo->CompMethodPrivateSize);
        memcpy(packet, trackInfo->CompMethodPrivate, trackInfo->CompMethodPrivateSize);
    }
    else
        packet = malloc(iSize);

    if (packet == NULL) {
        fprintf(stderr,"Out of memory\n");
        return 0;
    }

    size_t rd = fread(packet + trackInfo->CompMethodPrivateSize, 1, iSize, ioStream->fp);
    if (rd != iSize) {
        if (rd == 0) {
            if (feof(ioStream->fp))
                fprintf(stderr,"Unexpected EOF while reading frame\n");
            else
                fprintf(stderr,"Error reading frame: %s\n",strerror(errno));
        } else
            fprintf(stderr,"Short read while reading audio frame\n");

        free(packet);
        return 0;
    }

    iSize += trackInfo->CompMethodPrivateSize;

    if (trackInfo->CompEnabled) {
        switch (trackInfo->CompMethod) {
            case COMP_ZLIB:
                if (!DecompressZlib(&packet, &iSize)) {
                    free(packet);
                    return 0;
                }
                break;

            case COMP_BZIP:
                if (!DecompressBzlib(&packet, &iSize)) {
                    free(packet);
                    return 0;
                }
                break;

            // Not Implemented yet
            case COMP_LZO1X:
                break;

            default:
                break;
        }
    }

    *frame = packet;
    *FrameSize = iSize;

    return 1;
}

@interface MP42MkvImporter ()
    - (MP42Metadata *)readMatroskaMetadata;
    - (NSString *)matroskaCodecIDToHumanReadableName:(TrackInfo *)track;
    - (NSString *)matroskaTrackName:(TrackInfo *)track;
    - (uint64_t)matroskaTrackStartTime:(TrackInfo *)track Id:(MP4TrackId)Id;
@end

@implementation MP42MkvImporter

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError
{
    if ((self = [super init])) {
        _fileURL = [fileURL retain];

        _ioStream = calloc(1, sizeof(StdIoStream));
        _matroskaFile= openMatroskaFile((char *)[[_fileURL path] UTF8String], _ioStream);

        if(!_matroskaFile) {
            if (outError)
                *outError = MP42Error(@"The movie could not be opened.", @"The file is not a matroska file.", 100);

            [self release];
            return nil;
        }

        //SegmentInfo *info = mkv_GetFileInfo(matroskaFile);
        uint64_t *trackSizes = [self copyGuessedTrackDataLength];

        NSInteger trackCount = mkv_GetNumTracks(_matroskaFile);
        _tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger i;

        for (i = 0; i < trackCount; i++) {
            TrackInfo *mkvTrack = mkv_GetTrackInfo(_matroskaFile, i);
            MP42Track *newTrack = nil;

            // Video
            if (mkvTrack->Type == TT_VIDEO)  {
                float trackWidth = 0;
                newTrack = [[MP42VideoTrack alloc] init];

                [(MP42VideoTrack*)newTrack setWidth:mkvTrack->AV.Video.PixelWidth];
                [(MP42VideoTrack*)newTrack setHeight:mkvTrack->AV.Video.PixelHeight];

                AVRational dar, invPixelSize, sar;
                dar			   = (AVRational){mkvTrack->AV.Video.DisplayWidth, mkvTrack->AV.Video.DisplayHeight};
                invPixelSize   = (AVRational){mkvTrack->AV.Video.PixelHeight, mkvTrack->AV.Video.PixelWidth};
                sar = av_mul_q(dar, invPixelSize);    

                av_reduce(&sar.num, &sar.den, sar.num, sar.den, fixed1);
                
                if (sar.num && sar.den)
                    trackWidth = mkvTrack->AV.Video.PixelWidth * sar.num / sar.den;
                else
                    trackWidth = mkvTrack->AV.Video.PixelWidth;

                [(MP42VideoTrack*)newTrack setTrackWidth:trackWidth];
                [(MP42VideoTrack*)newTrack setTrackHeight:mkvTrack->AV.Video.PixelHeight];

                [(MP42VideoTrack*)newTrack setHSpacing:sar.num];
                [(MP42VideoTrack*)newTrack setVSpacing:sar.den];
            }

            // Audio
            else if (mkvTrack->Type == TT_AUDIO) {
                newTrack = [[MP42AudioTrack alloc] init];
                [(MP42AudioTrack*)newTrack setChannels:mkvTrack->AV.Audio.Channels];
                [newTrack setAlternate_group:1];

                for (MP42Track* audioTrack in _tracksArray) {
                    if ([audioTrack isMemberOfClass:[MP42AudioTrack class]])
                        [newTrack setEnabled:NO];
                }
            }

            // Text
            else if (mkvTrack->Type == TT_SUB) {
                newTrack = [[MP42SubtitleTrack alloc] init];
                [newTrack setAlternate_group:2];

                for (MP42Track* subtitleTrack in _tracksArray) {
                    if ([subtitleTrack isMemberOfClass:[MP42SubtitleTrack class]])
                        [newTrack setEnabled:NO];
                }
            }

            if (newTrack) {
                newTrack.format = [self matroskaCodecIDToHumanReadableName:mkvTrack];
                newTrack.Id = i;
                newTrack.sourceURL = _fileURL;
                newTrack.dataLength = trackSizes[i];
                if (mkvTrack->Type == TT_AUDIO)
                    newTrack.startOffset = [self matroskaTrackStartTime:mkvTrack Id:i];

                if ([newTrack.format isEqualToString:MP42VideoFormatH264]) {
                    uint8_t* avcCAtom = (uint8_t *)malloc(mkvTrack->CodecPrivateSize); // mkv stores h.264 avcC in CodecPrivate
                    memcpy(avcCAtom, mkvTrack->CodecPrivate, mkvTrack->CodecPrivateSize);
                    if (mkvTrack->CodecPrivateSize >= 3) {
                        [(MP42VideoTrack*)newTrack setOrigProfile:avcCAtom[1]];
                        [(MP42VideoTrack*)newTrack setNewProfile:avcCAtom[1]];
                        [(MP42VideoTrack*)newTrack setOrigLevel:avcCAtom[3]];
                        [(MP42VideoTrack*)newTrack setNewLevel:avcCAtom[3]];
                    }
                    free(avcCAtom);
                }

                double trackTimecodeScale = mkv_TruncFloat(mkvTrack->TimecodeScale);
                SegmentInfo *segInfo = mkv_GetFileInfo(_matroskaFile);
                UInt64 scaledDuration = (UInt64)segInfo->Duration / 1000000 * trackTimecodeScale;

                newTrack.duration = scaledDuration;

                if (scaledDuration > _fileDuration)
                    _fileDuration = scaledDuration;

                if ([self matroskaTrackName:mkvTrack])
                    newTrack.name = [self matroskaTrackName:mkvTrack];
                iso639_lang_t *isoLanguage = lang_for_code2(mkvTrack->Language);
                newTrack.language = [NSString stringWithUTF8String:isoLanguage->eng_name];

                [_tracksArray addObject:newTrack];
                [newTrack release];
            }
        }

        Chapter* chapters;
        unsigned count;
        mkv_GetChapters(_matroskaFile, &chapters, &count);

        if (count) {
            MP42ChapterTrack *newTrack = [[MP42ChapterTrack alloc] init];
            
            SegmentInfo *segInfo = mkv_GetFileInfo(_matroskaFile);
            UInt64 scaledDuration = (UInt64)segInfo->Duration / 1000000;
            [newTrack setDuration:scaledDuration];

            if (count) {
                unsigned int xi = 0;
                for (xi = 0; xi < chapters->nChildren; xi++) {
                    uint64_t timestamp = (chapters->Children[xi].Start) / 1000000;
                    if (!xi)
                        timestamp = 0;
                    if (xi && timestamp == 0)
                        continue;
                    if (chapters->Children[xi].Display && strlen(chapters->Children[xi].Display->String))
                        [newTrack addChapter:[NSString stringWithUTF8String:chapters->Children[xi].Display->String]
                                    duration:timestamp];
                    else
                        [newTrack addChapter:[NSString stringWithFormat:@"Chapter %d", xi+1]
                                    duration:timestamp];
                }
            }
            [_tracksArray addObject:newTrack];
            [newTrack release];
        }

        if (trackSizes)
            free(trackSizes);

        _metadata = [[self readMatroskaMetadata] retain];
    }

    return self;
}

- (MP42Metadata *)readMatroskaMetadata
{
    MP42Metadata *mkvMetadata = [[MP42Metadata alloc] init];

    SegmentInfo *segInfo = mkv_GetFileInfo(_matroskaFile);
    if (segInfo->Title)
        [mkvMetadata setTag:[NSString stringWithUTF8String:segInfo->Title] forKey:@"Name"];
    
    Tag* tags;
    unsigned count;

    mkv_GetTags(_matroskaFile, &tags, &count);
    if (count) {
        unsigned int xi = 0;
        for (xi = 0; xi < tags->nSimpleTags; xi++) {

            if (!strcmp(tags->SimpleTags[xi].Name, "TITLE"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Name"];
            
            if (!strcmp(tags->SimpleTags[xi].Name, "DATE_RELEASED"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Release Date"];

            if (!strcmp(tags->SimpleTags[xi].Name, "COMMENT"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Comments"];

            if (!strcmp(tags->SimpleTags[xi].Name, "DIRECTOR"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Director"];

            if (!strcmp(tags->SimpleTags[xi].Name, "COPYRIGHT"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Copyright"];

            if (!strcmp(tags->SimpleTags[xi].Name, "ARTIST"))
                [mkvMetadata setTag:[NSString stringWithUTF8String:tags->SimpleTags[xi].Value] forKey:@"Artist"];
        }
    }

    if ([mkvMetadata.tagsDict count])
        return [mkvMetadata autorelease];
    else {
        [mkvMetadata release];
        return nil;
    }
}

- (uint64_t *)copyGuessedTrackDataLength
{
    uint64_t    *trackSizes = NULL;
    uint64_t    *trackTimestamp;
    uint64_t    StartTime, EndTime, FilePos;
    uint32_t    Track, FrameSize, FrameFlags;
    int i = 0;

    SegmentInfo *segInfo = mkv_GetFileInfo(_matroskaFile);
    NSInteger trackCount = mkv_GetNumTracks(_matroskaFile);

    if (trackCount) {
        trackSizes = (uint64_t *) malloc(sizeof(uint64_t) * trackCount);
        trackTimestamp = (uint64_t *) malloc(sizeof(uint64_t) * trackCount);

        for (i= 0; i < trackCount; i++) {
            trackSizes[i] = 0;
            trackTimestamp[i] = 0;
        }

        StartTime = 0;
        i = 0;
        while (StartTime < (segInfo->Duration / 64)) {
            if (!mkv_ReadFrame(_matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags)) {
                trackSizes[Track] += FrameSize;
                trackTimestamp[Track] = StartTime;
                i++;
            }
            else
                break;
        }

        for (i= 0; i < trackCount; i++)
            if (trackTimestamp[i] > 0)
                trackSizes[i] = trackSizes[i] * (segInfo->Duration / trackTimestamp[i]);

        free(trackTimestamp);
        mkv_Seek(_matroskaFile, 0, 0);
    }

    return trackSizes;
}

- (NSString *)matroskaCodecIDToHumanReadableName:(TrackInfo *)track
{
    if (track->CodecID) {
        if (!strcmp(track->CodecID, "V_MPEG4/ISO/AVC"))
            return MP42VideoFormatH264;
        else if (!strcmp(track->CodecID, "A_AAC") ||
                 !strcmp(track->CodecID, "A_AAC/MPEG4/LC") ||
                 !strcmp(track->CodecID, "A_AAC/MPEG2/LC"))
            return MP42AudioFormatAAC;
        else if (!strcmp(track->CodecID, "A_AC3"))
            return MP42AudioFormatAC3;
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/SP"))
            return MP42VideoFormatMPEG4Visual;
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/ASP"))
            return MP42VideoFormatMPEG4Visual;
        else if (!strcmp(track->CodecID, "V_MPEG2"))
            return MP42VideoFormatMPEG2;
        else if (!strcmp(track->CodecID, "A_DTS"))
            return MP42AudioFormatDTS;
        else if (!strcmp(track->CodecID, "A_VORBIS"))
            return MP42AudioFormatVorbis;
        else if (!strcmp(track->CodecID, "A_FLAC"))
            return MP42AudioFormatFLAC;
        else if (!strcmp(track->CodecID, "A_MPEG/L3"))
            return MP42AudioFormatMP3;
        else if (!strcmp(track->CodecID, "A_TRUEHD"))
            return MP42AudioFormatTrueHD;
        else if (!strcmp(track->CodecID, "A_MLP"))
            return @"MLP";
        else if (!strcmp(track->CodecID, "S_TEXT/UTF8"))
            return MP42SubtitleFormatText;
        else if (!strcmp(track->CodecID, "S_TEXT/ASS")
                 || !strcmp(track->CodecID, "S_TEXT/SSA"))
            return MP42SubtitleFormatSSA;
        else if (!strcmp(track->CodecID, "S_VOBSUB"))
            return MP42SubtitleFormatVobSub;
        else if (!strcmp(track->CodecID, "S_HDMV/PGS"))
            return MP42SubtitleFormatPGS;

        else
            return [NSString stringWithUTF8String:track->CodecID];
    }
    else {
        return @"Unknown";
    }
}

- (NSString *)matroskaTrackName:(TrackInfo *)track
{    
    if(track->Name && strlen(track->Name))
        return [NSString stringWithUTF8String:track->Name];
    else
        return nil;
}

- (uint64_t)matroskaTrackStartTime:(TrackInfo *)track Id:(MP4TrackId)Id
{
    uint64_t        StartTime, EndTime, FilePos;
    uint32_t        Track, FrameSize, FrameFlags;

    /* mask other tracks because we don't need them */
    unsigned int TrackMask = ~0;
    TrackMask &= ~(1 << Id);

    mkv_SetTrackMask(_matroskaFile, TrackMask);
    mkv_ReadFrame(_matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags);
    mkv_Seek(_matroskaFile, 0, 0);

    return StartTime / 1000000;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    TrackInfo *trackInfo = mkv_GetTrackInfo(_matroskaFile, [track sourceId]);
    if (trackInfo->Type == TT_VIDEO)
        return 100000;
    else if (trackInfo->Type == TT_AUDIO) {
        NSUInteger sampleRate = mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
        if (!strcmp(trackInfo->CodecID, "A_AC3")) {
            if (sampleRate < 24000)
                return 48000;
        }

        return mkv_TruncFloat(trackInfo->AV.Audio.SamplingFreq);
    }

    return 1000;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42VideoTrack*)track width], [(MP42VideoTrack*) track height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    if (!_matroskaFile)
        return nil;

    TrackInfo *trackInfo = mkv_GetTrackInfo(_matroskaFile, [track sourceId]);

    if ((!strcmp(trackInfo->CodecID, "A_AAC/MPEG4/LC") ||
        !strcmp(trackInfo->CodecID, "A_AAC/MPEG2/LC")) && !trackInfo->CodecPrivateSize) {
        NSMutableData *magicCookie = [[NSMutableData alloc] init];
        uint8_t aac[2];
        aac[0] = 0x11;
        aac[1] = 0x90;

        [magicCookie appendBytes:aac length:2];
        return [magicCookie autorelease];
    }
    
    if (!strcmp(trackInfo->CodecID, "A_AC3")) {
        mkv_SetTrackMask(_matroskaFile, ~(1 << [track sourceId]));

        uint64_t        StartTime, EndTime, FilePos;
        uint32_t        rt, FrameSize, FrameFlags;
        uint8_t         *frame = NULL;

		// read first header to create track
		int firstFrame = mkv_ReadFrame(_matroskaFile, 0, &rt, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags);
		if (firstFrame != 0)
			return nil;
        
        if (readMkvPacket(_ioStream, trackInfo, FilePos, &frame, &FrameSize)) {
            // parse AC3 header
            // collect all the necessary meta information
            uint32_t fscod, frmsizecod, bsid, bsmod, acmod, lfeon;
            uint32_t lfe_offset = 4;

            fscod = (*(frame+4) >> 6) & 0x3;
            frmsizecod = (*(frame+4) & 0x3f) >> 1;
            bsid =  (*(frame+5) >> 3) & 0x1f;
            bsmod = (*(frame+5) & 0xf);
            acmod = (*(frame+6) >> 5) & 0x7;
            if (acmod == 2)
                lfe_offset -= 2;
            else {
                if ((acmod & 1) && acmod != 1)
                    lfe_offset -= 2;
                if (acmod & 4)
                    lfe_offset -= 2;
            }
            lfeon = (*(frame+6) >> lfe_offset) & 0x1;

            mkv_Seek(_matroskaFile, 0, 0);

            NSMutableData *ac3Info = [[NSMutableData alloc] init];
            [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
            [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
            [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
            [ac3Info appendBytes:&frmsizecod length:sizeof(uint64_t)];

            free(frame);

            return [ac3Info autorelease];
        }
        else
            return nil;
    }
    else if (!strcmp(trackInfo->CodecID, "S_VOBSUB")) {
        char *string = (char *) trackInfo->CodecPrivate;
        char *palette = strnstr(string, "palette:", trackInfo->CodecPrivateSize);

        UInt32 colorPalette[16];

        if (palette != NULL) {
            sscanf(palette, "palette: %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx", 
                   &colorPalette[ 0], &colorPalette[ 1], &colorPalette[ 2], &colorPalette[ 3],
                   &colorPalette[ 4], &colorPalette[ 5], &colorPalette[ 6], &colorPalette[ 7],
                   &colorPalette[ 8], &colorPalette[ 9], &colorPalette[10], &colorPalette[11],
                   &colorPalette[12], &colorPalette[13], &colorPalette[14], &colorPalette[15]);
        }
        return [NSData dataWithBytes:colorPalette length:sizeof(UInt32)*16];
    }

    NSData * magicCookie = [NSData dataWithBytes:trackInfo->CodecPrivate length:trackInfo->CodecPrivateSize];

    if (magicCookie)
        return magicCookie;
    else
        return nil;
}

// Methods to extract all the samples from the active tracks at the same time

- (void)demux:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    uint64_t        StartTime, EndTime, FilePos;
    uint32_t        Track, FrameSize, FrameFlags;
    uint8_t         *frame = NULL;

    MP42Track           *track = nil;
    MatroskaDemuxHelper *demuxHelper = nil;
    MatroskaSample      *frameSample = nil, * currentSample = nil;
    int64_t             offset, minOffset = 0, duration, next_duration;

    const unsigned int bufferSize = 20;

    /* mask other tracks because we don't need them */
    unsigned int TrackMask = ~0;

    for (MP42Track *track in _inputTracks) {
        TrackMask &= ~(1 << [track sourceId]);
        track.muxer_helper->demuxer_context = [[MatroskaDemuxHelper alloc] init];
    }

    mkv_SetTrackMask(_matroskaFile, TrackMask);

    while (!mkv_ReadFrame(_matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags) && !_cancelled) {
        _progress = (StartTime / _fileDuration / 10000);
        muxer_helper *helper = NULL;

        for (MP42Track *fTrack in _inputTracks){
            if (fTrack.sourceId == Track) {
                helper = fTrack.muxer_helper;
                demuxHelper = helper->demuxer_context;
                track = fTrack;
            }
        }

        TrackInfo *trackInfo = mkv_GetTrackInfo(_matroskaFile, Track);

        if (trackInfo->Type == TT_AUDIO) {
            demuxHelper->samplesWritten++;

            if (readMkvPacket(_ioStream, trackInfo, FilePos, &frame, &FrameSize)) {
                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->data = frame;
                sample->size = FrameSize;
                sample->duration = MP4_INVALID_DURATION;
                sample->offset = 0;
                sample->timestamp = StartTime;
                sample->isSync = YES;
                sample->trackId = track.sourceId;

                [self enqueue:sample];
                [sample release];
            }
        }

        if (trackInfo->Type == TT_SUB) {
            if (readMkvPacket(_ioStream, trackInfo, FilePos, &frame, &FrameSize)) {
                if (strcmp(trackInfo->CodecID, "S_VOBSUB") && strcmp(trackInfo->CodecID, "S_HDMV/PGS")) {
                    if (!demuxHelper->ss)
                        demuxHelper->ss = [[SBSubSerializer alloc] init];

                    NSString *string = [[[NSString alloc] initWithBytes:frame length:FrameSize encoding:NSUTF8StringEncoding] autorelease];
                    if (!strcmp(trackInfo->CodecID, "S_TEXT/ASS") || !strcmp(trackInfo->CodecID, "S_TEXT/SSA"))
                        string = StripSSALine(string);
                    
                    if ([string length]) {
                        SBSubLine *sl = [[SBSubLine alloc] initWithLine:string start:StartTime/1000000 end:EndTime/1000000];
                        [demuxHelper->ss addLine:[sl autorelease]];
                    }
                    demuxHelper->samplesWritten++;
                    free(frame);
                }
                else {
                    MP42SampleBuffer *nextSample = [[MP42SampleBuffer alloc] init];

                    nextSample->duration = 0;
                    nextSample->offset = 0;
                    nextSample->timestamp = StartTime;
                    nextSample->data = frame;
                    nextSample->size = FrameSize;
                    nextSample->isSync = YES;
                    nextSample->trackId = track.sourceId;

                    // PGS are usually stored with just the start time, and blank samples to fill the gaps
                    if (!strcmp(trackInfo->CodecID, "S_HDMV/PGS")) {
                        if (!demuxHelper->previousSample) {
                            demuxHelper->previousSample = [[MP42SampleBuffer alloc] init];
                            demuxHelper->previousSample->duration = StartTime / 1000000;
                            demuxHelper->previousSample->offset = 0;
                            demuxHelper->previousSample->timestamp = 0;
                            demuxHelper->previousSample->isSync = YES;
                            demuxHelper->previousSample->trackId = track.sourceId;
                        }
                        else {
                            if (nextSample->timestamp < demuxHelper->previousSample->timestamp) {
                                // Out of order samples? swap the next with the previous
                                MP42SampleBuffer *temp = nextSample;
                                nextSample = demuxHelper->previousSample;
                                demuxHelper->previousSample = temp;
                            }

                            demuxHelper->previousSample->duration = (nextSample->timestamp - demuxHelper->previousSample->timestamp) / 1000000;
                        }

                        [self enqueue:demuxHelper->previousSample];
                        [demuxHelper->previousSample release];

                        demuxHelper->previousSample = nextSample;
                        demuxHelper->samplesWritten++;
                    }
                    // VobSub seems to have an end duration, and no blank samples, so create a new one each time to fill the gaps
                    else if (!strcmp(trackInfo->CodecID, "S_VOBSUB")) {
                        if (StartTime > demuxHelper->current_time) {
                            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                            sample->duration = (StartTime - demuxHelper->current_time) / 1000000;
                            sample->size = 2;
                            sample->data = calloc(1, 2);
                            sample->isSync = YES;
                            sample->trackId = track.sourceId;
                            
                            [self enqueue:sample];
                            [sample release];
                        }
                        
                        nextSample->duration = (EndTime - StartTime ) / 1000000;
                        
                        [self enqueue:nextSample];
                        [nextSample release];
                        
                        demuxHelper->current_time = EndTime;
                    }
                }
            }
        }

        else if (trackInfo->Type == TT_VIDEO) {

            /* read frames from file */
            frameSample = [[MatroskaSample alloc] init];
            frameSample->startTime = StartTime;
            frameSample->endTime = EndTime;
            frameSample->filePos = FilePos;
            frameSample->frameSize = FrameSize;
            frameSample->frameFlags = FrameFlags;
            [demuxHelper->queue addObject:frameSample];
            [frameSample release];

            if ([demuxHelper->queue count] < bufferSize)
                continue;
            else {
                currentSample = [demuxHelper->queue objectAtIndex:demuxHelper->buffer];

                // matroska stores only the start and end time, so we need to recreate
                // the frame duration and the offset from the start time, the end time is useless
                // duration calculation
                duration = ((MatroskaSample*)[demuxHelper->queue lastObject])->startTime - currentSample->startTime;

                for (MatroskaSample *sample in demuxHelper->queue)
                    if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                        if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                            duration = next_duration;

                // offset calculation
                offset = currentSample->startTime - demuxHelper->current_time;
                // save the minimum offset, used later to keep all the offset values positive
                if (offset < minOffset)
                    minOffset = offset;

                [demuxHelper->offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

                demuxHelper->current_time += duration;

                if (readMkvPacket(_ioStream, trackInfo, currentSample->filePos, &frame, &currentSample->frameSize)) {
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->data = frame;
                    sample->size = currentSample->frameSize;
                    sample->duration = duration / 10000.0f;
                    sample->offset = offset / 10000.0f;
                    sample->timestamp = StartTime;
                    sample->isSync = currentSample->frameFlags & FRAME_KF;
                    sample->trackId = track.sourceId;

                    demuxHelper->samplesWritten++;

                    if (sample->offset < demuxHelper->minDisplayOffset)
                        demuxHelper->minDisplayOffset = sample->offset;

                    if (demuxHelper->buffer >= bufferSize)
                        [demuxHelper->queue removeObjectAtIndex:0];
                    if (demuxHelper->buffer < bufferSize)
                        demuxHelper->buffer++;

                    [self enqueue:sample];
                    [sample release];
                }
                else
                    continue;
            }
        }
    }

    for (MP42Track *track in _inputTracks) {
        muxer_helper *helper = track.muxer_helper;
        demuxHelper = helper->demuxer_context;

        if (demuxHelper->queue) {
            TrackInfo *trackInfo = mkv_GetTrackInfo(_matroskaFile, [track sourceId]);

            while ([demuxHelper->queue count]) {
                if (demuxHelper->bufferFlush == 1) {
                    // add a last sample to get the duration for the last frame
                    MatroskaSample *lastSample = [demuxHelper->queue lastObject];
                    for (MatroskaSample *sample in demuxHelper->queue) {
                        if (sample->startTime > lastSample->startTime)
                            lastSample = sample;
                    }
                    frameSample = [[MatroskaSample alloc] init];
                    frameSample->startTime = lastSample->endTime;
                    [demuxHelper->queue addObject:frameSample];
                    [frameSample release];
                }
                currentSample = [demuxHelper->queue objectAtIndex:demuxHelper->buffer];

                // matroska stores only the start and end time, so we need to recreate
                // the frame duration and the offset from the start time, the end time is useless
                // duration calculation
                duration = ((MatroskaSample*)[demuxHelper->queue lastObject])->startTime - currentSample->startTime;

                for (MatroskaSample *sample in demuxHelper->queue)
                    if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                        if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                            duration = next_duration;

                // offset calculation
                offset = currentSample->startTime - demuxHelper->current_time;
                // save the minimum offset, used later to keep the all the offset values positive
                if (offset < minOffset)
                    minOffset = offset;

                [demuxHelper->offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

                demuxHelper->current_time += duration;

                if (readMkvPacket(_ioStream, trackInfo, currentSample->filePos, &frame, &currentSample->frameSize)) {
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->data = frame;
                    sample->size = currentSample->frameSize;
                    sample->duration = duration / 10000.0f;
                    sample->offset = offset / 10000.0f;
                    sample->timestamp = StartTime;
                    sample->isSync = currentSample->frameFlags & FRAME_KF;
                    sample->trackId = track.sourceId;

                    demuxHelper->samplesWritten++;

                    if (sample->offset < demuxHelper->minDisplayOffset)
                        demuxHelper->minDisplayOffset = sample->offset;

                    if (demuxHelper->buffer >= bufferSize)
                        [demuxHelper->queue removeObjectAtIndex:0];

                    [self enqueue:sample];
                    [sample release];

                    demuxHelper->bufferFlush++;
                    if (demuxHelper->bufferFlush >= bufferSize - 1) {
                        break;
                    }
                }
                else
                    continue;
            }
        }

        if (demuxHelper->ss) {
            MP42SampleBuffer *sample = nil;
            MP4TrackId dstTrackId = track.sourceId;
            SBSubSerializer *ss = demuxHelper->ss;

            [ss setFinished:YES];

            while (![ss isEmpty] && !_cancelled) {
                SBSubLine *sl = [ss getSerializedPacket];

                if ([sl->line isEqualToString:@"\n"])
                    sample = copyEmptySubtitleSample(dstTrackId, sl->end_time - sl->begin_time, NO);
                else
                    sample = copySubtitleSample(dstTrackId, sl->line, sl->end_time - sl->begin_time, NO, NO, CGSizeMake(0, 0), 0);

                if (!sample)
                    break;

                demuxHelper->current_time += sample->duration;
                sample->timestamp = demuxHelper->current_time;

                [self enqueue:sample];
                [sample release];

                demuxHelper->samplesWritten++;
            }
        }
    }

    [self setDone:YES];
    [pool release];
}

- (void)startReading
{
    [super startReading];

    if (!_matroskaFile)
        return;

    if (!_demuxerThread && !_done) {
        _demuxerThread = [[NSThread alloc] initWithTarget:self selector:@selector(demux:) object:self];
        [_demuxerThread setName:@"Matroska Demuxer"];
        [_demuxerThread start];
    }
}

- (BOOL)cleanUp:(MP4FileHandle)fileHandle
{
    for (MP42Track *track in _outputsTracks) {
        MP42Track *inputTrack = [self inputTrackWithTrackID:track.sourceId];

        MatroskaDemuxHelper *demuxHelper = inputTrack.muxer_helper->demuxer_context;
        MP4TrackId trackId = track.Id;

        if (demuxHelper->minDisplayOffset != 0) {
            int i;
            for (i = 0; i < demuxHelper->samplesWritten; i++)
            MP4SetSampleRenderingOffset(fileHandle,
                                        trackId,
                                        1 + i,
                                        MP4GetSampleRenderingOffset(fileHandle, trackId, 1+i) - demuxHelper->minDisplayOffset);

            MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                   trackId,
                                                                   MP4GetTrackDuration(fileHandle, trackId),
                                                                   MP4GetTimeScale(fileHandle));
            MP4AddTrackEdit(fileHandle, trackId, MP4_INVALID_EDIT_ID, - demuxHelper->minDisplayOffset,
                            editDuration, 0);
        }
    }

    return YES;
}

- (void) dealloc
{
	/* close matroska parser */ 
    closeMatroskaFile(_matroskaFile, _ioStream);

    [super dealloc];
}

@end
