//
//  SMOpRemoveLabel.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/5/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@class MCOIndexSet;

@interface SMOpRemoveLabel : SMOperation

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName label:(NSString*)label operationExecutor:(SMOperationExecutor*)operationExecutor;

@end
