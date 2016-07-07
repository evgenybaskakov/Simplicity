//
//  SMMessageComparators.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMMessageComparators : NSObject

@property (readonly) NSComparator messagesComparatorByImapMessage;
@property (readonly) NSComparator messagesComparatorByMessageId;
@property (readonly) NSComparator messagesComparatorByDate;
@property (readonly) NSComparator messagesComparatorBySequenceNumber;
@property (readonly) NSComparator messageThreadsComparatorByDate;

@end
