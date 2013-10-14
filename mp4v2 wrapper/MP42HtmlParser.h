//
//  SBHtmlParser.h
//  Subler
//
//  Created by Damiano Galassi on 13/06/13.
//
//

#import <Foundation/Foundation.h>

#define kStyleBold 1
#define kStyleItalic 2
#define kStyleUnderlined 4
#define kStyleColor 8

#define kTagOpen 1
#define kTagClose 2

typedef struct rgba_color {
    u_int8_t r;
    u_int8_t g;
    u_int8_t b;
    u_int8_t a;
} rgba_color;

rgba_color make_color(u_int8_t r, u_int8_t g, u_int8_t b, u_int8_t a);
int compare_color(rgba_color c1, rgba_color c2);

@interface MP42Style : NSObject
{
    NSInteger _style;
    rgba_color _color;
    NSInteger _type;
    NSUInteger _location;
    NSUInteger _length;
}

- (instancetype)initWithStyle:(NSInteger)style type:(NSInteger)type location:(NSUInteger) location color:(rgba_color) color;

@property (readwrite) NSInteger style;
@property (readwrite) rgba_color color;
@property (readwrite) NSInteger type;
@property (readwrite) NSUInteger location;
@property (readwrite) NSUInteger length;

@end

@interface MP42HtmlParser : NSObject
{
    NSUInteger _location;
    NSMutableString *_text;
    NSMutableArray *_styles;
    rgba_color _defaultColor;
}

@property (readonly) NSString *text;
@property (readonly) NSArray *styles;
@property (readwrite) rgba_color defaultColor;

- (instancetype)initWithString:(NSString *)string;
- (NSInteger) parseNextTag;
- (void)serializeStyles;

@end
