//
//  SMOpMoveMessages.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@interface SMOpMoveMessages : SMOperation

- (id)initWithUids:(MCOIndexSet*)uids srcRemoteFolderName:(NSString*)src dstRemoteFolderName:(NSString*)dst operationExecutor:(SMOperationExecutor*)operationExecutor;

@end
