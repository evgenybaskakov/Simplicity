//
//  SMFolderKind.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/18/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

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
