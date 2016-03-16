//
//  SMOpSetMessageFlags.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/5/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@interface SMOpSetMessageFlags : SMOperation

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName kind:(MCOIMAPStoreFlagsRequestKind)kind flags:(MCOMessageFlag)flags operationExecutor:(SMOperationExecutor*)operationExecutor;

@end
