//
//  MP42Fifo.m
//  Subler
//
//  Created by Damiano Galassi on 09/08/13.
//
//

#import "MP42Fifo.h"

@implementation MP42Fifo

- (NSString *)queueName {
    static int32_t queueCount = 0;
    return [NSString stringWithFormat:@"com.subler.fifo-%d", queueCount++];
}

- (id)init {
    self = [self initWithCapacity:300];

    return self;
}

- (id)initWithCapacity:(NSUInteger)numItems {
    self = [super init];
    if (self) {
        _size = numItems;
        _iSize = numItems * 4;
        _queue = dispatch_queue_create([[self queueName] UTF8String], DISPATCH_QUEUE_SERIAL);
        _array = (id *) malloc(sizeof(id) * _iSize);
    }
    return self;
}

- (void)enqueue:(id)item {
    while (_count > _size && !_cancelled)
        usleep(500);

    if (_cancelled)
        return;

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

- (void)drain {
    while (![self isEmpty])
        [[self deque] release];
}

- (void)cancel {
    OSAtomicIncrement32(&_cancelled);
}

- (void)dealloc {
    [self drain];

	free(_array);
    dispatch_release(_queue);

    [super dealloc];
}

@end
