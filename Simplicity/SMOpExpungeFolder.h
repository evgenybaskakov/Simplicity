//
//  SMOpExpungeFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/4/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMOperation.h"

@interface SMOpExpungeFolder : SMOperation

- (id)initWithRemoteFolder:(NSString*)remoteFolderName operationExecutor:(SMOperationExecutor*)operationExecutor;

@end
