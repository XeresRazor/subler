//
//  MP42Fifo.h
//  Subler
//
//  Created by Damiano Galassi on 09/08/13.
//
//

#import <Foundation/Foundation.h>

@interface MP42Fifo : NSObject {
    id *_array;

    int32_t     _head;
    int32_t     _tail;

    int32_t     _count;
    int32_t     _size;
    int32_t     _iSize;

    int32_t     _cancelled;

    dispatch_queue_t _queue;
}

- (id)init;
- (id)initWithCapacity:(NSUInteger)numItems;

- (void)enqueue:(id)item;
- (id)deque NS_RETURNS_RETAINED;

- (NSInteger)count;

- (BOOL)isFull;
- (BOOL)isEmpty;

- (void)drain;
- (void)cancel;

@end
