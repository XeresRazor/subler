//
//  MP42Image.m
//  Subler
//
//  Created by Damiano Galassi on 27/06/13.
//
//

#import "MP42Image.h"
#import <Quartz/Quartz.h>

NSLock *lock;

@implementation MP42Image

- (id)initWithImage:(NSImage*)image
{
    if (self = [super init])
        _image = [image retain];
    
    return self;
}

- (id)initWithData:(NSData*)data type:(NSInteger)type
{
    if (self = [super init]) {
        _data = [data retain];
        _type = type;
        [self image];
    }
    
    return self;
}

- (id)initWithBytes:(const void*)bytes length:(NSUInteger)length type:(NSInteger)type
{
    if (self = [super init]) {
        _data = [[NSData alloc] initWithBytes:bytes length:length];
        _type = type;
        [self image];
    }

    return self;
}

- (NSString *)imageRepresentationType
{
    return IKImageBrowserNSImageRepresentationType;
}

- (NSString *)imageUID
{
    return [self.image description];
}

- (id) imageRepresentation
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

- (NSImage*)image
{
    if (_image)
        return _image;
    else if (_data) {
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:_data];
        if (imageRep != nil) {
            _image = [[NSImage alloc] initWithSize:[imageRep size]];
            [_image addRepresentation:imageRep];
        }
    }

    return nil;
}

- (void)dealloc
{
    [_image release];
    [_data release];
    
    [super dealloc];
}

@synthesize data = _data;
@synthesize type = _type;

@end