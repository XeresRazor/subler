//
//  MP42SubtitleTrack.m
//  Subler
//
//  Created by Damiano Galassi on 31/01/09.
//  Copyright 2009 Damiano Galassi. All rights reserved.
//

#import "MP42SubtitleTrack.h"
#import "MP42Utilities.h"
#import "MP42MediaFormat.h"
#import "MP42HtmlParser.h"
#import "SBLanguages.h"

@implementation MP42SubtitleTrack

@synthesize verticalPlacement = _verticalPlacement;
@synthesize someSamplesAreForced = _someSamplesAreForced;
@synthesize allSamplesAreForced = _allSamplesAreForced;
@synthesize forcedTrackId = _forcedTrackId;

- (id)initWithSourceURL:(NSURL *)URL trackID:(NSInteger)trackID fileHandle:(MP4FileHandle)fileHandle
{
    if ((self = [super initWithSourceURL:URL trackID:trackID fileHandle:fileHandle])) {
        if (![format isEqualToString:MP42SubtitleFormatVobSub]) {
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", &height);
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", &width);

            uint64_t displayFlags = 0;
            MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.displayFlags", &displayFlags);

            if (displayFlags) {
                if ((displayFlags & 0x20000000) == 0x20000000)
                    _verticalPlacement = YES;
                if ((displayFlags & 0x40000000) == 0x40000000)
                    _someSamplesAreForced = YES;
                if ((displayFlags & 0x80000000) == 0x80000000)
                    _allSamplesAreForced = YES;
            }

            if (MP4HaveTrackAtom(fileHandle, Id, "tref.forc")) {
                uint64_t forcedId = 0;
                MP4GetTrackIntegerProperty(fileHandle, Id, "tref.forc.entries.trackId", &forcedId);
                _forcedTrackId = (MP4TrackId) forcedId;
            }
        }
    }

    return self;
}

- (id)init
{
    if ((self = [super init])) {
        name = [self defaultName];
        format = MP42SubtitleFormatTx3g;
    }

    return self;
}

- (BOOL)writeToFile:(MP4FileHandle)fileHandle error:(NSError **)outError
{
    if (!fileHandle || !Id) {
        if ( outError != NULL) {
            *outError = MP42Error(@"Error: couldn't mux subtitle track",
                                  nil,
                                  120);
            return NO;
            
        }
    }

    if ([updatedProperty valueForKey:@"forced"] || !muxed) {
        if (_forcedTrack)
            _forcedTrackId = _forcedTrack.Id;

        if (MP4HaveTrackAtom(fileHandle, Id, "tref.forc") && (_forcedTrackId == 0)) {
            MP4RemoveAllTrackReferences(fileHandle, "tref.forc", Id);
        }
        else if (MP4HaveTrackAtom(fileHandle, Id, "tref.forc") && (_forcedTrackId)) {
            MP4SetTrackIntegerProperty(fileHandle, Id, "tref.forc.entries.trackId", _forcedTrackId);
        }
        else if (_forcedTrackId)
            MP4AddTrackReference(fileHandle, "tref.forc", _forcedTrackId, Id);
    }

    if (isEdited && !muxed) {
        muxed = YES;

        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.width", &trackWidth);
        MP4GetTrackFloatProperty(fileHandle, Id, "tkhd.height", &trackHeight);

        uint8_t *val;
        uint8_t nval[36];
        uint32_t *ptr32 = (uint32_t*) nval;
        uint32_t size;

        MP4GetTrackBytesProperty(fileHandle ,Id, "tkhd.matrix", &val, &size);
        memcpy(nval, val, size);
        offsetX = CFSwapInt32BigToHost(ptr32[6]) / 0x10000;
        offsetY = CFSwapInt32BigToHost(ptr32[7]) / 0x10000;
        free(val);

        [super writeToFile:fileHandle error:outError];

        return Id;
    }
    else
        [super writeToFile:fileHandle error:outError];

    if (![format isEqualToString:MP42SubtitleFormatVobSub]) {
        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxBottom", trackHeight);
        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.defTextBoxRight", trackWidth);

        uint32_t displayFlags = 0;
        if (_verticalPlacement)
            displayFlags = 0x20000000;
        if (_someSamplesAreForced)
            displayFlags |= 0x40000000;
        if (_allSamplesAreForced)
            displayFlags |= 0x80000000;

        MP4SetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.tx3g.displayFlags", displayFlags);
    }

    return YES;
}

