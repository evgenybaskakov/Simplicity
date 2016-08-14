//
//  SMMessageThreadAccountProxy.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/19/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMFolder;
@class SMMessageThread;

@interface SMMessageThreadAccountProxy : NSObject

- (void)setMessageUnseen:(SMMessageThread*)messageThread message:(SMMessage*)message unseen:(Boolean)unseen;
- (void)setMessageFlagged:(SMMessageThread*)messageThread message:(SMMessage*)message flagged:(Boolean)flagged;
- (void)addMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label;
- (BOOL)removeMessageThreadLabel:(SMMessageThread*)messageThread label:(NSString*)label;
- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels;
- (void)fetchMessageBodyUrgently:(SMMessageThread*)messageThread uid:(uint32_t)uid messageId:(uint64_t)messageId messageDate:(NSDate*)messageDate remoteFolder:(NSString*)remoteFolderName;

@end
