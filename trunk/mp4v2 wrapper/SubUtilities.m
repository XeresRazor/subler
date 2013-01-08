//
//  SubUtilities.m
//  Subler
//
//  Created by Alexander Strange on 7/24/07.
//  Copyright 2007 Perian. All rights reserved.
//

#import "SubUtilities.h"
#import "RegexKitLite.h"
#import "MP42Sample.h"

@implementation SBTextSample

-(NSComparisonResult)compare:(SBTextSample *)otherObject
{
    MP4Duration otherTimestamp = [otherObject timestamp];

    if (timestamp < otherTimestamp)
        return NSOrderedAscending;
    else if (timestamp > otherTimestamp)
        return NSOrderedDescending;

    return NSOrderedSame;
}

-(void) dealloc
{
    [title release];
    [super dealloc];
}

@synthesize timestamp;
@synthesize title;

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInt64:timestamp forKey:@"timestamp"];
    [coder encodeObject:title forKey:@"title"];
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];

    timestamp = [decoder decodeInt64ForKey:@"timestamp"];
    title = [[decoder decodeObjectForKey:@"title"] retain];

    return self;
}

@end

@implementation SBSubSerializer
-(id)init
{
	if ((self = [super init])) {
		lines = [[NSMutableArray alloc] init];
		finished = NO;
		last_begin_time = last_end_time = 0;
		linesInput = 0;
	}
	
	return self;
}

-(void)dealloc
{
	[lines release];
	[super dealloc];
}

static CFComparisonResult CompareLinesByBeginTime(const void *a, const void *b, void *unused)
{
	SBSubLine *al = (SBSubLine*)a, *bl = (SBSubLine*)b;
	
	if (al->begin_time > bl->begin_time) return kCFCompareGreaterThan;
	if (al->begin_time < bl->begin_time) return kCFCompareLessThan;
	
	if (al->no > bl->no) return kCFCompareGreaterThan;
	if (al->no < bl->no) return kCFCompareLessThan;
	return kCFCompareEqualTo;
}

/*static int cmp_uint(const void *a, const void *b)
{
	unsigned av = *(unsigned*)a, bv = *(unsigned*)b;
	
	if (av > bv) return 1;
	if (av < bv) return -1;
	return 0;
}*/

-(void)addLine:(SBSubLine *)line
{
	if (line->begin_time >= line->end_time) {
		if (line->begin_time)
			//Codecprintf(NULL, "Invalid times (%d and %d) for line \"%s\"", line->begin_time, line->end_time, [line->line UTF8String]);
		return;
	}
	
	line->no = linesInput++;
	
	int nlines = [lines count];
	
	if (!nlines || line->begin_time > ((SBSubLine*)[lines objectAtIndex:nlines-1])->begin_time) {
		[lines addObject:line];
	} else {
		CFIndex i = CFArrayBSearchValues((CFArrayRef)lines, CFRangeMake(0, nlines), line, CompareLinesByBeginTime, NULL);
		
		if (i >= nlines)
			[lines addObject:line];
		else
			[lines insertObject:line atIndex:i];
	}
	
}

-(SBSubLine*)getNextRealSerializedPacket
{
	int nlines = [lines count];
	SBSubLine *first = [lines objectAtIndex:0];
    NSMutableString *str;
	int i;
    
	if (!finished) {
		if (nlines > 1) {
			unsigned maxEndTime = first->end_time;
			
			for (i = 1; i < nlines; i++) {
				SBSubLine *l = [lines objectAtIndex:i];
				
				if (l->begin_time >= maxEndTime) {
					goto canOutput;
				}
				
				maxEndTime = MAX(maxEndTime, l->end_time);
			}
		}
		
		return nil;
	}

canOutput:
	str = [NSMutableString stringWithString:first->line];
	unsigned begin_time = last_end_time, end_time = first->end_time;
	int deleted = 0;
    
	for (i = 1; i < nlines; i++) {
		SBSubLine *l = [lines objectAtIndex:i];
		if (l->begin_time >= end_time) break;
		
		//shorten packet end time if another shorter time (begin or end) is found
		//as long as it isn't the begin time
		end_time = MIN(end_time, l->end_time);
		if (l->begin_time > begin_time)
			end_time = MIN(end_time, l->begin_time);
		
		if (l->begin_time <= begin_time)
			[str appendString:l->line];
	}
	
	for (i = 0; i < nlines; i++) {
		SBSubLine *l = [lines objectAtIndex:i - deleted];
		
		if (l->end_time == end_time) {
			[lines removeObjectAtIndex:i - deleted];
			deleted++;
		}
	}
	
	return [[[SBSubLine alloc] initWithLine:str start:begin_time end:end_time] autorelease];
}

-(SBSubLine*)getSerializedPacket
{
	int nlines = [lines count];
    
	if (!nlines) return nil;
	
	SBSubLine *nextline = [lines objectAtIndex:0], *ret;
	
	if (nextline->begin_time > last_end_time) {
		ret = [[[SBSubLine alloc] initWithLine:@"\n" start:last_end_time end:nextline->begin_time] autorelease];
	} else {
		ret = [self getNextRealSerializedPacket];
	}
	
	if (!ret) return nil;
	
	last_begin_time = ret->begin_time;
	last_end_time   = ret->end_time;
    
	return ret;
}

-(void)setFinished:(BOOL)_finished
{
	finished = _finished;
}

-(BOOL)isEmpty
{
	return [lines count] == 0;
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"lines left: %d finished inputting: %d",[lines count],finished];
}
@end

