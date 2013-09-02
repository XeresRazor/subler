//
//  SBImageBrowserView.m
//  Subler
//
//  Created by Damiano Galassi on 02/09/13.
//
//

#import "SBImageBrowserView.h"

@implementation SBImageBrowserView

@synthesize _pasteboardTypes;

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    id delegate = [self delegate];
    SEL action = [item action];

    if (action == @selector(paste:)) {
        if (![self pasteboardHasSupportedType] || ![delegate respondsToSelector:@selector(_pasteToImageBrowserView:)])
            return NO;
        else
            return YES;
    }
    else
        return [super validateMenuItem:item];
}

- (IBAction)paste:(id)sender
{
    if ([[self delegate] respondsToSelector:@selector(_pasteToImageBrowserView:)])
        [(SBImageBrowserView *)[self delegate] _pasteToImageBrowserView:self];
}

- (BOOL)pasteboardHasSupportedType {
    // has the pasteboard got a type we support?
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *bestType = [pb availableTypeFromArray:_pasteboardTypes];
    return (bestType != nil);

    return YES;
}

@end
