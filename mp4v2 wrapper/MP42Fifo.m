//
//  MP42Fifo.m
//  Subler
//
//  Created by Damiano Galassi on 09/08/13.
//
//

#import "MP42Fifo.h"

@implementation MP42Fifo

- (id)init
{
    self = [super init];
    if (self) {
        _size = 300;
        _iSize = _size * 4;
        _queue = dispatch_queue_create("com.subler.fifo", DISPATCH_QUEUE_SERIAL);
        _array = (id *) malloc(sizeof(id) * _iSize);
    }
    return self;
}

- (id)initWithCapacity:(NSUInteger)numItems;
{
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.subler.fifo", DISPATCH_QUEUE_SERIAL);
        _size = numItems;
        _iSize = numItems * 4;
        _array = (id *) malloc(sizeof(id) * _iSize);
    }
    return self;
}

- (void)enqueue:(id)item {
    [item retain];

    dispatch_sync(_queue, ^{
        _array[_tail++ % _iSize] = item;
        OSAtomicIncrement32(&_count);
    });
}

- (id)deque {
    __block id item;

    if (!_count)
        return nil;

    dispatch_sync(_queue, ^{
        item = _array[_head++ % _iSize];
        OSAtomicDecrement32(&_count);
    });

    return item;
}

- (NSInteger)count {
    return _count;
}

- (BOOL)isFull {
    return (_count > _size);
}

- (BOOL)isEmpty {
    return !_count;
}

- (void)dealloc
{
    while ([self count])
        [[self deque] release];

	free(_array);
    dispatch_release(_queue);

    [super dealloc];
}

@end
