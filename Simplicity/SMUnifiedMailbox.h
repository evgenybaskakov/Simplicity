//
//  SMUnifiedMailbox.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

@class SMMailbox;
@class SMFolder;

@interface SMUnifiedMailbox : NSObject

@property NSArray<SMFolder*> *mainFolders;
@property BOOL loaded;

- (id)init;
- (void)addMailbox:(SMMailbox*)mailbox;
- (void)removeMailbox:(SMMailbox*)mailbox;
- (void)updateMailbox:(SMMailbox*)mailbox;

@end