@implementation SBSubLine
-(id)initWithLine:(NSString*)l start:(unsigned)s end:(unsigned)e
{
	if ((self = [super init])) {
		if ([l characterAtIndex:[l length]-1] != '\n') l = [l stringByAppendingString:@"\n"];
		line = [l retain];
		begin_time = s;
		end_time = e;
		no = 0;
	}
	
	return self;
}

-(void)dealloc
{
	[line release];
	[super dealloc];
}

-(NSString*)description
{
	return [NSString stringWithFormat:@"\"%@\", from %d s to %d s",[line substringToIndex:[line length]-1],begin_time,end_time];
}
@end

unsigned ParseSubTime(const char *time, unsigned secondScale, BOOL hasSign)
{
	unsigned hour, minute, second, subsecond, timeval;
	char separator;
	int sign = 1;

	if (hasSign && *time == '-') {
		sign = -1;
		time++;
	}

	if (sscanf(time,"%u:%u:%u%[,.:]%u",&hour,&minute,&second,&separator,&subsecond) < 5)
		return 0;

    if (second > 60)
        second = 0;
    if (subsecond > secondScale)
        subsecond = 0;

	timeval = hour * 60 * 60 + minute * 60 + second;
	timeval = secondScale * timeval + subsecond;

	return timeval * sign;
}

NSMutableString *STStandardizeStringNewlines(NSString *str)
{
    if(str == nil)
		return nil;
	NSMutableString *ms = [NSMutableString stringWithString:str];
	[ms replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0,[ms length])];
	[ms replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0,[ms length])];
	return ms;
}

static const short frequencies[] = {
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
	0, 1026, 29, -1258, 539, -930, -652, -815, -487, -2526, -2161, 146, -956, -914, 1149, -102, 
	293, -2675, -923, -597, 339, 110, 247, 9, 0, 1024, 1239, 0, 0, 0, 0, 0, 
	0, 1980, 1472, 1733, -304, -4086, 273, 582, 333, 2479, 1193, 5014, -1039, 1964, -2025, 1083, 
	-154, -5000, -1725, -4843, -366, -1850, -191, 1356, -2262, 1648, 1475, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, -458, 0, 0, 0, 0, 300, 0, 0, 300, 601, 0, 
	0, 0, -2247, 0, 0, 0, 0, 0, 0, 0, 3667, 0, 0, 3491, 3567, 0, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1993, 0, 0, 0, 0, 0, 
	0, 0, 0, 0, 0, 0, 1472, 0, 0, 0, 5000, 0, 601, 0, 1993, 0, 
	0, 1083, 0, 672, -458, 0, 0, -458, 1409, 0, 0, 0, 0, 0, 1645, 425, 
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 601, -1123, 
	-1912, 4259, 2573, 8866, 55, 0, 0, -2247, -831, -3788, -3043, 0, 0, 3412, 2921, 1251, 
	0, 0, 1377, 520, 1344, 0, -1123, 0, 0, -1213, 2208, -458, -794, 2636, 3824, 0};

BOOL SubDifferentiateLatin12(const unsigned char *data, int length)
{
	// generated from french/german (latin1) and hungarian/romanian (latin2)
	
	int frcount = 0;
	
	while (length--) {
		frcount += frequencies[*data++];
	}
	
	return frcount <= 0;
}


extern NSString *STLoadFileWithUnknownEncoding(NSString *path)
{
	NSData *data = [NSData dataWithContentsOfMappedFile:path];

    if (!data)
        return nil;

	UniversalDetector *ud = [[UniversalDetector alloc] init];
	NSString *res = nil;
	NSStringEncoding enc;
	float conf;
	NSString *enc_str;
	BOOL latin2;

	[ud analyzeData:data];

	enc = [ud encoding];
	conf = [ud confidence];
	enc_str = [ud MIMECharset];
	latin2 = enc == NSWindowsCP1250StringEncoding;

	if (latin2) {
		if (SubDifferentiateLatin12([data bytes], [data length])) { // seems to actually be latin1
			enc = NSWindowsCP1252StringEncoding;
			enc_str = @"windows-1252";
		}
	}

	if ((conf < .6 || latin2) && enc != NSASCIIStringEncoding) {
		NSLog(@"Guessed encoding \"%s\" for \"%s\", but not sure (confidence %f%%).\n",[enc_str UTF8String],[path UTF8String],conf*100.);
	}

	res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];

	if (!res) {
		if (latin2) {
			NSLog(@"Encoding %s failed, retrying.\n",[enc_str UTF8String]);
			enc = (enc == NSWindowsCP1252StringEncoding) ? NSWindowsCP1250StringEncoding : NSWindowsCP1252StringEncoding;
			res = [[[NSString alloc] initWithData:data encoding:enc] autorelease];
			if (!res) NSLog(@"Both of latin1/2 failed.\n");
		} else {
            res = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
            if (!res) NSLog(@"ASCII failed."), NSLog(@"Failed to load file as guessed encoding %@.",enc_str);
        }
	}
	[ud release];

	return res;
}

