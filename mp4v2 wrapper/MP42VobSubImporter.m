//
//  SBVobSubImpoter.m
//  Subler
//
//  Created by Damiano Galassi on 20/12/12.
//  Based on parts of Perian's source code.
//

#import "MP42VobSubImporter.h"
#import "SubUtilities.h"
#import "SBLanguages.h"
#import "MP42File.h"


@implementation SBVobSubSample

- (id)initWithTime:(long)time offset:(long)offset
{
	self = [super init];
	if(!self)
		return self;

	timeStamp = time;
	fileOffset = offset;

	return self;
}

@end

@implementation SBVobSubTrack

- (id)initWithPrivateData:(NSArray *)idxPrivateData language:(NSString *)lang andIndex:(int)trackIndex
{
	self = [super init];
	if(!self)
		return self;

	privateData = [idxPrivateData retain];
	language = [lang retain];
	index = trackIndex;
	samples = [[NSMutableArray alloc] init];

	return self;
}

- (void)dealloc
{
	[privateData release];
	[language release];
	[samples release];
	[super dealloc];
}

- (void)addSample:(SBVobSubSample *)sample
{
	[samples addObject:sample];
    duration = sample->timeStamp;
}

- (void)addSampleTime:(long)time offset:(long)offset
{
	SBVobSubSample *sample = [[SBVobSubSample alloc] initWithTime:time offset:offset];
	[self addSample:sample];
	[sample release];
}

@end

typedef enum {
	VOB_SUB_STATE_READING_PRIVATE,
	VOB_SUB_STATE_READING_TRACK_HEADER,
	VOB_SUB_STATE_READING_DELAY,
	VOB_SUB_STATE_READING_TRACK_DATA
} VobSubState;

static NSString *getNextVobSubLine(NSEnumerator *lineEnum)
{
	NSString *line;
	while ((line = [lineEnum nextObject]) != nil) {
		//Reject empty lines which may contain whitespace
		if([line length] < 3)
			continue;
		
		if([line characterAtIndex:0] == '#')
			continue;
		
		break;
	}
	return line;
}

