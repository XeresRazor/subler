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

    int32_t     _cancelled;

    dispatch_semaphore_t _full;
    dispatch_semaphore_t _empty;
}

- (instancetype)init;
- (instancetype)initWithCapacity:(NSUInteger)numItems;

- (void)enqueue:(id)item;
- (id)deque NS_RETURNS_RETAINED;
- (id)dequeAndWait NS_RETURNS_RETAINED;

- (NSInteger)count;

- (BOOL)isFull;
- (BOOL)isEmpty;

- (void)drain;
- (void)cancel;

@end
