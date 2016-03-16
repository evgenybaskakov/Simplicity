//
//  SMOpDeleteMessages.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/31/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@interface SMOpDeleteMessages : SMOperation

- (id)initWithUids:(MCOIndexSet*)uids remoteFolderName:(NSString*)remoteFolderName operationExecutor:(SMOperationExecutor*)operationExecutor;

@end
