//
//  MP42Fifo.m
//  Subler
//
//  Created by Damiano Galassi on 09/08/13.
//
//

#import "MP42Fifo.h"

@implementation MP42Fifo

- (instancetype)init {
    self = [self initWithCapacity:300];
    return self;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems {
    self = [super init];
    if (self) {
        _size = numItems;
        _array = (id *) malloc(sizeof(id) * _size);
        _sem = dispatch_semaphore_create(_size);
    }
    return self;
}

- (void)enqueue:(id)item {
    if (_cancelled) return;

    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);

    [item retain];

    _array[_tail++] = item;

    if (_tail == _size)
        _tail = 0;

    OSAtomicIncrement32(&_count);
}

- (id)deque {
    if (!_count) return nil;

    id item = _array[_head++];

    if (_head == _size)
        _head = 0;

    OSAtomicDecrement32(&_count);
    dispatch_semaphore_signal(_sem);

    return item;
}

- (NSInteger)count {
    return _count;
}

- (BOOL)isFull {
    return (_count >= _size);
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
    [self drain];
}

- (void)dealloc {
    [self drain];

	free(_array);
    dispatch_release(_sem);

    [super dealloc];
}

@end
