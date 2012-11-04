//
//  MP42MkvFileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#if __MAC_OS_X_VERSION_MAX_ALLOWED > 1060

#import "MP42AVFImporter.h"
#import "SBLanguages.h"
#import "MP42File.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AVFTrackHelper : NSObject {
@public
    CMTime              currentTime;
    AVAssetReaderOutput *assetReaderOutput;
    int64_t             minDisplayOffset;
}
@end

@implementation AVFTrackHelper

-(id)init
{
    if ((self = [super init])) {
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}
@end

@implementation MP42AVFImporter

- (NSString*)formatForTrack: (AVAssetTrack *)track;
{
    NSString* result = @"";
    
    CMFormatDescriptionRef formatDescription = NULL;
    NSArray *formatDescriptions = track.formatDescriptions;
    if ([formatDescriptions count] > 0)
        formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];
    
    if (formatDescription) {
        FourCharCode code = CMFormatDescriptionGetMediaSubType(formatDescription);
        switch (code) {
            case kCMVideoCodecType_H264:
                result = @"H.264";
                break;
            case kCMVideoCodecType_MPEG4Video:
                result = @"MPEG-4 Visual";
                break;
            case kCMVideoCodecType_MPEG2Video:
                result = @"MPEG-2";
                break;
            case kCMVideoCodecType_MPEG1Video:
                result = @"MPEG-1";
                break;
            case kCMVideoCodecType_AppleProRes422:
            case kCMVideoCodecType_AppleProRes422HQ:
            case kCMVideoCodecType_AppleProRes422LT:
            case kCMVideoCodecType_AppleProRes422Proxy:
            case kCMVideoCodecType_AppleProRes4444:
                result = @"Apple ProRes";
                break;
            case kCMVideoCodecType_SorensonVideo3:
                result = @"Sorenson 3";
                break;
            case 'png ':
                result = @"PNG";
                break;
            case kAudioFormatMPEG4AAC:
                result = @"AAC";
                break;
            case kAudioFormatMPEG4AAC_HE:
            case kAudioFormatMPEG4AAC_HE_V2:
                result = @"HE-AAC";
                break;
            case kAudioFormatLinearPCM:
                result = @"PCM";
                break;
            case kAudioFormatAppleLossless:
                result = @"ALAC";
                break;
            case kAudioFormatAC3:
            case 'ms \0':
                result = @"AC-3";
                break;
            case kAudioFormatMPEGLayer1:
            case kAudioFormatMPEGLayer2:
            case kAudioFormatMPEGLayer3:
                result = @"MP3";
                break;
            case kAudioFormatAMR:
                result = @"AMR Narrow Band";
                break;
            case kAudioFormatAppleIMA4:
                result = @"IMA 4:1";
                break;
            case kCMTextFormatType_QTText:
                result = @"Text";
                break;
            case kCMTextFormatType_3GText:
                result = @"3GPP Text";
                break;
            case 'SRT ':
                result = @"Text";
                break;
            case 'SSA ':
                result = @"SSA";
                break;
            case kCMClosedCaptionFormatType_CEA608:
                result = @"CEA-608";
                break;
            case kCMClosedCaptionFormatType_CEA708:
                result = @"CEA-708";
                break;
            case kCMClosedCaptionFormatType_ATSC:
                result = @"ATSC/52 part-4";
                break;
            case kCMTimeCodeFormatType_TimeCode32:
            case kCMTimeCodeFormatType_TimeCode64:
            case kCMTimeCodeFormatType_Counter32:
            case kCMTimeCodeFormatType_Counter64:
                result = @"Timecode";
                break;
            case kCMVideoCodecType_JPEG:
                result = @"Photo - JPEG";
                break;
            case kCMVideoCodecType_DVCNTSC:
            case kCMVideoCodecType_DVCPAL:
                result = @"DV";
                break;
            case kCMVideoCodecType_DVCProPAL:
            case kCMVideoCodecType_DVCPro50NTSC:
            case kCMVideoCodecType_DVCPro50PAL:
                result = @"DVCPro";
                break;
            case kCMVideoCodecType_DVCPROHD720p60:
            case kCMVideoCodecType_DVCPROHD720p50:
            case kCMVideoCodecType_DVCPROHD1080i60:
            case kCMVideoCodecType_DVCPROHD1080i50:
            case kCMVideoCodecType_DVCPROHD1080p30:
            case kCMVideoCodecType_DVCPROHD1080p25:
                result = @"DVCProHD";
                break;
            default:
                result = @"Unknown";
                break;
        }
    }
    return result;
}

- (NSString*)langForTrack: (AVAssetTrack *)track
{
    return [NSString stringWithUTF8String:lang_for_qtcode([[track languageCode] integerValue])->eng_name];
}

