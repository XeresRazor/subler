//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42MkvImporter.h"
#import "MatroskaParser.h"
#import "MatroskaFile.h"
#import "SubUtilities.h"
#import "SBLanguages.h"
#import "MP42File.h"

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
@property(readwrite) unsigned long long startTime;
@property(readwrite) unsigned long long endTime;
@property(readwrite) unsigned long long filePos;
@property(readwrite) unsigned int frameSize;
@property(readwrite) unsigned int frameFlags;

@end

@interface MatroskaTrackHelper : NSObject {
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

@implementation MatroskaTrackHelper

-(id)init
{
    if ((self = [super init]))
    {
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

@implementation MatroskaSample
@synthesize startTime;
@synthesize endTime;
@synthesize filePos;
@synthesize frameSize;
@synthesize frameFlags;

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

@interface MP42MkvImporter (Private)
    - (MP42Metadata*) readMatroskaMetadata;
    - (NSString*) matroskaCodecIDToHumanReadableName:(TrackInfo *)track;
    - (NSString*) matroskaTrackName:(TrackInfo *)track;
    - (uint64_t) matroskaTrackStartTime:(TrackInfo *)track Id:(MP4TrackId)Id;
@end

@implementation MP42MkvImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    if ((self = [super init])) {
        delegate = del;
        fileURL = [URL retain];

        ioStream = calloc(1, sizeof(StdIoStream)); 
        matroskaFile = openMatroskaFile((char *)[[fileURL path] UTF8String], ioStream);

        if(!matroskaFile) {
            if (outError)
                *outError = MP42Error(@"The movie could not be opened.", @"The file is not a matroska file.", 100);

            [self release];
            return nil;
        }

        //SegmentInfo *info = mkv_GetFileInfo(matroskaFile);
        uint64_t *trackSizes = [self copyGuessedTrackDataLength];

        NSInteger trackCount = mkv_GetNumTracks(matroskaFile);
        tracksArray = [[NSMutableArray alloc] initWithCapacity:trackCount];

        NSInteger i;

        for (i = 0; i < trackCount; i++) {
            TrackInfo *mkvTrack = mkv_GetTrackInfo(matroskaFile, i);
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

                for (MP42Track* audioTrack in tracksArray) {
                    if ([audioTrack isMemberOfClass:[MP42AudioTrack class]])
                        [newTrack setEnabled:NO];
                }
            }

            // Text
            else if (mkvTrack->Type == TT_SUB) {
                newTrack = [[MP42SubtitleTrack alloc] init];
                [newTrack setAlternate_group:2];

                for (MP42Track* subtitleTrack in tracksArray) {
                    if ([subtitleTrack isMemberOfClass:[MP42SubtitleTrack class]])
                        [newTrack setEnabled:NO];
                }
            }

            if (newTrack) {
                newTrack.format = [self matroskaCodecIDToHumanReadableName:mkvTrack];
                newTrack.sourceFormat = [self matroskaCodecIDToHumanReadableName:mkvTrack];
                newTrack.Id = i;
                newTrack.sourceURL = fileURL;
                newTrack.dataLength = trackSizes[i];
                if (mkvTrack->Type == TT_AUDIO)
                    newTrack.startOffset = [self matroskaTrackStartTime:mkvTrack Id:i];

                if ([newTrack.format isEqualToString:@"H.264"]) {
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
                SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
                UInt64 scaledDuration = (UInt64)segInfo->Duration / 1000000 * trackTimecodeScale;

                newTrack.duration = scaledDuration;

                if (scaledDuration > fileDuration)
                    fileDuration = scaledDuration;

                if ([self matroskaTrackName:mkvTrack])
                    newTrack.name = [self matroskaTrackName:mkvTrack];
                iso639_lang_t *isoLanguage = lang_for_code2(mkvTrack->Language);
                newTrack.language = [NSString stringWithUTF8String:isoLanguage->eng_name];

                [tracksArray addObject:newTrack];
                [newTrack release];
            }
        }

        Chapter* chapters;
        unsigned count;
        mkv_GetChapters(matroskaFile, &chapters, &count);

        if (count) {
            MP42ChapterTrack *newTrack = [[MP42ChapterTrack alloc] init];
            
            SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
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
            [tracksArray addObject:newTrack];
            [newTrack release];
        }

        if (trackSizes)
            free(trackSizes);

        metadata = [[self readMatroskaMetadata] retain];
    }

    return self;
}

- (MP42Metadata*) readMatroskaMetadata
{
    MP42Metadata *mkvMetadata = [[MP42Metadata alloc] init];

    SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
    if (segInfo->Title)
        [mkvMetadata setTag:[NSString stringWithUTF8String:segInfo->Title] forKey:@"Name"];
    
    Tag* tags;
    unsigned count;

    mkv_GetTags(matroskaFile, &tags, &count);
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

- (uint64_t*)copyGuessedTrackDataLength
{
    uint64_t    *trackSizes = NULL;
    uint64_t    *trackTimestamp;
    uint64_t    StartTime, EndTime, FilePos;
    uint32_t    Track, FrameSize, FrameFlags;
    int i = 0;

    SegmentInfo *segInfo = mkv_GetFileInfo(matroskaFile);
    NSInteger trackCount = mkv_GetNumTracks(matroskaFile);

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
            if (!mkv_ReadFrame(matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags)) {
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
        mkv_Seek(matroskaFile, 0, 0);
    }

    return trackSizes;
}

- (NSString*) matroskaCodecIDToHumanReadableName:(TrackInfo *)track
{
    if (track->CodecID) {
        if (!strcmp(track->CodecID, "V_MPEG4/ISO/AVC"))
            return @"H.264";
        else if (!strcmp(track->CodecID, "A_AAC") ||
                 !strcmp(track->CodecID, "A_AAC/MPEG4/LC") ||
                 !strcmp(track->CodecID, "A_AAC/MPEG2/LC"))
            return @"AAC";
        else if (!strcmp(track->CodecID, "A_AC3"))
            return @"AC-3";
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/SP"))
            return @"MPEG-4 Visual";
        else if (!strcmp(track->CodecID, "V_MPEG4/ISO/ASP"))
            return @"MPEG-4 Visual";
        else if (!strcmp(track->CodecID, "V_MPEG2"))
            return @"MPEG-2";
        else if (!strcmp(track->CodecID, "A_DTS"))
            return @"DTS";
        else if (!strcmp(track->CodecID, "A_VORBIS"))
            return @"Vorbis";
        else if (!strcmp(track->CodecID, "A_FLAC"))
            return @"Flac";
        else if (!strcmp(track->CodecID, "A_MPEG/L3"))
            return @"Mp3";
        else if (!strcmp(track->CodecID, "A_TRUEHD"))
            return @"True HD";
        else if (!strcmp(track->CodecID, "A_MLP"))
            return @"MLP";
        else if (!strcmp(track->CodecID, "S_TEXT/UTF8"))
            return @"Plain Text";
        else if (!strcmp(track->CodecID, "S_TEXT/ASS"))
            return @"ASS";
        else if (!strcmp(track->CodecID, "S_TEXT/SSA"))
            return @"SSA";
        else if (!strcmp(track->CodecID, "S_VOBSUB"))
            return @"VobSub";
        else if (!strcmp(track->CodecID, "S_HDMV/PGS"))
            return @"PGS";

        else
            return [NSString stringWithUTF8String:track->CodecID];
    }
    else {
        return @"Unknown";
    }
}

- (NSString*) matroskaTrackName:(TrackInfo *)track
{    
    if(track->Name && strlen(track->Name))
        return [NSString stringWithUTF8String:track->Name];
    else
        return nil;
}

- (uint64_t) matroskaTrackStartTime:(TrackInfo *)track Id:(MP4TrackId)Id
{
    uint64_t        StartTime, EndTime, FilePos;
    uint32_t        Track, FrameSize, FrameFlags;

    /* mask other tracks because we don't need them */
    unsigned int TrackMask = ~0;
    TrackMask &= ~(1 << Id);

    mkv_SetTrackMask(matroskaFile, TrackMask);
    mkv_ReadFrame(matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags);
    mkv_Seek(matroskaFile, 0, 0);

    return StartTime / 1000000;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);
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
    if (!matroskaFile)
        return nil;

    TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);

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
        mkv_SetTrackMask(matroskaFile, ~(1 << [track sourceId]));

        uint64_t        StartTime, EndTime, FilePos;
        uint32_t        rt, FrameSize, FrameFlags;
        uint8_t         *frame = NULL;

		// read first header to create track
		int firstFrame = mkv_ReadFrame(matroskaFile, 0, &rt, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags);
		if (firstFrame != 0)
			return nil;
        
        if (readMkvPacket(ioStream, trackInfo, FilePos, &frame, &FrameSize)) {
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

            mkv_Seek(matroskaFile, 0, 0);

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

    if (!matroskaFile)
        return;

    uint64_t        StartTime, EndTime, FilePos;
    uint32_t        Track, FrameSize, FrameFlags;
    uint8_t         * frame = NULL;

    MP42Track           * track = nil;
    MatroskaTrackHelper * trackDemuxerHelper = nil;
    MatroskaSample      * frameSample = nil, * currentSample = nil;
    int64_t             offset, minOffset = 0, duration, next_duration;

    const unsigned int bufferSize = 20;

    /* mask other tracks because we don't need them */
    unsigned int TrackMask = ~0;

    for (MP42Track* track in activeTracks){
        muxer_helper *helper = track.muxer_helper;

        TrackMask &= ~(1 << [track sourceId]);
        if (helper->trackDemuxer == nil) {
            trackDemuxerHelper = [[MatroskaTrackHelper alloc] init];
            helper->trackDemuxer = trackDemuxerHelper;
        }
    }

    mkv_SetTrackMask(matroskaFile, TrackMask);

    while (!mkv_ReadFrame(matroskaFile, 0, &Track, &StartTime, &EndTime, &FilePos, &FrameSize, &FrameFlags) && !isCancelled) {
        progress = (StartTime / fileDuration / 10000);
        muxer_helper *helper = NULL;

        for (MP42Track* fTrack in activeTracks){
            if (fTrack.sourceId == Track) {
                helper = fTrack.muxer_helper;
                trackDemuxerHelper = helper->trackDemuxer;
                track = fTrack;
            }
        }
        
        while ([helper->fifo count] >= 200) {
            usleep(200);
        }

        if (trackDemuxerHelper == nil) {
            NSLog(@"trackHelper is nil, aborting");
            return;
        }

        TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, Track);

        if (trackInfo->Type == TT_AUDIO) {
            trackDemuxerHelper->samplesWritten++;

            if (readMkvPacket(ioStream, trackInfo, FilePos, &frame, &FrameSize)) {
                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->sampleData = frame;
                sample->sampleSize = FrameSize;
                sample->sampleDuration = MP4_INVALID_DURATION;
                sample->sampleOffset = 0;
                sample->sampleTimestamp = StartTime;
                sample->sampleIsSync = YES;
                sample->sampleTrackId = track.Id;
                if(track.needConversion)
                    sample->sampleSourceTrack = track;

                @synchronized(helper->fifo) {
                    [helper->fifo addObject:sample];
                    [sample release];
                }
            }
        }

        if (trackInfo->Type == TT_SUB) {
            if (readMkvPacket(ioStream, trackInfo, FilePos, &frame, &FrameSize)) {
                if (strcmp(trackInfo->CodecID, "S_VOBSUB") && strcmp(trackInfo->CodecID, "S_HDMV/PGS")) {
                    if (!trackDemuxerHelper->ss)
                        trackDemuxerHelper->ss = [[SBSubSerializer alloc] init];
                    
                    NSString *string = [[[NSString alloc] initWithBytes:frame length:FrameSize encoding:NSUTF8StringEncoding] autorelease];
                    if (!strcmp(trackInfo->CodecID, "S_TEXT/ASS") || !strcmp(trackInfo->CodecID, "S_TEXT/SSA"))
                        string = StripSSALine(string);
                    
                    if ([string length]) {
                        SBSubLine *sl = [[SBSubLine alloc] initWithLine:string start:StartTime/1000000 end:EndTime/1000000];
                        [trackDemuxerHelper->ss addLine:[sl autorelease]];
                    }
                    trackDemuxerHelper->samplesWritten++;
                    free(frame);
                }
                else {
                    MP42SampleBuffer *nextSample = [[MP42SampleBuffer alloc] init];
                    
                    nextSample->sampleDuration = 0;
                    nextSample->sampleOffset = 0;
                    nextSample->sampleTimestamp = StartTime;
                    nextSample->sampleData = frame;
                    nextSample->sampleSize = FrameSize;
                    nextSample->sampleIsSync = YES;
                    nextSample->sampleTrackId = track.Id;
                    if(track.needConversion)
                        nextSample->sampleSourceTrack = track;
                    
                    // PGS are usually stored with just the start time, and blank samples to fill the gaps
                    if (!strcmp(trackInfo->CodecID, "S_HDMV/PGS")) {
                        if (!trackDemuxerHelper->previousSample) {
                            trackDemuxerHelper->previousSample = [[MP42SampleBuffer alloc] init];
                            trackDemuxerHelper->previousSample.sampleDuration = StartTime / 1000000;
                            trackDemuxerHelper->previousSample.sampleOffset = 0;
                            trackDemuxerHelper->previousSample.sampleTimestamp = 0;
                            trackDemuxerHelper->previousSample.sampleIsSync = YES;
                            trackDemuxerHelper->previousSample.sampleTrackId = track.Id;
                            if(track.needConversion)
                                trackDemuxerHelper->previousSample.sampleSourceTrack = track;

                            @synchronized(helper->fifo) {
                                [helper->fifo addObject:trackDemuxerHelper->previousSample];
                                [trackDemuxerHelper->previousSample release];
                            }
                        }
                        else {
                            if (nextSample->sampleTimestamp < trackDemuxerHelper->previousSample.sampleTimestamp) {
                                // Out of order samples? swap the next with the previous
                                MP42SampleBuffer *temp = nextSample;
                                nextSample = trackDemuxerHelper->previousSample;
                                trackDemuxerHelper->previousSample = temp;
                            }

                            trackDemuxerHelper->previousSample.sampleDuration = (nextSample->sampleTimestamp - trackDemuxerHelper->previousSample.sampleTimestamp) / 1000000;
                            @synchronized(helper->fifo) {
                                [helper->fifo addObject:trackDemuxerHelper->previousSample];
                                [trackDemuxerHelper->previousSample release];
                            }
                        }

                        trackDemuxerHelper->previousSample = nextSample;
                        trackDemuxerHelper->samplesWritten++;
                    }
                    // VobSub seems to have an end duration, and no blank samples, so create a new one each time to fill the gaps
                    else if (!strcmp(trackInfo->CodecID, "S_VOBSUB")) {
                        if (StartTime > trackDemuxerHelper->current_time) {
                            MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                            sample->sampleDuration = (StartTime - trackDemuxerHelper->current_time) / 1000000;
                            sample->sampleSize = 2;
                            sample->sampleData = calloc(1, 2);
                            sample->sampleIsSync = YES;
                            sample->sampleTrackId = track.Id;
                            if(track.needConversion)
                                sample->sampleSourceTrack = track;
                            
                            @synchronized(helper->fifo) {
                                [helper->fifo addObject:sample];
                                [sample release];
                            }
                        }
                        
                        nextSample->sampleDuration = (EndTime - StartTime ) / 1000000;
                        
                        @synchronized(helper->fifo) {
                            [helper->fifo addObject:nextSample];
                            [nextSample release];
                        }
                        
                        trackDemuxerHelper->current_time = EndTime;
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
            [trackDemuxerHelper->queue addObject:frameSample];
            [frameSample release];

            if ([trackDemuxerHelper->queue count] < bufferSize)
                continue;
            else {
                currentSample = [trackDemuxerHelper->queue objectAtIndex:trackDemuxerHelper->buffer];

                // matroska stores only the start and end time, so we need to recreate
                // the frame duration and the offset from the start time, the end time is useless
                // duration calculation
                duration = [[trackDemuxerHelper->queue lastObject] startTime] - currentSample->startTime;

                for (MatroskaSample *sample in trackDemuxerHelper->queue)
                    if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                        if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                            duration = next_duration;

                // offset calculation
                offset = currentSample->startTime - trackDemuxerHelper->current_time;
                // save the minimum offset, used later to keep all the offset values positive
                if (offset < minOffset)
                    minOffset = offset;

                [trackDemuxerHelper->offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

                trackDemuxerHelper->current_time += duration;

                if (readMkvPacket(ioStream, trackInfo, currentSample->filePos, &frame, &currentSample->frameSize)) {
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->sampleData = frame;
                    sample->sampleSize = currentSample->frameSize;
                    sample->sampleDuration = duration / 10000.0f;
                    sample->sampleOffset = offset / 10000.0f;
                    sample->sampleTimestamp = StartTime;
                    sample->sampleIsSync = currentSample->frameFlags & FRAME_KF;
                    sample->sampleTrackId = track.Id;

                    trackDemuxerHelper->samplesWritten++;

                    if (sample->sampleOffset < trackDemuxerHelper->minDisplayOffset)
                        trackDemuxerHelper->minDisplayOffset = sample->sampleOffset;

                    if (trackDemuxerHelper->buffer >= bufferSize)
                        [trackDemuxerHelper->queue removeObjectAtIndex:0];
                    if (trackDemuxerHelper->buffer < bufferSize)
                        trackDemuxerHelper->buffer++;

                    @synchronized(helper->fifo) {
                        [helper->fifo addObject:sample];
                        [sample release];
                    }
                }
                else
                    continue;
            }
        }        
    }

    for (MP42Track* track in activeTracks) {
        muxer_helper *helper = track.muxer_helper;
        trackDemuxerHelper = helper->trackDemuxer;

        if (trackDemuxerHelper->queue) {
            TrackInfo *trackInfo = mkv_GetTrackInfo(matroskaFile, [track sourceId]);

            while ([trackDemuxerHelper->queue count]) {
                if (trackDemuxerHelper->bufferFlush == 1) {
                    // add a last sample to get the duration for the last frame
                    MatroskaSample *lastSample = [trackDemuxerHelper->queue lastObject];
                    for (MatroskaSample *sample in trackDemuxerHelper->queue) {
                        if (sample->startTime > lastSample->startTime)
                            lastSample = sample;
                    }
                    frameSample = [[MatroskaSample alloc] init];
                    frameSample->startTime = [lastSample endTime];
                    [trackDemuxerHelper->queue addObject:frameSample];
                    [frameSample release];
                }
                currentSample = [trackDemuxerHelper->queue objectAtIndex:trackDemuxerHelper->buffer];

                // matroska stores only the start and end time, so we need to recreate
                // the frame duration and the offset from the start time, the end time is useless
                // duration calculation
                duration = [[trackDemuxerHelper->queue lastObject] startTime] - currentSample->startTime;

                for (MatroskaSample *sample in trackDemuxerHelper->queue)
                    if (sample != currentSample && (sample->startTime >= currentSample->startTime))
                        if ((next_duration = (sample->startTime - currentSample->startTime)) < duration)
                            duration = next_duration;

                // offset calculation
                offset = currentSample->startTime - trackDemuxerHelper->current_time;
                // save the minimum offset, used later to keep the all the offset values positive
                if (offset < minOffset)
                    minOffset = offset;

                [trackDemuxerHelper->offsetsArray addObject:[NSNumber numberWithLongLong:offset]];

                trackDemuxerHelper->current_time += duration;

                if (readMkvPacket(ioStream, trackInfo, currentSample->filePos, &frame, &currentSample->frameSize)) {
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->sampleData = frame;
                    sample->sampleSize = currentSample->frameSize;
                    sample->sampleDuration = duration / 10000.0f;
                    sample->sampleOffset = offset / 10000.0f;
                    sample->sampleTimestamp = StartTime;
                    sample->sampleIsSync = currentSample->frameFlags & FRAME_KF;
                    sample->sampleTrackId = track.Id;

                    trackDemuxerHelper->samplesWritten++;

                    if (sample->sampleOffset < trackDemuxerHelper->minDisplayOffset)
                        trackDemuxerHelper->minDisplayOffset = sample->sampleOffset;

                    if (trackDemuxerHelper->buffer >= bufferSize)
                        [trackDemuxerHelper->queue removeObjectAtIndex:0];

                    @synchronized(helper->fifo) {
                        [helper->fifo addObject:sample];
                        [sample release];
                    }

                    trackDemuxerHelper->bufferFlush++;
                    if (trackDemuxerHelper->bufferFlush >= bufferSize - 1) {
                        break;
                    }
                }
                else
                    continue;
            }
        }

        if (trackDemuxerHelper->ss) {
            MP42SampleBuffer *sample;
            MP4TrackId dstTrackId = track.Id;
            SBSubSerializer *ss = trackDemuxerHelper->ss;

            [ss setFinished:YES];

            while (![ss isEmpty]) {
                SBSubLine *sl = [ss getSerializedPacket];

                if ([sl->line isEqualToString:@"\n"]) {
                    if (!(sample = copyEmptySubtitleSample(dstTrackId, sl->end_time - sl->begin_time, NO)))
                        break;

                    @synchronized(helper->fifo) {
                        [helper->fifo addObject:sample];
                        [sample release];
                        trackDemuxerHelper->samplesWritten++;
                    }

                    continue;
                }
                if (!(sample = copySubtitleSample(dstTrackId, sl->line, sl->end_time - sl->begin_time, NO, NO, CGSizeMake(0, 0), 0)))
                    break;

                @synchronized(helper->fifo) {
                    [helper->fifo addObject:sample];
                    [sample release];
                    trackDemuxerHelper->samplesWritten++;
                }
            }
        }
    }

    readerStatus = 1;
    [pool release];
}

- (void)start
{
    if (!matroskaFile)
        return;

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(demux:) object:self];
        [dataReader setName:@"Matroska Demuxer"];
        [dataReader start];
    }

}

- (BOOL)done
{
    return readerStatus;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];

    [activeTracks addObject:track];
}

- (CGFloat)progress
{
    return progress;
}

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{
    for (MP42Track * track in activeTracks) {
        MatroskaTrackHelper * trackHelper = track.muxer_helper->trackDemuxer;
        MP4TrackId trackId = [track Id];

        if (trackHelper->minDisplayOffset != 0) {
            int i;
            for (i = 0; i < trackHelper->samplesWritten; i++)
            MP4SetSampleRenderingOffset(fileHandle,
                                        trackId,
                                        1 + i,
                                        MP4GetSampleRenderingOffset(fileHandle, trackId, 1+i) - trackHelper->minDisplayOffset);

            MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                   trackId,
                                                                   MP4GetTrackDuration(fileHandle, trackId),
                                                                   MP4GetTimeScale(fileHandle));
            MP4AddTrackEdit(fileHandle, trackId, MP4_INVALID_EDIT_ID, -trackHelper->minDisplayOffset,
                            editDuration, 0);
        }
    }

    return YES;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release], dataReader = nil;

    [metadata release], metadata = nil;
    [activeTracks release], activeTracks = nil;
    [tracksArray release], tracksArray = nil;
	[fileURL release], fileURL = nil;

	/* close matroska parser */ 
    closeMatroskaFile(matroskaFile, ioStream);

    [super dealloc];
}

@end