int LoadSRTFromPath(NSString *path, SBSubSerializer *ss, MP4Duration *duration)
{
	NSMutableString *srt = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(path));
	if (!srt) return 0;

	if ([srt characterAtIndex:0] == 0xFEFF) [srt deleteCharactersInRange:NSMakeRange(0,1)];
	if ([srt characterAtIndex:[srt length]-1] != '\n') [srt appendFormat:@"%c",'\n'];

	NSScanner *sc = [NSScanner scannerWithString:srt];
	NSString *res = nil;
	[sc setCharactersToBeSkipped:nil];

	unsigned startTime=0, endTime=0;

	enum {
		INITIAL,
		TIMESTAMP,
		LINES
	} state = INITIAL;

	do {
		switch (state) {
			case INITIAL:
				if ([sc scanInt:NULL] == TRUE && [sc scanUpToString:@"\n" intoString:&res] == FALSE) {
					state = TIMESTAMP;
					[sc scanString:@"\n" intoString:nil];
				} else
					[sc setScanLocation:[sc scanLocation]+1];
				break;
			case TIMESTAMP:
				[sc scanUpToString:@" --> " intoString:&res];
				[sc scanString:@" --> " intoString:nil];
				startTime = ParseSubTime([res UTF8String], 1000, NO);

				[sc scanUpToString:@"\n" intoString:&res];
				[sc scanString:@"\n" intoString:nil];
				endTime = ParseSubTime([res UTF8String], 1000, NO);
				state = LINES;
				break;
			case LINES:
				[sc scanUpToString:@"\n\n" intoString:&res];
				[sc scanString:@"\n\n" intoString:nil];
				SBSubLine *sl = [[SBSubLine alloc] initWithLine:res start:startTime end:endTime];
				[ss addLine:[sl autorelease]];
				state = INITIAL;
				break;
		};
	} while (![sc isAtEnd]);

    *duration = endTime;

    return 1;
}

int LoadChaptersFromPath(NSString *path, NSMutableArray *ss)
{
	NSMutableString *srt = STStandardizeStringNewlines(STLoadFileWithUnknownEncoding(path));
	if (!srt) return 0;

	if ([srt characterAtIndex:0] == 0xFEFF) [srt deleteCharactersInRange:NSMakeRange(0,1)];
	if ([srt characterAtIndex:[srt length]-1] != '\n') [srt appendFormat:@"%c",'\n'];

    NSScanner *sc = [NSScanner scannerWithString:srt];
	NSString *res=nil;
	[sc setCharactersToBeSkipped:nil];

	unsigned time=0;
    int count = 1;
	enum {
		TIMESTAMP,
		LINES
	} state = TIMESTAMP;

    if ([srt characterAtIndex:0] == 'C') { // ogg tools format
        do {
            switch (state) {
                case TIMESTAMP:
                    [sc scanUpToString:@"=" intoString:nil];
                    [sc scanString:@"=" intoString:nil];
                    [sc scanUpToString:@"\n" intoString:&res];
                    [sc scanString:@"\n" intoString:nil];
                    time = ParseSubTime([res UTF8String], 1000, NO);

                    state = LINES;
                    break;
                case LINES:
                    [sc scanUpToString:@"=" intoString:nil];
                    [sc scanString:@"=" intoString:nil];
                    if (!([sc scanUpToString:@"\n" intoString:&res]))
                        res = [NSString stringWithFormat:@"Chapter %d", count];
                    [sc scanString:@"\n" intoString:nil];

                    SBTextSample *chapter = [[SBTextSample alloc] init];
                    chapter.timestamp = time;
                    chapter.title = res;

                    [ss addObject:chapter];
                    count++;

                    [chapter release];
                    state = TIMESTAMP;
                    break;
            };
        } while (![sc isAtEnd]);
    }
    else  //mp4chaps format
    {
        do {
            switch (state) {
                case TIMESTAMP:
                    [sc scanUpToString:@" " intoString:&res];
                    [sc scanString:@" " intoString:nil];
                    time = ParseSubTime([res UTF8String], 1000, NO);

                    state = LINES;
                    break;
                case LINES:
                    if (!([sc scanUpToString:@"\n" intoString:&res]))
                        res = [NSString stringWithFormat:@"Chapter %d", count];

                    [sc scanString:@"\n" intoString:nil];

                    SBTextSample *chapter = [[SBTextSample alloc] init];
                    chapter.timestamp = time;
                    chapter.title = res;
                    
                    [ss addObject:chapter];
                    count++;

                    [chapter release];
                    state = TIMESTAMP;
                    break;
            };
        } while (![sc isAtEnd]);
    }
    
    return 1;
}

static int parse_SYNC(NSString *str)
{
	NSScanner *sc = [NSScanner scannerWithString:str];
    
	int res = 0;
    
	if ([sc scanString:@"START=" intoString:nil])
		[sc scanInt:&res];
    
	return res;
}

static NSArray *parse_STYLE(NSString *str)
{
	NSScanner *sc = [NSScanner scannerWithString:str];
    
	NSString *firstRes;
	NSString *secondRes;
	NSArray *subArray;
	int secondLoc;
    
	[sc scanUpToString:@"<P CLASS=" intoString:nil];
	if ([sc scanString:@"<P CLASS=" intoString:nil])
		[sc scanUpToString:@">" intoString:&firstRes];
	else
		firstRes = @"noClass";
    
	secondLoc = [str length] * .9;
	[sc setScanLocation:secondLoc];
    
	[sc scanUpToString:@"<P CLASS=" intoString:nil];
	if ([sc scanString:@"<P CLASS=" intoString:nil])
		[sc scanUpToString:@">" intoString:&secondRes];
	else
		secondRes = @"noClass";
    
	if ([firstRes isEqualToString:secondRes])
		secondRes = @"noClass";
    
	subArray = [NSArray arrayWithObjects:firstRes, secondRes, nil];
    
	return subArray;
}