- (id)initWithDelegate:(id)del andFile:(NSURL *)URL error:(NSError **)outError
{
    if ((self = [super init])) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        delegate = del;
        fileURL = [URL retain];

        localAsset = [[AVAsset assetWithURL:fileURL] retain];

        tracksArray = [[NSMutableArray alloc] init];
        NSArray *tracks = [localAsset tracks];

        NSArray *availableChapter = [localAsset availableChapterLocales];
        MP42ChapterTrack *chapters = nil;

        for (NSLocale *locale in availableChapter) {
            chapters = [[MP42ChapterTrack alloc] init];
            NSArray *chapterList = [localAsset chapterMetadataGroupsWithTitleLocale:locale containingItemsWithCommonKeys:nil];
            for (AVTimedMetadataGroup* chapterData in chapterList) {
                for (AVMetadataItem *item in [chapterData items]) {
                    CMTime time = [item time];
                    [chapters addChapter:[item stringValue] duration:time.value * time.timescale / 1000];
                }
            }
        }

        for (AVAssetTrack *track in tracks) {
            MP42Track *newTrack = nil;

            CMFormatDescriptionRef formatDescription = NULL;
            NSArray *formatDescriptions = track.formatDescriptions;
			if ([formatDescriptions count] > 0)
				formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];

            NSArray *trackMetadata = [track metadataForFormat:AVMetadataFormatQuickTimeUserData];

            if ([[track mediaType] isEqualToString:AVMediaTypeVideo]) {
                newTrack = [[MP42VideoTrack alloc] init];
                CGSize naturalSize = [track naturalSize];

                [(MP42VideoTrack*)newTrack setTrackWidth: naturalSize.width];
                [(MP42VideoTrack*)newTrack setTrackHeight: naturalSize.height];

                [(MP42VideoTrack*)newTrack setWidth: naturalSize.width];
                [(MP42VideoTrack*)newTrack setHeight: naturalSize.height];

                if (formatDescription) {
                    CFDictionaryRef pixelAspectRatioFromCMFormatDescription = CMFormatDescriptionGetExtension(formatDescription, kCMFormatDescriptionExtension_PixelAspectRatio);
                    if (pixelAspectRatioFromCMFormatDescription)
                    {
                        NSInteger hSpacing, vSpacing;
                        CFNumberGetValue(CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing), kCFNumberIntType, &hSpacing);
                        CFNumberGetValue(CFDictionaryGetValue(pixelAspectRatioFromCMFormatDescription, kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing), kCFNumberIntType, &vSpacing);
                        [(MP42VideoTrack*)newTrack setHSpacing:hSpacing];
                        [(MP42VideoTrack*)newTrack setVSpacing:vSpacing];
                    }
                }
            }
            else if ([[track mediaType] isEqualToString:AVMediaTypeAudio]) {
                newTrack = [[MP42AudioTrack alloc] init];

                if (formatDescription) {
                    size_t layoutSize = 0;
                    const AudioChannelLayout *layout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &layoutSize);

                    if (layoutSize) {
                        [(MP42AudioTrack*)newTrack setChannels: AudioChannelLayoutTag_GetNumberOfChannels(layout->mChannelLayoutTag)];
                        [(MP42AudioTrack*)newTrack setChannelLayoutTag: layout->mChannelLayoutTag];
                    }
                    else
                        [(MP42AudioTrack*)newTrack setChannels: 1];
                }
            }
            else if ([[track mediaType] isEqualToString:AVMediaTypeSubtitle]) {
                newTrack = [[MP42SubtitleTrack alloc] init];
            }
            else if ([[track mediaType] isEqualToString:AVMediaTypeText]) {
                // It looks like there is no way to know what text track is used for chapters in the original file.
                if (chapters)
                    newTrack = chapters;
                else
                    newTrack = [[MP42ChapterTrack alloc] init];
            }
            else {
                newTrack = [[MP42Track alloc] init];
            }

            newTrack.format = [self formatForTrack:track];
            newTrack.sourceFormat = newTrack.format;
            newTrack.Id = [track trackID];
            newTrack.sourceURL = fileURL;
            newTrack.sourceFileHandle = localAsset;
            newTrack.dataLength = [track totalSampleDataLength];

            // "name" is undefinited in AVMetadataFormat.h, so read the official track name "tnam", and then "name". On 10.7, "name" is returned as an NSData
            id trackName = [[[AVMetadataItem metadataItemsFromArray:trackMetadata withKey:AVMetadataQuickTimeUserDataKeyTrackName keySpace:nil] lastObject] value];
            id trackName_oldFormat = [[[AVMetadataItem metadataItemsFromArray:trackMetadata withKey:@"name" keySpace:nil] lastObject] value];
            if (trackName && [trackName isKindOfClass:[NSString class]])
                newTrack.name = trackName;
            else if (trackName_oldFormat && [trackName_oldFormat isKindOfClass:[NSString class]])
                newTrack.name = trackName_oldFormat;
            else if (trackName_oldFormat && [trackName_oldFormat isKindOfClass:[NSData class]])
                newTrack.name = [NSString stringWithCString:[trackName_oldFormat bytes] encoding:NSMacOSRomanStringEncoding];

            newTrack.language = [self langForTrack:track];

            CMTimeRange timeRange = [track timeRange];
            newTrack.duration = timeRange.duration.value / timeRange.duration.timescale * 1000;

            [tracksArray addObject:newTrack];
            [newTrack release];
        }
        
        [self convertMetadata];

        [pool release];
    }

    return self;
}