typedef struct style_record {
    uint16_t startChar;
    uint16_t endChar;
    uint16_t fontID;
    uint8_t  fontStyles;
    uint8_t  fontSize;
    rgba_color color;
} style_record;

typedef struct tbox_record {
    uint16_t top;
    uint16_t left;
    uint16_t bottom;
    uint16_t right;
} tbox_record;

static void insertTag(NSString* tag, NSMutableString *sampleText, NSUInteger *index, uint8_t *fontStyles, uint8_t type, uint8_t status) {
    [sampleText insertString:tag atIndex:*index];
    *index += [tag length];

    if (status == kTagOpen)
        *fontStyles |= type;
    else if (status == kTagClose)
        *fontStyles ^= type;
}

static void insertTagsFromStyleRecord(style_record record, NSMutableString *sampleText, uint8_t *fontStyles, rgba_color fontColor, uint8_t *numberOfInsertedChars) {
    NSUInteger len = [sampleText length];
    NSUInteger index = record.startChar + *numberOfInsertedChars;
    rgba_color dcolor = {0xFF, 0xFF, 0xFF, 0xFF};

    if (record.startChar <= len && record.endChar <= len) {
        // Open tag
        if ((record.fontStyles & kStyleColor && !(*fontStyles & kStyleColor)) ||
            (compare_color(record.color, fontColor) && compare_color(record.color, dcolor))) {
            // Special case: if there is already a font tag open, close it;
            if (!(record.fontStyles & kStyleColor && !(*fontStyles & kStyleColor)))
                insertTag(@"</font>", sampleText, &index, fontStyles, 0, kTagClose);

            NSString *font = [NSString stringWithFormat:@"<font color=\"#%02x%02x%02x\">", (uint8_t)record.color.r, (uint8_t)record.color.g, (uint8_t)record.color.b];
            insertTag(font, sampleText, &index, fontStyles, kStyleColor, kTagOpen);
        }
        if (record.fontStyles & kStyleBold && !(*fontStyles & kStyleBold))
            insertTag(@"<b>", sampleText, &index, fontStyles, kStyleBold, kTagOpen);

        if (record.fontStyles & kStyleItalic && !(*fontStyles & kStyleItalic))
            insertTag(@"<i>", sampleText, &index, fontStyles, kStyleItalic, kTagOpen);

        if (record.fontStyles & kStyleUnderlined && !(*fontStyles & kStyleUnderlined))
            insertTag(@"<u>", sampleText, &index, fontStyles, kStyleUnderlined, kTagOpen);

        // Close tag
        if (!(record.fontStyles & kStyleUnderlined) && *fontStyles & kStyleUnderlined)
            insertTag(@"</u>", sampleText, &index, fontStyles, kStyleUnderlined, kTagClose);

        if (!(record.fontStyles & kStyleItalic) && *fontStyles & kStyleItalic)
            insertTag(@"</i>", sampleText, &index, fontStyles, kStyleItalic, kTagClose);

        if (!(record.fontStyles & kStyleBold) && *fontStyles & kStyleBold)
            insertTag(@"</b>", sampleText, &index, fontStyles, kStyleBold, kStyleColor);


        if ((!(record.fontStyles & kStyleColor) && *fontStyles & kStyleColor))
            insertTag(@"</font>", sampleText, &index, fontStyles, kStyleColor, kTagClose);
    }

    *numberOfInsertedChars += index - record.startChar - *numberOfInsertedChars;
}

