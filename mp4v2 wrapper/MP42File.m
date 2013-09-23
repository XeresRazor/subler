//
//  MP42File.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42File.h"
#import <QTKit/QTKit.h>
#import "SubUtilities.h"
#import "SBLanguages.h"

#if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
#import <AVFoundation/AVFoundation.h>
#endif

#import "MP42FileImporter.h"

NSString * const MP42Create64BitData = @"64BitData";
NSString * const MP42Create64BitTime = @"64BitTime";
NSString * const MP42CreateChaptersPreviewTrack = @"ChaptersPreview";

@interface MP42File (Private)

- (void) removeMuxedTrack: (MP42Track *)track;
- (BOOL) createChaptersPreview;

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

- (id)initWithDelegate:(id)del;
{
    if ((self = [self init])) {
        _delegate = del;
    }

    return self;
}

- (id)initWithExistingFile:(NSURL *)URL andDelegate:(id)del;
{
    if ((self = [super init]))
	{
        _delegate = del;
		_fileHandle = MP4Read([[URL path] UTF8String]);

        if (!_fileHandle) {
            [self release];
			return nil;
        }

        const char* brand = NULL;
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

        _tracksToBeDeleted = [[NSMutableArray alloc] init];
        _metadata = [[MP42Metadata alloc] initWithSourceURL:_fileURL fileHandle:_fileHandle];
        _importers = [[NSMutableDictionary alloc] init];
        MP4Close(_fileHandle, 0);

        _size = [[[[NSFileManager defaultManager] attributesOfItemAtPath:[_fileURL path] error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
	}

	return self;
}

- (NSUInteger)movieDuration
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

- (void)removeTracksAtIndexes:(NSIndexSet *)indexes
{
    NSUInteger index = [indexes firstIndex];
    while (index != NSNotFound) {    
        MP42Track *track = [_tracks objectAtIndex:index];
        if (track.muxed)
            [_tracksToBeDeleted addObject:track];
        index = [indexes indexGreaterThanIndex:index];
    }

    [_tracks removeObjectsAtIndexes:indexes];
}

- (NSUInteger)tracksCount
{
    return [_tracks count];
}

- (id)trackAtIndex:(NSUInteger) index
{
    return [_tracks objectAtIndex:index];
}

- (void)addTrack:(id)object
{
    MP42Track *track = (MP42Track *) object;
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

    if (trackNeedConversion(track.format))
        track.needConversion = YES;

    if (track.muxer_helper->importer) {
        if ([_importers objectForKey:[[track sourceURL] path]])
            [track setTrackImporterHelper:[_importers objectForKey:[[track sourceURL] path]]];
        else
            [_importers setObject:track.muxer_helper->importer forKey:[[track sourceURL] path]];
    }

    [_tracks addObject:track];
}

- (void)removeTrackAtIndex:(NSUInteger) index
{
    MP42Track *track = [_tracks objectAtIndex:index];
    if (track.muxed)
        [_tracksToBeDeleted addObject:track];
    [_tracks removeObjectAtIndex:index];
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

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
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
    [pool release];

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
        char* majorBrand = "mp42";
        char* supportedBrands[4];
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

                if (fileImporter) {
                    [track setTrackImporterHelper:fileImporter];
                }
                else {
                    fileImporter = [[[MP42FileImporter alloc] initWithDelegate:nil andFile:[track sourceURL] error:outError] autorelease];
                    [track setTrackImporterHelper:fileImporter];
                    [_importers setObject:fileImporter forKey:[[track sourceURL] path]];
                }
            }

            // Add the track to the muxer
            if (track.muxer_helper->importer)
                [_muxer addTrack:track];
        }
    }

    noErr = [_muxer setup:_fileHandle error:outError];

    if (!noErr) {
        [_muxer release], _muxer = nil;
        return NO;
    }

    // Start the muxer and wait
    [_muxer work];

    [_muxer release], _muxer = nil;
    [_importers removeAllObjects];

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
    if ([[attributes valueForKey:@"ChaptersPreview"] boolValue])
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

- (uint64_t)estimatedDataLength {
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

    if ([track isMemberOfClass:[MP42SubtitleTrack class]])
        enableFirstSubtitleTrack(_fileHandle);
}

/* Create a set of alternate group the way iTunes and Apple devices want:
   one alternate group for sound, one for subtitles, a disabled photo-jpeg track,
   a disabled chapter track, and a video track with no alternate group */
- (void)iTunesFriendlyTrackGroups
{
    NSInteger firstAudioTrack = 0, firstSubtitleTrack = 0, firstVideoTrack = 0;

    for (MP42Track *track in _tracks) {
        if ([track isMemberOfClass:[MP42ChapterTrack class]])
            track.enabled = NO;
        else if ([track isMemberOfClass:[MP42AudioTrack class]]) {
            if (!firstAudioTrack)
                track.enabled = YES;
            else
                track.enabled = NO;
            
            track.alternate_group = 1;
            firstAudioTrack++;
        }
        else if ([track isMemberOfClass:[MP42SubtitleTrack class]]) {
            if (!firstSubtitleTrack)
                track.enabled = YES;
            else
                track.enabled = NO;
            
            track.alternate_group = 2;
            firstSubtitleTrack++;
        }
        else if ([track isMemberOfClass:[MP42VideoTrack class]]) {
            track.alternate_group = 0;
            if ([track.format isEqualToString:MP42VideoFormatJPEG])
                track.enabled = NO;
            else {
                if (!firstVideoTrack) {
                    track.enabled = YES;
                    firstVideoTrack++;
                }
            }
        }
    }
}

- (BOOL)createChaptersPreview {
    NSError *error;
    NSInteger decodable = 1;
    MP42ChapterTrack * chapterTrack = nil;
    MP4TrackId jpegTrack = 0;

    for (MP42Track *track in _tracks) {
        if ([track isMemberOfClass:[MP42ChapterTrack class]])
            chapterTrack = (MP42ChapterTrack*) track;
        
        if ([track.format isEqualToString:MP42VideoFormatJPEG])
            jpegTrack = track.Id;
        
        if ([track.format isEqualToString:MP42VideoFormatH264])
            if ((((MP42VideoTrack *)track).origProfile) == 110)
                decodable = 0;
    }

    if (chapterTrack && !jpegTrack && decodable) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSMutableArray * previewImages = [NSMutableArray arrayWithCapacity:[chapterTrack chapterCount]];

        // If we are on 10.7, use the AVFoundation path
        if (NSClassFromString(@"AVAsset")) {
            #if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060
            AVAsset *asset = [AVAsset assetWithURL:_fileURL];

            if ([asset tracksWithMediaCharacteristic:AVMediaCharacteristicVisual]) {
                AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
                generator.appliesPreferredTrackTransform = YES;
                generator.apertureMode = AVAssetImageGeneratorApertureModeCleanAperture;
                generator.requestedTimeToleranceBefore = kCMTimeZero;
                generator.requestedTimeToleranceAfter  = kCMTimeZero;

                for (SBTextSample * chapter in [chapterTrack chapters]) {
                    CMTime time = CMTimeMake([chapter timestamp] + 1800, 1000);
                    CGImageRef imgRef = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
                    if (imgRef) {
                        NSSize size = NSMakeSize(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
                        NSImage *previewImage = [[NSImage alloc] initWithCGImage:imgRef size:size];

                        [previewImages addObject:previewImage];
                        [previewImage release];
                    }

                    CGImageRelease(imgRef);
                }
            }
            #endif
        }
        // Else fall back to QTKit
        else {
            __block QTMovie * qtMovie;
            // QTMovie objects must always be create on the main thread.
            NSDictionary *movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 _fileURL, QTMovieURLAttribute,
                                                 [NSNumber numberWithBool:NO], QTMovieAskUnresolvedDataRefsAttribute,
                                                 [NSNumber numberWithBool:YES], @"QTMovieOpenForPlaybackAttribute",
                                                 [NSNumber numberWithBool:NO], @"QTMovieOpenAsyncRequiredAttribute",
                                                 [NSNumber numberWithBool:NO], @"QTMovieOpenAsyncOKAttribute",
                                                 QTMovieApertureModeClean, QTMovieApertureModeAttribute,
                                                 nil];
            if (dispatch_get_current_queue() != dispatch_get_main_queue()) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    qtMovie = [[QTMovie alloc] initWithAttributes:movieAttributes error:nil];
                });
            }
            else
                qtMovie = [[QTMovie alloc] initWithAttributes:movieAttributes error:nil];


            if (!qtMovie)
                return NO;

            for (QTTrack* qtTrack in [qtMovie tracksOfMediaType:@"sbtl"])
                [qtTrack setAttribute:[NSNumber numberWithBool:NO] forKey:QTTrackEnabledAttribute];

            NSDictionary *attributes = [NSDictionary dictionaryWithObject:QTMovieFrameImageTypeNSImage forKey:QTMovieFrameImageType];

            for (SBTextSample * chapter in [chapterTrack chapters]) {
                QTTime chapterTime = {
                    [chapter timestamp] + 1500, // Add a short offset, hopefully we will get a better image
                    1000,                       // if there is a fade
                    0
                };

                NSImage *previewImage = [qtMovie frameImageAtTime:chapterTime withAttributes:attributes error:&error];

                if (previewImage)
                    [previewImages addObject:previewImage];
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
        }
        // If we haven't got enought images, return.
        if (([previewImages count] < [[chapterTrack chapters] count]) || [previewImages count] == 0 ) {
            [pool release];
            return NO;
        }

        // Reopen the mp4v2 fileHandle
        _fileHandle = MP4Modify([[_fileURL path] UTF8String], 0);
        if (_fileHandle == MP4_INVALID_FILE_HANDLE)
            return NO;

        MP4TrackId refTrack = findFirstVideoTrack(_fileHandle);
        if (!refTrack)
            refTrack = 1;

        CGFloat maxWidth = 640;
        NSSize imageSize = [[previewImages objectAtIndex:0] size];
        if (imageSize.width > maxWidth) {
            imageSize.height = maxWidth / imageSize.width * imageSize.height;
            imageSize.width = maxWidth;
        }

        jpegTrack = MP4AddJpegVideoTrack(_fileHandle, MP4GetTrackTimeScale(_fileHandle, [chapterTrack Id]),
                                          MP4_INVALID_DURATION, imageSize.width, imageSize.height);

        NSString *language = @"Unknown";
        for (MP42Track *track in _tracks)
            if ([track isMemberOfClass:[MP42VideoTrack class]])
                language = ((MP42VideoTrack*) track).language;

        MP4SetTrackLanguage(_fileHandle, jpegTrack, lang_for_english([language UTF8String])->iso639_2);

        MP4SetTrackIntegerProperty(_fileHandle, jpegTrack, "tkhd.layer", 1);
        disableTrack(_fileHandle, jpegTrack);

        NSInteger i = 0;
        MP4Duration duration = 0;

        for (SBTextSample *chapterT in [chapterTrack chapters]) {
            duration = MP4GetSampleDuration(_fileHandle, [chapterTrack Id], i+1);

            // Scale the image.
            NSRect newRect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
            NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                               pixelsWide:newRect.size.width
                                                                               pixelsHigh:newRect.size.height
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

            [[previewImages objectAtIndex:0] drawInRect:newRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];

            [NSGraphicsContext restoreGraphicsState];

            NSData * jpegData = [bitmap representationUsingType:NSJPEGFileType properties:nil];
            [bitmap release];

            i++;
            MP4WriteSample(_fileHandle,
                           jpegTrack,
                           [jpegData bytes],
                           [jpegData length],
                           duration,
                           0,
                           true);

            [previewImages removeObjectAtIndex:0];
        }

        MP4RemoveAllTrackReferences(_fileHandle, "tref.chap", refTrack);
        MP4AddTrackReference(_fileHandle, "tref.chap", [chapterTrack Id], refTrack);
        MP4AddTrackReference(_fileHandle, "tref.chap", jpegTrack, refTrack);
        copyTrackEditLists(_fileHandle, [chapterTrack Id], jpegTrack);

        MP4Close(_fileHandle, 0);

        [pool release];
        return YES;
    }
    else if (chapterTrack && jpegTrack) {
        // We already have all the tracks, so hook them up.
        _fileHandle = MP4Modify([[_fileURL path] UTF8String], 0);
        if (_fileHandle == MP4_INVALID_FILE_HANDLE)
            return NO;

        MP4TrackId refTrack = findFirstVideoTrack(_fileHandle);
        if (!refTrack)
            refTrack = 1;

        MP4RemoveAllTrackReferences(_fileHandle, "tref.chap", refTrack);
        MP4AddTrackReference(_fileHandle, "tref.chap", [chapterTrack Id], refTrack);
        MP4AddTrackReference(_fileHandle, "tref.chap", jpegTrack, refTrack);
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