-(MP42Metadata*)convertMetadata
{
    NSArray *items = nil;
    NSDictionary *commonItemsDict = [NSDictionary dictionaryWithObjectsAndKeys:@"Name", AVMetadataCommonKeyTitle,
                                     //nil, AVMetadataCommonKeyCreator,
                                     //nil, AVMetadataCommonKeySubject,
                                     @"Description", AVMetadataCommonKeyDescription,
                                     @"Publisher", AVMetadataCommonKeyPublisher,
                                     //nil, AVMetadataCommonKeyContributor,
                                     @"Release Date", AVMetadataCommonKeyCreationDate,
                                     //nil, AVMetadataCommonKeyLastModifiedDate,
                                     @"Genre", AVMetadataCommonKeyType,
                                     //nil, AVMetadataCommonKeyFormat,
                                     //nil, AVMetadataCommonKeyIdentifier,
                                     //nil, AVMetadataCommonKeySource,
                                     //nil, AVMetadataCommonKeyLanguage,
                                     //nil, AVMetadataCommonKeyRelation,
                                     //nil, AVMetadataCommonKeyLocation,
                                     @"Copyright", AVMetadataCommonKeyCopyrights,
                                     @"Album", AVMetadataCommonKeyAlbumName,
                                     //nil, AVMetadataCommonKeyAuthor,
                                     //nil, AVMetadataCommonKeyArtwork
                                     @"Artist", AVMetadataCommonKeyArtist,
                                     //nil, AVMetadataCommonKeyMake,
                                     //nil, AVMetadataCommonKeyModel,
                                     @"Encoding Tool", AVMetadataCommonKeySoftware,
                                     nil];

    metadata = [[MP42Metadata alloc] init];

    for (NSString *commonKey in [commonItemsDict allKeys]) {
        items = [AVMetadataItem metadataItemsFromArray:localAsset.commonMetadata withKey:commonKey keySpace:AVMetadataKeySpaceCommon];
        if ([items count])
            [metadata setTag:[[items lastObject] stringValue] forKey:[commonItemsDict objectForKey:commonKey]];
    }
    
    items = [AVMetadataItem metadataItemsFromArray:localAsset.commonMetadata withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
    if ([items count]) {
        id artworkData = [[items lastObject] value];
        if ([artworkData isKindOfClass:[NSData class]]) {
            NSImage *image = [[NSImage alloc] initWithData:artworkData];
            [metadata setArtwork:image];
            [image release];
        }
    }

    NSArray* availableMetadataFormats = [localAsset availableMetadataFormats];

    if ([availableMetadataFormats containsObject:AVMetadataFormatiTunesMetadata]) {
        NSArray* itunesMetadata = [localAsset metadataForFormat:AVMetadataFormatiTunesMetadata];
        
        NSDictionary *itunesMetadataDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                            @"Album",               AVMetadataiTunesMetadataKeyAlbum,
                                            @"Artist",              AVMetadataiTunesMetadataKeyArtist,
                                            @"Comments",            AVMetadataiTunesMetadataKeyUserComment,
                                            //AVMetadataiTunesMetadataKeyCoverArt,
                                            @"Copyright",           AVMetadataiTunesMetadataKeyCopyright,
                                            @"Release Date",        AVMetadataiTunesMetadataKeyReleaseDate,
                                            @"Encoded By",          AVMetadataiTunesMetadataKeyEncodedBy,
                                            //AVMetadataiTunesMetadataKeyPredefinedGenre,
                                            @"Genre",               AVMetadataiTunesMetadataKeyUserGenre,
                                            @"Name",                AVMetadataiTunesMetadataKeySongName,
                                            @"Track Sub-Title",     AVMetadataiTunesMetadataKeyTrackSubTitle,
                                            @"Encoding Tool",       AVMetadataiTunesMetadataKeyEncodingTool,
                                            @"Composer",            AVMetadataiTunesMetadataKeyComposer,
                                            @"Album Artist",        AVMetadataiTunesMetadataKeyAlbumArtist,
                                            @"iTunes Account Type", AVMetadataiTunesMetadataKeyAccountKind,
                                            @"iTunes Account",      AVMetadataiTunesMetadataKeyAppleID,
                                            @"artistID",            AVMetadataiTunesMetadataKeyArtistID,
                                            @"content ID",          AVMetadataiTunesMetadataKeySongID,
                                            @"Compilation",         AVMetadataiTunesMetadataKeyDiscCompilation,
                                            @"Disk #",              AVMetadataiTunesMetadataKeyDiscNumber,
                                            @"genreID",             AVMetadataiTunesMetadataKeyGenreID,
                                            @"Grouping",            AVMetadataiTunesMetadataKeyGrouping,
                                            @"playlistID",          AVMetadataiTunesMetadataKeyPlaylistID,
                                            @"Content Rating",      AVMetadataiTunesMetadataKeyContentRating,
                                            @"Rating",              @"com.apple.iTunes.iTunEXTC",
                                            @"Tempo",               AVMetadataiTunesMetadataKeyBeatsPerMin,
                                            @"Track #",             AVMetadataiTunesMetadataKeyTrackNumber,
                                            @"Art Director",        AVMetadataiTunesMetadataKeyArtDirector,
                                            @"Arranger",            AVMetadataiTunesMetadataKeyArranger,
                                            @"Lyricist",            AVMetadataiTunesMetadataKeyAuthor,
                                            @"Lyrics",              AVMetadataiTunesMetadataKeyLyrics,
                                            @"Acknowledgement",     AVMetadataiTunesMetadataKeyAcknowledgement,
                                            @"Conductor",           AVMetadataiTunesMetadataKeyConductor,
                                            @"Song Description",    AVMetadataiTunesMetadataKeyDescription,
                                            @"Description",         @"desc",
                                            @"Long Description",    @"ldes",
                                            @"Media Kind",          @"stik",
                                            @"TV Show",             @"tvsh",
                                            @"TV Episode #",        @"tves",
                                            @"TV Network",          @"tvnn",
                                            @"TV Episode ID",       @"tven",
                                            @"TV Season",           @"tvsn",
                                            @"HD Video",            @"hdvd",
                                            @"Gapless",             @"pgap",
                                            @"Sort Name",           @"sonm",
                                            @"Sort Artist",         @"soar",
                                            @"Sort Album Artist",   @"soaa",
                                            @"Sort Album",          @"soal",
                                            @"Sort Composer",       @"soco",
                                            @"Sort TV Show",        @"sosn",
                                            @"Category",            @"catg",
                                            @"iTunes U",            @"itnu",
                                            @"Purchase Date",       @"purd",
                                            @"Director",            AVMetadataiTunesMetadataKeyDirector,
                                            //AVMetadataiTunesMetadataKeyEQ,
                                            @"Linear Notes",        AVMetadataiTunesMetadataKeyLinerNotes,
                                            @"Record Company",      AVMetadataiTunesMetadataKeyRecordCompany,
                                            @"Original Artist",     AVMetadataiTunesMetadataKeyOriginalArtist,
                                            @"Phonogram Rights",    AVMetadataiTunesMetadataKeyPhonogramRights,
                                            @"Producer",            AVMetadataiTunesMetadataKeyProducer,
                                            @"Performer",           AVMetadataiTunesMetadataKeyPerformer,
                                            @"Publisher",           AVMetadataiTunesMetadataKeyPublisher,
                                            @"Sound Engineer",      AVMetadataiTunesMetadataKeySoundEngineer,
                                            @"Soloist",             AVMetadataiTunesMetadataKeySoloist,
                                            @"Credits",             AVMetadataiTunesMetadataKeyCredits,
                                            @"Thanks",              AVMetadataiTunesMetadataKeyThanks,
                                            @"Online Extras",       AVMetadataiTunesMetadataKeyOnlineExtras,
                                            @"Executive Producer",  AVMetadataiTunesMetadataKeyExecProducer,
                                            nil];

        for (NSString *itunesKey in [itunesMetadataDict allKeys]) {
            items = [AVMetadataItem metadataItemsFromArray:itunesMetadata withKey:itunesKey keySpace:AVMetadataKeySpaceiTunes];
            if ([items count]) {
                [metadata setTag:[[items lastObject] value] forKey:[itunesMetadataDict objectForKey:itunesKey]];
            }
        }

        items = [AVMetadataItem metadataItemsFromArray:itunesMetadata withKey:AVMetadataiTunesMetadataKeyCoverArt keySpace:AVMetadataKeySpaceiTunes];
        if ([items count]) {
            id artworkData = [[items lastObject] value];
            if ([artworkData isKindOfClass:[NSData class]]) {
                NSImage *image = [[NSImage alloc] initWithData:artworkData];
                [metadata setArtwork:image];
                [image release];
            }
        }
    }
    if ([availableMetadataFormats containsObject:AVMetadataFormatQuickTimeMetadata]) {
        NSArray* quicktimeMetadata = [localAsset metadataForFormat:AVMetadataFormatQuickTimeMetadata];
        
        NSDictionary *quicktimeMetadataDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                               @"Arist",        AVMetadataQuickTimeMetadataKeyAuthor,
                                               @"Comments",     AVMetadataQuickTimeMetadataKeyComment,
                                               @"Copyright",    AVMetadataQuickTimeMetadataKeyCopyright,
                                               @"Release Date", AVMetadataQuickTimeMetadataKeyCreationDate,
                                               @"Director",     AVMetadataQuickTimeMetadataKeyDirector,
                                               @"Name",         AVMetadataQuickTimeMetadataKeyDisplayName,
                                               @"Description",  AVMetadataQuickTimeMetadataKeyInformation,
                                               @"Keyworkds",    AVMetadataQuickTimeMetadataKeyKeywords,
                                               @"Producer",     AVMetadataQuickTimeMetadataKeyProducer,
                                               @"Publisher",    AVMetadataQuickTimeMetadataKeyPublisher,
                                               @"Album",        AVMetadataQuickTimeMetadataKeyAlbum,
                                               @"Artist",       AVMetadataQuickTimeMetadataKeyArtist,
                                               @"Description",  AVMetadataQuickTimeMetadataKeyDescription,
                                               @"Encoding Tool",AVMetadataQuickTimeMetadataKeySoftware,
                                               @"Genre",        AVMetadataQuickTimeMetadataKeyGenre,
                                               //AVMetadataQuickTimeMetadataKeyiXML,
                                               @"Arranger",     AVMetadataQuickTimeMetadataKeyArranger,
                                               @"Encoded By",   AVMetadataQuickTimeMetadataKeyEncodedBy,
                                               @"Original Artist",  AVMetadataQuickTimeMetadataKeyOriginalArtist,
                                               @"Performer",    AVMetadataQuickTimeMetadataKeyPerformer,
                                               @"Composer",     AVMetadataQuickTimeMetadataKeyComposer,
                                               @"Credits",      AVMetadataQuickTimeMetadataKeyCredits,
                                               @"Phonogram Rights", AVMetadataQuickTimeMetadataKeyPhonogramRights,
                                               @"Name",         AVMetadataQuickTimeMetadataKeyTitle, nil];
        
        for (NSString *qtKey in [quicktimeMetadataDict allKeys]) {
            items = [AVMetadataItem metadataItemsFromArray:quicktimeMetadata withKey:qtKey keySpace:AVMetadataKeySpaceQuickTimeUserData];
            if ([items count]) {
                [metadata setTag:[[items lastObject] value] forKey:[quicktimeMetadataDict objectForKey:qtKey]];
            }
        }
    }
    if ([availableMetadataFormats containsObject:AVMetadataFormatQuickTimeUserData]) {
        NSArray* quicktimeUserDataMetadata = [localAsset metadataForFormat:AVMetadataFormatQuickTimeUserData];
        
        NSDictionary *quicktimeUserDataMetadataDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                       @"Album",                AVMetadataQuickTimeUserDataKeyAlbum,
                                                       @"Arranger",             AVMetadataQuickTimeUserDataKeyArranger,
                                                       @"Artist",               AVMetadataQuickTimeUserDataKeyArtist,
                                                       @"Lyricist",             AVMetadataQuickTimeUserDataKeyAuthor,
                                                       @"Comments",             AVMetadataQuickTimeUserDataKeyComment,
                                                       @"Composer",             AVMetadataQuickTimeUserDataKeyComposer,
                                                       @"Copyright",            AVMetadataQuickTimeUserDataKeyCopyright,
                                                       @"Release Date",         AVMetadataQuickTimeUserDataKeyCreationDate,
                                                       @"Description",          AVMetadataQuickTimeUserDataKeyDescription,
                                                       @"Director",             AVMetadataQuickTimeUserDataKeyDirector,
                                                       @"Encoded By",           AVMetadataQuickTimeUserDataKeyEncodedBy,
                                                       @"Name",                 AVMetadataQuickTimeUserDataKeyFullName,
                                                       @"Genre",                AVMetadataQuickTimeUserDataKeyGenre,
                                                       @"Keywords",             AVMetadataQuickTimeUserDataKeyKeywords,
                                                       @"Original Artist",      AVMetadataQuickTimeUserDataKeyOriginalArtist,
                                                       @"Performer",            AVMetadataQuickTimeUserDataKeyPerformers,
                                                       @"Producer",             AVMetadataQuickTimeUserDataKeyProducer,
                                                       @"Publisher",            AVMetadataQuickTimeUserDataKeyPublisher,
                                                       @"Online Extras",        AVMetadataQuickTimeUserDataKeyURLLink,
                                                       @"Credits",              AVMetadataQuickTimeUserDataKeyCredits,
                                                       @"Phonogram Rights",     AVMetadataQuickTimeUserDataKeyPhonogramRights, nil];

        for (NSString *qtUserDataKey in [quicktimeUserDataMetadataDict allKeys]) {
            items = [AVMetadataItem metadataItemsFromArray:quicktimeUserDataMetadata withKey:qtUserDataKey keySpace:AVMetadataKeySpaceQuickTimeUserData];
            if ([items count]) {
                [metadata setTag:[[items lastObject] value] forKey:[quicktimeUserDataMetadataDict objectForKey:qtUserDataKey]];
            }
        }
    }

    return metadata;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    AVAssetTrack *assetTrack = [localAsset trackWithTrackID:[track sourceId]];
    
    CMFormatDescriptionRef formatDescription = NULL;
    NSArray *formatDescriptions = assetTrack.formatDescriptions;
    if ([formatDescriptions count] > 0)
        formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];
        if ([[assetTrack mediaType] isEqualToString:AVMediaTypeAudio]) {
            const AudioStreamBasicDescription* const asbd =
            CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);

            double sampleRate = asbd->mSampleRate;

            return (NSUInteger)sampleRate;
    }

    return [assetTrack naturalTimeScale];
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
    MP42VideoTrack* currentTrack = (MP42VideoTrack*) track;

    return NSMakeSize([currentTrack width], [currentTrack height]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    AVAssetTrack *assetTrack = [localAsset trackWithTrackID:[track sourceId]];

    CMFormatDescriptionRef formatDescription = NULL;
    NSArray *formatDescriptions = assetTrack.formatDescriptions;
    if ([formatDescriptions count] > 0)
        formatDescription = (CMFormatDescriptionRef)[formatDescriptions objectAtIndex:0];

    if (formatDescription) {
        FourCharCode code = CMFormatDescriptionGetMediaSubType(formatDescription);
        if ([[assetTrack mediaType] isEqualToString:AVMediaTypeVideo]) {
            CFDictionaryRef extentions = CMFormatDescriptionGetExtensions(formatDescription);
            CFDictionaryRef atoms = CFDictionaryGetValue(extentions, kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms);
            CFDataRef magicCookie = NULL;

            if (code == kCMVideoCodecType_H264) 
                magicCookie = CFDictionaryGetValue(atoms, @"avcC");
            else if (code == kCMVideoCodecType_MPEG4Video)
                magicCookie = CFDictionaryGetValue(atoms, @"esds");

            return (NSData*)magicCookie;
        }
        else if ([[assetTrack mediaType] isEqualToString:AVMediaTypeAudio]) {

            size_t cookieSizeOut;
            const void *magicCookie = CMAudioFormatDescriptionGetMagicCookie(formatDescription, &cookieSizeOut);

            if (code == kAudioFormatMPEG4AAC || code == kAudioFormatMPEG4AAC_HE || code == kAudioFormatMPEG4AAC_HE_V2) {
                // Extract DecoderSpecific info
                UInt8* buffer;
                int size;
                ReadESDSDescExt((void*)magicCookie, &buffer, &size, 0);

                return [NSData dataWithBytes:buffer length:size];
            }
            else if (code == kAudioFormatAppleLossless) {
                if (cookieSizeOut > 48) {
                    // Remove unneeded parts of the cookie, as describred in ALACMagicCookieDescription.txt
                    magicCookie += 24;
                    cookieSizeOut = cookieSizeOut - 24 - 8;
                }

                return [NSData dataWithBytes:magicCookie length:cookieSizeOut];
            }
            else if (code == kAudioFormatAC3) {
                OSStatus err = noErr;
                size_t channelLayoutSize = 0;
                const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
                const AudioChannelLayout* channelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &channelLayoutSize);

                UInt32 bitmapSize = sizeof(UInt32);
                UInt32 channelBitmap;
                err = AudioFormatGetProperty(kAudioFormatProperty_BitmapForLayoutTag,
                                               sizeof(AudioChannelLayoutTag), &channelLayout->mChannelLayoutTag,
                                               &bitmapSize, &channelBitmap);
                if (err && AudioChannelLayoutTag_GetNumberOfChannels(channelLayout->mChannelLayoutTag) == 6)
                    channelBitmap = 0x3F;

                uint8_t fscod = 0;
                uint8_t bsid = 8;
                uint8_t bsmod = 0;
                uint8_t acmod = 7;
                uint8_t lfeon = (channelBitmap & kAudioChannelBit_LFEScreen) ? 1 : 0;
                uint8_t bit_rate_code = 15;

                switch (AudioChannelLayoutTag_GetNumberOfChannels(channelLayout->mChannelLayoutTag) - lfeon) {
                    case 1:
                        acmod = 1;
                        break;
                    case 2:
                        acmod = 2;
                        break;
                    case 3:
                        if (channelBitmap & kAudioChannelBit_CenterSurround) acmod = 3;
                        else acmod = 4;
                        break;
                    case 4:
                        if (channelBitmap & kAudioChannelBit_CenterSurround) acmod = 5;
                        else acmod = 6;
                        break;
                    case 5:
                        acmod = 7;
                        break;
                    default:
                        break;
                }

                if (asbd->mSampleRate == 48000) fscod = 0;
                else if (asbd->mSampleRate == 44100) fscod = 1;
                else if (asbd->mSampleRate == 32000) fscod = 2;
                else fscod = 3;

                NSMutableData *ac3Info = [[NSMutableData alloc] init];
                [ac3Info appendBytes:&fscod length:sizeof(uint64_t)];
                [ac3Info appendBytes:&bsid length:sizeof(uint64_t)];
                [ac3Info appendBytes:&bsmod length:sizeof(uint64_t)];
                [ac3Info appendBytes:&acmod length:sizeof(uint64_t)];
                [ac3Info appendBytes:&lfeon length:sizeof(uint64_t)];
                [ac3Info appendBytes:&bit_rate_code length:sizeof(uint64_t)];

                return [ac3Info autorelease];

            }
            else if (cookieSizeOut)
                return [NSData dataWithBytes:magicCookie length:cookieSizeOut];
        }
    }
    return nil;
}