- (BOOL)exportToURL:(NSURL *)url error:(NSError **)error
{
    MP4FileHandle fileHandle = MP4Read([[sourceURL path] UTF8String]);
    if (!fileHandle)
        return NO;

    MP4TrackId srcTrackId = Id;

    MP4SampleId sampleId = 1;
    NSUInteger srtSampleNumber = 1;

    MP4Timestamp time = 0;
    uint32_t timeScale = MP4GetTrackTimeScale(fileHandle, srcTrackId);
    uint64_t samples = MP4GetTrackNumberOfSamples(fileHandle, srcTrackId);

    NSMutableString *srtFile = [[[NSMutableString alloc] init] autorelease];
    
    uint64_t r, g, b, a;
    MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorRed", &r);
    MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorGreen", &g);
    MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorBlue", &b);
    MP4GetTrackIntegerProperty(fileHandle, srcTrackId, "mdia.minf.stbl.stsd.tx3g.fontColorAlpha", &a);
    rgba_color dcolor = {r, g, b, a};

    for (sampleId = 1; sampleId <= samples; sampleId++) {
        uint8_t *pBytes = NULL;
        uint64_t pos = 0;
        uint32_t numBytes = 0;
        MP4Duration sampleDuration;
        MP4Duration renderingOffset;
        MP4Timestamp pStartTime;
        bool isSyncSample;
        BOOL forced = NO;
        BOOL tbox = NO;

        if (!MP4ReadSample(fileHandle,
                           srcTrackId,
                           sampleId,
                           &pBytes, &numBytes,
                           &pStartTime, &sampleDuration, &renderingOffset,
                           &isSyncSample)) {
            break;
        }

        NSMutableString * sampleText = nil;
        NSUInteger textSampleLength = ((pBytes[0] << 8) & 0xff00) + pBytes[1];

        if (textSampleLength) {
            sampleText = [[[NSMutableString alloc] initWithBytes:(pBytes + 2)
                                                          length:textSampleLength
                                                        encoding:NSUTF8StringEncoding] autorelease];
        }

        // Let's see if there is an atom after the text sample
        pos = textSampleLength + 2;

		while (pos + 8 < numBytes && sampleText) {
			uint8_t *styleAtoms = pBytes + pos;
			size_t atomLength = ((styleAtoms[0] << 24) & 0xff000000) + ((styleAtoms[1] << 16) & 0xff0000) + ((styleAtoms[2] << 8) & 0xff00) + styleAtoms[3];

            pos += atomLength;

			if (pos <= numBytes) {
                // If we found a style atom, read it and insert html-like tags in the new file
                if (styleAtoms[4] == 's' && styleAtoms[5] == 't' && styleAtoms[6] == 'y' && styleAtoms[7] == 'l') {
                    uint16_t styleCount = ((styleAtoms[8] << 8) & 0xff00) + styleAtoms[9];
                    uint8_t *style_sample = styleAtoms + 10;
                    uint8_t numberOfInsertedChars = 0;

                    uint8_t styles = 0;
                    uint64_t endChar = [sampleText length];
                    style_record previousRecord = {0, 0, 0, 0, 0, dcolor};

                    while (styleCount) {
                        // Read the style record
                        style_record record;
                        record.startChar    = (style_sample[0] << 8) & 0xff00;
                        record.startChar    += style_sample[1];
                        record.endChar      = (style_sample[2] << 8) & 0xff00;
                        record.endChar      += style_sample[3];
                        record.fontID       = (style_sample[4] << 8) & 0xff00;
                        record.fontID       += style_sample[5];
                        record.fontStyles	= style_sample[6];
                        record.fontSize     = style_sample[7];
                        record.color.r = style_sample[8];
                        record.color.g = style_sample[9];
                        record.color.b = style_sample[10];
                        record.color.a = style_sample[11];

                        // Is the color different?
                        if (compare_color(record.color, dcolor))
                            record.fontStyles |= kStyleColor;

                        // Create a record to close the gap between two non-adiacent records
                        if (record.startChar > previousRecord.endChar + 1) {
                            style_record gapRecord = {previousRecord.endChar, record.startChar - 1, 0, 0, 0, dcolor};
                            insertTagsFromStyleRecord(gapRecord, sampleText, &styles, previousRecord.color, &numberOfInsertedChars);
                        }

                        insertTagsFromStyleRecord(record, sampleText, &styles, previousRecord.color, &numberOfInsertedChars);

                        previousRecord = record;
                        styleCount--;
                        style_sample += 12;
                    }

                    // Add a final record to close all the remainings open tags
                    if (previousRecord.endChar < endChar + 1) {
                        style_record gapRecord = {previousRecord.endChar, endChar, 0, 0, 0, dcolor};
                        insertTagsFromStyleRecord(gapRecord, sampleText, &styles, previousRecord.color, &numberOfInsertedChars);
                    }
                }
                else if (styleAtoms[4] == 'f' && styleAtoms[5] == 'r' && styleAtoms[6] == 'c' && styleAtoms[7] == 'd') {
                    // Found a forced atom
                    forced = YES;
                }
                else if (styleAtoms[4] == 't' && styleAtoms[5] == 'b' && styleAtoms[6] == 'o' && styleAtoms[7] == 'x') {
                    // Found a tbox atom, if top == 0, the sub line is aligned at the top
                    uint8_t *tbox_atom = styleAtoms + 8;

                    tbox_record record;
                    record.top = (tbox_atom[0] << 8) & 0xff00;
                    record.top += tbox_atom[1];
                    record.left = (tbox_atom[2] << 8) & 0xff00;
                    record.left += tbox_atom[3];
                    record.bottom = (tbox_atom[4] << 8) & 0xff00;
                    record.bottom += tbox_atom[5];
                    record.right = (tbox_atom[6] << 8) & 0xff00;
                    record.right += tbox_atom[7];

                    if (record.top == 0)
                        tbox = YES;
                }
            }
        }

        if (textSampleLength) {
            if ([sampleText characterAtIndex:[sampleText length] - 1] == '\n')
                [sampleText deleteCharactersInRange:NSMakeRange([sampleText length] - 1, 1)];

            if (sampleText) {
                [srtFile appendFormat:@"%lu\n%@ --> %@", (unsigned long)srtSampleNumber++,
                                                      SRTStringFromTime(time, timeScale, ','), SRTStringFromTime(time + sampleDuration, timeScale, ',')];
                if (tbox)
                    [srtFile appendString:@" X1:0"];
                if (forced)
                    [srtFile appendString:@" !!!"];
                [srtFile appendString:@"\n"];

                [srtFile appendString:sampleText];
                [srtFile appendString:@"\n\n"];
            }
		}

        time += sampleDuration;
        free(pBytes);
    }

    MP4Close(fileHandle, 0);

    return [srtFile writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:error];
}

