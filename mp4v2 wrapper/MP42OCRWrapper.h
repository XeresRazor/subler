//
//  SBOcr.h
//  Subler
//
//  Created by Damiano Galassi on 27/03/11.
//  Copyright 2011 Damiano Galassi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MP42OCRWrapper : NSObject {
    void *tess_base;
    
    NSString *_language;
}

- (instancetype)initWithLanguage:(NSString *)language;
- (NSString *)performOCROnCGImage:(CGImageRef)image;

@end
