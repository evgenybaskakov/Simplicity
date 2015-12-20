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
};

@interface SMFolder : NSObject

@property (readonly) char delimiter;
@property (readonly) NSString *shortName;
@property (readonly) NSString *fullName;
@property (readonly) NSArray *subfolders;
@property (readonly) MCOIMAPFolderFlag flags;

@property NSString *displayName;
@property SMFolderKind kind;

- (id)initWithShortName:(NSString*)shortName fullName:(NSString*)fullName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags;
- (SMFolder*)addSubfolder:(NSString*)shortName fullName:(NSString*)fullName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags;

@end