static int parse_P(NSString *str, NSArray *subArray)
{
	NSScanner *sc = [NSScanner scannerWithString:str];
    
	NSString *res;
	int subLang;
    
	if ([sc scanString:@"CLASS=" intoString:nil])
		[sc scanUpToString:@">" intoString:&res];
	else
		res = @"noClass";
    
	if ([res isEqualToString:[subArray objectAtIndex:0]])
		subLang = 1;
	else if ([res isEqualToString:[subArray objectAtIndex:1]])
		subLang = 2;
	else
		subLang = 3;
    
	return subLang;
}

static NSString *parse_COLOR(NSString *str)
{
	NSString *cvalue;
	NSMutableString *cname = [NSMutableString stringWithString:str];
    
	if (![str length]) return str;
	
	if ([cname characterAtIndex:0] == '#' && [cname lengthOfBytesUsingEncoding:NSASCIIStringEncoding] == 7)
		cvalue = [NSString stringWithFormat:@"{\\1c&H%@%@%@&}", [cname substringWithRange:NSMakeRange(5,2)], [cname substringWithRange:NSMakeRange(3,2)], [cname substringWithRange:NSMakeRange(1,2)]];
	else {
		[cname replaceOccurrencesOfString:@"Aqua" withString:@"00FFFF" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Black" withString:@"000000" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Blue" withString:@"0000FF" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Fuchsia" withString:@"FF00FF" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Gray" withString:@"808080" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Green" withString:@"008000" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Lime" withString:@"00FF00" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Maroon" withString:@"800000" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Navy" withString:@"000080" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Olive" withString:@"808000" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Purple" withString:@"800080" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Red" withString:@"FF0000" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Silver" withString:@"C0C0C0" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Teal" withString:@"008080" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"White" withString:@"FFFFFF" options:1 range:NSMakeRange(0,[cname length])];
		[cname replaceOccurrencesOfString:@"Yellow" withString:@"FFFF00" options:1 range:NSMakeRange(0,[cname length])];
        
		if ([cname lengthOfBytesUsingEncoding:NSASCIIStringEncoding] == 6)
			cvalue = [NSString stringWithFormat:@"{\\1c&H%@%@%@&}", [cname substringWithRange:NSMakeRange(4,2)], [cname substringWithRange:NSMakeRange(2,2)], [cname substringWithRange:NSMakeRange(0,2)]];
		else
			cvalue = @"{\\1c&HFFFFFF&}";
	}
    
	return cvalue;
}

static NSString *parse_FONT(NSString *str)
{
	NSScanner *sc = [NSScanner scannerWithString:str];
    
	NSString *res;
	NSString *color;
    
	if ([sc scanString:@"COLOR=" intoString:nil]) {
		[sc scanUpToString:@">" intoString:&res];
		color = parse_COLOR(res);
	}
	else
		color = @"{\\1c&HFFFFFF&}";
    
	return color;
}

static NSMutableString *StandardizeSMIWhitespace(NSString *str)
{
	if (!str) return nil;
	NSMutableString *ms = [NSMutableString stringWithString:str];
	[ms replaceOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0,[ms length])];
	[ms replaceOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange(0,[ms length])];
	[ms replaceOccurrencesOfString:@"&nbsp;" withString:@" " options:0 range:NSMakeRange(0,[ms length])];
	return ms;
}

