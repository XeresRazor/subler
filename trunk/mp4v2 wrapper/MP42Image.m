//
//  MP42Image.m
//  Subler
//
//  Created by Damiano Galassi on 27/06/13.
//
//

#import "MP42Image.h"
#import <Quartz/Quartz.h>

@implementation MP42Image

- (id)initWithURL:(NSURL *)url type:(NSInteger)type
{
    if (self = [super init]) {
        _url = [url retain];
        _type = type;
    }

    return self;
}

- (id)initWithImage:(NSImage *)image
{
    if (self = [super init])
        _image = [image retain];
    
    return self;
}

- (id)initWithData:(NSData *)data type:(NSInteger)type
{
    if (self = [super init]) {
        _data = [data retain];
        _type = type;
    }
    
    return self;
}

- (id)initWithBytes:(const void*)bytes length:(NSUInteger)length type:(NSInteger)type
{
    if (self = [super init]) {
        _data = [[NSData alloc] initWithBytes:bytes length:length];
        _type = type;
    }

    return self;
}

- (NSImage *)imageFromData:(NSData *)data
{
    NSImage *image = nil;
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
    if (imageRep != nil) {
        image = [[NSImage alloc] initWithSize:[imageRep size]];
        [image addRepresentation:imageRep];
    }

    return [image autorelease];
}

- (NSData *)data {
    if (_data)
        return _data;
    else if (_url) {
        NSError *outError = nil;
        _data = [[NSData dataWithContentsOfURL:_url options:NSDataReadingUncached error:&outError] retain];
    }

    return _data;
}

- (NSImage *)image
{
    if (_image)
        return _image;
    else if (self.data) {
        _image = [[self imageFromData:_data] retain];
    }

    return _image;
}

- (NSString *)imageRepresentationType
{
    return IKImageBrowserNSImageRepresentationType;
}

- (NSString *)imageUID
{
    return [self.image description];
}

- (id)imageRepresentation
{
    return self.image;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (_data)
        [coder encodeObject:_data forKey:@"MP42Image_Data"];
    else
        [coder encodeObject:_image forKey:@"MP42Image"];
    
    [coder encodeInt:_type forKey:@"MP42ImageType"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    _image = [[decoder decodeObjectForKey:@"MP42Image"] retain];
    _data = [[decoder decodeObjectForKey:@"MP42Image_Data"] retain];

    _type = [decoder decodeIntForKey:@"MP42ImageType"];

    return self;
}

- (void)dealloc
{
    [_image release];
    [_data release];
    
    [super dealloc];
}

@synthesize url = _url;
@synthesize data = _data;
@synthesize type = _type;

@end