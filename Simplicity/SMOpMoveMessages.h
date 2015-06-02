//
//  SMOpMoveMessages.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SMOpMoveMessages : NSObject

- (id)initWithUids:(MCOIndexSet*)uids srcRemoteFolderName:(NSString*)src dstRemoteFolderName:(NSString*)dst;
- (void)start;
- (void)cancel;

@end
