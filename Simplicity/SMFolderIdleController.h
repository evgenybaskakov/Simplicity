//
//  SMFolderIdleController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/9/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMLocalFolder;

@interface SMFolderIdleController : NSObject

@property SMLocalFolder *watchedFolder;

- (id)initWithUserAccount:(SMUserAccount*)account folder:(SMLocalFolder*)folder;

- (void)startIdle;
- (void)stopIdle;
- (void)stopReachabilityMonitor;

@end