int LoadSMIFromPath(NSString *path, SBSubSerializer *ss, int subCount)
{
	NSMutableString *smi = StandardizeSMIWhitespace(STLoadFileWithUnknownEncoding(path));
	if (!smi) return 0;
    
	NSScanner *sc = [NSScanner scannerWithString:smi];
	NSString *res = nil;
	[sc setCharactersToBeSkipped:nil];
	[sc setCaseSensitive:NO];
	
	NSMutableString *cmt = [NSMutableString string];
	NSArray *subLanguage = parse_STYLE(smi);
    
	int startTime=-1, endTime=-1, syncTime=-1;
	int cc=1;
	
	enum {
		TAG_INIT,
		TAG_SYNC,
		TAG_P,
		TAG_BR_OPEN,
		TAG_BR_CLOSE,
		TAG_B_OPEN,
		TAG_B_CLOSE,
		TAG_I_OPEN,
		TAG_I_CLOSE,
		TAG_FONT_OPEN,
		TAG_FONT_CLOSE,
		TAG_COMMENT
	} state = TAG_INIT;
	
	do {
		switch (state) {
			case TAG_INIT:
				[sc scanUpToString:@"<SYNC" intoString:nil];
				if ([sc scanString:@"<SYNC" intoString:nil])
					state = TAG_SYNC;
				break;
			case TAG_SYNC:
				[sc scanUpToString:@">" intoString:&res];
				syncTime = parse_SYNC(res);
				if (startTime > -1) {
					endTime = syncTime;
					if (subCount == 2 && cc == 2)
						[cmt insertString:@"{\\an8}" atIndex:0];
					if ((subCount == 1 && cc == 1) || (subCount == 2 && cc == 2)) {
						SBSubLine *sl = [[SBSubLine alloc] initWithLine:cmt start:startTime end:endTime];
						[ss addLine:[sl autorelease]];
					}
				}
				startTime = syncTime;
				[cmt setString:@""];
				state = TAG_COMMENT;
				break;
			case TAG_P:
				[sc scanUpToString:@">" intoString:&res];
				cc = parse_P(res, subLanguage);
				[cmt setString:@""];
				state = TAG_COMMENT;
				break;
			case TAG_BR_OPEN:
				[sc scanUpToString:@">" intoString:nil];
				[cmt appendString:@"\\n"];
				state = TAG_COMMENT;
				break;
			case TAG_BR_CLOSE:
				[sc scanUpToString:@">" intoString:nil];
				[cmt appendString:@"\\n"];
				state = TAG_COMMENT;
				break;
			case TAG_B_OPEN:
				[sc scanUpToString:@">" intoString:&res];
				[cmt appendString:@"{\\b1}"];
				state = TAG_COMMENT;
				break;
			case TAG_B_CLOSE:
				[sc scanUpToString:@">" intoString:nil];
				[cmt appendString:@"{\\b0}"];
				state = TAG_COMMENT;
				break;
			case TAG_I_OPEN:
				[sc scanUpToString:@">" intoString:&res];
				[cmt appendString:@"{\\i1}"];
				state = TAG_COMMENT;
				break;
			case TAG_I_CLOSE:
				[sc scanUpToString:@">" intoString:nil];
				[cmt appendString:@"{\\i0}"];
				state = TAG_COMMENT;
				break;
			case TAG_FONT_OPEN:
				[sc scanUpToString:@">" intoString:&res];
				[cmt appendString:parse_FONT(res)];
				state = TAG_COMMENT;
				break;
			case TAG_FONT_CLOSE:
				[sc scanUpToString:@">" intoString:nil];
				[cmt appendString:@"{\\1c&HFFFFFF&}"];
				state = TAG_COMMENT;
				break;
			case TAG_COMMENT:
				[sc scanString:@">" intoString:nil];
				if ([sc scanUpToString:@"<" intoString:&res])
					[cmt appendString:res];
				else
					[cmt appendString:@"<>"];
				if ([sc scanString:@"<" intoString:nil]) {
					if ([sc scanString:@"SYNC" intoString:nil]) {
						state = TAG_SYNC;
						break;
					}
					else if ([sc scanString:@"P" intoString:nil]) {
						state = TAG_P;
						break;
					}
					else if ([sc scanString:@"BR" intoString:nil]) {
						state = TAG_BR_OPEN;
						break;
					}
					else if ([sc scanString:@"/BR" intoString:nil]) {
						state = TAG_BR_CLOSE;
						break;
					}
					else if ([sc scanString:@"B" intoString:nil]) {
						state = TAG_B_OPEN;
						break;
					}
					else if ([sc scanString:@"/B" intoString:nil]) {
						state = TAG_B_CLOSE;
						break;
					}
					else if ([sc scanString:@"I" intoString:nil]) {
						state = TAG_I_OPEN;
						break;
					}
					else if ([sc scanString:@"/I" intoString:nil]) {
						state = TAG_I_CLOSE;
						break;
					}
					else if ([sc scanString:@"FONT" intoString:nil]) {
						state = TAG_FONT_OPEN;
						break;
					}
					else if ([sc scanString:@"/FONT" intoString:nil]) {
						state = TAG_FONT_CLOSE;
						break;
					}
					else {
						[cmt appendString:@"<"];
						state = TAG_COMMENT;
						break;
					}
				}
		}
	} while (![sc isAtEnd]);
    return 1;
}

int ParseSSAHeader(NSString *header) {
    NSString *info;
    NSString *styles;
    //NSString *splitLine  = @"\\n+";
    //NSArray * stylesArray;

    //NSLog(@"%@", header);
    NSScanner *sc = [NSScanner scannerWithString:header];
	[sc setCharactersToBeSkipped:nil];

    [sc scanUpToString:@"[V4+ Styles]" intoString:&info];
    if (info) {
    }
    [sc scanUpToString:@"[Events]" intoString:&styles];
    if (styles) {
        //stylesArray = [styles componentsSeparatedByRegex:splitLine];
        //NSLog(@"%@", styles);
    }
    [sc scanUpToString:@"Format:" intoString:nil];

    return 0;
}

NSString* StripSSALine(NSString *line){
    NSUInteger i = 0;

    NSScanner *sc = [NSScanner scannerWithString:line];
    for (i = 0; i < 8; i++) {
        [sc scanUpToString:@"," intoString:nil];
        [sc scanString:@"," intoString:nil];
    }

    line = [[sc string]substringFromIndex:[sc scanLocation]];

    NSRange startRange = [line rangeOfString: @"}"];
    while (startRange.location != NSNotFound) {
        NSRange endRange = [line rangeOfString: @"{"];
        if (endRange.location != NSNotFound && endRange.length != 0) {
            NSString * replacement = @"";
            if (endRange.location + 3 < [line length]) {
                unichar tag = [line characterAtIndex:endRange.location + 2];
                unichar tagState = [line characterAtIndex:endRange.location + 3];
                if (tagState == '1') {
                    if (tag == 'i') replacement = @"<i>";
                    else if (tag == 'b') replacement = @"<b>";
                    else if (tag == 'u') replacement = @"<u>";
                }
                else if (tagState == '0'){
                    if (tag == 'i') replacement = @"</i>";
                    else if (tag == 'b') replacement = @"</b>";
                    else if (tag == 'u') replacement = @"</u>";
                }
            }
            endRange.length = startRange.location - endRange.location +1;
            line = [line stringByReplacingCharactersInRange:endRange withString:replacement];
            startRange = [line rangeOfString: @"}"];
        }
        else
            break;
    }

    startRange = [line rangeOfString: @"\\N"];
    while (startRange.location != NSNotFound) {
        startRange.length = 2;
        line = [line stringByReplacingCharactersInRange:startRange withString:@"\n"];
        startRange = [line rangeOfString: @"\\N"];
    }
    
    startRange = [line rangeOfString: @"\\n"];
    while (startRange.location != NSNotFound) {
        startRange.length = 2;
        line = [line stringByReplacingCharactersInRange:startRange withString:@"\n"];
        startRange = [line rangeOfString: @"\\n"];
    }

    return line;
}

