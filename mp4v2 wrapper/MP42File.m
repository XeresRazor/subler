//
//  MP42File.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42File.h"
#import "MP42FileImporter.h"
#import "MP42SubUtilities.h"
#import "SBLanguages.h"

#import <QTKit/QTKit.h>

#if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
#import <AVFoundation/AVFoundation.h>
#endif

NSString * const MP42Create64BitData = @"MP4264BitData";
NSString * const MP42Create64BitTime = @"MP4264BitTime";
NSString * const MP42CreateChaptersPreviewTrack = @"MP42ChaptersPreview";
NSString * const MP42OrganizeAlternateGroups = @"MP42AlternateGroups";

@interface MP42File ()

- (void)reconnectReferences;
- (void)removeMuxedTrack:(MP42Track *)track;

- (void)organizeAlternateGroupsForMediaType:(NSString *)mediaType withGroupID:(NSUInteger)groupID;

- (NSArray *)generatePreviewImagesQTKitFromChapters:(NSArray *)chapters andFile:(NSURL *)file;
- (NSArray *)generatePreviewImagesAVFoundationFromChapters:(NSArray *)chapters andFile:(NSURL *)file;

- (BOOL)createChaptersPreview;

@end

@implementation MP42File

- (id)init
{
    if ((self = [super init])) {
        _hasFileRepresentation = NO;
        _tracks = [[NSMutableArray alloc] init];
        _tracksToBeDeleted = [[NSMutableArray alloc] init];

        _metadata = [[MP42Metadata alloc] init];
        _importers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithDelegate:(id <MP42FileDelegate>)del;
{
    if ((self = [self init])) {
        _delegate = del;
    }

    return self;
}

- (instancetype)initWithExistingFile:(NSURL *)URL andDelegate:(id <MP42FileDelegate>)del;
{
    if ((self = [super init]))
	{
        _delegate = del;
		_fileHandle = MP4Read([[URL path] UTF8String]);

        if (!_fileHandle) {
            [self release];
			return nil;
        }

        const char *brand = NULL;
        MP4GetStringProperty(_fileHandle, "ftyp.majorBrand", &brand);
        if (brand != NULL) {
            if (!strcmp(brand, "qt  ")) {
                MP4Close(_fileHandle, 0);
                [self release];
                return nil;
            }
        }

        _fileURL = [URL retain];
        _hasFileRepresentation = YES;

        _tracks = [[NSMutableArray alloc] init];
        int i, tracksCount = MP4GetNumberOfTracks(_fileHandle, 0, 0);
        MP4TrackId chapterId = findChapterTrackId(_fileHandle);

        for (i=0; i< tracksCount; i++) {
            id track;
            MP4TrackId trackId = MP4FindTrackId(_fileHandle, i, 0, 0);
            const char* type = MP4GetTrackType(_fileHandle, trackId);

            if (MP4_IS_AUDIO_TRACK_TYPE(type))
                track = [MP42AudioTrack alloc];
            else if (MP4_IS_VIDEO_TRACK_TYPE(type))
                track = [MP42VideoTrack alloc];
            else if (!strcmp(type, MP4_TEXT_TRACK_TYPE)) {
                if (trackId == chapterId)
                    track = [MP42ChapterTrack alloc];
                else
                    track = [MP42Track alloc];
            }
            else if (!strcmp(type, MP4_SUBTITLE_TRACK_TYPE))
                track = [MP42SubtitleTrack alloc];
            else if (!strcmp(type, MP4_SUBPIC_TRACK_TYPE))
                track = [MP42SubtitleTrack alloc];
            else if (!strcmp(type, MP4_CC_TRACK_TYPE))
                track = [MP42ClosedCaptionTrack alloc];
            else
                track = [MP42Track alloc];

            track = [track initWithSourceURL:_fileURL trackID:trackId fileHandle:_fileHandle];
            [_tracks addObject:track];
            [track release];
        }

        [self reconnectReferences];

        _tracksToBeDeleted = [[NSMutableArray alloc] init];
        _metadata = [[MP42Metadata alloc] initWithSourceURL:_fileURL fileHandle:_fileHandle];
        _importers = [[NSMutableDictionary alloc] init];
        MP4Close(_fileHandle, 0);
	}

	return self;
}

- (void)reconnectReferences {
    for (MP42Track *ref in _tracks) {
        if ([ref isMemberOfClass:[MP42AudioTrack class]]) {
            MP42AudioTrack *a = (MP42AudioTrack *)ref;
            if (a.fallbackTrackId)
                a.fallbackTrack = [self trackWithTrackID:a.fallbackTrackId];
            if (a.followsTrackId)
                a.followsTrack = [self trackWithTrackID:a.followsTrackId];
        }
        if ([ref isMemberOfClass:[MP42SubtitleTrack class]]) {
            MP42SubtitleTrack *a = (MP42SubtitleTrack *)ref;
            if (a.forcedTrackId)
                a.forcedTrack = [self trackWithTrackID:a.forcedTrackId];
        }
    }
}

- (NSUInteger)duration
{
    NSUInteger duration = 0;
    NSUInteger trackDuration = 0;
    for (MP42Track *track in _tracks)
        if ((trackDuration = [track duration]) > duration)
            duration = trackDuration;

    return duration;
}

- (MP42ChapterTrack *)chapters
{
    MP42ChapterTrack *chapterTrack = nil;

    for (MP42Track *track in _tracks)
        if ([track isMemberOfClass:[MP42ChapterTrack class]])
            chapterTrack = (MP42ChapterTrack*) track;

    return [[chapterTrack retain] autorelease];
}

- (NSUInteger)tracksCount
{
    return [_tracks count];
}

- (id)trackAtIndex:(NSUInteger)index
{
    return [_tracks objectAtIndex:index];
}

- (id)trackWithTrackID:(NSUInteger)trackId
{
    for (MP42Track *track in _tracks) {
        if (track.Id == trackId)
            return track;
    }

    return nil;
}

- (NSArray *)tracksWithMediaType:(NSString *)mediaType
{
    NSMutableArray *tracks = [[[NSMutableArray alloc] init] autorelease];

    for (MP42Track *track in _tracks) {
        if ([track.mediaType isEqualToString:mediaType])
            [tracks addObject:track];
    }

    return [[tracks copy] autorelease];
}

- (void)addTrack:(MP42Track *)track
{
    track.sourceId = track.Id;
    track.Id = 0;
    track.muxed = NO;
    track.isEdited = YES;

    track.language = track.language;
    track.name = track.name;
    if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
        for (id previousTrack in _tracks)
            if ([previousTrack isMemberOfClass:[MP42ChapterTrack class]]) {
                [_tracks removeObject:previousTrack];
                break;
        }
    }

    if (trackNeedConversion(track.format) || track.needConversion) {
        track.needConversion = YES;
        track.sourceFormat = track.format;
        if ([track isMemberOfClass:[MP42AudioTrack class]]) {
            MP42AudioTrack *audioTrack = (MP42AudioTrack *)track;
            track.format = MP42AudioFormatAAC;
            audioTrack.sourceChannels = audioTrack.channels;
            if ([audioTrack.mixdownType isEqualToString:SBMonoMixdown] || audioTrack.sourceChannels == 1)
                audioTrack.channels = 1;
            else if (audioTrack.mixdownType)
                audioTrack.channels = 2;
        }
        else if ([track isMemberOfClass:[MP42SubtitleTrack class]])
            track.format = MP42SubtitleFormatTx3g;
    }

    if (track.muxer_helper->importer && track.sourceURL) {
        if ([_importers objectForKey:[[track sourceURL] path]])
            track.muxer_helper->importer = [_importers objectForKey:[[track sourceURL] path]];
        else
            [_importers setObject:track.muxer_helper->importer forKey:[[track sourceURL] path]];
    }

    [_tracks addObject:track];
}

- (void)removeTrackAtIndex:(NSUInteger) index
{
    [self removeTracksAtIndexes:[NSIndexSet indexSetWithIndex:index]];
}

- (void)removeTracksAtIndexes:(NSIndexSet *)indexes
{
    NSUInteger index = [indexes firstIndex];
    while (index != NSNotFound) {
        MP42Track *track = [_tracks objectAtIndex:index];

        // track is muxed, it needs to be removed from the file
        if (track.muxed)
            [_tracksToBeDeleted addObject:track];

        // Remove the reference
        for (MP42Track *ref in _tracks) {
            if ([ref isMemberOfClass:[MP42AudioTrack class]]) {
                MP42AudioTrack *a = (MP42AudioTrack *)ref;
                if (a.fallbackTrack == track)
                    a.fallbackTrack = nil;
                if (a.followsTrack == track)
                    a.followsTrack = nil;
            }
            if ([ref isMemberOfClass:[MP42SubtitleTrack class]]) {
                MP42SubtitleTrack *a = (MP42SubtitleTrack *)ref;
                if (a.forcedTrack == track)
                    a.forcedTrack = nil;
            }
        }
        index = [indexes indexGreaterThanIndex:index];
    }

    [_tracks removeObjectsAtIndexes:indexes];
}

- (void)moveTrackAtIndex:(NSUInteger)index toIndex:(NSUInteger) newIndex
{
    id track = [[_tracks objectAtIndex:index] retain];

    [_tracks removeObjectAtIndex:index];
    if (newIndex > [_tracks count] || newIndex > index)
        newIndex--;
    [_tracks insertObject:track atIndex:newIndex];
    [track release];
}

- (BOOL)optimize
{
    __block BOOL noErr = NO;
    __block BOOL done = NO;

    @autoreleasepool {
        NSError *error;

        NSFileManager *fileManager = [[NSFileManager alloc] init];
#ifdef SB_SANDBOX
        NSURL *folderURL = [fileURL URLByDeletingLastPathComponent];
        NSURL *tempURL = [fileManager URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:folderURL create:YES error:&error];
#else
        NSURL *tempURL = [_fileURL URLByDeletingLastPathComponent];
#endif
        if (tempURL) {
            tempURL = [tempURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp", [_fileURL lastPathComponent]]];

            unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[_fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];

            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                noErr = MP4Optimize([[_fileURL path] UTF8String], [[tempURL path] UTF8String]);
                done = YES;
            });

            while (!done) {
                unsigned long long fileSize = [[[fileManager attributesOfItemAtPath:[tempURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
                [self progressStatus:((CGFloat)fileSize / originalFileSize) * 100];
                usleep(450000);
            }

            if (noErr) {
                NSURL *result = nil;
                noErr = [fileManager replaceItemAtURL:_fileURL withItemAtURL:tempURL backupItemName:nil options:0 resultingItemURL:&result error:&error];
                if (noErr) {
                    [_fileURL release];
                    _fileURL = [result retain];
                }
            }
        }

        [fileManager release];
    }
    
    if ([_delegate respondsToSelector:@selector(endSave:)])
        [_delegate performSelector:@selector(endSave:) withObject:self];
    
    return noErr;
}

- (BOOL)writeToUrl:(NSURL *)url withAttributes:(NSDictionary *)attributes error:(NSError **)outError
{
    BOOL success = YES;

    if (!url && outError) {
        *outError = MP42Error(@"Invalid path.", @"The destination path cannot be empty.", 100);
        return NO;
    }

    if ([self hasFileRepresentation]) {
        __block BOOL noErr = YES;

        if (![_fileURL isEqualTo:url]) {
            __block BOOL done = NO;
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            unsigned long long originalFileSize = [[[fileManager attributesOfItemAtPath:[_fileURL path] error:NULL] valueForKey:NSFileSize] unsignedLongLongValue];

            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                noErr = [fileManager copyItemAtURL:_fileURL toURL:url error:outError];
                done = YES;
            });

            while (!done) {
                unsigned long long fileSize = [[[fileManager attributesOfItemAtPath:[url path] error:NULL] valueForKey:NSFileSize] unsignedLongLongValue];
                [self progressStatus:((CGFloat)fileSize / originalFileSize) * 100];
                usleep(450000);
            }
            [fileManager release];
        }

        if (noErr) {
            _fileURL = [url retain];
            success = [self updateMP4FileWithAttributes:attributes error:outError];
        }
        else
            success = NO;
    }
    else {
        _fileURL = [url retain];

        NSString *fileExtension = [_fileURL pathExtension];
        char *majorBrand = "mp42";
        char *supportedBrands[4];
        uint32_t supportedBrandsCount = 0;
        uint32_t flags = 0;

        if ([[attributes valueForKey:MP42Create64BitData] boolValue])
            flags += 0x01;

        if ([[attributes valueForKey:MP42Create64BitTime] boolValue])
            flags += 0x02;

        if ([fileExtension isEqualToString:MP42FileTypeM4V]) {
            majorBrand = "M4V ";
            supportedBrands[0] = majorBrand;
            supportedBrands[1] = "M4A ";
            supportedBrands[2] = "mp42";
            supportedBrands[3] = "isom";
            supportedBrandsCount = 4;
        }
        else if ([fileExtension isEqualToString:MP42FileTypeM4A] || [fileExtension isEqualToString:MP42FileTypeM4A]) {
            majorBrand = "M4A ";
            supportedBrands[0] = majorBrand;
            supportedBrands[1] = "mp42";
            supportedBrands[2] = "isom";
            supportedBrandsCount = 3;
        }
        else {
            supportedBrands[0] = majorBrand;
            supportedBrands[1] = "isom";
            supportedBrandsCount = 2;
        }

        _fileHandle = MP4CreateEx([[_fileURL path] UTF8String],
                                 flags, 1, 1,
                                 majorBrand, 0,
                                 supportedBrands, supportedBrandsCount);
        if (_fileHandle) {
            MP4SetTimeScale(_fileHandle, 600);
            MP4Close(_fileHandle, 0);

            success = [self updateMP4FileWithAttributes:attributes error:outError];
        }
    }

    return success;
}

- (BOOL)updateMP4FileWithAttributes:(NSDictionary *)attributes error:(NSError **)outError
{
    BOOL noErr = YES;

    // Open the mp4 file
    _fileHandle = MP4Modify([[_fileURL path] UTF8String], 0);
    if (_fileHandle == MP4_INVALID_FILE_HANDLE) {
        if (outError)
            *outError = MP42Error(@"Unable to open the file", nil, 100);
        return NO;
    }

    // Delete tracks
    for (MP42Track *track in _tracksToBeDeleted)
        [self removeMuxedTrack:track];

    // Init the muxer and prepare the work
    _muxer = [[MP42Muxer alloc] initWithDelegate:self];

    for (MP42Track *track in _tracks) {
        if (!track.muxed) {
            // Reopen the file importer is they are not already open
            // this happens when the object was unarchived from a file
            if (![track isMemberOfClass:[MP42ChapterTrack class]] && !track.muxer_helper->importer && [track sourceURL]) {
                MP42FileImporter *fileImporter = [_importers valueForKey:[[track sourceURL] path]];

                if (!fileImporter) {
                    fileImporter = [[[MP42FileImporter alloc] initWithURL:[track sourceURL] error:outError] autorelease];
                    [_importers setObject:fileImporter forKey:[[track sourceURL] path]];
                }

                if (fileImporter) {
                    track.muxer_helper->importer = fileImporter;
                } else {
                    *outError = MP42Error(@"Missing sources.",
                                          @"One or more sources files are missing.",
                                          200);
                    noErr = NO;
                    break;
                }

            }

            // Add the track to the muxer
            if (track.muxer_helper->importer)
                [_muxer addTrack:track];
        }
    }

    if (!noErr) {
        [_muxer release], _muxer = nil;
        MP4Close(_fileHandle, 0);
        return NO;
    }

    noErr = [_muxer setup:_fileHandle error:outError];

    if (!noErr) {
        [_muxer release], _muxer = nil;
        MP4Close(_fileHandle, 0);
        return NO;
    }

    // Start the muxer and wait
    [_muxer work];

    [_muxer release], _muxer = nil;
    [_importers removeAllObjects];

    // Generate previews images for chapters
    if ([[attributes valueForKey:MP42OrganizeAlternateGroups] boolValue])
        [self organizeAlternateGroups];

    // Update modified tracks properties
    updateMoovDuration(_fileHandle);
    for (MP42Track *track in _tracks) {
        if (track.isEdited) {
            noErr = [track writeToFile:_fileHandle error:outError];
            if (!noErr)
                break;
        }
    }

    // Update metadata
    if (_metadata.isEdited)
        [_metadata writeMetadataWithFileHandle:_fileHandle];

    // Close the mp4 file handle
    if (!MP4Close(_fileHandle, 0)) {
        if (outError)
            *outError = MP42Error(@"File excedes 4 GB.",
                                  @"The file is bigger than 4 GB, but it was created with 32bit data chunk offset.\nSelect 64bit data chunk offset in the save panel.",
                                  100);
        return NO;
    }

    // Generate previews images for chapters
    if ([[attributes valueForKey:MP42CreateChaptersPreviewTrack] boolValue] && [_tracks count])
        [self createChaptersPreview];

    if ([_delegate respondsToSelector:@selector(endSave:)])
        [_delegate performSelector:@selector(endSave:) withObject:self];

    return noErr;
}

- (void)cancel;
{
    _cancelled = YES;
    [_muxer cancel];
}

- (void)progressStatus:(CGFloat)progress {
    if ([_delegate respondsToSelector:@selector(progressStatus:)])
        [_delegate progressStatus:progress];
}

- (uint64_t)dataSize {
    uint64_t estimation = 0;
    for (MP42Track *track in _tracks)
        estimation += track.dataLength;

    return estimation;
}

- (void)removeMuxedTrack:(MP42Track *)track
{
    if (!_fileHandle)
        return;

    // We have to handle a few special cases here.
    if ([track isMemberOfClass:[MP42ChapterTrack class]]) {
        MP4ChapterType err = MP4DeleteChapters(_fileHandle, MP4ChapterTypeAny, track.Id);
        if (err == 0)
            MP4DeleteTrack(_fileHandle, track.Id);
    }
    else
        MP4DeleteTrack(_fileHandle, track.Id);

    updateTracksCount(_fileHandle);
    updateMoovDuration(_fileHandle);
}

- (void)organizeAlternateGroupsForMediaType:(NSString *)mediaType withGroupID:(NSUInteger)groupID
{
    NSArray *tracks = [self tracksWithMediaType:mediaType];
    BOOL enabled = NO;

    if (![tracks count])
        return;

    for (MP42Track *track in tracks) {
        track.alternate_group = groupID;

        if (track.enabled && !enabled)
            enabled = YES;
        else if (track.enabled)
            track.enabled = NO;
    }

    if (!enabled)
        [[tracks objectAtIndex:0] setEnabled:YES];
}

/** Create a set of alternate group the way iTunes and Apple devices want:
    one alternate group for sound, one for subtitles, a disabled photo-jpeg track,
    a disabled chapter track, and a video track with no alternate group */
- (void)organizeAlternateGroups
{
    NSArray *typeToOrganize = @[MP42MediaTypeVideo,
                                MP42MediaTypeAudio,
                                MP42MediaTypeSubtitle];

    for (int i = 0; i < [typeToOrganize count]; i++) {
        [self organizeAlternateGroupsForMediaType:[typeToOrganize objectAtIndex:i]
                                     withGroupID:i];
    }

    for (MP42Track *track in _tracks) {
        if ([track isMemberOfClass:[MP42ChapterTrack class]])
            track.enabled = NO;
    }
}

- (NSArray *)generatePreviewImagesQTKitFromChapters:(NSArray *)chapters andFile:(NSURL *)file {
    __block QTMovie * qtMovie;

    // QTMovie objects must always be create on the main thread.
    NSDictionary *movieAttributes = @{QTMovieURLAttribute: file,
                                      QTMovieAskUnresolvedDataRefsAttribute: @NO,
                                      @"QTMovieOpenForPlaybackAttribute": @YES,
                                      @"QTMovieOpenAsyncRequiredAttribute": @NO,
                                      @"QTMovieOpenAsyncOKAttribute": @NO,
                                      QTMovieApertureModeAttribute: QTMovieApertureModeClean};

    if (dispatch_get_current_queue() != dispatch_get_main_queue()) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            qtMovie = [[QTMovie alloc] initWithAttributes:movieAttributes error:nil];
        });
    }
    else
        qtMovie = [[QTMovie alloc] initWithAttributes:movieAttributes error:nil];

    if (!qtMovie)
        return nil;

    for (QTTrack *qtTrack in [qtMovie tracksOfMediaType:@"sbtl"])
        [qtTrack setAttribute:@NO forKey:QTTrackEnabledAttribute];

    NSDictionary *attributes = [NSDictionary dictionaryWithObject:QTMovieFrameImageTypeNSImage forKey:QTMovieFrameImageType];
    NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:[chapters count]];

    for (SBTextSample *chapter in chapters) {
        QTTime chapterTime = {
            [chapter timestamp] + 1500, // Add a short offset, hopefully we will get a better image
            1000,                       // if there is a fade
            0
        };

        NSImage *frame = [qtMovie frameImageAtTime:chapterTime withAttributes:attributes error:nil];

        if (images)
            [images addObject:frame];
    }

    // Release the movie, we don't want to keep it open while we are writing in it using another library.
    // I am not sure if it is safe to release a QTMovie from a background thread, let's do it on the main just to be sure.
    if (dispatch_get_current_queue() != dispatch_get_main_queue()) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [qtMovie release];
        });
    }
    else
        [qtMovie release];

    return [images autorelease];
}

