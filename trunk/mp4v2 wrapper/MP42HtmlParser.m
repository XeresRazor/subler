//
//  SBHtmlParser.m
//  Subler
//
//  Created by Damiano Galassi on 13/06/13.
//
//

#import "MP42HtmlParser.h"

rgba_color make_color(u_int8_t r, u_int8_t g, u_int8_t b, u_int8_t a) {
    rgba_color color;
    color.r = r;
    color.g = g;
    color.b = b;
    color.a = a;
    return color;
}

int compare_color(rgba_color c1, rgba_color c2) {
    if (c1.r == c2.r &&
        c1.g == c2.g &&
        c1.b == c2.b &&
        c1.a == c2.a)
        return 0;
    else
        return 1;
}
@implementation MP42Style

- (instancetype)init {
    self = [super init];
    if (self) {
        _color = make_color(255, 255, 255, 255);
    }
    return self;
}

- (instancetype)initWithStyle:(NSInteger)style type:(NSInteger)type location:(NSUInteger) location color:(rgba_color) color
{
    self = [super init];
    if (self) {
        _style = style;
        _type = type;
        _location = location;
        _color = color;

    }
    return self;
}

- (instancetype)copyWithZone:(NSZone *)zone
{
    MP42Style *newObject = [[MP42Style allocWithZone:zone] init];

    newObject.style = _style;
    newObject.type = _type;
    newObject.location = _location;
    newObject.length = _length;
    newObject.color = _color;
    
    return newObject;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"Style: %ld\n, Location: %lu, Length: %lu", (long)_style, (unsigned long)_location, (unsigned long)_length];
}

@synthesize style = _style;
@synthesize color = _color;
@synthesize type = _type;
@synthesize location = _location;
@synthesize length = _length;

@end

@implementation MP42HtmlParser

- (instancetype)initWithString: (NSString*) string
{
    self = [super init];
    if (self) {
        _text = [string mutableCopy];
        _styles = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSInteger)parseNextTag
{
    NSCharacterSet *openChar = [NSCharacterSet characterSetWithCharactersInString:@"<"];
    NSCharacterSet *closeChar = [NSCharacterSet characterSetWithCharactersInString:@">"];
    NSRange openRange;
    NSRange closeRange;

    NSString *content;

    openRange = [_text rangeOfCharacterFromSet:openChar];
    if (openRange.location != NSNotFound) {
        closeRange = [_text rangeOfCharacterFromSet:closeChar];

        while (closeRange.location < openRange.location) {
            [_text deleteCharactersInRange:closeRange];
            openRange.location--;
            closeRange = [_text rangeOfCharacterFromSet:closeChar];
        }

        if (closeRange.location == NSNotFound)
            closeRange.location = [_text length];
    }
    else {
        _location = [_text length];
        return NSNotFound;
    }

    NSRange contentRange, contentInternalRange;
    contentRange.location = openRange.location;
    contentRange.length = closeRange.location + closeRange.length - openRange.location;
    
    contentInternalRange = contentRange;
    contentInternalRange.location += 1;
    contentInternalRange.length -= 2;

    content = [_text substringWithRange:contentInternalRange];

    NSInteger tagType;
    MP42Style *style = nil;
    if ([content hasPrefix:@"/"]) {
        tagType = kTagClose;
        contentInternalRange.location +=1;
        contentInternalRange.length -=1;
        content = [_text substringWithRange:contentInternalRange];
    }
    else
        tagType = kTagOpen;

    if ([content hasPrefix:@"font"]) {
        style = [[MP42Style alloc] initWithStyle:kStyleColor type:tagType location:openRange.location color: _defaultColor];
        if (tagType == kTagOpen) {
            NSRange colorRange = [content rangeOfString:@"color=\"#"];
            if (colorRange.location != NSNotFound && colorRange.location < [content length]) {
                colorRange.location += 8;
                colorRange.length = 6;
                NSString *color = [content substringWithRange:colorRange];
                const char *r = [[color substringWithRange:NSMakeRange(0, 2)] UTF8String];
                const char *g = [[color substringWithRange:NSMakeRange(2, 2)] UTF8String];
                const char *b = [[color substringWithRange:NSMakeRange(4, 2)] UTF8String];
                int rc, gc, bc;
                sscanf(r, "%x", &rc);
                sscanf(g, "%x", &gc);
                sscanf(b, "%x", &bc);
                style.color = make_color(rc,gc,bc,255);
            }
        }
    }
    else if ([content hasPrefix:@"b"]) {
        style = [[MP42Style alloc] initWithStyle:kStyleBold type:tagType location:openRange.location color:_defaultColor];
    }
    else if ([content hasPrefix:@"i"]) {
        style = [[MP42Style alloc] initWithStyle:kStyleItalic type:tagType location:openRange.location color:_defaultColor];
    }
    else if ([content hasPrefix:@"u"]) {
        style = [[MP42Style alloc] initWithStyle:kStyleUnderlined type:tagType location:openRange.location color:_defaultColor];
    }

    if (style) {
        [_styles addObject:style];
        [style release];
    }

    [_text deleteCharactersInRange:contentRange];

    return contentRange.location;
}

- (void)serializeStyles
{
    NSMutableArray *serializedStyles = [[NSMutableArray alloc] init];
    MP42Style *currentStyle = [[MP42Style alloc] init];

    for (MP42Style *nextStyle in _styles) {
        if (currentStyle.location != nextStyle.location) {
            currentStyle.length = nextStyle.location - currentStyle.location;
            if (currentStyle.style || compare_color(currentStyle.color, nextStyle.color))
                if (currentStyle.length)
                    [serializedStyles addObject:[[currentStyle copy] autorelease]];

            currentStyle.location = nextStyle.location;
        }
        if (nextStyle.type == kTagOpen) {
            if (nextStyle.style == kStyleColor)
                currentStyle.color = nextStyle.color;
            else
                currentStyle.style |= nextStyle.style;
        }
        else if (nextStyle.type == kTagClose) {
            if (nextStyle.style == kStyleColor)
                currentStyle.color = _defaultColor;
            else
                currentStyle.style ^= nextStyle.style;
        }
    }

    if (currentStyle.style || compare_color(currentStyle.color, _defaultColor)) {
        currentStyle.length = [_text length] - currentStyle.location;
        if (currentStyle.length)
            [serializedStyles addObject:[[currentStyle copy] autorelease]];
    }

    [currentStyle release];
    [_styles release];
    _styles = serializedStyles;
}

@synthesize text = _text;
@synthesize styles = _styles;
@synthesize defaultColor = _defaultColor;


- (void)dealloc
{
    [_text release];
    [_styles release];
    [super dealloc];
}
@end