#define STYLE_BOLD 1
#define STYLE_ITALIC 2
#define STYLE_UNDERLINED 4

u_int8_t* createStyleRecord(u_int16_t startChar, u_int16_t endChar, u_int16_t fontID, u_int8_t flags, u_int8_t* style)
{
    style[0] = (startChar >> 8) & 0xff; // startChar
    style[1] = startChar & 0xff;
    style[2] = (endChar >> 8) & 0xff;   // endChar
    style[3] = endChar & 0xff;
    style[4] = (fontID >> 8) & 0xff;    // font-ID
    style[5] = fontID & 0xff;
    style[6] = flags;   // face-style-flags: 1 bold; 2 italic; 4 underline
    style[7] = 24;      // font-size
    style[8] = 255;     // r
    style[9] = 255;     // g
    style[10] = 255;    // b
    style[11] = 255;    // a
    
    return style;
}

size_t closeStyleAtom(u_int16_t styleCount, u_int8_t* styleAtom)
{
    size_t styleSize = 10 + (styleCount * 12);
    styleAtom[0] = 0;
    styleAtom[1] = 0;
    styleAtom[2] = (styleSize >> 8) & 0xff;
    styleAtom[3] = styleSize & 0xff;
    styleAtom[8] = (styleCount >> 8) & 0xff;
    styleAtom[9] = styleCount & 0xff;
    
    return styleSize;
}

NSString* createStyleAtomForString(NSString* string, u_int8_t* buffer, size_t *size)
{
    u_int16_t styleCount = 0;
    memcpy(buffer + 4, "styl", 4);

    u_int8_t italic = 0;
    u_int8_t bold = 0;
    u_int8_t underlined = 0;

    // Parse the tags in the line, remove them and create a style record for every style change
    NSRange endRange;
    NSRange tagEndRange;
    NSRange startRange = [string rangeOfString: @"<"];
    if (startRange.location != NSNotFound) {
        if ((startRange.location + 1) < [string length]) {
            unichar tag = [string characterAtIndex:startRange.location + 1];
            if (tag == 'i') italic++;
            else if (tag == 'b') bold++;
            else if (tag == 'u') underlined++;
            tagEndRange = [string rangeOfString: @">"];
            startRange.length = tagEndRange.location - startRange.location +1;
            if (tagEndRange.location == NSNotFound || startRange.location > tagEndRange.location || startRange.length > [string length])
                startRange.length = 2;
            string = [string stringByReplacingCharactersInRange:startRange withString:@""];
            }
        else
            startRange.location = NSNotFound;
    }

    while (startRange.location != NSNotFound) {
        endRange = [string rangeOfString: @"<"];
        if (endRange.location == NSNotFound)
            endRange.location = [string length] -1;

        u_int8_t styl = 0;
        if (italic) styl |= STYLE_ITALIC;
        if (bold) styl |= STYLE_BOLD;
        if (underlined) styl |= STYLE_UNDERLINED;

        if (styl && startRange.location != endRange.location) {
            u_int8_t styleRecord[12];
            createStyleRecord(startRange.location, endRange.location, 1, styl, styleRecord);
            memcpy(buffer + 10 + (12 * styleCount), styleRecord, 12);
            styleCount++;
        }

        endRange = [string rangeOfString: @"<"];
        if (endRange.location != NSNotFound && (endRange.location + 1) < [string length]) {
            unichar tag = [string characterAtIndex:endRange.location + 1];
            if (tag == 'i') italic++;
            else if (tag == 'b') bold++;
            else if (tag == 'u') underlined++;

            if (tag == '/' && (endRange.location + 2) < [string length]) {
                unichar tag2 = [string characterAtIndex:endRange.location + 2];
                if (tag2 == 'i') italic--;
                else if (tag2 == 'b') bold--;
                else if (tag2 == 'u') underlined--;
                tagEndRange = [string rangeOfString: @">"];
                if (tagEndRange.location < endRange.location) {
                    string = [string stringByReplacingCharactersInRange:tagEndRange withString:@""];
                    tagEndRange = [string rangeOfString: @">"];
                }
                endRange.length = tagEndRange.location - endRange.location +1;
                if (tagEndRange.location == NSNotFound || endRange.length > [string length])
                    endRange.length = 2;
                string = [string stringByReplacingCharactersInRange:endRange withString:@""];
            }
            else {
                tagEndRange = [string rangeOfString: @">"];
                endRange.length = tagEndRange.location - endRange.location +1;
                if (tagEndRange.location == NSNotFound || endRange.length > [string length])
                    endRange.length = 2;
                string = [string stringByReplacingCharactersInRange:endRange withString:@""];
            }
            startRange = endRange;
        }
        else
            break;
    }

    if (styleCount)
        *size = closeStyleAtom(styleCount, buffer);
    
    return string;
}

