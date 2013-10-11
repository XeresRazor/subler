//
//  MP42XMLReader.m
//  Subler
//
//  Created by Damiano Galassi on 25/01/13.
//
//

#import "MP42XMLReader.h"
#import "MP42Metadata.h"

@implementation MP42XMLReader

@synthesize mMetadata;

- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error
{
    if (self = [super init]) {
        NSXMLDocument *xml = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:NULL];
        if (xml) {
            NSError *err;
            mMetadata = [[MP42Metadata alloc] init];
            NSArray *nodes = [xml nodesForXPath:@"./movie" error:&err];
            if ([nodes count] == 1)
                [self metadata:mMetadata forNode:[nodes objectAtIndex:0]];
            
            nodes = [xml nodesForXPath:@"./video" error:&err];
            if ([nodes count] == 1)
                [self metadata2:mMetadata forNode:[nodes objectAtIndex:0]];
        }
        [xml release];
    }
    return self;
}

#pragma mark Parse metadata

- (NSString *) nodes:(NSXMLElement *)node forXPath:(NSString *)query joinedBy:(NSString *)joiner {
    NSError *err;
    NSArray *tag = [node nodesForXPath:query error:&err];
    if ([tag count]) {
        NSMutableArray *elements = [[[NSMutableArray alloc] initWithCapacity:[tag count]] autorelease];
        NSEnumerator *tagEnum = [tag objectEnumerator];
        NSXMLNode *element;
        while ((element = [tagEnum nextObject])) {
            [elements addObject:[element stringValue]];
        }
        return [elements componentsJoinedByString:@", "];
    } else {
        return nil;
    }
}

- (MP42Metadata *) metadata:(MP42Metadata *)metadata forNode:(NSXMLElement *)node {
    metadata.mediaKind = 9; // movie
    NSArray *tag;
    NSError *err;
    // initial fields from general movie search
    tag = [node nodesForXPath:@"./title" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Name"];
    tag = [node nodesForXPath:@"./year" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Release Date"];
    tag = [node nodesForXPath:@"./outline" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Description"];
    tag = [node nodesForXPath:@"./plot" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Long Description"];
    tag = [node nodesForXPath:@"./certification" error:&err];
    if ([tag count] && [[[tag objectAtIndex:0] stringValue] length]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Rating"];
    tag = [node nodesForXPath:@"./genre" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Genre"];
    tag = [node nodesForXPath:@"./credits" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Artist"];
    tag = [node nodesForXPath:@"./director" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Director"];
    tag = [node nodesForXPath:@"./studio" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Studio"];

    // additional fields from detailed movie info
    NSString *joined;
    joined = [self nodes:node forXPath:@"./cast/actor/@name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Cast"];

    return metadata;
}

- (MP42Metadata *) metadata2:(MP42Metadata *)metadata forNode:(NSXMLElement *)node {
    metadata.mediaKind = 9; // movie
    NSArray *tag;
    NSError *err;
    // initial fields from general movie search
    tag = [node nodesForXPath:@"./content_id" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"contentID"];
    tag = [node nodesForXPath:@"./genre" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Genre"];
    tag = [node nodesForXPath:@"./name" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Name"];
    tag = [node nodesForXPath:@"./release_date" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Release Date"];
    tag = [node nodesForXPath:@"./encoding_tool" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Encoding Tool"];
    tag = [node nodesForXPath:@"./copyright" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Copyright"];

    NSString *joined;
    joined = [self nodes:node forXPath:@"./producers/producer_name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Producers"];
    
    joined = [self nodes:node forXPath:@"./directors/director_name" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Director"], [metadata setTag:joined forKey:@"Artist"];
    
    joined = [self nodes:node forXPath:@"./casts/cast" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Cast"];

    tag = [node nodesForXPath:@"./studio" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Studio"];
    tag = [node nodesForXPath:@"./description" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Description"];
    tag = [node nodesForXPath:@"./long_description" error:&err];
    if ([tag count]) [metadata setTag:[[tag objectAtIndex:0] stringValue] forKey:@"Long Description"];

    joined = [self nodes:node forXPath:@"./categories/category" joinedBy:@","];
    if (joined) [metadata setTag:joined forKey:@"Category"];
    
    return metadata;
}


- (void)dealloc
{
    [mMetadata release];
    [super dealloc];
}

@end
