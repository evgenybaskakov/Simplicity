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

static NSComparisonResult compareMessageIds(uint64_t messageId1, uint64_t messageId2) {
    return (messageId1 == messageId2? NSOrderedSame : (messageId1 > messageId2? NSOrderedAscending : NSOrderedDescending));
}

static NSComparisonResult compareMessagesByMessageId(SMMessage *a, SMMessage *b) {
    uint64_t messageId1 = [(SMMessage*)a messageId];
    uint64_t messageId2 = [(SMMessage*)b messageId];
    
    return compareMessageIds(messageId1, messageId2);
}

static NSComparisonResult compareThreadsByThreadId(SMMessageThread *a, SMMessageThread *b) {
    if(a.threadId == b.threadId) {
        // Note: threads still can be different.
        // Such collision may happen in a unified local folder.
        return NSOrderedSame;
    }
    
    return a.threadId < b.threadId? NSOrderedAscending : NSOrderedDescending;
}

@implementation SMMessageComparators

- (id)init {
    self = [super init];
    if(self) {
        _messagesComparatorByImapMessage = ^NSComparisonResult(id a, id b) {
            uint64_t messageId1 = 0, messageId2 = 0;
            
            if([a isKindOfClass:[MCOIMAPMessage class]]) {
                messageId1 = [(MCOIMAPMessage*)a gmailMessageID];
                messageId2 = [(SMMessage*)b messageId];
            } else {
                messageId1 = [(SMMessage*)a messageId];
                messageId2 = [(MCOIMAPMessage*)b gmailMessageID];
            }
            
            return compareMessageIds(messageId1, messageId2);
        };

        _messagesComparatorByMessageId = ^NSComparisonResult(id a, id b) {
            uint64_t messageId1 = 0, messageId2 = 0;
            
            if([a isKindOfClass:[NSNumber class]]) {
                messageId1 = [(NSNumber*)a unsignedLongLongValue];
                messageId2 = [(SMMessage*)b messageId];
            }
            else {
                messageId1 = [(SMMessage*)a messageId];
                messageId2 = [(NSNumber*)b unsignedLongLongValue];
            }
            
            return compareMessageIds(messageId1, messageId2);
        };
        
        _messagesComparatorByDate = ^NSComparisonResult(id a, id b) {
            NSDate *date1 = [(SMMessage*)a date];
            NSDate *date2 = [(SMMessage*)b date];
            
            NSComparisonResult dateComparisonResult = [date2 compare:date1];

            if(dateComparisonResult == NSOrderedSame) {
                return compareMessagesByMessageId(a, b);
            }
            
            return dateComparisonResult;
        };

        _messagesComparatorBySequenceNumber = ^NSComparisonResult(MCOIMAPMessage *m1, MCOIMAPMessage *m2) {
            return m1.sequenceNumber < m2.sequenceNumber? NSOrderedDescending : (m1.sequenceNumber == m2.sequenceNumber? NSOrderedSame : NSOrderedAscending);
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