- (void) fillMovieSampleBuffer: (id)sender
{
	BOOL success = YES;
    OSStatus err = noErr;

    uint64_t currentDataLength = 0;
    uint64_t totalDataLength = 0;

    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    AVFTrackHelper * trackHelper=nil;
    NSError *localError;
    AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:localAsset error:&localError];

	success = (assetReader != nil);
	if (success) {
        for (MP42Track * track in activeTracks) {
            AVAssetReaderOutput *assetReaderOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[localAsset trackWithTrackID:track.sourceId] outputSettings:nil];
            if (! [assetReader canAddOutput: assetReaderOutput])
                NSLog(@"Unable to add the output to assetReader!");

            [assetReader addOutput:assetReaderOutput];

            track.trackDemuxerHelper = [[AVFTrackHelper alloc] init];
            trackHelper = track.trackDemuxerHelper;
            trackHelper->assetReaderOutput = assetReaderOutput;

            totalDataLength += [track dataLength];
        }
    }

    success = [assetReader startReading];
	if (!success)
		localError = [assetReader error];

    for (MP42Track * track in activeTracks) {
        AVAssetReaderOutput *assetReaderOutput = ((AVFTrackHelper*)track.trackDemuxerHelper)->assetReaderOutput;
        while (!isCancelled) {
            while ([samplesBuffer count] >= 300) {
                usleep(200);
            }

            CMSampleBufferRef sampleBuffer = [assetReaderOutput copyNextSampleBuffer];
            if (sampleBuffer) {
                CMItemCount samplesNum = CMSampleBufferGetNumSamples(sampleBuffer);
                if (samplesNum == 1) {
                    // We have only a sample
                    CMTime duration = CMSampleBufferGetDuration(sampleBuffer);
                    CMTime decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer);
                    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

                    CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                    size_t sampleSize = CMBlockBufferGetDataLength(buffer);
                    void *sampleData = malloc(sampleSize);
                    CMBlockBufferCopyDataBytes(buffer, 0, sampleSize, sampleData);

                    BOOL sync = 1;
                    CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, NO);
                    if (attachmentsArray) {
                        for (NSDictionary *dict in (NSArray*)attachmentsArray) {
                            if ([dict valueForKey:(NSString*)kCMSampleAttachmentKey_NotSync])
                                sync = 0;
                        }
                    }
                    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                    sample->sampleData = sampleData;
                    sample->sampleSize = sampleSize;
                    sample->sampleDuration = duration.value;
                    sample->sampleOffset = -decodeTimeStamp.value + presentationTimeStamp.value;
                    sample->sampleTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer).value;
                    sample->sampleIsSync = sync;
                    sample->sampleTrackId = track.Id;

                    @synchronized(samplesBuffer) {
                        [samplesBuffer addObject:sample];
                        [sample release];
                    }
            
                    currentDataLength += sampleSize;
                }
                else {
                    if (!CMSampleBufferDataIsReady(sampleBuffer))
                        CMSampleBufferMakeDataReady(sampleBuffer);

                    // A CMSampleBufferRef can contains an unknown number of samples, check how many needs to be divided to separated MP42SampleBuffers
                    // First get the array with the timings for each sample
                    CMItemCount timingArrayEntries = 0;
                    CMItemCount timingArrayEntriesNeededOut = 0;
                    err = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, timingArrayEntries, NULL, &timingArrayEntriesNeededOut);
                    if (err)
                        continue;

                    CMSampleTimingInfo *timingArrayOut = malloc(sizeof(CMSampleTimingInfo) * timingArrayEntriesNeededOut);
                    timingArrayEntries = timingArrayEntriesNeededOut;
                    err = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, timingArrayEntries, timingArrayOut, &timingArrayEntriesNeededOut);
                    if (err)
                        continue;

                    // Then the array with the size of each sample
                    CMItemCount sizeArrayEntries = 0;
                    CMItemCount sizeArrayEntriesNeededOut = 0;
                    err = CMSampleBufferGetSampleSizeArray(sampleBuffer, sizeArrayEntries, NULL, &sizeArrayEntriesNeededOut);
                    if (err)
                        continue;

                    size_t *sizeArrayOut = malloc(sizeof(size_t) * sizeArrayEntriesNeededOut);
                    sizeArrayEntries = sizeArrayEntriesNeededOut;
                    err = CMSampleBufferGetSampleSizeArray(sampleBuffer, sizeArrayEntries, sizeArrayOut, &sizeArrayEntriesNeededOut);
                    if (err)
                        continue;

                    // Get CMBlockBufferRef to extract the actual data later
                    CMBlockBufferRef buffer = CMSampleBufferGetDataBuffer(sampleBuffer);
                    size_t bufferSize = CMBlockBufferGetDataLength(buffer);

                    int i = 0, pos = 0;
                    for (i = 0; i < samplesNum; i++) {
                        CMSampleTimingInfo sampleTimingInfo;
                        size_t sampleSize = sizeArrayOut[i];

                        // If the size of sample timing array is equal to 1, it means every sample has got the same timing
                        if (timingArrayEntries == 1)
                            sampleTimingInfo = timingArrayOut[0];
                        else
                            sampleTimingInfo = timingArrayOut[i];

                        // If the size of sample size array is equal to 1, it means every sample has got the same size
                        if (sizeArrayEntries ==  1)
                            sampleSize = sizeArrayOut[0];
                        else
                            sampleSize = sizeArrayOut[i];

                        if (!sampleSize)
                            continue;

                        void *sampleData = malloc(sampleSize);

                        if (pos < bufferSize) {
                            CMBlockBufferCopyDataBytes(buffer, pos, sampleSize, sampleData);
                            pos += sampleSize;
                        }

                        BOOL sync = 1;
                        CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, NO);
                        if (attachmentsArray) {
                            for (NSDictionary *dict in (NSArray*)attachmentsArray) {
                                if ([dict valueForKey:(NSString*)kCMSampleAttachmentKey_NotSync])
                                    sync = 0;
                            }
                        }

                        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                        sample->sampleData = sampleData;
                        sample->sampleSize = sampleSize;
                        sample->sampleDuration = sampleTimingInfo.duration.value;
                        sample->sampleOffset = -sampleTimingInfo.decodeTimeStamp.value + sampleTimingInfo.presentationTimeStamp.value;
                        sample->sampleTimestamp = sampleTimingInfo.presentationTimeStamp.value;
                        sample->sampleIsSync = sync;
                        sample->sampleTrackId = track.Id;
                        if(track.needConversion)
                            sample->sampleSourceTrack = track;

                        @synchronized(samplesBuffer) {
                            [samplesBuffer addObject:sample];
                            [sample release];
                        }

                        currentDataLength += sampleSize;
                    }

                    if(timingArrayOut)
                        free(timingArrayOut);
                    if(sizeArrayOut)
                        free(sizeArrayOut);
                }
                CFRelease(sampleBuffer);

                progress = (((CGFloat) currentDataLength /  totalDataLength ) * 100);

            }
            else {
                AVAssetReaderStatus status = assetReader.status;

                if (status == AVAssetReaderStatusCompleted) {
                    NSLog(@"AVAssetReader: done");
                }

                break;
            }
        }
    }

    [assetReader release];
    readerStatus = 1;
    [pool release];
}