- (NSArray *)generatePreviewImagesAVFoundationFromChapters:(NSArray *)chapters andFile:(NSURL *)file {
    NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:[chapters count]];

    // If we are on 10.7, use the AVFoundation path
#if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
        AVAsset *asset = [AVAsset assetWithURL:file];

        if ([asset tracksWithMediaCharacteristic:AVMediaCharacteristicVisual]) {
            AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
            generator.appliesPreferredTrackTransform = YES;
            generator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
            generator.requestedTimeToleranceBefore = kCMTimeZero;
            generator.requestedTimeToleranceAfter  = kCMTimeZero;

            for (SBTextSample * chapter in chapters) {
                CMTime time = CMTimeMake([chapter timestamp] + 1800, 1000);
                CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:NULL];
                if (imgRef) {
                    NSSize size = NSMakeSize(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
                    NSImage *frame = [[NSImage alloc] initWithCGImage:imgRef size:size];

                    [images addObject:frame];
                    [frame release];
                }

                CGImageRelease(imgRef);
            }
        }
#endif

    return [images autorelease];
}

- (BOOL)createChaptersPreview {
    NSInteger decodable = 1;
    MP42ChapterTrack *chapterTrack = nil;
    MP42VideoTrack *refTrack = nil;
    MP4TrackId jpegTrack = 0;

    for (MP42Track *track in _tracks) {
        if ([track isMemberOfClass:[MP42ChapterTrack class]] && !chapterTrack)
            chapterTrack = (MP42ChapterTrack *)track;

        if ([track isMemberOfClass:[MP42VideoTrack class]] &&
            ![track.format isEqualToString:MP42VideoFormatJPEG]
            && !refTrack)
            refTrack = (MP42VideoTrack *)track;

        if ([track.format isEqualToString:MP42VideoFormatJPEG] && !jpegTrack)
            jpegTrack = track.Id;

        if ([track.format isEqualToString:MP42VideoFormatH264])
            if ((((MP42VideoTrack *)track).origProfile) == 110)
                decodable = 0;
    }

    if (!refTrack)
        refTrack = [_tracks objectAtIndex:0];

    if (chapterTrack && !jpegTrack && decodable) {
        @autoreleasepool {
            NSArray *images = nil;

            // If we are on 10.7 or later, use AVFoundation, else QTKit
            if (NSClassFromString(@"AVAsset")) {
                images = [self generatePreviewImagesAVFoundationFromChapters:[chapterTrack chapters] andFile:_fileURL];
            } else {
                images = [self generatePreviewImagesQTKitFromChapters:[chapterTrack chapters] andFile:_fileURL];
            }

            // If we haven't got any images, return.
            if (![images count])
                return NO;

            // Reopen the mp4v2 fileHandle
            _fileHandle = MP4Modify([[_fileURL path] UTF8String], 0);
            if (_fileHandle == MP4_INVALID_FILE_HANDLE)
                return NO;

            CGFloat maxWidth = 640;
            NSSize imageSize = [[images objectAtIndex:0] size];
            if (imageSize.width > maxWidth) {
                imageSize.height = maxWidth / imageSize.width * imageSize.height;
                imageSize.width = maxWidth;
            }
            NSRect rect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);

            jpegTrack = MP4AddJpegVideoTrack(_fileHandle, MP4GetTrackTimeScale(_fileHandle, [chapterTrack Id]),
                                             MP4_INVALID_DURATION, imageSize.width, imageSize.height);

            MP4SetTrackLanguage(_fileHandle, jpegTrack, lang_for_english([refTrack.language UTF8String])->iso639_2);
            MP4SetTrackIntegerProperty(_fileHandle, jpegTrack, "tkhd.layer", 1);
            MP4SetTrackDisabled(_fileHandle, jpegTrack);

            NSUInteger idx = 0;
            MP4Duration duration = 0;

            for (SBTextSample *chapterT in [chapterTrack chapters]) {
                duration = MP4GetSampleDuration(_fileHandle, chapterTrack.Id, idx + 1);

                // Scale the image.
                NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                                   pixelsWide:rect.size.width
                                                                                   pixelsHigh:rect.size.height
                                                                                bitsPerSample:8
                                                                              samplesPerPixel:4
                                                                                     hasAlpha:YES
                                                                                     isPlanar:NO
                                                                               colorSpaceName:NSCalibratedRGBColorSpace
                                                                                 bitmapFormat:NSAlphaFirstBitmapFormat
                                                                                  bytesPerRow:0
                                                                                 bitsPerPixel:32];
                [NSGraphicsContext saveGraphicsState];
                [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];

                [[NSColor blackColor] set];
                NSRectFill(rect);

                if (idx < [images count])
                    [[images objectAtIndex:idx] drawInRect:rect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

                [NSGraphicsContext restoreGraphicsState];

                NSData *data = [bitmap representationUsingType:NSJPEGFileType properties:nil];
                [bitmap release];

                MP4WriteSample(_fileHandle,
                               jpegTrack,
                               [data bytes],
                               [data length],
                               duration,
                               0,
                               true);
                idx++;
            }

            MP4RemoveAllTrackReferences(_fileHandle, "tref.chap", refTrack.Id);
            MP4AddTrackReference(_fileHandle, "tref.chap", chapterTrack.Id, refTrack.Id);
            MP4AddTrackReference(_fileHandle, "tref.chap", jpegTrack, refTrack.Id);
            copyTrackEditLists(_fileHandle, chapterTrack.Id, jpegTrack);

            MP4Close(_fileHandle, 0);
        }

        return YES;
    }
    else if (chapterTrack && jpegTrack) {
        // We already have all the tracks, so hook them up.
        _fileHandle = MP4Modify([[_fileURL path] UTF8String], 0);
        if (_fileHandle == MP4_INVALID_FILE_HANDLE)
            return NO;

        MP4RemoveAllTrackReferences(_fileHandle, "tref.chap", refTrack.Id);
        MP4AddTrackReference(_fileHandle, "tref.chap", chapterTrack.Id, refTrack.Id);
        MP4AddTrackReference(_fileHandle, "tref.chap", jpegTrack, refTrack.Id);
        MP4Close(_fileHandle, 0);
    }

    return NO;
}