static NSArray* LoadVobSubSubtitles(NSURL *theDirectory, NSString *filename)
{
    @autoreleasepool {
        NSString *nsPath = [[theDirectory path] stringByAppendingPathComponent:filename];
        NSString *idxContent = STLoadFileWithUnknownEncoding(nsPath);
        NSData *privateData = nil;

        VobSubState state = VOB_SUB_STATE_READING_PRIVATE;
        SBVobSubTrack *currentTrack = nil;
        int imageWidth = 0, imageHeight = 0;
        long delay=0;

        NSString *subFileName = [[nsPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"sub"];

        if([idxContent length]) {
            NSError *nsErr;
            NSDictionary *attr = [[NSFileManager defaultManager] attributesOfItemAtPath:subFileName error:&nsErr];
            if (!attr) goto bail;
            int subFileSize = [[attr objectForKey:NSFileSize] intValue];

            NSArray *lines = [idxContent componentsSeparatedByString:@"\n"];
            NSMutableArray *privateLines = [NSMutableArray array];
            NSEnumerator *lineEnum = [lines objectEnumerator];
            NSString *line;

            NSMutableArray *tracks = [NSMutableArray array];

            while((line = getNextVobSubLine(lineEnum)) != NULL)
            {
                if([line hasPrefix:@"timestamp: "])
                    state = VOB_SUB_STATE_READING_TRACK_DATA;
                else if([line hasPrefix:@"id: "])
                {
                    if(privateData == nil)
                    {
                        NSString *allLines = [privateLines componentsJoinedByString:@"\n"];
                        privateData = [allLines dataUsingEncoding:NSUTF8StringEncoding];
                    }
                    state = VOB_SUB_STATE_READING_TRACK_HEADER;
                }
                else if([line hasPrefix:@"delay: "])
                    state = VOB_SUB_STATE_READING_DELAY;
                else if(state != VOB_SUB_STATE_READING_PRIVATE)
                    state = VOB_SUB_STATE_READING_TRACK_HEADER;

                switch(state)
                {
                    case VOB_SUB_STATE_READING_PRIVATE:
                        [privateLines addObject:line];
                        if([line hasPrefix:@"size: "])
                        {
                            sscanf([line UTF8String], "size: %dx%d", &imageWidth, &imageHeight);
                        }
                        break;
                    case VOB_SUB_STATE_READING_TRACK_HEADER:
                        if([line hasPrefix:@"id: "])
                        {
                            char *langStr = (char *)malloc([line length]);
                            int index;
                            sscanf([line UTF8String], "id: %s index: %d", langStr, &index);
                            int langLength = strlen(langStr);
                            if(langLength > 0 && langStr[langLength-1] == ',')
                                langStr[langLength-1] = 0;
                            NSString *language = [NSString stringWithUTF8String:langStr];
                            free(langStr);

                            currentTrack = [[SBVobSubTrack alloc] initWithPrivateData:privateLines language:language andIndex:index];
                            [tracks addObject:currentTrack];
                            [currentTrack release];
                        }
                        break;
                    case VOB_SUB_STATE_READING_DELAY:
                        delay = ParseSubTime([[line substringFromIndex:7] UTF8String], 1000, YES);
                        break;
                    case VOB_SUB_STATE_READING_TRACK_DATA:
                    {
                        char *timeStr = (char *)malloc([line length]);
                        unsigned int position;
                        sscanf([line UTF8String], "timestamp: %s filepos: %x", timeStr, &position);
                        long time = ParseSubTime(timeStr, 1000, YES);
                        free(timeStr);
                        if(position > subFileSize)
                            position = subFileSize;
                        [currentTrack addSampleTime:time + delay offset:position];
                    }
                        break;
                }
            }

            return [tracks retain];
        }
    bail:
        ;
        NSLog(@"Exception occurred while importing VobSub");
        return nil;
    }
}

@implementation MP42VobSubImporter

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    if ((self = [super init])) {
        NSInteger count = 0;
        delegate = del;
        fileURL = [URL retain];

        tracks = LoadVobSubSubtitles([URL URLByDeletingLastPathComponent], [URL lastPathComponent]);
        tracksArray = [[NSMutableArray alloc] initWithCapacity:[tracks count]];

        for (SBVobSubTrack *track in tracks) {
            MP42SubtitleTrack *newTrack = [[MP42SubtitleTrack alloc] init];

            newTrack.format = @"VobSub";
            newTrack.sourceFormat = @"VobSub";
            newTrack.sourceURL = fileURL;
            newTrack.alternate_group = 2;
            newTrack.Id = count++;
            newTrack.language = [NSString stringWithFormat:@"%s", lang_for_code_s([track->language UTF8String])->eng_name];;
            newTrack.duration = track->duration;

            [tracksArray addObject:newTrack];
            [newTrack release];
        }

        if (![tracksArray count]) {
            if (outError)
                *outError = MP42Error(@"The file could not be opened.", @"The file is not a idx file, or it does not contain any subtitles.", 100);

            [self release];
            return nil;
        }
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    return 1000;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    return NSMakeSize([(MP42SubtitleTrack*)track trackWidth], [(MP42SubtitleTrack*) track trackHeight]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    SBVobSubTrack *vobTrack = [tracks objectAtIndex:track.sourceId];
    NSMutableData *magicCookie = nil;

    for (NSString *line in vobTrack->privateData) {
        if([line hasPrefix:@"palette: "]) {
            const char *palette = [line UTF8String];
            UInt32 colorPalette[16];

            if (palette != NULL) {
                sscanf(palette, "palette: %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx, %lx",
                       &colorPalette[ 0], &colorPalette[ 1], &colorPalette[ 2], &colorPalette[ 3],
                       &colorPalette[ 4], &colorPalette[ 5], &colorPalette[ 6], &colorPalette[ 7],
                       &colorPalette[ 8], &colorPalette[ 9], &colorPalette[10], &colorPalette[11],
                       &colorPalette[12], &colorPalette[13], &colorPalette[14], &colorPalette[15]);
            }
            magicCookie = [[NSData dataWithBytes:colorPalette length:sizeof(UInt32)*16] retain];
        }
    }

    return magicCookie;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    NSURL *subFileURL = [[fileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"sub"];

    NSData *subFileData = [NSData dataWithContentsOfURL:subFileURL];

    NSInteger tracksNumber = [activeTracks count];
    NSInteger tracksDone = 0;

    for (MP42Track * track in activeTracks) {
            SBVobSubTrack *vobTrack = [tracks objectAtIndex:track.sourceId];
            SBVobSubSample *firstSample = nil;

            uint32_t lastTime = 0;
            int i, sampleCount = [vobTrack->samples count];

            for(i = 0; i < sampleCount; i++) {
                SBVobSubSample *currentSample = [vobTrack->samples objectAtIndex:i];
                int offset = currentSample->fileOffset;
                int nextOffset;
                if(i == sampleCount - 1)
                    nextOffset = [subFileData length];
                else
                    nextOffset = ((SBVobSubSample *)[vobTrack->samples objectAtIndex:i+1])->fileOffset;
                int size = nextOffset - offset;
                if(size < 0)
                    //Skip samples for which we cannot determine size
                    continue;

                NSData *subData = [subFileData subdataWithRange:NSMakeRange(offset, size)];
                uint8_t *extracted = (uint8_t *)malloc(size);
                //The index here likely should really be track->index, but I'm not sure we can really trust it.
                int extractedSize = ExtractVobSubPacket(extracted, (UInt8 *)[subData bytes], size, &size, -1);

                uint16_t startTimestamp, endTimestamp;
                uint8_t forced;
                if(!ReadPacketTimes(extracted, extractedSize, &startTimestamp, &endTimestamp, &forced)) {
                    free(extracted);
                    continue;
                }

                uint32_t startTime = currentSample->timeStamp + startTimestamp;
                uint32_t endTime = currentSample->timeStamp + endTimestamp;

                int duration = endTimestamp - startTimestamp;
                if(duration <= 0 && i <= sampleCount - 1) {
                    //Sample with no end duration, use the duration of the next one
                    endTime = ((SBVobSubSample *)[vobTrack->samples objectAtIndex:i+1])->timeStamp;
                    duration = endTime - startTime;
                }
                if(duration <= 0) {
                    //Skip samples which are broken
                    free(extracted);
                    continue;
                }
                if(firstSample == nil) {
                    currentSample->timeStamp = startTime;
                    firstSample = currentSample;
                }
                if(lastTime != startTime) {
                    //insert a sample with no real data, to clear the subs
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->sampleSize = 2;
                    sample->sampleData = calloc(1, 2);
                    sample->sampleDuration = startTime - lastTime;
                    sample->sampleOffset = 0;
                    sample->sampleTimestamp = startTime;
                    sample->sampleIsSync = YES;
                    sample->sampleTrackId = track.Id;
                    if(track.needConversion)
                        sample->sampleSourceTrack = track;

                    @synchronized(samplesBuffer) {
                        [samplesBuffer addObject:sample];
                        [sample release];
                    }

                    sample++;
                }

                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->sampleData = extracted;
                sample->sampleSize = size;
                sample->sampleDuration = duration;
                sample->sampleOffset = 0;
                sample->sampleTimestamp = startTime;
                sample->sampleIsSync = YES;
                sample->sampleTrackId = track.Id;
                if(track.needConversion)
                    sample->sampleSourceTrack = track;

                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:sample];
                    [sample release];
                }

                lastTime = endTime;

                progress = ((i / (CGFloat) sampleCount ) * 100 / tracksNumber) + (tracksDone / (CGFloat) tracksNumber * 100);
            }
        tracksDone++;
    }

    readerStatus = 1;
    [pool release];
}


- (MP42SampleBuffer*)nextSampleForTrack:(MP42Track *)track
{
    return [[self copyNextSample] autorelease];
}

- (MP42SampleBuffer*)copyNextSample
{
    if (samplesBuffer == nil)
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
        [dataReader start];
    }

    while (![samplesBuffer count] && !readerStatus)
        usleep(2000);

    if (readerStatus)
        if ([samplesBuffer count] == 0) {
            readerStatus = 0;
            [dataReader release];
            dataReader = nil;
            return nil;
        }

    MP42SampleBuffer* sample;

    @synchronized(samplesBuffer) {
        sample = [samplesBuffer objectAtIndex:0];
        [sample retain];
        [samplesBuffer removeObjectAtIndex:0];
    }

    return sample;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];

    [activeTracks addObject:track];
}

- (CGFloat)progress {
    return progress;
}

- (void) dealloc
{
	[fileURL release];
    [tracksArray release];
    [tracks release];

    [dataReader release];
    [activeTracks release];
    [samplesBuffer release];

    [super dealloc];
}

@end
