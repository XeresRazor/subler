//
//  MP42Image.h
//  Subler
//
//  Created by Damiano Galassi on 27/06/13.
//
//

#import <Foundation/Foundation.h>

@class NSImage;

typedef enum MP42TagArtworkType_e {
    MP42_ART_UNDEFINED = 0,
    MP42_ART_BMP       = 1,
    MP42_ART_GIF       = 2,
    MP42_ART_JPEG      = 3,
    MP42_ART_PNG       = 4
} MP42TagArtworkType;

@interface MP42Image : NSObject <NSCoding> {
    NSImage *_image;

    NSURL   *_url;
    NSData  *_data;

    NSInteger _type;
}

- (instancetype)initWithURL:(NSURL *)url  type:(NSInteger)type;
- (instancetype)initWithImage:(NSImage *)image;
- (instancetype)initWithData:(NSData *)data type:(NSInteger)type;
- (instancetype)initWithBytes:(const void*)bytes length:(NSUInteger)length type:(NSInteger)type;

@property(readonly) NSImage *image;
@property(readonly) NSURL *url;
@property(readonly) NSData *data;
@property(readonly) NSInteger type;

@end