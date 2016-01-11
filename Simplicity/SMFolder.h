//
//  SMFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/23/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SMFolderKind) {
    SMFolderKindRegular,
    SMFolderKindInbox,
    SMFolderKindImportant,
    SMFolderKindSent,
    SMFolderKindSpam,
    SMFolderKindOutbox,
    SMFolderKindStarred,
    SMFolderKindDrafts,
    SMFolderKindTrash,
    SMFolderKindAllMail,
    SMFolderKindSearch,
};

@interface SMFolder : NSObject

@property (readonly) char delimiter;
@property (readonly) NSString *fullName;
@property (readonly) MCOIMAPFolderFlag flags;

@property NSString *displayName;
@property SMFolderKind kind;

- (id)initWithFullName:(NSString*)fullName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags;

@end
