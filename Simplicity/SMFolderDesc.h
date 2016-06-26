//
//  SMFolderDesc.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/20/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/MailCore.h>

@interface SMFolderDesc : NSObject

@property (readonly) NSString *folderName;
@property (readonly) char delimiter;
@property (readonly) MCOIMAPFolderFlag flags;

@property NSUInteger unreadCount;

- (id)initWithFolderName:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags unreadCount:(NSUInteger)unreadCount;

@end