- (MP42SampleBuffer*)copyNextSample
{    
    if (samplesBuffer == nil) {
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];
    }    
    
    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
        [dataReader setName:@"AVFoundation Demuxer"];
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

- (CGFloat)progress
{
    return progress;
}

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{
    uint32_t timescale = MP4GetTimeScale(fileHandle);

    for (MP42Track * track in activeTracks) {
        AVAssetTrack *assetTrack = [localAsset trackWithTrackID:track.sourceId];

        for (AVAssetTrackSegment *segment in assetTrack.segments) {
            bool empty = NO;
            CMTimeMapping timeMapping = segment.timeMapping;
            
            if (timeMapping.source.duration.flags & kCMTimeFlags_Indefinite || timeMapping.target.duration.flags & kCMTimeFlags_Indefinite) {
                //NSLog(@"Indefinite time mappings");
            }
            else {
                /*NSLog(@"Source --");
                NSLog(@"Start: %lld", timeMapping.source.start.value);
                NSLog(@"Timescale: %d", timeMapping.source.start.timescale);
                NSLog(@"Duration: %lld", timeMapping.source.duration.value);
                NSLog(@"Timescale: %d", timeMapping.source.duration.timescale);

                NSLog(@"Target --");
                NSLog(@"Start %lld", timeMapping.target.start.value);
                NSLog(@"Timescale: %d", timeMapping.target.start.timescale);
                NSLog(@"Duration: %lld", timeMapping.target.duration.value);
                NSLog(@"Timescale: %d", timeMapping.target.start.timescale);*/

                if (segment.empty) {
                    NSLog(@"Empty segment");
                    empty = YES;
                }

                if (empty)
                    MP4AddTrackEdit(fileHandle, [track Id], MP4_INVALID_EDIT_ID, -1,
                                    timeMapping.target.duration.value * ((double) timescale / timeMapping.target.start.timescale), 0);
                else
                    MP4AddTrackEdit(fileHandle, [track Id], MP4_INVALID_EDIT_ID, timeMapping.target.start.value,
                                    timeMapping.target.duration.value * ((double) timescale / timeMapping.target.start.timescale), 0);
            }
        }
    }
    return YES;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release];

    [localAsset release];

    if (activeTracks)
        [activeTracks release];
    if (samplesBuffer)
        [samplesBuffer release];

    [metadata release];
	[fileURL release];
    [tracksArray release];

    [super dealloc];
}

@end

#endif
