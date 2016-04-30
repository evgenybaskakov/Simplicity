//
//  SMUnifiedMailboxController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 4/28/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMMailboxController.h"

@class SMFolder;

@interface SMUnifiedMailboxController : NSObject<SMMailboxController>

@property SMFolder *selectedFolder;

@end
