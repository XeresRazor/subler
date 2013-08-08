//
//  MP42MediaFormat.h
//  Subler
//
//  Created by Damiano Galassi on 08/08/13.
//
//

#import <Foundation/Foundation.h>

// File Type
NSString *const MP42FileTypeMP4 = @"mp4";
NSString *const MP42FileTypeM4V = @"m4v";
NSString *const MP42FileTypeM4A = @"m4a";
NSString *const MP42FileTypeM4B = @"m4b";


// Media Type
NSString *const MP42MediaTypeVideo = @"Video Track";
NSString *const MP42MediaTypeAudio = @"Sound Track";
NSString *const MP42MediaTypeText = @"Text Track";
NSString *const MP42MediaTypeClosedCaption = @"Closed Caption Track";
NSString *const MP42MediaTypeSubtitle = @"Subtitle Track";
NSString *const MP42MediaTypeTimecode = @"TimeCode Track";


// Video Format
NSString *const MP42VideoFormatH264 = @"H.264";
NSString *const MP42VideoFormatMPEG4Visual = @"MPEG-4 Visual";
NSString *const MP42VideoFormatSorenson = @"Sorenson Video";
NSString *const MP42VideoFormatSorenson3 = @"Sorenson Video 3";
NSString *const MP42VideoFormatMPEG1 = @"MPEG-1";
NSString *const MP42VideoFormatMPEG2 = @"MPEG-2";
NSString *const MP42VideoFormatDV = @"DV";
NSString *const MP42VideoFormatPNG = @"PNG";
NSString *const MP42VideoFormatAnimation = @"Animation";
NSString *const MP42VideoFormatProRes = @"Apple ProRes";
NSString *const MP42VideoFormatJPEG = @"Photo-JPEG";
NSString *const MP42VideoFormatMotionJPEG = @"Motion JPEG";
NSString *const MP42VideoFormatFairPlay = @"FairPlay Video";


// Audio Format
NSString *const MP42AudioFormatAAC = @"AAC";
NSString *const MP42AudioFormatHEAAC = @"HE-AAC";
NSString *const MP42AudioFormatMP3 = @"MP3";
NSString *const MP42AudioFormatVorbis = @"Vorbis";
NSString *const MP42AudioFormatFLAC = @"FLAC";
NSString *const MP42AudioFormatALAC = @"ALAC";
NSString *const MP42AudioFormatAC3 = @"AC-3";
NSString *const MP42AudioFormatDTS = @"DTS";
NSString *const MP42AudioFormatTrueHD = @"True HD";
NSString *const MP42AudioFormatAMR = @"AMR Narrow Band";
NSString *const MP42AudioFormatPCM = @"PCM";
NSString *const MP42AudioFormatFairPlay = @"FairPlay Sound";


// Subtitle Format
NSString *const MP42SubtitleFormatTx3g = @"Tx3g";
NSString *const MP42SubtitleFormatText = @"Text";
NSString *const MP42SubtitleFormatVobSub = @"VobSub";
NSString *const MP42SubtitleFormatPGS = @"PGS";
NSString *const MP42SubtitleFormatSSA = @"SSA";


// Closed Caption Fromat
NSString *const MP42ClosedCaptionFormatCEA608 = @"CEA-608";
NSString *const MP42ClosedCaptionFormatCEA708 = @"CEA-708";


// TimeCode Format
NSString *const MP42TimeCodeFormat = @"TimeCode";