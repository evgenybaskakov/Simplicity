//
//  SMMessageComparators.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import "SMMessage.h"
#import "SMMessageThread.h"
#import "SMMessageComparators.h"

static NSComparisonResult compareUIDs(uint32_t uid1, uint32_t uid2) {
    return (uid1 == uid2? NSOrderedSame : (uid1 > uid2? NSOrderedAscending : NSOrderedDescending));
}

static NSComparisonResult compareMessagesByUID(SMMessage *a, SMMessage *b) {
    uint32_t uid1 = [(SMMessage*)a uid];
    uint32_t uid2 = [(SMMessage*)b uid];

    return compareUIDs(uid1, uid2);
}

static NSComparisonResult compareThreadsByThreadId(SMMessageThread *a, SMMessageThread *b) {
    if(a.threadId == b.threadId) {
        assert(a == b);
        return NSOrderedSame;
    }
    
    return a.threadId < b.threadId? NSOrderedAscending : NSOrderedDescending;
}

@implementation SMMessageComparators

- (id)init {
    self = [super init];
    if(self) {
        _messagesComparator = ^NSComparisonResult(id a, id b) {
            return compareMessagesByUID(a, b);
        };
        
        _messagesComparatorByImapMessage = ^NSComparisonResult(id a, id b) {
            uint32_t uid1 = 0, uid2 = 0;
            
            if([a isKindOfClass:[MCOIMAPMessage class]]) {
                uid1 = [(MCOIMAPMessage*)a uid];
                uid2 = [(SMMessage*)b uid];
            } else {
                uid1 = [(SMMessage*)a uid];
                uid2 = [(MCOIMAPMessage*)b uid];
            }
            
            return compareUIDs(uid1, uid2);
        };
        
        _messagesComparatorByUID = ^NSComparisonResult(id a, id b) {
            uint32_t uid1 = 0, uid2 = 0;
            
            if([a isKindOfClass:[NSNumber class]]) {
                uid1 = [(NSNumber*)a unsignedIntValue];
                uid2 = [(SMMessage*)b uid];
            } else {
                uid1 = [(SMMessage*)a uid];
                uid2 = [(NSNumber*)b unsignedIntValue];
            }
            
            return compareUIDs(uid1, uid2);
        };
        
        _messagesComparatorByDate = ^NSComparisonResult(id a, id b) {
            NSDate *date1 = [(SMMessage*)a date];
            NSDate *date2 = [(SMMessage*)b date];
            
            NSComparisonResult dateComparisonResult = [date2 compare:date1];

            if(dateComparisonResult == NSOrderedSame) {
                return compareMessagesByUID(a, b);
            }
            
            return dateComparisonResult;
        };
        
        _messageThreadsComparatorByDate = ^NSComparisonResult(id a, id b) {
            if([a messagesCount] == 0) {
                if([b messagesCount] == 0) {
                    return compareThreadsByThreadId(a, b);
                }

                return NSOrderedAscending;
            } else if([b messagesCount] == 0) {
                return NSOrderedDescending;
            }

            SMMessage *message1 = [a messagesSortedByDate].firstObject;
            SMMessage *message2 = [b messagesSortedByDate].firstObject;
            
            NSDate *date1 = [message1 date];
            NSDate *date2 = [message2 date];

            NSComparisonResult dateComparisonResult = [date2 compare:date1];
            
            if(dateComparisonResult == NSOrderedSame) {
                return compareThreadsByThreadId(a, b);
            }
            
            return dateComparisonResult;
        };
    }

    return self;
}

@end
