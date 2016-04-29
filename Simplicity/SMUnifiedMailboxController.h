//
//  SMUnifiedMailboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMFolder;

@interface SMUnifiedMailboxController : NSObject

@property SMFolder *selectedFolder;

- (id)init;
- (NSUInteger)unseenMessagesCount:(NSString*)folderName;
- (NSUInteger)totalMessagesCount:(NSString*)folderName;

@end
