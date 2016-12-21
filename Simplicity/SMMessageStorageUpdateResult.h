//
//  SMMesssageStorageUpdateResult.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/20/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

typedef NS_ENUM(NSInteger, SMMessageStorageUpdateResult) {
    SMMesssageStorageUpdateResultNone,
    SMMesssageStorageUpdateResultFlagsChanged,
    SMMesssageStorageUpdateResultStructureChanged
};
