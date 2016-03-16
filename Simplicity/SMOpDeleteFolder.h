//
//  SMOpDeleteFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/10/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import "SMOperation.h"

@interface SMOpDeleteFolder : SMOperation

- (id)initWithRemoteFolder:(NSString*)remoteFolderName operationExecutor:(SMOperationExecutor*)operationExecutor;

@end
