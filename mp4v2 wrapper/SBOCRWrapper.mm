//
//  SBOcr.mm
//  Subler
//
//  Created by Damiano Galassi on 27/03/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import "SBOCRWrapper.h"
#import "SBLanguages.h"

// Tesseract OCR
#include "tesseract/baseapi.h"

using namespace tesseract;

class OCRWrapper {
public:
OCRWrapper(const char* lang, const char* base_path) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *path = nil;
    if (base_path)
        path = [[NSString stringWithUTF8String:base_path] stringByAppendingString:@"/"];
    else
        path = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Resources/"];

    setenv("TESSDATA_PREFIX", [path UTF8String], 1);

    path = [path stringByAppendingString:@"tessdata/"];

    tess_base_api.Init([path UTF8String], lang, OEM_DEFAULT);

    [pool release];
}
char* OCRFrame(const unsigned char *image, int bytes_per_pixel, int bytes_per_line, int width, int height) {
    char* text = tess_base_api.TesseractRect(image,
                                             bytes_per_pixel,
                                             bytes_per_line,
                                             0, 0,
                                             width, height);
    return text;
}

void End()
{
    tess_base_api.End();
}

protected:
    TessBaseAPI tess_base_api;
};

@implementation SBOCRWrapper

- (NSURL*) appSupportUrl
{
    NSURL *URL = nil;

    NSArray *allPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                            NSUserDomainMask,
                                                            YES);
    if ([allPaths count]) {
        NSString* path = [[allPaths lastObject] stringByAppendingPathComponent:@"Subler"];
        URL = [NSURL fileURLWithPath:path];

        if (URL) {
            return URL;
        }
    }

    return nil;

}

- (BOOL)tessdataAvailableForLanguage:(NSString*) language
{
    NSURL *URL = [self appSupportUrl];

    if (URL) {
        NSString* path = [[[URL path] stringByAppendingPathComponent:@"tessdata"] stringByAppendingFormat:@"/%@.traineddata", language];
        URL = [NSURL fileURLWithPath:path];

        if ([[NSFileManager defaultManager] fileExistsAtPath:[URL path]]) {
            return YES;
        }
    }

    return NO;
}


- (id)init
{
    if ((self = [super init]))
    {
        tess_base = (void *)new OCRWrapper(lang_for_english([_language UTF8String])->iso639_2, NULL);
    }
    return self;
}

- (id) initWithLanguage: (NSString*) language
{
    if ((self = [super init]))
    {
        _language = [language retain];

        NSString * lang = [NSString stringWithUTF8String:lang_for_english([_language UTF8String])->iso639_2];
        NSURL *dataURL = [self appSupportUrl];
        if (![self tessdataAvailableForLanguage:lang]) {
            lang = @"eng";
            dataURL = nil;
        }

        tess_base = (void *)new OCRWrapper([lang UTF8String], [[dataURL path] UTF8String]);
    }
    return self;
}

- (NSString*) performOCROnCGImage:(CGImageRef)cgImage {
    NSMutableString * text;

    OCRWrapper *ocr = (OCRWrapper *)tess_base;
    size_t bytes_per_line   = CGImageGetBytesPerRow(cgImage);
    size_t bytes_per_pixel  = CGImageGetBitsPerPixel(cgImage) / 8.0;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(cgImage));
    const UInt8 *imageData = CFDataGetBytePtr(data);

    
    char* string = ocr->OCRFrame(imageData,
                                 bytes_per_pixel,
                                 bytes_per_line,
                                 width,
                                 height);
    CFRelease(data);

    if (string && strlen(string)) {
        text = [NSMutableString stringWithUTF8String:string];
        if ([text characterAtIndex:[text length] -1] == '\n')
            [text replaceOccurrencesOfString:@"\n\n" withString:@"" options:nil range:NSMakeRange(0,[text length])];
    }
    else
        text = nil;

    delete[]string;

    return text;

}

- (void) dealloc {
    OCRWrapper *ocr = (OCRWrapper *)tess_base;
    ocr->End();
    delete ocr;

    [_language release];
    [super dealloc];
}
@end
