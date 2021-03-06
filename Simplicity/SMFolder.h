//
//  SMFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/23/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import <Foundation/Foundation.h>

#import "SMFolderKind.h"

@interface SMFolder : NSObject

@property (readonly) char delimiter;
@property (readonly) NSString *fullName;
@property (readonly) MCOIMAPFolderFlag mcoFlags;
@property (readonly) NSUInteger initialUnreadCount;

@property NSString *displayName;
@property SMFolderKind kind;

- (id)initWithFullName:(NSString*)fullName delimiter:(char)delimiter mcoFlags:(MCOIMAPFolderFlag)mcoFlags initialUnreadCount:(NSUInteger)initialUnreadCount kind:(SMFolderKind)kind;

@end