NSString* removeNewLines(NSString* string) {
    NSMutableString *mutableString = [NSMutableString stringWithString:string];

	[mutableString replaceOccurrencesOfString:@"\r\n" withString:@"\n" options:0 range:NSMakeRange(0,[mutableString length])];
	[mutableString replaceOccurrencesOfString:@"\r" withString:@"\n" options:0 range:NSMakeRange(0,[mutableString length])];

    while ([mutableString length] && [mutableString characterAtIndex:[mutableString length] - 1] == '\n')
        [mutableString deleteCharactersInRange:NSMakeRange([mutableString length] -1, 1)];

    NSMutableString *mutableString2 = [NSMutableString stringWithString:mutableString];
    NSUInteger       replacedCount  = 0;

    replacedCount = [mutableString2 replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0,[mutableString2 length])];
    if (replacedCount >= 2)
        return mutableString2;
    else
        return mutableString;
}

void createForcedAtom(u_int8_t* buffer) {
    buffer[0] = 0;
    buffer[1] = 0;
    buffer[2] = 0;
    buffer[3] = 8;
    buffer[4] = 'f';
    buffer[5] = 'r';
    buffer[6] = 'c';
    buffer[7] = 'd';
}

MP42SampleBuffer* copySubtitleSample(MP4TrackId subtitleTrackId, NSString* string, MP4Duration duration, BOOL forced)
{
    uint8_t *sampleData = NULL;
    u_int8_t styleAtom[2048];
    size_t styleSize = 0;
    size_t sampleSize = 0;

    string = removeNewLines(string);
    string = createStyleAtomForString(string, styleAtom, &styleSize);

    size_t stringLength = strlen([string UTF8String]);

    u_int8_t buffer[8192];
    if (stringLength > 2048) {
        stringLength = 2048;
    }

    memcpy(buffer+2, [string UTF8String], stringLength);
    memcpy(buffer+2+stringLength, styleAtom, styleSize);
    sampleSize = 2 + stringLength + styleSize;
    if (forced) {
        u_int8_t forcedAtom[8];
        createForcedAtom(forcedAtom);

        memcpy(buffer + sampleSize, forcedAtom, 8);
        sampleSize += 8;
    }

    buffer[0] = (stringLength >> 8) & 0xff;
    buffer[1] = stringLength & 0xff;

    sampleData = malloc(sampleSize);
    memcpy(sampleData, buffer, sampleSize);

    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
    sample->sampleData = sampleData;
    sample->sampleSize = sampleSize;
    sample->sampleDuration = duration;
    sample->sampleOffset = 0;
    sample->sampleTimestamp = duration;
    sample->sampleIsSync = true;
    sample->sampleTrackId = subtitleTrackId;

    return sample;
}

MP42SampleBuffer* copyEmptySubtitleSample(MP4TrackId subtitleTrackId, MP4Duration duration, BOOL forced)
{
    uint8_t *sampleData = NULL;
    u_int8_t empty[2] = {0,0};

    sampleData = malloc(2);
    memcpy(sampleData, empty, 2);

    MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
    sample->sampleData = sampleData;
    sample->sampleSize = 2;
    sample->sampleDuration = duration;
    sample->sampleOffset = 0;
    sample->sampleTimestamp = duration;
    sample->sampleIsSync = true;
    sample->sampleTrackId = subtitleTrackId;

    return sample;
}

/* VobSub related */
int ExtractVobSubPacket(UInt8 *dest, UInt8 *framedSrc, int srcSize, int *usedSrcBytes, int index) {
	int copiedBytes = 0;
	UInt8 *currentPacket = framedSrc;
	int packetSize = INT_MAX;
	
	while (currentPacket - framedSrc < srcSize && copiedBytes < packetSize) {
		// 3-byte start code: 0x00 00 01
		if (currentPacket[0] + currentPacket[1] != 0 || currentPacket[2] != 1) {
			//Codecprintf(NULL, "VobSub Codec: !! Unknown header: %02x %02x %02x\n", currentPacket[0], currentPacket[1], currentPacket[2]);
			return copiedBytes;
		}
		
		int packet_length;
		
		switch (currentPacket[3]) {
			case 0xba:
				// discard PS packets; nothing in them we're interested in
				// here, packet_length is the additional stuffing
				packet_length = currentPacket[13] & 0x7;
				
				currentPacket += 14 + packet_length;
				break;
				
			case 0xbe:
			case 0xbf:
				// skip padding and navigation data
				// (navigation shouldn't be present anyway)
				packet_length = currentPacket[4];
				packet_length <<= 8;
				packet_length += currentPacket[5];
				
				currentPacket += 6 + packet_length;
				break;
				
			case 0xbd:
				// a private stream packet, contains subtitle data
				packet_length = currentPacket[4];
				packet_length <<= 8;
				packet_length += currentPacket[5];
				
				int header_data_length = currentPacket[8];
				int packetIndex = currentPacket[header_data_length + 9] & 0x1f;
				if(index == -1)
					index = packetIndex;
				if(index == packetIndex)
				{
					int blockSize = packet_length - 1 - (header_data_length + 3);
					memcpy(&dest[copiedBytes],
						   // header's 9 bytes + extension, we don't want 1st byte of packet
						   &currentPacket[9 + header_data_length + 1],
						   // we don't want the 1-byte stream ID, or the header
						   blockSize);
					copiedBytes += blockSize;
                    
					if(packetSize == INT_MAX)
					{
						packetSize = dest[0] << 8 | dest[1];
					}
				}
				currentPacket += packet_length + 6;
				break;
				
			default:
				// unknown packet, probably video, return for now
				//Codecprintf(NULL, "VobSubCodec - Unknown packet type %x, aborting\n", (int)currentPacket[3]);
				return copiedBytes;
		} // switch (currentPacket[3])
	} // while (currentPacket - framedSrc < srcSize)
	if(usedSrcBytes != NULL)
		*usedSrcBytes = currentPacket - framedSrc;
	
	return copiedBytes;
}