- (void)setForcedTrack:(MP42Track *)newForcedTrack
{
    _forcedTrack = newForcedTrack;
    _forcedTrackId = 0;
    isEdited = YES;
    [updatedProperty setValue:@"True" forKey:@"forced"];
}

- (MP42Track *)forcedTrack
{
    return _forcedTrack;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];

    [coder encodeInt:1 forKey:@"MP42SubtitleTrackVersion"];

    [coder encodeBool:_verticalPlacement forKey:@"verticalPlacement"];
    [coder encodeBool:_someSamplesAreForced forKey:@"someSamplesAreForced"];
    [coder encodeBool:_allSamplesAreForced forKey:@"allSamplesAreForced"];

    [coder encodeInt64:_forcedTrackId forKey:@"forcedTrackId"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];

    _verticalPlacement = [decoder decodeBoolForKey:@"verticalPlacement"];
    _someSamplesAreForced = [decoder decodeBoolForKey:@"someSamplesAreForced"];
    _allSamplesAreForced = [decoder decodeBoolForKey:@"allSamplesAreForced"];

    _forcedTrackId = [decoder decodeInt64ForKey:@"forcedTrackId"];

    return self;
}

- (NSString *)defaultName {
    return MP42MediaTypeSubtitle;
}

- (void)dealloc
{
    [super dealloc];
}

@end