@synthesize delegate = _delegate;
@synthesize URL = _fileURL;
@synthesize tracks = _tracks;
@synthesize metadata = _metadata;
@synthesize hasFileRepresentation = _hasFileRepresentation;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt:2 forKey:@"MP42FileVersion"];

#ifdef SB_SANDBOX
    if ([fileURL respondsToSelector:@selector(startAccessingSecurityScopedResource)]) {
            NSData *bookmarkData = nil;
            NSError *error = nil;
            bookmarkData = [fileURL bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope
                             includingResourceValuesForKeys:nil
                                              relativeToURL:nil // Make it app-scoped
                                                      error:&error];
        if (error) {
            NSLog(@"Error creating bookmark for URL (%@): %@", fileURL, error);
        }
        
        [coder encodeObject:bookmarkData forKey:@"bookmark"];

    }
    else {
        [coder encodeObject:fileURL forKey:@"fileUrl"];
    }
#else
    [coder encodeObject:_fileURL forKey:@"fileUrl"];
#endif

    [coder encodeObject:_tracksToBeDeleted forKey:@"tracksToBeDeleted"];
    [coder encodeBool:_hasFileRepresentation forKey:@"hasFileRepresentation"];

    [coder encodeObject:_tracks forKey:@"tracks"];
    [coder encodeObject:_metadata forKey:@"metadata"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    NSData *bookmarkData = [decoder decodeObjectForKey:@"bookmark"];
    if (bookmarkData) {
        BOOL bookmarkDataIsStale;
        NSError *error;
        _fileURL = [[NSURL
                    URLByResolvingBookmarkData:bookmarkData
                    options:NSURLBookmarkResolutionWithSecurityScope
                    relativeToURL:nil
                    bookmarkDataIsStale:&bookmarkDataIsStale
                    error:&error] retain];
    }
    else {
        _fileURL = [[decoder decodeObjectForKey:@"fileUrl"] retain];
    }

    _tracksToBeDeleted = [[decoder decodeObjectForKey:@"tracksToBeDeleted"] retain];

    _hasFileRepresentation = [decoder decodeBoolForKey:@"hasFileRepresentation"];

    _tracks = [[decoder decodeObjectForKey:@"tracks"] retain];
    _metadata = [[decoder decodeObjectForKey:@"metadata"] retain];

    return self;
}

- (void)dealloc
{
    [_fileURL release];
    [_tracks release];
    [_importers release];
    [_tracksToBeDeleted release];
    [_metadata release];

    [super dealloc];
}

@end