ComponentResult ReadPacketControls(UInt8 *packet, UInt32 palette[16], PacketControlData *controlDataOut,BOOL *forced) {
	// to set whether the key sequences 0x03 - 0x06 have been seen
	UInt16 controlSeqSeen = 0;
	int i = 0;
	Boolean loop = TRUE;
	int controlOffset = (packet[2] << 8) + packet[3] + 4;
	uint8_t *controlSeq = packet + controlOffset;
	
	memset(controlDataOut, 0, sizeof(PacketControlData));
	
	while (loop) {
		switch (controlSeq[i]) {
			case 0x00:
				// subpicture identifier, we don't care
                *forced = YES;
				i++;
				break;
				
			case 0x01:
				// start displaying, we don't care
				i++;
				break;
				
			case 0x03:
				// palette info
				controlDataOut->pixelColor[3] += palette[controlSeq[i+1] >> 4 ];
				controlDataOut->pixelColor[2] += palette[controlSeq[i+1] & 0xf];
				controlDataOut->pixelColor[1] += palette[controlSeq[i+2] >> 4 ];
				controlDataOut->pixelColor[0] += palette[controlSeq[i+2] & 0xf];
				
				i += 3;
				controlSeqSeen |= 0x0f;
				break;
				
			case 0x04:
				// alpha info
				controlDataOut->pixelColor[3] += (controlSeq[i + 1] & 0xf0) << 20;
				controlDataOut->pixelColor[2] += (controlSeq[i + 1] & 0x0f) << 24;
				controlDataOut->pixelColor[1] += (controlSeq[i + 2] & 0xf0) << 20;
				controlDataOut->pixelColor[0] += (controlSeq[i + 2] & 0x0f) << 24;
				
				// double the nibble
				controlDataOut->pixelColor[3] += (controlSeq[i + 1] & 0xf0) << 24;
				controlDataOut->pixelColor[2] += (controlSeq[i + 1] & 0x0f) << 28;
				controlDataOut->pixelColor[1] += (controlSeq[i + 2] & 0xf0) << 24;
				controlDataOut->pixelColor[0] += (controlSeq[i + 2] & 0x0f) << 28;
				
				i += 3;
				controlSeqSeen |= 0xf0;
				break;
				
			case 0x05:
				// coordinates of image, ffmpeg takes care of this
				i += 7;
				break;
				
			case 0x06:
				// offset of the first graphic line, and second, ffmpeg takes care of this
				i += 5;
				break;
				
			case 0xff:
				// end of control sequence
				loop = FALSE;
				break;
				
			default:
				NSLog(@"!! Unknown control sequence 0x%02x  aborting (offset %x)\n", controlSeq[i], i);
				loop = FALSE;
				break;
		}
	}
	
	// force fully transparent to transparent black; needed? for graphicsModePreBlackAlpha
	for (i = 0; i < 4; i++) {
		if ((controlDataOut->pixelColor[i] & 0xff000000) == 0)
			controlDataOut->pixelColor[i] = 0;
	}
	
	if (controlSeqSeen != 0xff)
		return -1;
	return noErr;
}

Boolean ReadPacketTimes(uint8_t *packet, uint32_t length, uint16_t *startTime, uint16_t *endTime, uint8_t *forced) {
	// to set whether the key sequences 0x01 - 0x02 have been seen
	Boolean loop = TRUE;
	*startTime = *endTime = 0;
	*forced = 0;
    
	int controlOffset = (packet[2] << 8) + packet[3];
	while(loop)
	{
		if(controlOffset > length)
			return NO;
		uint8_t *controlSeq = packet + controlOffset;
		int32_t i = 4;
		int32_t end = length - controlOffset;
		uint16_t timestamp = (controlSeq[0] << 8) | controlSeq[1];
		uint16_t nextOffset = (controlSeq[2] << 8) + controlSeq[3];
		while (i < end) {
			switch (controlSeq[i]) {
				case 0x00:
					*forced = 1;
					i++;
					break;
					
				case 0x01:
					*startTime = (timestamp << 10) / 90;
					i++;
					break;
                    
				case 0x02:
					*endTime = (timestamp << 10) / 90;
					i++;
					loop = false;
					break;
					
				case 0x03:
					// palette info, we don't care
					i += 3;
					break;
					
				case 0x04:
					// alpha info, we don't care
					i += 3;
					break;
					
				case 0x05:
					// coordinates of image, ffmpeg takes care of this
					i += 7;
					break;
					
				case 0x06:
					// offset of the first graphic line, and second, ffmpeg takes care of this
					i += 5;
					break;
					
				case 0xff:
					// end of control sequence
					if(controlOffset == nextOffset)
						loop = false;
					controlOffset = nextOffset;
					i = INT_MAX;
					break;
					
				default:
					return NO;
					break;
			}
		}
		if(i != INT_MAX)
		{
			//End of packet
			loop = false;
		}
	}
	return YES;
}
