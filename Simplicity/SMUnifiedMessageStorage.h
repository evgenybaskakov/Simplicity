//
//  SMUnifiedMessageStorage.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/8/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMAbstractMessageStorage.h"

@protocol SMAbstractLocalFolder;
@protocol SMAbstractAccount;

@class SMUnifiedAccount;
@class SMMessageStorage;

@interface SMUnifiedMessageStorage : SMUserAccountDataObject<SMAbstractMessageStorage>

- (id)initWithUserAccount:(SMUnifiedAccount *)account localFolder:(id<SMAbstractLocalFolder>)localFolder;

- (void)attachMessageStorage:(SMMessageStorage*)messageStorage;
- (void)detachMessageStorage:(SMMessageStorage*)messageStorage;

// These two methods are called from the attached message storages.
- (void)addMessageThread:(SMMessageThread*)messageThread;
- (void)removeMessageThread:(SMMessageThread*)messageThread;

@end
